# openEO workarounds

Here we document workarounds that we had to implement to circumvent bugs or deficiencies in openEO / the CDSE openEO backend.

Each item is a TODO: delete the workaround from our code once the backend supports the native process.

## UDP parameters ignored in band math

Native comparisons (`>`, `>=`, `<=`) and arithmetic do not apply UDP
`Parameter` values. 
The backend silently fails!

- https://forum.dataspace.copernicus.eu/t/udp-parameter-not-applied/5282

### Workaround

A custom UDF `udf/binary_operator.py` in every UDP that thresholds a parameter.
Used in place of quick native band math.

Inline scripts use native `>` / `>=` / `<=` because they have concrete numbers.

## boolean `not` behaves like 2s complement signed integer bitwise not

`not` is applied as bitwise complement when the cube dtype is not a real
boolean (common after `merge_cubes`). There is no client-side way to
inspect the backend dtype.

- https://forum.dataspace.copernicus.eu/t/invert-not-of-a-pixel-mask/5323

### Workaround

`utils.logical_not()` is `(cube == 0)`.
This seems to work most of the time, but intermediate results must be checked manually.

## `sum` behaves like `XOR`

`sum` is applied as bitwise XOR when the cube dtype is boolean.
There is no client-side way to inspect the backend dtype.

- https://forum.dataspace.copernicus.eu/t/aggregate-temporal-period-with-sum-behaves-like-xor/5667

### Workaround

Multiply by 1.0 to coerce to float dtype.

## Inconsistent band names between CSV and Parquet

After `aggregate_spatial`, the resulting VectorCube has different band names when downloaded as CSV or Parquet.

- https://forum.dataspace.copernicus.eu/t/inconsistent-band-names-csv-parquet/5683

It is also not possible to manually relabel the bands.

### Workarounds

None.

## Band math across different cubes

`cube_a.band(...) & cube_b.band(...)` raises

> BandMathException: 'Band math' between bands of different data cubes is not supported yet.

### Workaround

First, `merge_cubes` into a single datacube, then band-math on the stacked cube. 
