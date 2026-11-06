"""
This is an openEO UDF (User Defined Function).
https://open-eo.github.io/openeo-python-client/udf.html

It targets the "python" runtime, version 3.11.
https://openeofed.dataspace.copernicus.eu/?discover=0&udf-runtime=Python
"""

from typing import TypedDict

import numpy as np
import xarray as xr

from openeo.udf import inspect

LOG_CODE = "binary_operator"


class Context(TypedDict):
    operator: str
    argument: float | int


OPERATORS = {
    "gte": np.greater_equal,
    "gt": np.greater,
    "lte": np.less_equal,
    "lt": np.less,
}


def apply_datacube(cube: xr.DataArray, context: Context) -> xr.DataArray:
    """
    Apply a binary (2 argument) operator to a cube.

    Example:

    ```
    context.operator = "gte"
    context.argument = 30
    result = (cube >= 30)
    ```

    Why not just use native openEO processes?
    Because there seems to be a bug related to Parameters.
    https://forum.dataspace.copernicus.eu/t/udp-parameter-not-applied/5282/3

    Arguments:
        cube: xarray DataArray
        context: user-provided arguments.
    """
    # parse and validate context
    operator_name = context["operator"]
    try:
        operator = OPERATORS[operator_name]
    except KeyError:
        raise ValueError(f"Invalid operator: {operator_name}")

    argument = context["argument"]
    if not isinstance(argument, float | int):
        raise TypeError(f"Invalid argument: {argument}")

    inspect(
        message=f"applying {operator_name}(cube, {argument})",
        code=LOG_CODE,
        level="debug",
    )

    return operator(cube, argument)
