"""Build AOI GeoJSON from the upstream and downstream shapefile zips.

Based on email correspondence 2026-10-22

> For the WQRI calculation, we buffered these lines to create polygons 
> defining the areas from which Sentinel-2 water pixels could be extracted. 
> We used a 500 m buffer with flat end caps to preserve the upstream and 
> downstream limits of each reach.
"""

import json

import geopandas as gpd
import pandas as pd

BUFFER_M = 500
UPSTREAM_AND_DOWNSTREAM_NAME = "upstream_and_downstream.geojson"
BBOX_NAME = "aoi_bbox.json"


def write_geojson(gdf: gpd.GeoDataFrame, name: str) -> None:
    """Write a GeoDataFrame as indented GeoJSON in EPSG:4326.

    GDAL's GeoJSON driver cannot indent, so this uses `GeoDataFrame.to_json`.

    Args:
        gdf: Features to write. They are reprojected to EPSG:4326.
        name: Output GeoJSON filename.
    """
    with open(name, "w") as f:
        f.write(gdf.to_crs("EPSG:4326").to_json(indent=2, drop_id=True))
        f.write("\n")


def shp_zip_to_geojson(zip_name: str, feature_name: str) -> tuple[str, str]:
    """Write a zone and its buffered copy as GeoJSON.

    The buffer is applied in the shapefile's CRS so that `BUFFER_M` is in
    metres.

    Args:
        zip_name: Zipped shapefile containing one zone feature.
        feature_name: Value stored in each output feature's `name` property,
            so the zones can be identified after they are merged.

    Returns:
        A tuple of the zone GeoJSON filename and the buffered GeoJSON
        filename.

    Raises:
        ValueError: If the shapefile does not contain exactly one feature, or
            its CRS is not projected.
    """
    # One .shp at the zip root; geopandas/pyogrio reads that directly.
    gdf = gpd.read_file(zip_name)
    if len(gdf) != 1:
        raise ValueError(f"{zip_name}: expected 1 feature, found {len(gdf)}")
    if not gdf.crs.is_projected:
        raise ValueError(f"{zip_name}: CRS {gdf.crs} is not projected; can't buffer in metres")

    stem = zip_name.removesuffix(".zip").removesuffix(".shp")
    gdf["name"] = feature_name
    out_name = f"{stem}.geojson"
    buffered_name = f"{stem}_buffered_{BUFFER_M}m.geojson"

    write_geojson(gdf, out_name)

    buffered = gdf.copy()
    buffered.geometry = gdf.buffer(BUFFER_M, cap_style="flat")
    write_geojson(buffered, buffered_name)

    return out_name, buffered_name


def merge_geojsons(paths: list[str], out_name: str) -> gpd.GeoDataFrame:
    """Merge GeoJSON files into one FeatureCollection.

    Features stay separate; they are not dissolved.

    Args:
        paths: GeoJSON files to merge.
        out_name: Output GeoJSON filename.

    Returns:
        The merged features.
    """
    frames = [gpd.read_file(path) for path in paths]
    merged = gpd.GeoDataFrame(pd.concat(frames, ignore_index=True), crs=frames[0].crs)
    write_geojson(merged, out_name)
    return merged


def write_bbox(gdf: gpd.GeoDataFrame) -> str:
    """Write an openEO bounding box that covers every feature in a collection.

    Args:
        gdf: Features to cover. They are reprojected to EPSG:4326.

    Returns:
        The output bounding box JSON filename.
    """
    gdf = gdf.to_crs("EPSG:4326")
    west, south, east, north = gdf.total_bounds
    bbox = {
        "west": west,
        "south": south,
        "east": east,
        "north": north,
        "crs": f"EPSG:{gdf.crs.to_epsg()}",
    }
    with open(BBOX_NAME, "w") as f:
        json.dump(bbox, f, indent=2)
        f.write("\n")
    return BBOX_NAME


def main() -> None:
    upstream, upstream_buffered = shp_zip_to_geojson(
        "upstream_0_15km.shp.zip", "upstream control zone"
    )
    downstream, downstream_buffered = shp_zip_to_geojson(
        "downstream_0_15km.zip", "downstream influence zone"
    )
    print(f"{upstream}, {upstream_buffered}")
    print(f"{downstream}, {downstream_buffered}")
    merged = merge_geojsons(
        [upstream_buffered, downstream_buffered], UPSTREAM_AND_DOWNSTREAM_NAME
    )
    print(f"upstream and downstream -> {UPSTREAM_AND_DOWNSTREAM_NAME}")
    print(f"bbox -> {write_bbox(merged)}")


if __name__ == "__main__":
    main()
