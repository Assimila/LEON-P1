import unittest

import numpy as np
import xarray as xr

from udf import binary_operator


class Test_binary_operator(unittest.TestCase):
    def setUp(self):
        self.input_xr = xr.DataArray(
            np.array(
                [
                    [10.0, 20.0, 30.0],
                    [40.0, 50.0, 60.0],
                    [70.0, 80.0, 90.0],
                ],
                dtype=float,
            ),
            dims=["y", "x"],
        )

    def test_gte(self):
        expected = xr.DataArray(
            np.array(
                [
                    [False, False, False],
                    [False, True, True],
                    [True, True, True],
                ],
                dtype=bool,
            ),
            dims=["y", "x"],
        )
        context = {"operator": "gte", "argument": 50}
        output_xr = binary_operator.apply_datacube(self.input_xr, context)
        xr.testing.assert_equal(output_xr, expected)

    def test_gt(self):
        expected = xr.DataArray(
            np.array(
                [
                    [False, False, False],
                    [False, False, True],
                    [True, True, True],
                ],
                dtype=bool,
            ),
            dims=["y", "x"],
        )
        context = {"operator": "gt", "argument": 50}
        output_xr = binary_operator.apply_datacube(self.input_xr, context)
        xr.testing.assert_equal(output_xr, expected)

    def test_lte(self):
        expected = xr.DataArray(
            np.array(
                [
                    [True, True, True],
                    [True, True, False],
                    [False, False, False],
                ],
                dtype=bool,
            ),
            dims=["y", "x"],
        )
        context = {"operator": "lte", "argument": 50}
        output_xr = binary_operator.apply_datacube(self.input_xr, context)
        xr.testing.assert_equal(output_xr, expected)

    def test_lt(self):
        expected = xr.DataArray(
            np.array(
                [
                    [True, True, True],
                    [True, False, False],
                    [False, False, False],
                ],
                dtype=bool,
            ),
            dims=["y", "x"],
        )
        context = {"operator": "lt", "argument": 50}
        output_xr = binary_operator.apply_datacube(self.input_xr, context)
        xr.testing.assert_equal(output_xr, expected)

    def test_argument_int_and_float(self):
        expected = xr.DataArray(
            np.array(
                [
                    [False, False, False],
                    [False, True, True],
                    [True, True, True],
                ],
                dtype=bool,
            ),
            dims=["y", "x"],
        )
        for argument in (50, 50.0):
            with self.subTest(argument=argument):
                context = {"operator": "gte", "argument": argument}
                output_xr = binary_operator.apply_datacube(self.input_xr, context)
                xr.testing.assert_equal(output_xr, expected)

    def test_invalid_operator(self):
        context = {"operator": "eq", "argument": 50}
        with self.assertRaises(ValueError):
            binary_operator.apply_datacube(self.input_xr, context)

    def test_invalid_argument_type(self):
        for argument in ("30", None):
            with self.subTest(argument=argument):
                context = {"operator": "gte", "argument": argument}
                with self.assertRaises(TypeError):
                    binary_operator.apply_datacube(self.input_xr, context)
