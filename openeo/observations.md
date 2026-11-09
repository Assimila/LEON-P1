## -

The water masking isn't great. especially downstream.
We're seeing quite a few land pixels.

## -

The monthly median composite does not necessarily produce valid values for all pixels.
Some pixels are cloud masked in all daily observations,
and hence masked in the monthly median composite.

This assumption cascades into the hotspot analysis.

> exceed_count = sum of monthly exceedance (0–12)

This is treated as an absolute threshold,
but a pixel may be cloud-masked (not sampled) in some months.

e.g. high rainfall in one month leads to high turbidity,
but also high cloud cover, so this event is not observed.

## -

The floor on `std` is 0.0001.
This will be applied in the Z-score calculation,
if there is only a single observation for a pixel in the baseline period.

On inspection, the smallest standard deviation of NDTI returned by the openEO worflow is 0.000742,
over the default baseline period and spatial extent,
so this fallback is not applied.
