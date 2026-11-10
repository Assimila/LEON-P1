"""
Build a static STAC Collection for JRC Global Surface Water (GSW) VER4-0
occurrence tiles.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen

import pystac
import rasterio as rio
from pystac import CatalogType, Collection, Item
from pystac.layout import CustomLayoutStrategy
from rio_stac.stac import create_stac_item

SCRIPT_DIR = Path(__file__).resolve().parent
STAC_DIR = SCRIPT_DIR / "STAC"
DESCRIPTION_PATH = SCRIPT_DIR / "description.txt"

TILES_INDEX_URL = (
    "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/"
    "GSWE/Aggregated/VER4-0/occurrence/tiles/"
)

# GSW 1.4 collates Landsat observations from 16 March 1984 through 31 December 2021.
START_DATETIME = "1984-03-16T00:00:00Z"
END_DATETIME = "2021-12-31T23:59:59Z"

RASTER_EXT_V2 = "https://stac-extensions.github.io/raster/v2.0.0/schema.json"

COLLECTION_ID = "jrc-gsw-ver4-0-occurrence"
COLLECTION_TITLE = "Joint Research Centre (JRC) Global Surface Water (GSW) — VER4-0 occurrence (tiles)"

# Tile names: occurrence-<minx>-<miny>.tif (10-digit coords in the index).
_TILE_NAME_RE = re.compile(r"occurrence-\d{10}-\d{10}\.tif")


def fetch_tile_filenames(index_url: str) -> list[str]:
    """GET directory index HTML and return sorted occurrence tile filenames."""
    req = Request(index_url)
    with urlopen(req, timeout=120) as resp:
        html = resp.read().decode("utf-8", errors="replace")
    seen: set[str] = set()
    for m in _TILE_NAME_RE.finditer(html):
        seen.add(m.group(0))
    return sorted(seen)


def build_item_for_tile(tile_url: str, tile_stem: str, description: str) -> pystac.Item:
    """Build a STAC Item for one JRC occurrence GeoTIFF tile.

    Args:
        tile_url: HTTPS URL of the `occurrence-*.tif` file on the JRC server.
        tile_stem: Item id and basename without extension (e.g.
            `occurrence-0000360000-0000520000`).
        description: Human-readable text stored in `common_metadata.description`.

    Returns:
        A `pystac.Item` with one `data` asset pointing at `tile_url` (absolute href).
    """
    with rio.open(tile_url) as dataset:
        item = create_stac_item(
            source=dataset,
            id=tile_stem,
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

        band = 0
        data_type = dataset.dtypes[band]
        nodata = dataset.nodata
        scale = dataset.scales[band]
        offset = dataset.offsets[band]

    item.common_metadata.description = description

    if RASTER_EXT_V2 not in item.stac_extensions:
        item.stac_extensions.append(RASTER_EXT_V2)

    (asset,) = item.assets.values()
    bands_obj: dict = {
        "name": "occurrence",
        "description": (
            "Percentage of valid observations in which surface water was present, "
            "from 0 to 100."
        ),
        "data_type": data_type,
    }
    if nodata is not None:
        bands_obj["nodata"] = nodata
    asset.extra_fields["bands"] = [bands_obj]
    asset.extra_fields["raster:scale"] = scale
    asset.extra_fields["raster:offset"] = offset

    return item


def stac_collection_href(collection: Collection, parent_dir: str, is_root: bool) -> str:
    """Path for this collection's JSON file when normalizing the STAC tree.

    Writes `collection.json` in the catalog root
    directory instead of a subdirectory named after the collection id.

    Args:
        collection:
        parent_dir: 
        is_root: Whether this collection is the normalize/save root

    Returns:
        Absolute path to `collection.json` under `parent_dir`.
    """
    return os.path.join(parent_dir, "collection.json")


def stac_item_href(item: Item, parent_dir: str) -> str:
    """Path for each Item JSON when normalizing the STAC tree.

    Puts every item under an `items/` subfolder next
    to `collection.json`, named `{item.id}.json`.

    Args:
        item: The STAC Item
        parent_dir: Absolute directory of the parent Collection on disk

    Returns:
        Absolute path to `items/<item.id>.json` under `parent_dir`.
    """
    return os.path.join(parent_dir, "items", f"{item.id}.json")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Generate STAC collection for JRC GSW VER4-0 occurrence tiles."
    )
    p.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help="Only process the first N tiles (after sorting). Default: all tiles.",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    t0 = time.perf_counter()

    description = DESCRIPTION_PATH.read_text(encoding="utf-8")

    print(f"Fetching tile list from {TILES_INDEX_URL!r} ...")
    all_tiles = fetch_tile_filenames(TILES_INDEX_URL)
    total_indexed = len(all_tiles)
    if total_indexed == 0:
        print("No occurrence-*.tif files found in directory listing.", file=sys.stderr)
        sys.exit(1)

    if args.limit is not None:
        if args.limit <= 0:
            print("--limit must be positive.", file=sys.stderr)
            sys.exit(1)
        tiles = all_tiles[: args.limit]
    else:
        tiles = all_tiles

    if STAC_DIR.exists():
        shutil.rmtree(STAC_DIR)
    STAC_DIR.mkdir(parents=True)

    start_dt = pystac.utils.str_to_datetime(START_DATETIME)
    end_dt = pystac.utils.str_to_datetime(END_DATETIME)

    collection = pystac.Collection(
        id=COLLECTION_ID,
        title=COLLECTION_TITLE,
        description=description.strip(),
        extent=pystac.Extent(
            spatial=pystac.SpatialExtent([[-180.0, -90.0, 180.0, 90.0]]),
            temporal=pystac.TemporalExtent([[start_dt, end_dt]]),
        ),
    )

    n_tiles = len(tiles)
    for i, name in enumerate(tiles, start=1):
        tile_url = TILES_INDEX_URL + name
        stem = Path(name).stem
        print(f"[{i}/{n_tiles}] {stem} ...")
        item = build_item_for_tile(tile_url, stem, description)
        item.validate()
        collection.add_item(item)

    collection.update_extent_from_items()

    root_href = os.fspath(STAC_DIR.resolve())
    strategy = CustomLayoutStrategy(
        collection_func=stac_collection_href,
        item_func=stac_item_href,
    )
    collection.normalize_and_save(
        root_href=root_href,
        catalog_type=CatalogType.SELF_CONTAINED,
        strategy=strategy,
    )

    collection.validate()

    elapsed = time.perf_counter() - t0
    per_tile = elapsed / n_tiles if n_tiles else float("nan")
    est_full = per_tile * total_indexed if n_tiles else float("nan")
    print(
        f"Done: {n_tiles} tile(s) in {elapsed:.1f}s "
        f"({per_tile:.2f}s/tile). "
        f"Index has {total_indexed} tiles; "
        f"extrapolated full run ~{est_full/60:.1f} min."
    )


if __name__ == "__main__":
    main()
