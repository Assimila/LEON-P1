import unittest
from collections.abc import Sequence

import numpy as np
import numpy.testing as npt
import pandas as pd
import xarray as xr
from openeo.metadata import Band, BandDimension, CollectionMetadata
from udf import monthly_climatology


def _default_context(**overrides):
    ctx = {
        "target_band": "NDTI",
        "baseline_start": "2018-01-01",
        "baseline_end": "2020-12-31",
        "std_min": 0.0001,
    }
    ctx.update(overrides)
    return ctx


def _make_cube(
    times: Sequence[pd.Timestamp],
    ndti_values: Sequence[float],
    ndci_scale: float = 0.0,
) -> xr.DataArray:
    """
    Build a small [x, y, t, bands] cube with one pixel.

    `ndti_values` must have one entry per timestamp in `times`.
    """
    ndti = np.asarray(ndti_values, dtype=float)
    if ndti.shape != (len(times),):
        raise ValueError("ndti_values length must match times")
    ndci = ndti * ndci_scale
    data = np.stack([ndti, ndci], axis=-1)[None, None, :, :]
    return xr.DataArray(
        data,
        dims=["x", "y", "t", "bands"],
        coords={
            "x": [0],
            "y": [0],
            "t": pd.to_datetime(times),
            "bands": ["NDTI", "NDCI"],
        },
    )


_BASELINE_JAN_NDTI = {2018: 1.0, 2019: 3.0, 2020: 5.0}
_BASELINE_FEB_NDTI = {2018: 10.0, 2019: 20.0, 2020: 30.0}
_BASELINE_MAR_NDTI = {2018: np.nan, 2019: 7.0, 2020: np.nan}
_JAN_NDTI = 99.0


def _synthetic_ndti(t: pd.Timestamp) -> float:
    """NDTI for one month; pattern matches `_three_baseline_years_plus_post_baseline`."""
    if t.month > 3:
        return np.nan
    if t.month == 1:
        try:
            return _BASELINE_JAN_NDTI[t.year]
        except KeyError:
            return _JAN_NDTI
    if t.month == 2:
        try:
            return _BASELINE_FEB_NDTI[t.year]
        except KeyError:
            return np.nan
    if t.month == 3:
        try:
            return _BASELINE_MAR_NDTI[t.year]
        except KeyError:
            return np.nan


def _three_baseline_years_plus_post_baseline() -> xr.DataArray:
    """
    Synthetic cube for climatology and broadcast tests.

    Time: monthly 2018-01 through 2020-12 (baseline window in `_default_context`),
    then full years 2021-2023 after baseline.

    NDTI: Jan/Feb in 2018-2020 use fixed values (medians 3 and 20, known population
    std). March has one baseline sample (2019 = 7.0) and NaN in 2018 and 2020.
    Other baseline months NaN. From 2021 onward, January is 99.0, other months NaN.
    """
    baseline_months = pd.date_range("2018-01-01", "2020-12-01", freq="MS")
    post_baseline_months = pd.date_range("2021-01-01", "2023-12-01", freq="MS")
    times = baseline_months.append(post_baseline_months).tolist()
    ndti = [_synthetic_ndti(t) for t in times]
    return _make_cube(times, ndti)


class Test_monthly_climatology(unittest.TestCase):
    def test_apply_metadata_band_names(self):
        meta = CollectionMetadata(
            {},
            dimensions=[
                BandDimension("bands", [Band(name="NDTI"), Band(name="NDCI")])
            ],
        )
        out = monthly_climatology.apply_metadata(meta, _default_context())
        self.assertEqual(out.band_names, ["NDTI", "NDTI_median", "NDTI_std"])

    def test_climatology_median_std_by_month(self):
        cube = _three_baseline_years_plus_post_baseline()
        out = monthly_climatology.apply_datacube(cube, _default_context())
        jan = out.sel(t="2018-01-01")
        feb = out.sel(t="2018-02-01")
        npt.assert_allclose(jan.sel(bands="NDTI_median").item(), 3.0)
        npt.assert_allclose(
            jan.sel(bands="NDTI_std").item(), np.std([1.0, 3.0, 5.0])
        )
        npt.assert_allclose(feb.sel(bands="NDTI_median").item(), 20.0)
        npt.assert_allclose(
            feb.sel(bands="NDTI_std").item(), np.std([10.0, 20.0, 30.0])
        )
        mar = out.sel(t="2018-03-01")
        npt.assert_allclose(mar.sel(bands="NDTI_median").item(), 7.0)
        npt.assert_allclose(mar.sel(bands="NDTI_std").item(), 0.0001)

    def test_broadcasts_to_all_timesteps(self):
        cube = _three_baseline_years_plus_post_baseline()
        out = monthly_climatology.apply_datacube(cube, _default_context())
        jan2018 = out.sel(t="2018-01-01").sel(bands="NDTI_median")
        jan2023 = out.sel(t="2023-01-01").sel(bands="NDTI_median")
        npt.assert_allclose(jan2018.item(), jan2023.item())
        npt.assert_allclose(
            out.sel(t="2023-01-01").sel(bands="NDTI").item(), 99.0
        )

    def test_std_min_floor_single_sample(self):
        times = [pd.Timestamp("2019-01-01")]
        cube = _make_cube(times, [4.2])
        ctx = _default_context(
            baseline_start="2019-01-01",
            baseline_end="2019-12-31",
            std_min=0.0001,
        )
        out = monthly_climatology.apply_datacube(cube, ctx)
        npt.assert_allclose(out.sel(bands="NDTI_median").item(), 4.2)
        npt.assert_allclose(out.sel(bands="NDTI_std").item(), 0.0001)

    def test_monthly_climatology_has_twelve_months(self):
        times = [pd.Timestamp("2018-01-01"), pd.Timestamp("2019-01-01")]
        cube = _make_cube(times, [1.0, 3.0])
        baseline = cube.sel(bands="NDTI", drop=True)
        med, std = monthly_climatology._monthly_climatology(baseline, 0.0001)
        self.assertEqual(med.sizes["month"], 12)
        self.assertEqual(std.sizes["month"], 12)
        npt.assert_array_equal(med.coords["month"].values, np.arange(1, 13))
        self.assertTrue(np.isnan(med.sel(month=2).item()))

    def test_sparse_baseline_missing_calendar_month_broadcasts_nan(self):
        """Baseline index has no February; Feb timesteps get NaN climatology bands."""
        times = [
            pd.Timestamp("2018-01-01"),
            pd.Timestamp("2019-01-01"),
            pd.Timestamp("2020-01-01"),
            pd.Timestamp("2021-02-01"),
        ]
        cube = _make_cube(times, [1.0, 3.0, 5.0, 42.0])
        out = monthly_climatology.apply_datacube(cube, _default_context())
        npt.assert_allclose(
            out.sel(t="2018-01-01").sel(bands="NDTI_median").item(), 3.0
        )
        feb = out.sel(t="2021-02-01")
        self.assertTrue(np.isnan(feb.sel(bands="NDTI_median").item()))
        self.assertTrue(np.isnan(feb.sel(bands="NDTI_std").item()))
        npt.assert_allclose(feb.sel(bands="NDTI").item(), 42.0)

    def test_baseline_all_nan_month_stays_nan(self):
        times = [
            pd.Timestamp("2018-03-01"),
            pd.Timestamp("2019-03-01"),
            pd.Timestamp("2020-03-01"),
        ]
        cube = _make_cube(times, [np.nan, np.nan, np.nan])
        out = monthly_climatology.apply_datacube(cube, _default_context())
        med = out.sel(t="2018-03-01").sel(bands="NDTI_median").item()
        std = out.sel(t="2018-03-01").sel(bands="NDTI_std").item()
        self.assertTrue(np.isnan(med))
        self.assertTrue(np.isnan(std))

    def test_output_dims_and_band_order(self):
        cube = _three_baseline_years_plus_post_baseline()
        out = monthly_climatology.apply_datacube(cube, _default_context())
        self.assertEqual(out.dims, ("x", "y", "t", "bands"))
        npt.assert_array_equal(out.coords["t"].values, cube.coords["t"].values)
        self.assertEqual(
            list(out.coords["bands"].values),
            ["NDTI", "NDTI_median", "NDTI_std"],
        )
