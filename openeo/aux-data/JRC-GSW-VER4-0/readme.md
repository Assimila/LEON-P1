# Joint Research Centre (JRC) Global Surface Water (GSW)

The reference GEE workflow uses version 1.4.
Specifically, the `occurrence` band is used.

Creodias says: STAC (available soon)
https://creodias.eu/eodata/global-surface-water-gsw/

Direct download from:
https://global-surface-water.appspot.com/download/

To match the dataset version from GEE we need this tile:
https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GSWE/Aggregated/VER5-0/occurrence/tiles/occurrence-0000360000-0000520000.tif

## VER4-0

Static STAC Collection for https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GSWE/Aggregated/VER4-0/occurrence/tiles/.

Each Item has one GeoTIFF asset with an absolute `href` on the JRC server.

## Regenerate STAC

From this directory

```bash
python stac-ify.py
```

### Timing / sampling

Use `--limit N` to process only the first `N` tiles (after sorting) and estimate runtime:

```bash
python stac-ify.py --limit 10
```
