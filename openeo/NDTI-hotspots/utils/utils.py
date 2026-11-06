import pprint
import sys

import openeo.processes
from openeo.api.process import Parameter

import openeo


def describe_collection(
    connection: openeo.Connection,
    collection_id: str,
    stream=sys.stdout,
):
    """
    Prints information about the collection

    The summaries key tells you what you can filter on using properties argument of load_collection.
    https://open-eo.github.io/openeo-python-client/api.html#openeo.rest.connection.Connection.load_collection
    """
    desc = connection.describe_collection(collection_id)
    for key, value in desc.items():
        print(f"{key}:", file=stream)
        pprint.pprint(value, stream=stream)


def percentile_cube(
    cube: openeo.DataCube,
    aoi,
    percentile,
) -> openeo.DataCube:
    """
    Calculate `percentile` over spatial `aoi`.

    The `aoi` argument is required because the openEO process `reduce_spatial` is not available 🙁

    Arguments:
        cube: The input data cube.
            Should have dimensions of a least (x, y).
        aoi: A geojson Parameter.
            Should contain a single polygon geometry over the area of interest.
            Pixels outside the aoi will be masked out.
        percentile: A number Parameter.
            Should have value between 0 and 1.

    Returns:
        A DataCube like `cube` but where the pixel values are equal to the calculated percentile.
    """
    if isinstance(percentile, Parameter):
        # https://forum.dataspace.copernicus.eu/t/udp-parameter-not-applied/5282/
        raise NotImplementedError("Percentile as Parameter is not supported")

    def calculate_percentile(data: openeo.processes.ProcessBuilder) -> openeo.processes.ProcessBuilder:
        return data.quantiles(probabilities=[percentile])

    # reduce_spatial not available
    percentile_vectorcube = cube.aggregate_spatial(
        geometries=aoi,
        reducer=calculate_percentile,
        # target_dimension argument not supported?!
        # target_dimension = "result",
    )

    # vector_to_raster is an "experimental" openEO process.
    # This implementation is based on
    # https://github.com/Open-EO/openeo-community-examples/blob/49033e3709be1d709bd5b0a918e94c1833964f6e/python/RankComposites/utils_BAP.py#L25
    # There is a known issue where metadata is not set correctly client side (openeo version 0.50.0)
    percentile_datacube = percentile_vectorcube.vector_to_raster(cube)

    return percentile_datacube


def convert_to_dB(cube: openeo.DataCube) -> openeo.DataCube:

    def calculate_dB(data: openeo.processes.ProcessBuilder):
        return 10.0 * data.log(10)
    
    return cube.apply(calculate_dB)


def drop_hidden_dimension(cube: openeo.DataCube, name: str) -> openeo.DataCube:
    """
    Workaround for https://forum.dataspace.copernicus.eu/t/load-stac-time-dimension-hidden/5312
    """
    if cube.metadata and name in cube.metadata.dimension_names():
        raise ValueError(f"Dimension {name} is not hidden")
    return cube.process(
        process_id="drop_dimension",
        arguments={"data": cube, "name": name},
        metadata=cube.metadata or None,
    )


def logical_not(cube: openeo.DataCube) -> openeo.DataCube:
    """
    There appear to be many situations where the datatype of a boolean cube
    is actually something else, or is interpreted as something else.

    There appears to be no client-side access to the actual backend datatype.

    When such a situation occurs, the logical not operation is incorrectly applied as a bitwise not!

    https://forum.dataspace.copernicus.eu/t/invert-not-of-a-pixel-mask/5323
    """
    return (cube == 0)


def t_index(cube: openeo.DataCube, index: int = 0) -> openeo.DataCube:
    """
    Reduce over time, retaining only the slice at `index`.
    Removes the time dimension, and all labels.
    
    Arguments:
        cube: The input data cube.
        index: The index of the time slice to retain. (zero-based)
    """
    def at_index(data: openeo.processes.ProcessBuilder) -> openeo.processes.ProcessBuilder:
        return data.array_element(index)

    return cube.reduce_dimension(
        dimension="t",
        reducer=at_index,
    )
