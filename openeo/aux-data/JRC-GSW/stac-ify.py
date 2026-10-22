"""
Creates a STAC item for the single tile of
Joint Research Centre (JRC) Global Surface Water (GSW)
that we need for the openEO workflow.
"""

import rasterio as rio
from rio_stac.stac import create_stac_item

TILE_URL = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GSWE/Aggregated/VER5-0/occurrence/tiles/occurrence-0000360000-0000520000.tif"
# GSW 1.4 collates Landsat observations from 16 March 1984 through 31 December 2021.
# A null datetime with start/end is the STAC way to record that range.
START_DATETIME = "1984-03-16T00:00:00Z"
END_DATETIME = "2021-12-31T23:59:59Z"

RASTER_EXT_V2 = "https://stac-extensions.github.io/raster/v2.0.0/schema.json"


with rio.open(TILE_URL) as dataset:
    item = create_stac_item(
        source=dataset,
        input_datetime=None,
        properties={
            "start_datetime": START_DATETIME,
            "end_datetime": END_DATETIME,
        },
        asset_roles=["data"],
        with_proj=True,
        with_raster=False,
        with_eo=False,
    )

    BAND = 0

    data_type = dataset.dtypes[BAND]
    nodata = dataset.nodata
    scale = dataset.scales[BAND]
    offset = dataset.offsets[BAND]

item.common_metadata.description = open("description.txt").read()
item.stac_extensions.append(RASTER_EXT_V2)
(asset,) = item.assets.values()

# STAC v1.1 field, not yet supported natively by pystac
bands_obj = {
    "name": "occurrence",
    "description": "Percentage of valid observations in which surface water was present, from 0 to 100.",
    "data_type": data_type,
}
if nodata is not None:
    # the correct way to indicate "there is no nodata encoding" is to omit the field(?)
    # https://github.com/radiantearth/stac-spec/issues/1401
    bands_obj["nodata"] = nodata
asset.extra_fields["bands"] = [bands_obj]
# openEO does not read these 2 fields from "bands"
asset.extra_fields["raster:scale"] = scale
asset.extra_fields["raster:offset"] = offset

item.validate()

item.save_object(dest_href="item.json")
