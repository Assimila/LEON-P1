"""
This is an openEO UDF (User Defined Function).
https://open-eo.github.io/openeo-python-client/udf.html

It targets the "python" runtime, version 3.11.
https://openeofed.dataspace.copernicus.eu/?discover=0&udf-runtime=Python
"""

import warnings
from typing import TypedDict

import numpy as np
import pandas as pd
import xarray as xr
from openeo.metadata import Band, CollectionMetadata

from openeo.udf import inspect

LOG_CODE = "monthly_climatology"


class Context(TypedDict):
    target_band: str

    # baseline period over which to compute the climatology
    # inclusive
    # iso8601 date string
    baseline_start: str
    baseline_end: str

    # replace small standard deviations with this value
    # e.g. where there is only a single observation in the baseline period
    std_min: float


BAND_DIM = "bands"
CALENDAR_MONTHS = np.arange(1, 13)


def _as_datetime_index(t_index: pd.Index) -> pd.DatetimeIndex:
    if isinstance(t_index, pd.DatetimeIndex):
        return t_index
    return pd.to_datetime(t_index)


def _calendar_months(t_coord: xr.DataArray) -> xr.DataArray:
    """Calendar month (1-12) for each time label.

    Returns:
        DataArray with dims [t], aligned to `t_coord`.
    """
    months = _as_datetime_index(t_coord.indexes["t"]).month
    return xr.DataArray(months, coords={"t": t_coord}, dims="t")


def _monthly_climatology(
    baseline: xr.DataArray, std_min: float
) -> tuple[xr.DataArray, xr.DataArray]:
    """Per calendar month: median and population std over baseline timesteps.

    Arguments:
        baseline: Single-band cube, typically [x, y, t].
        std_min: Lower bound applied to std where baseline samples exist.

    Returns:
        (clim_median, clim_std): two DataArrays with the same dimensionality.
        We drop the `t` dimension, and add a `month` dimension with 12 months.
        Months with no baseline timestep (or only NaN values) are NaN.
    """
    month = _calendar_months(baseline.coords["t"]).rename("month")
    by_month = baseline.assign_coords(month=month).groupby("month")

    clim_median = by_month.median(dim="t", skipna=True)

    # For an all-NaN month, numpy logs:
    # RuntimeWarning: Degrees of freedom <= 0 for slice.
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="Degrees of freedom <= 0 for slice.",
            category=RuntimeWarning,
        )
        clim_std = by_month.std(dim="t", skipna=True, ddof=0)

    # ensure we have all 12 months
    clim_median = clim_median.reindex(month=CALENDAR_MONTHS)
    clim_std = clim_std.reindex(month=CALENDAR_MONTHS)

    clim_std = clim_std.clip(min=std_min)

    return clim_median, clim_std


def _broadcast_to_timesteps(
    clim: xr.DataArray, t_coord: xr.DataArray
) -> xr.DataArray:
    """Map per-month climatology onto every time step.

    Arguments:
        clim: Climatology field with dims [x, y, month]
        t_coord: Time coordinate for the output series (typically all timesteps in the cube).

    Returns:
        DataArray with dims [x, y, t]. Each label along `t` gets the clim value for
        its calendar month (January timesteps all share the month=1 climatology).
    """
    month_of_t = _calendar_months(t_coord)
    return clim.sel(month=month_of_t)


def apply_datacube(cube: xr.DataArray, context: Context) -> xr.DataArray:
    """
    Compute a monthly median and standard deviation climatology.

    Assuming `cube` has dimensions [x, y, t, bands].
    Filter to target_band.

    This monthly climatology would normally have some "temporal" dimension
    of length 12 (Jan, Feb, ..., Dec).
    But here we retain the time (t) dimension as-is, broadcasting
    the climatology values back to match each individual time step.

    Arguments:
        cube: xarray DataArray
        context: user-provided arguments.

    Returns:
        xarray DataArray with dimensions [x, y, t, bands].
        bands = [target_band, target_band_median, target_band_std]
    """
    target_band = context["target_band"]
    baseline_start = context["baseline_start"]
    baseline_end = context["baseline_end"]
    std_min = context["std_min"]
    inspect(
        message=f"applying {LOG_CODE} to {target_band} with baseline={baseline_start} to {baseline_end} and std_min={std_min}",
        code=LOG_CODE,
        level="debug",
    )

    if BAND_DIM not in cube.dims:
        raise ValueError(f"Expected band dimension {BAND_DIM!r}, got dims {cube.dims!r}")
    if target_band not in cube.coords[BAND_DIM].values:
        raise ValueError(f"Band {target_band!r} not in {list(cube.coords[BAND_DIM].values)!r}")

    values = cube.sel({BAND_DIM: target_band}, drop=True)
    t = cube.coords["t"]
    t_index = cube.indexes["t"]
    if isinstance(t_index, pd.DatetimeIndex):
        t_dt = t_index
    else:
        inspect(
            message=(
                f"{LOG_CODE}: t index is {type(t_index).__name__} "
                f"(dtype={getattr(t_index, 'dtype', None)!r}), not DatetimeIndex; "
                "parsing with pd.to_datetime"
            ),
            code=LOG_CODE,
            level="warning",
        )
        t_dt = pd.to_datetime(t_index)
    baseline_start_ts = pd.Timestamp(baseline_start)
    baseline_end_ts = pd.Timestamp(baseline_end)
    in_baseline = (t_dt >= baseline_start_ts) & (t_dt <= baseline_end_ts)
    baseline = values.sel(t=t[in_baseline])

    clim_median, clim_std = _monthly_climatology(baseline, std_min)
    median_t = _broadcast_to_timesteps(clim_median, t)
    std_t = _broadcast_to_timesteps(clim_std, t)

    median_band = f"{target_band}_median"
    std_band = f"{target_band}_std"
    median_t = median_t.assign_coords(bands=median_band).expand_dims(BAND_DIM)
    std_t = std_t.assign_coords(bands=std_band).expand_dims(BAND_DIM)
    values_out = values.assign_coords(bands=target_band).expand_dims(BAND_DIM)

    out = xr.concat(
        [values_out, median_t, std_t],
        dim=BAND_DIM,
    )
    return out.transpose(*cube.dims)


def apply_metadata(
    metadata: CollectionMetadata, context: Context
) -> CollectionMetadata:
    """
    Returns the expected cube metadata, after applying this UDF, based on input metadata.
    """
    target_band = context["target_band"]
    metadata = metadata.filter_bands([target_band])
    metadata = metadata.append_band(
        Band(
            name=f"{target_band}_median",
        )
    )
    metadata = metadata.append_band(
        Band(
            name=f"{target_band}_std",
        )
    )
    return metadata
