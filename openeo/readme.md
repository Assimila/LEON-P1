# LEON P1 OpenEO Implementation

This is an openEO implementation of the LEON Pilot 1 workflow,
based on the Algorithm Theoretical Baseline Document,
and the reference Google Earth Engine scripts.

The openEO implementation is encapsulated in a single User Defined Process (UDP).
This does the majority of the EO data processing,
bracketed by some light pre and post processing.

# Repository Structure

```
openeo
├── AOI
│   ├── downstream_0_15km.zip
│   ├── shp_to_buffered_geojson.py
│   └── upstream_0_15km.shp.zip
├── NDTI-hotspots
│   ├── run-udp.ipynb
│   ├── script.ipynb
│   ├── udp.ipynb
│   ├── udp.json
│   ├── utils -> ../utils/
│   └── udf -> ../udf/
├── WQRI.ipynb
├── aux-data
│   └── JRC-GSW-VER4-0
│       ├── STAC
│       │   ├── collection.json
│       │   └── items
│       │       └── ...
│       ├── description.txt
│       ├── readme.md
│       └── stac-ify.py
├── environment.yml
├── observations.md
├── openEO-workarounds.md
├── readme.md
├── test-udf
│   └── ...
├── udf
│   └── ...
└── utils
    └── ...
```

## Step 1: `AOI/`

Here we preprocess the upstream and downstream river multilinestrings
into GeoJSON polygons.

These are combined into a single GeoJSON feature collection,
with each feature having a `name` property - either `"upstream control zone"` or `"downstream influence zone"`.

This feature collection is an input to the openEO User Defined Process (UDP).

## Step 2: `NDTI-hotspots/`

This is the openEO workflow.

- `udp.ipynb` — builds the User Defined Process
- `udp.json` — exported process graph (this is the serialised UDP)
- `script.ipynb` — the same workflow as an inline script, which returns intermediate results
- `run-udp.ipynb` — runs the UDP against the OpenEO backend

## Step 3: `WQRI.ipynb`

This notebook generates the Water Quality Risk Index (WQRI),
from the results from the openEO User Defined Process (UDP).

## `aux-data/`

This directory describes the auxiliary data used by the openEO workflow.

## `udf` and `test-udf`

These directories contain the User Defined Functions (UDFs) used by the openEO workflow.

- `udf` — the UDFs
- `test-udf` — the unit tests for the UDFs

# Quickstart

## create conda environment

```bash
cd openeo
conda env create -f environment.yml
```

make sure to activate the environment

```bash
conda activate LEON-P1
```

update the environment

```bash
conda env update -f environment.yml
```

## install nbstripout as git filter

```bash
nbstripout --install
```

## run unit tests

for the UDFs

```bash
cd openeo 
python -m unittest discover -t . -s test-udf/ -p "*.py"
```

# Why are the openEO results different from GEE?

Looking at the pixel climatology (monthly median), it is clear the the openEO workflow returns different results than the Google Earth Engine workflow.

Note: the openEO climatology is broadcast across many years, but you can extract this from the first 12 timesteps of intermediate file `0110_climatology.nc` variable `NDTI_median`.

Note: this is compared to a file `P1_BaselineMonthlyClimatology_2018_2022_v1.tif` which is in EPSG:4326.

## Data gaps

The GEE `COPERNICUS/S2_SR_HARMONIZED` collection has significant gaps in 2018 - a quick look counts only 8 scenes, compared to the 71 processed by the openEO workflow.

## Processing baseline

Prior to 2023 the GEE `COPERNICUS/S2_SR_HARMONIZED` collection mostly contains the originally processed L2A products (see `PROCESSING_BASELINE` metadata). 
Versions 02.11 – 04.00, 83 – 92% of scenes each year.
Only a few scenes are reprocessed to version 05.xx.

openEO on CDSE serves ESA's reprocessed Collection 1 for the same dates: version 05.xx. 
The reprocessing used an updated processing chain, including atmospheric correction and scene classification (SCL).
