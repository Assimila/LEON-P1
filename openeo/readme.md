# LEON P1 OpenEO Implementation

Assume that user has already defined 

- downstream influence zone
- upstream influence zone

as GeoJSON polygons, based on the HydroRIVERS and HydroBASINS datasets.

# create conda environment

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

# run unit tests

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
