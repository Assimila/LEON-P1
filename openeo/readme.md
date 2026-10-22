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
