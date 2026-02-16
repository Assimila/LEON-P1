// =================================================================================================
//  WATER QUALITY HOTSPOT WORKFLOW (SENTINEL-2 / GEE)
//  PURPOSE
//    Detect persistent freshwater turbidity (and optional chlorophyll) anomaly hotspots potentially
//    associated with mining impacts, using a monthly baseline climatology and annual persistence.
//
//  MAIN OUTPUTS
//    1) Baseline median climatology (NDTI) as ONE 12-band GeoTIFF: baseline_median_m01 ... m12
//    2) Annual exports (per year) as 3-band GeoTIFF:
//         - exceed_count        (0–12)  : number of anomalous months in year
//         - hotspot_YYYY        (0/1)   : persistent hotspot (after cluster filter)
//         - water_valid_YYYY    (0/1)   : validity mask (1 if pixel valid at least once in year)
//
//  NOTES
//    • “mask” in GEE is not the same as value 0. Masked pixels are NoData for computations.
//    • ArcGIS may not always honor GeoTIFF internal masks → exporting an explicit validity band helps.
// =================================================================================================


// =================================================================================================
//  0) MAP VIEW / INPUTS
// =================================================================================================

// AOI visualization (your AOI is expected as `geometry`; table is displayed for context)
// Centered on the Geometry bounding box
Map.addLayer(table, {}, 'table');

// =================================================================================================
//  1) USER PARAMETERS (centralized)
// =================================================================================================

// 1.1 Analysis period (all processing uses these dates)
var startDate = '2018-01-01';
var endDate   = '2025-12-31';

// 1.2 Baseline period (used to compute monthly climatology statistics)
var baselineStart = '2018-01-01';
var baselineEnd   = '2022-12-31';

// 1.3 Composite cadence (currently monthly only; variable kept for future extension)
var cadence = 'monthly';

// 1.4 Anomaly & persistence thresholds
var anomalyZThreshold = 2;          // z-score threshold to call an exceedance (monthly anomaly)
var minMonthsPerYearForHotspot = 2; // k-month persistence threshold (annual). At least k months in a year must exceed. 
var minContiguousPixels = 6;        // minimum hotspot cluster size in pixels (spatial coherence)
var effectThreshold = 0.40;         //fractional effect size threshold vs baseline (e.g. 0.40 = +40%). 
                                    //“Only count pixels as hotspots if their monthly value is at least 40% higher 
                                    //than the normal (baseline) value for that month.”

// Guidance for tweaking parameters: How to tighten/loosen results
//Fewer hotspots (stricter):  increase anomalyZThreshold (from 2.0 → 3.0), 
                            //increase minMonthsPerYearForHotspot (from 2 → 4), 
                            //increase minContiguousPixels (from 5 → 8), 
                            //or raise effectThreshold (from 0.3 → 0.5).
//More hotspots (looser): lower those values.
                            
                    

// ---------------------------
// a) Indicator choices
// ---------------------------

// Hotspot/anomaly indicator (used in z-score, annual hotspots, and annual exports)
var hotspotBand = 'NDTI';      // 'NDTI' or 'NDCI'

// Baseline climatology export indicator (12-band monthly medians)
// NOTE: keep separate from hotspotBand in case you want hotspots from NDTI but baseline export for NDCI too.
var climBand = 'NDTI';         // 'NDTI' or 'NDCI'


// ---------------------------
// b) Visualization parameters (map display only)
// ---------------------------

// Year to visualize on the map (does not affect exports unless you export the example layer)
var vizYear = 2020;

// Visualization dictionaries (tune to your AOI)
var vizNDTI = {min: -0.2, max: 0.6, palette: ['blue','green','yellow','orange','red']};
var vizNDCI = {min: -0.2, max: 0.6, palette: ['purple','white','green']};

// IMPORTANT: reproject() should be used ONLY for display to speed up map rendering.
// Do NOT use it for exports/analysis.
var mapDisplayCRS = 'EPSG:3857';
var mapDisplayScale = 200;


// ---------------------------
// c) Export parameters
// ---------------------------

var exportFolder = 'GEE_exports';
var exportScale = 10;
var exportMaxPixels = 1e13;

// Optional: toggle small “example” export (single band for vizYear) without touching main exports
var doExampleExport = false;


// =================================================================================================
//  2) SENTINEL-2 BAND DEFINITIONS
// =================================================================================================

// Sentinel-2 SR bands in COPERNICUS/S2_SR_HARMONIZED
// Sentinel-2 bands (SR scaled by 1e4 in GEE): each reflectance band in COPERNICUS/S2_SR must be 
// divided by 10 000 to obtain true reflectance (ρ: which range from 0 to 1). In GEE the data is stored 
// as integers scaled by a factor of 10,000 to improve performance and reduce file size

// Sentinel-2 SR bands in COPERNICUS/S2_SR_HARMONIZED
var bands = {
  blue:     'B2',
  green:    'B3',
  red:      'B4',
  redEdge:  'B5',
  redEdge2: 'B6',
  redEdge3: 'B7',
  nir:      'B8',
  nirA:     'B8A',
  swir1:    'B11',
  swir2:    'B12',
  scl:      'SCL'     // Scene Classification Layer (cloud/shadow/snow flags)
};

// List of reflectance bands to scale to 0–1
var bandNames = [
  bands.blue, bands.green, bands.red,
  bands.redEdge, bands.redEdge2, bands.redEdge3,
  bands.nir, bands.nirA, bands.swir1, bands.swir2
];

// =================================================================================================
//  3) PREPROCESSING FUNCTIONS
// =================================================================================================

// 3.1 Cloud / shadow masking using Sentinel-2 SCL
function maskS2sr(image) {
  var scl = image.select(bands.scl);
   // Mask SCL classes:
  //   3 = cloud shadow
  //   8 = cloud medium probability
  //   9 = cloud high probability
  //  10 = thin cirrus
  //  11 = snow/ice
  var mask = scl.neq(3)
    .and(scl.neq(8))
    .and(scl.neq(9))
    .and(scl.neq(10))
    .and(scl.neq(11));

  return image.updateMask(mask);
}

// 3.2 Convert scaled SR reflectance (0..10000) to physical reflectance (0..1)
function toReflectance(image) {
  var scaled = image.select(bandNames).divide(10000).rename(bandNames);
  return image.addBands(scaled, null, true); // overwrite original bands
}

// 3.3 Stable water mask (JRC Global Surface Water)
// Goal: remove land / riverbank noise and avoid month-to-month mask flicker
// use permanent water > threshold— relax threshold if too stric (from 50 to 10)
var gsw = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');
var occurrence = gsw.select('occurrence'); // 0..100
var stableWaterMask = occurrence.gte(10).clip(geometry); // water occurrence >=10%


// 3.4 Compute indices used in this workflow
//   • NDTI (turbidity proxy): (Red - Green) / (Red + Green)
//   • NDCI (chlorophyll proxy): (RedEdge - Red) / (RedEdge + Red)
//   • RRED: Red reflectance (optional diagnostic / potential single-band turbidity model input)
function computeIndices(image) {
  var r = image.select(bands.red);
  var re = image.select(bands.redEdge); // B5 ~705 nm
  
  var ndci = re.subtract(r).divide(re.add(r)).rename('NDCI'); // red-edge index, Chlorophyll-a proxy
  var ndti = image.select(bands.red).subtract(image.select(bands.green))
                    .divide(image.select(bands.red).add(image.select(bands.green)))
                    .rename('NDTI'); // simple turbidity proxy (can be replaced)
                    
  var rrsRed = r.rename('RRED');//For single-band turbidity models
  
  return image.addBands([ndci, ndti, rrsRed]);
}

// =================================================================================================
//  4) BUILD PREPROCESSED SENTINEL-2 COLLECTION (WATER-ONLY, INDICES ADDED)
// =================================================================================================

var s2Pre = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(geometry)
  .filterDate(startDate, endDate)
  .map(maskS2sr)
  .map(toReflectance)
  .map(function(img){ return img.updateMask(stableWaterMask); })// keep only water pixels
  .map(computeIndices);
  
//(Optional) sanity checks
print('S2 preprocessed (with indices) count:');
print(s2Pre.size());


// =================================================================================================
//  5) MONTHLY COMPOSITES (MEDIAN PER MONTH)
// =================================================================================================

// 5.1Produce monthly composite (median) for a given imageCollection
function monthlyComposites(collection, startStr, endStr) {
  var start = ee.Date(startStr);
  var end = ee.Date(endStr);
  
  // Number of months between start and end (exclusive of end boundary)
  var nMonths = end.difference(start, 'month').subtract(1);
  var months = ee.List.sequence(0, nMonths);
  
  
  return ee.ImageCollection.fromImages(
    months.map(function(m) {
      var startM = start.advance(m, 'month');
      var endM = startM.advance(1, 'month');
      
      // Median composite for robustness to outliers (cloud edge artifacts etc.)
      var comp = collection.filterDate(startM, endM)
        .median()
        .set('system:time_start', startM.millis())
        .set('year', startM.get('year'))
        .set('month', startM.get('month'));
      return comp;
    })
  );
}

// Build monthly composites from images that already have indices
var monthly = monthlyComposites(s2Pre, startDate, endDate);


// 5.2 Validity filter: remove months with no valid pixels
// Goal: prevent errors from operating on empty images (zero-band images)

function addValidPixelCount(img) {
  var nBands = img.bandNames().size();

  // anyValidMask = 1 where any band is unmasked; otherwise masked
  // If the image has bands, build a single-band mask = max mask across bands.
  // If not, return a fully masked dummy "valid" band.
  var anyValidMask = ee.Image(ee.Algorithms.If(
    nBands.gt(0),
    img.mask().reduce(ee.Reducer.max()).rename('valid'),
    ee.Image(0).rename('valid').updateMask(ee.Image(0))
  ));

  // Count valid pixels in AOI (sum of the binary valid mask)
  var validCount = anyValidMask.reduceRegion({
    reducer: ee.Reducer.sum(),
    geometry: geometry,
    scale: 10,
    maxPixels: 1e10
  }).getNumber('valid');

  return img.set('valid_count', validCount);
}

var monthlyWithCounts = monthly.map(addValidPixelCount);
var monthlyValid = monthlyWithCounts.filter(ee.Filter.gt('valid_count', 0));

// (Optional) sanity checks
print('Monthly (raw):');   print(monthly.size());
print('Monthly (valid):'); print(monthlyValid.size());
print('First valid monthly bands:');
print(ee.Image(monthlyValid.first()).bandNames());

// =================================================================================================
//  6) QUICK VISUAL CHECKS (OPTIONAL)
// =================================================================================================

// Pick the first non-empty monthly composite
var exampleNDTI = ee.Image(monthlyValid.first());

// Check what bands are available (helpful if you run into issues)
print('Bands on example monthly composite:');
print(exampleNDTI.bandNames());

// If NDTI exists, display it; if not, recompute it quickly
var hasNDTI = exampleNDTI.bandNames().contains('NDTI');
exampleNDTI = ee.Image(ee.Algorithms.If(hasNDTI, exampleNDTI, computeIndices(exampleNDTI)));

// Center the map on your AOI and add layer
Map.centerObject(geometry, 9);
Map.addLayer(
  exampleNDTI.select('NDTI'),
  vizNDTI,
  'Monthly Composite – NDTI (Turbidity Proxy)'
);

// Optional: show water mask overlay for context
Map.addLayer(stableWaterMask, {min:0, max:1, palette:['white','blue']}, 'Stable Water Mask');


// =================================================================================================
//  7) BASELINE CLIMATOLOGY (12 MONTHS, BASELINE PERIOD)
// =================================================================================================

// 7.1 Build baseline “monthly median per calendar month” image collection
function baselineMonthlyMedian(monthlyCollection, baselineStart, baselineEnd) {
  var base = monthlyCollection.filterDate(baselineStart, baselineEnd);
  var months = ee.List.sequence(1, 12);
  var byMonth = months.map(function(m) {
    var monthImgs = base.filter(ee.Filter.eq('month', m));
    // If a month never occurs in baseline (rare), return a masked constant
    return ee.Algorithms.If(
      monthImgs.size().gt(0),
      monthImgs.median().set('month', m),
      ee.Image(0).updateMask(ee.Image(0)).set('month', m) // empty placeholder
    );
  });
  return ee.ImageCollection.fromImages(byMonth);
}

var baseline = baselineMonthlyMedian(monthlyValid, baselineStart, baselineEnd);
print('Baseline months (should be up to 12):'); print(baseline.size());


// =================================================================================================
//  8) ANOMALY COMPUTATION (MONTHLY Z-SCORE)
// =================================================================================================
// Statistical measure of how many standard deviations a data point is away from the mean, 
//indicating its potential as an outlier. A large absolute Z-score, such as a value greater 
//than \(3\), suggests a data point is far from the average and is likely an anomaly. 


function computeZscore(img) {
  var month = ee.Number(img.get('month'));

  // Baseline median for the same calendar month
  var bImg  = ee.Image(baseline.filter(ee.Filter.eq('month', month)).first());

  var meanImg = bImg.select(hotspotBand);
  
    // Baseline stdDev for the same calendar month, computed across baseline years
  var baseColl = monthlyValid.filterDate(baselineStart, baselineEnd)
                             .filter(ee.Filter.eq('month', month));
  var stdImg = baseColl.select(hotspotBand).reduce(ee.Reducer.stdDev());
  
  // Z-score with guard against divide-by-zero
  var z = img.select(hotspotBand).subtract(meanImg)
             .divide(stdImg.max(0.0001))
             .rename('z_' + hotspotBand);

  return img.addBands(z);
}

var monthlyZ = monthlyValid.map(computeZscore);

// =================================================================================================
//  9) ANNUAL PERSISTENCE & HOTSPOT GENERATION
// =================================================================================================

// For each year:
//   A) monthly exceedance = (z > threshold) AND (effect size > threshold) AND valid pixel
//   B) exceed_count = sum of monthly exceedance (0–12)
//   C) hotspot binary = exceed_count ≥ k months
//   D) spatial coherence = remove tiny patches using connectedPixelCount
function annualHotspot(year) {        // fuction you call with the year you want to calculate teh hotspots
  year = ee.Number(year).toInt();     // <-- force integer (important for fromYMD and band naming)
  var ystr = year.format();  // <-- server-side string, e.g., "2020" (so teh band can be named hotspot_2020)

  var yearStart = ee.Date.fromYMD(year, 1, 1);
  var yearEnd   = yearStart.advance(1, 'year');
  
  // Monthly z-score images for this year
  var monthsInYear = monthlyZ.filterDate(yearStart, yearEnd);

  // Build exceedance images (per month): z > threshold AND effect-size > threshold
  var exceedColl = monthsInYear.map(function(img) {
    var month = ee.Number(img.get('month'));

    // Monthly baseline (mean) for the chosen hotspotBand (e.g., 'NDTI' or 'NDCI')
    var baseMonthImg = ee.Image(baseline.filter(ee.Filter.eq('month', month)).first());
    var meanImg = baseMonthImg.select(hotspotBand);

    // Fractional effect size = (current - median) / max(|median|, small)
    var denom = meanImg.max(1e-6);  // guard division-by-zero
    var effect = img.select(hotspotBand).subtract(meanImg)
                    .divide(denom)
                    .rename('effect');

    // Exceedance rules
    var exceedZ   = img.select('z_' + hotspotBand).gt(anomalyZThreshold);
    var exceedEff = effect.gt(effectThreshold);

    // Validity condition: only count pixels where the hotspotBand itself is valid
    // Must satisfy both & be on valid pixels
    var exceed = exceedZ.and(exceedEff).rename('exceed');
    var validMask = img.select(hotspotBand).mask();  // use band mask as validity
    return exceed.updateMask(validMask);
  });

  // Annual exceedance count (0–12)
  var exceedSum = exceedColl.sum().rename('exceed_count').set('year', year);
  
  // Hotspot = persistently anomalous (≥ k months)
  var hotspotBinary = exceedSum.gte(minMonthsPerYearForHotspot).selfMask();

  // Spatial coherence filtering (remove isolated pixels)
  var conn = hotspotBinary.connectedPixelCount(8, true);
  var hotspotClusters = hotspotBinary.updateMask(conn.gte(minContiguousPixels));

  // Name hotspot band hotspot_YYYY with a server-side string (no floats)
  var hotspotBandName = ee.String('hotspot_').cat(ystr);
  var hotspot = hotspotClusters.rename(hotspotBandName).set('year', year);

  // Return both exceed_count and hotspot_<year>
  return exceedSum.addBands(hotspot).set('year', year);
}


// Build the annual collection for all years in the analysis window

var startYear = ee.Number(ee.Date(startDate).get('year'));
var endYear   = ee.Number(ee.Date(endDate).advance(-1, 'day').get('year'));
var years     = ee.List.sequence(startYear, endYear);

var annualCollection = ee.ImageCollection.fromImages(
  years.map(function(y) { return annualHotspot(ee.Number(y)); })
);
 
print('Annual hotspot images:'); print(annualCollection.size());

// =================================================================================================
//  10) OPTIONAL VISUALIZATION OF ONE YEAR HOTSPOT
// =================================================================================================
Map.centerObject(geometry, 9);

// Show one valid monthly composite (NDTI or NDCI)
var exampleMonth = ee.Image(monthlyValid.first());
print('First valid monthly bands:'); print(exampleMonth.bandNames());
Map.addLayer(
  exampleMonth.select(hotspotBand),
  hotspotBand === 'NDTI' ? vizNDTI : vizNDCI,
  'Monthly Composite – ' + hotspotBand
);

// Show one hotspot year
var exampleHotspot = annualCollection.filter(ee.Filter.eq('year', vizYear)).first();
Map.addLayer(
  exampleHotspot.select('hotspot_' + vizYear)
    .reproject({crs: mapDisplayCRS, scale: mapDisplayScale}), // display-only
  {min: 0, max: 1, palette: ['white','red']},
  'Hotspot ' + vizYear + ' (z>' + anomalyZThreshold + ', ≥' + minMonthsPerYearForHotspot + ' months)'
);

// =================================================================================================
//  11) EXPORTS
// =================================================================================================

// -------------------------------------------------------------------------------------------------
//  EXPORT 0 (EXAMPLE): single-year hotspot band (simple export example)
// -------------------------------------------------------------------------------------------------
if (doExampleExport) {
  Export.image.toDrive({
    image: exampleHotspot.select('hotspot_' + vizYear),
    description: 'Hotspot_' + vizYear + '_' + hotspotBand,
    folder: exportFolder,
    region: geometry,
    scale: exportScale,
    maxPixels: exportMaxPixels
  });
}
  

// -------------------------------------------------------------------------------------------------
//  EXPORT 1: Baseline climatology as ONE 12-band GeoTIFF (NDTI)
//    • One band per calendar month: baseline_median_m01 ... baseline_median_m12
// -------------------------------------------------------------------------------------------------


// Build ONE 12-band image (baseline median per calendar month)
var baselineMed12_NDTI = ee.ImageCollection.fromImages(
  ee.List.sequence(1, 12).map(function(m) {
    m = ee.Number(m);
    var mm = m.format('%02d'); // server-side string OK when used via ee.String + rename below

    var monthImgs = monthlyValid
      .filterDate(baselineStart, baselineEnd)
      .filter(ee.Filter.eq('month', m))
      .select([climBand]);

    // Baseline median for this month (single band)
    var med = monthImgs.median().toFloat();

    // Fully masked placeholder if no data exist for this month
    var emptyMed = ee.Image(0).toFloat().updateMask(ee.Image(0));

    // Select real vs empty, then rename band to a FIXED month-specific name
    var bandName = ee.String('baseline_median_m').cat(mm);

    var out = ee.Image(ee.Algorithms.If(
      monthImgs.size().gt(0),
      med.rename(bandName),
      emptyMed.rename(bandName)
    ));

    return out;
  })
).toBands();

// Clean band names created by toBands() (it prefixes with IDs)
// This produces exactly: baseline_median_m01 ... baseline_median_m12
var cleanedNames = ee.List.sequence(1, 12).map(function(m) {
  m = ee.Number(m);
  return ee.String('baseline_median_m').cat(m.format('%02d'));
});

baselineMed12_NDTI = baselineMed12_NDTI.rename(cleanedNames);

// Sanity check
print('Baseline median climatology stack (NDTI) band names:');
print(baselineMed12_NDTI.bandNames());

// Export ONE multi-band GeoTIFF (12 bands)
Export.image.toDrive({
  image: baselineMed12_NDTI,
  description: 'BaselineMedian_12Bands_NDTI_' + baselineStart.slice(0, 4) + '-' + baselineEnd.slice(0, 4),
  folder: exportFolder,
  region: geometry,
  scale: exportScale,
  maxPixels: exportMaxPixels
});


// -------------------------------------------------------------------------------------------------
//  EXPORT 2: Annual exports (per year) as 3-band GeoTIFF
//    Band 1: exceed_count (0–12) [Byte]
//    Band 2: hotspot_YYYY (0/1)  [Byte]
//    Band 3: water_valid_YYYY (0/1) [Byte] (valid at least once that year)
// -------------------------------------------------------------------------------------------------

// Years (client-side loop for Export)
var startYear = parseInt(startDate.slice(0, 4), 10);
var endYear   = parseInt(endDate.slice(0, 4), 10);

// Function OUTSIDE loop (avoids "Don't make functions within a loop")
function validMaskTo01(img) {
  // Convert validity (mask) into an explicit 0/1 band
  // hotspotBand is present on monthlyZ images (e.g., NDTI or NDCI)
  return img.select(hotspotBand).mask().rename('valid');
}

for (var y = startYear; y <= endYear; y++) {

  var annualImg = ee.Image(
    annualCollection.filter(ee.Filter.eq('year', y)).first()
  );

  // Build a YEAR validity water mask:
  // 1 where pixel was valid (unmasked) in at least one month of the year
  var yearStart = ee.Date.fromYMD(y, 1, 1);
  var yearEnd   = yearStart.advance(1, 'year');

  var yearValid = monthlyZ
    .filterDate(yearStart, yearEnd)
    .map(validMaskTo01)              // each month -> 0/1 "valid" band
    .max()                           // max across months -> 1 if ever valid
    .rename('water_valid_' + y)      // explicit band name
    .toByte();                       // keep consistent type

  // Build 2-band image with consistent integer type
  var exportImg = annualImg
    .select(['exceed_count', 'hotspot_' + y])
    .toByte()
    .addBands(yearValid);            // add validity mask as third band

  Export.image.toDrive({
    image: exportImg,
    description: 'AnnualHotspot_ExceedCount_ValidMask_' + y + '_' + hotspotBand,
    folder: exportFolder,
    region: geometry,
    scale: exportScale,
    maxPixels: exportMaxPixels
  });
}
