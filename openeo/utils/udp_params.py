"""
OpenEO UDP parameters
"""

import json
from importlib import resources

from openeo.api.process import Parameter

with resources.files(__package__).joinpath("upstream_and_downstream.geojson").open() as f:
    _DEFAULT_GEOJSON = json.load(f)

UPSTREAM_AND_DOWNSTREAM = Parameter.geojson(
    name="upstream_and_downstream",
    description=(
        "GeoJSON FeatureCollection containing the upstream control zone "
        "and downstream influence zone. "
        "Features should be polygons with a corresponding 'name' property."
    ),
    default=_DEFAULT_GEOJSON,
)

TEMPORAL_EXTENT = Parameter.temporal_interval(
    name="temporal_extent",
    default=["2018-01-01", "2025-12-31"],
)

BASELINE_START = Parameter.date(
    name="baseline_start",
    description="Start of the baseline period for climatology",
    default="2018-01-01",
)

BASELINE_END = Parameter.date(
    name="baseline_end",
    description="End of the baseline period for climatology (inclusive).",
    default="2022-12-31",
)

WATER_OCCURRENCE_THRESHOLD = Parameter.number(
    name="water_occurrence_threshold",
    description=(
        "Minimum Joint Research Centre (JRC) Global Surface Water (GSW) "
        "occurrence (percent) for a pixel to be treated as water."
    ),
    default=10,
)

ANOMALY_Z_THRESHOLD = Parameter.number(
    name="anomaly_z_threshold",
    description=(
        "For a pixel-month to count as anomalous, its NDTI Z-score must be "
        "greater than or equal to this value."
    ),
    default=2,
)

EFFECT_THRESHOLD = Parameter.number(
    name="effect_threshold",
    description=(
        "For a pixel-month to count as anomalous, NDTI must be at least "
        "(1 + effect_threshold) times the climatological monthly median."
    ),
    default=0.40,
)

MIN_MONTHS_PER_YEAR_FOR_HOTSPOT = Parameter.integer(
    name="min_months_per_year_for_hotspot",
    description=(
        "Minimum number of anomalous months in a calendar year for a pixel "
        "to be flagged as a hotspot that year."
    ),
    default=2,
)

MIN_CONTIGUOUS_PIXELS = Parameter.integer(
    name="min_contiguous_pixels",
    description=(
        "Minimum 8-connected component size (pixels) for hotspot pixels. "
        "Isolated pixels are excluded."
    ),
    default=6,
)
