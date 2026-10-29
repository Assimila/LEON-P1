import unittest

import numpy as np
import numpy.testing as npt
import xarray as xr
from udf import connectivity_filter


def _default_context(**overrides):
    ctx = {"min_pixels": 2}
    ctx.update(overrides)
    return ctx


def _bool_cube_yx(data_yx: np.ndarray) -> xr.DataArray:
    """Build [y, x] cube from a 2D array indexed as [y, x]."""
    ny, nx = data_yx.shape
    return xr.DataArray(
        data_yx,
        dims=["y", "x"],
        coords={"y": np.arange(ny), "x": np.arange(nx)},
    )


def _bool_cube_tyx(data_tyx: np.ndarray, times) -> xr.DataArray:
    """Build [t, y, x] cube from a 3D array indexed as [t, y, x]."""
    _, ny, nx = data_tyx.shape
    return xr.DataArray(
        data_tyx,
        dims=["t", "y", "x"],
        coords={"t": times, "y": np.arange(ny), "x": np.arange(nx)},
    )


class TestConnectivityFilter(unittest.TestCase):
    def test_large_block_retained(self):
        # 3x3 block = 9 pixels; min_pixels=6 (must be < total grid pixels)
        data = np.ones((3, 3), dtype=bool)
        cube = _bool_cube_yx(data)
        out = connectivity_filter.apply_datacube(cube, _default_context(min_pixels=6))
        npt.assert_array_equal(out.values, np.ones((3, 3), dtype=bool))

    def test_isolated_pixels_removed(self):
        data = np.array(
            [
                [1, 0, 1],
                [0, 0, 0],
            ],
            dtype=bool,
        )
        cube = _bool_cube_yx(data)
        out = connectivity_filter.apply_datacube(cube, _default_context(min_pixels=2))
        expected = np.zeros_like(data)
        npt.assert_array_equal(out.values, expected)

    def test_diagonal_connectivity(self):
        # Pixels touch only on diagonals; 8-connectivity merges them into one component.
        data = np.array(
            [
                [1, 0, 0],
                [0, 1, 0],
                [0, 0, 1],
            ],
            dtype=bool,
        )
        cube = _bool_cube_yx(data)
        out = connectivity_filter.apply_datacube(cube, _default_context(min_pixels=3))
        npt.assert_array_equal(out.values, data)

    def test_mixed_large_and_small_components(self):
        # 2x2 block (4 px) + isolated single pixel; min_pixels=4
        data = np.array(
            [
                [1, 1, 0, 0, 0, 0],
                [1, 1, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 1, 0],
            ],
            dtype=bool,
        )
        cube = _bool_cube_yx(data)
        out = connectivity_filter.apply_datacube(cube, _default_context(min_pixels=4))
        expected = np.array(
            [
                [1, 1, 0, 0, 0, 0],
                [1, 1, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
            ],
            dtype=bool,
        )
        npt.assert_array_equal(out.values, expected)

    def test_independent_per_time_slice(self):
        slice_a = np.array([[1, 0], [0, 0]], dtype=bool)
        slice_b = np.array([[1, 1], [1, 1]], dtype=bool)
        data = np.stack([slice_a, slice_b], axis=0)
        cube = _bool_cube_tyx(data, times=["2020", "2021"])
        out = connectivity_filter.apply_datacube(cube, _default_context(min_pixels=2))
        expected = np.stack(
            [
                np.zeros((2, 2), dtype=int),
                slice_b,
            ],
            axis=0,
        )
        npt.assert_array_equal(out.values, expected)

    def test_float_input_nan_not_labeled(self):
        # NaN and 0 are invalid; only finite non-zero pixels join components.
        data = np.array(
            [
                [1.0, 1.0, np.nan, np.nan],
                [1.0, 1.0, np.nan, 0.0],
                [np.nan, np.nan, np.nan, np.nan],
                [np.nan, np.nan, np.nan, 1.0],
            ],
            dtype=float,
        )
        cube = _bool_cube_yx(data)

        # Mute openEO inspect() user logger for the expected dtype warning
        with self.assertLogs("openeo.udf.debug.user", level="WARNING"):
            out = connectivity_filter.apply_datacube(cube, _default_context(min_pixels=4))

        expected = np.array(
            [
                [True, True, False, False],
                [True, True, False, False],
                [False, False, False, False],
                [False, False, False, False],
            ],
            dtype=bool,
        )
        npt.assert_array_equal(out.values, expected)
        npt.assert_array_equal(out.values[np.isnan(data)], False)
