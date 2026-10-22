"""Build a bounding-box polygon for each AOI zone.

1. Read each zip. Each shapefile must contain one feature.
2. Reproject that feature to EPSG:4326.
3. Replace the geometry with its bounding-box polygon. Properties are kept.
4. Write one GeoJSON rectangle per zone.
5. Merge those rectangles into upstream_and_downstream.geojson.
6. Write an openEO bounding box of that collection to aoi_bbox.json.
"""

import json

import geopandas as gpd
import pandas as pd

UPSTREAM_AND_DOWNSTREAM_NAME = "upstream_and_downstream.geojson"
AOI_BBOX_NAME = "aoi_bbox.json"


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


def shp_zip_to_bbox(zip_name: str, feature_name: str) -> str:
    """Write one zone as an EPSG:4326 bounding-box polygon.

    Args:
        zip_name: Zipped shapefile containing one zone feature.
        feature_name: Value stored in the output feature's `name` property,
            so the zones can be identified after they are merged.

    Returns:
        The bounding-box GeoJSON filename.

    Raises:
        ValueError: If the shapefile does not contain exactly one feature, or
            it has no CRS.
    """
    # One .shp at the zip root; geopandas/pyogrio reads that directly.
    gdf = gpd.read_file(zip_name)
    if len(gdf) != 1:
        raise ValueError(f"{zip_name}: expected 1 feature, found {len(gdf)}")
    if gdf.crs is None:
        raise ValueError(f"{zip_name}: shapefile has no CRS")

    gdf = gdf.to_crs("EPSG:4326")
    gdf["name"] = feature_name
    gdf.geometry = gdf.geometry.envelope

    stem = zip_name.removesuffix(".zip").removesuffix(".shp")
    out_name = f"{stem}_bbox.geojson"
    write_geojson(gdf, out_name)
    return out_name


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
    with open(AOI_BBOX_NAME, "w") as f:
        json.dump(bbox, f, indent=2)
        f.write("\n")
    return AOI_BBOX_NAME


def main() -> None:
    upstream = shp_zip_to_bbox("upstream_0_15km.shp.zip", "upstream control zone")
    downstream = shp_zip_to_bbox("downstream_0_15km.zip", "downstream influence zone")
    print(upstream)
    print(downstream)
    merged = merge_geojsons([upstream, downstream], UPSTREAM_AND_DOWNSTREAM_NAME)
    print(f"upstream and downstream -> {UPSTREAM_AND_DOWNSTREAM_NAME}")
    print(f"bbox -> {write_bbox(merged)}")


if __name__ == "__main__":
    main()
