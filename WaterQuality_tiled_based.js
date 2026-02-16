
// =================================================================================================
// TILE-BASED HOTSPOT WORKFLOW + MOSAIC / TILE EXPORTS
// =================================================================================================
// GOAL
//   Run the same monthly-anomaly → annual-persistence hotspot workflow, but at scale by tiling the AOI.
//   Tiles are ~10 km x 10 km (≈100 km²) in a meter CRS, clipped to the AOI bounding box and filtered
//   to only those intersecting the AOI.
//
// DESIGN CONSTRAINTS (why the code is structured like this)
//   • Avoid 0-band images (common when monthly collections are empty):
//       - use masked templates so monthly/annual reducers always see expected band sets.
//   • Keep TUNABLE parameters up top (first ~30-ish lines) for reproducibility.
//
// OUTPUTS (per tile)
//   1) Baseline median climatology (12 bands): baseline_median_m01..m12 (for climBand)
//   2) Annual export (3 bands) for one chosen year:
//        - exceed_count (0–12)  [Byte]
//        - hotspot_year (0/1)  [Byte]
//        - water_valid (0/1)   [Byte]  (valid at least once in that year)
//
// ---------------------------------------------------------------------------------------------
// TIP: INSPECT TILE NAMES (tile_id) USING THE INSPECTOR
//   1) In the Code Editor, open the "Inspector" tab (top-right panel).
//   2) Click on any tile polygon on the map.
//   3) In the Inspector results, expand the clicked Feature → check its properties.
//   4) The property "tile_id" shows the tile name (e.g., tile_4_1).
// =================================================================================================


// =================================================================================================
// 1) USER PARAMETERS (TUNE THESE) 
// =================================================================================================

// ---------------------------
// A) AOI / data sources
// ---------------------------
var aoiAssetId = 'projects/unep-wcmc/hybas_lev08_lithium_mines_boundary'; // AOI FeatureCollection
var gswAssetId = 'JRC/GSW1_4/GlobalSurfaceWater';                         // stable water reference

// ---------------------------
// B) Tiling (scale / performance)
// ---------------------------
var tileSideMeters = 10000;              // 10 km tiles (~100 km²)
var gridCrs = 'EPSG:3857';               // meter-based CRS used for tiling grid

// ---------------------------
// C) Time windows (analysis + baseline)
// ---------------------------
var startDate = '2018-01-01';
var endDate   = '2025-12-31';
var baselineStart = '2018-01-01';
var baselineEnd   = '2022-12-31';

// ---------------------------
// D) Hotspot detection thresholds
// ---------------------------
var anomalyZThreshold = 2;
var effectThreshold = 0.40;              // fractional effect size threshold vs baseline
var minMonthsPerYearForHotspot = 2;      // persistence threshold
var minContiguousPixels = 6;             // spatial coherence / cluster size

// ---------------------------
// E) Indicators
// ---------------------------
var hotspotBand = 'NDTI';                // 'NDTI' or 'NDCI' (controls anomaly + annual hotspot)
var climBand    = 'NDTI';                // baseline climatology export band (can differ from hotspotBand)

// ---------------------------
// F) Tile export controls (batching)
// ---------------------------
// Choose ONE year for annual outputs in this run
var chosenYear = 2023;

// Export settings
var exportFolder = 'GEE_exports_tiles';
var exportScale  = 10;
var exportMaxPixels = 1e13;

// Batch controls (avoid launching too many tasks)
var startTile = 0;          // 0, 25, 50, ...
var nTilesThisBatch = 51;   // number of tiles to export in this run



// =================================================================================================
// 2) LOAD AOI + BUILD TILING GRID (FIXED LOGIC)
// =================================================================================================

// 2.1 Load AOI
var aoiFc = ee.FeatureCollection(aoiAssetId);
var aoiGeom = aoiFc.geometry();

// 2.2 Visualize AOI (optional)
Map.centerObject(aoiFc, 7);
Map.addLayer(aoiFc.style({color: 'red', fillColor: '00000000', width: 2}), {}, 'AOI boundary');

// 2.3 Bounding box around AOI (for tiling)
var bbox = aoiGeom.bounds();
var bboxFc = ee.FeatureCollection([ee.Feature(bbox)]);
Map.addLayer(bboxFc.style({color: 'yellow', fillColor: '00000000', width: 3}), {}, 'AOI bounding box');

print('AOI feature count:', aoiFc.size());
print('AOI bounds geometry:', bbox);

// 2.4 Project bbox to a meter CRS for consistent tiling in meters
var bboxProj = bbox.transform(gridCrs, 1);

// Extract projected bounds (xmin,ymin,xmax,ymax)
var ring = ee.List(ee.List(bboxProj.coordinates()).get(0));
var xmin = ee.Number(ee.List(ring.get(0)).get(0));
var ymin = ee.Number(ee.List(ring.get(0)).get(1));
var xmax = ee.Number(ee.List(ring.get(2)).get(0));
var ymax = ee.Number(ee.List(ring.get(2)).get(1));

var width  = xmax.subtract(xmin);
var height = ymax.subtract(ymin);
var nx = width.divide(tileSideMeters).ceil();
var ny = height.divide(tileSideMeters).ceil();

print('Tile side (m):', tileSideMeters);
print('Tiles in X:', nx, 'Tiles in Y:', ny, 'Total:', nx.multiply(ny));

// 2.5 Create tile grid clipped to bbox extent (tiles don’t overshoot bbox)
var xList = ee.List.sequence(0, nx.subtract(1));
var yList = ee.List.sequence(0, ny.subtract(1));

var tiles = ee.FeatureCollection(
  yList.map(function(j) {
    j = ee.Number(j);
    return xList.map(function(i) {
      i = ee.Number(i);

      var x0 = xmin.add(i.multiply(tileSideMeters));
      var y0 = ymin.add(j.multiply(tileSideMeters));

      var x1 = x0.add(tileSideMeters).min(xmax);
      var y1 = y0.add(tileSideMeters).min(ymax);

      var rect = ee.Geometry.Rectangle([x0, y0, x1, y1], gridCrs, false);
      var areaKm2 = rect.area(1).divide(1e6);

      return ee.Feature(rect, {
        tile_i: i,
        tile_j: j,
        tile_id: ee.String('tile_')
          .cat(i.toInt().format())
          .cat('_')
          .cat(j.toInt().format()),
        area_km2: areaKm2
      });
    });
  }).flatten()
);

// 2.6 Keep only tiles that intersect the AOI
var tilesIntersectingAOI = tiles.filterBounds(aoiGeom);

// Optional: show tiles (inspect tile_id with Inspector)
Map.addLayer(
  tilesIntersectingAOI,
  {color: '00FFFF'},
  'Tiles (inspect tile_id)',
  true,
  0.8
);

print('Tiles intersecting AOI:', tilesIntersectingAOI.size());
print('Tile area (km²) stats:', tilesIntersectingAOI.aggregate_stats('area_km2'));



// =================================================================================================
// 3) S2 BANDS + SHARED GLOBAL DATA 
// =================================================================================================

// Sentinel-2 bands (same as original)
var bands = {
  blue: 'B2', green: 'B3', red: 'B4',
  redEdge: 'B5', redEdge2: 'B6', redEdge3: 'B7',
  nir: 'B8', nirA: 'B8A', swir1: 'B11', swir2: 'B12',
  scl: 'SCL'
};

var bandNames = [
  bands.blue, bands.green, bands.red,
  bands.redEdge, bands.redEdge2, bands.redEdge3,
  bands.nir, bands.nirA, bands.swir1, bands.swir2
];

// Global Surface Water occurrence (global, reused per tile)
var gsw = ee.Image(gswAssetId);
var occurrence = gsw.select('occurrence'); // 0..100



// =================================================================================================
// 4) SHARED FUNCTIONS 
// =================================================================================================

// 4.1 Cloud/shadow mask using S2 SCL
function maskS2sr(image) {
  var scl = image.select(bands.scl);
  var mask = scl.neq(3).and(scl.neq(8)).and(scl.neq(9)).and(scl.neq(10)).and(scl.neq(11));
  return image.updateMask(mask);
}

// 4.2 Convert SR (0..10000) to reflectance (0..1)
function toReflectance(image) {
  var scaled = image.select(bandNames).divide(10000).rename(bandNames);
  return image.addBands(scaled, null, true);
}

// 4.3 Compute indices used (NDCI, NDTI, RRED)
function computeIndices(image) {
  var r = image.select(bands.red);
  var re = image.select(bands.redEdge);

  var ndci = re.subtract(r).divide(re.add(r)).rename('NDCI');
  var ndti = image.select(bands.red).subtract(image.select(bands.green))
    .divide(image.select(bands.red).add(image.select(bands.green)))
    .rename('NDTI');

  var rrsRed = r.rename('RRED');
  return image.addBands([ndci, ndti, rrsRed]);
}

// 4.4 Baseline monthly median (12-image collection) (unchanged)
function baselineMonthlyMedian(monthlyCollection, baselineStart, baselineEnd) {
  var base = monthlyCollection.filterDate(baselineStart, baselineEnd);
  var months = ee.List.sequence(1, 12);

  var byMonth = months.map(function(m) {
    var monthImgs = base.filter(ee.Filter.eq('month', m));
    return ee.Algorithms.If(
      monthImgs.size().gt(0),
      monthImgs.median().set('month', m),
      ee.Image(0).updateMask(ee.Image(0)).set('month', m)
    );
  });

  return ee.ImageCollection.fromImages(byMonth);
}



// =================================================================================================
// 5) TILE-SAFE MONTHLY PIPELINE (NEVER RETURNS 0-BAND IMAGES)
// =================================================================================================

// 5.1 Monthly template (masked, with expected bands)
function makeMonthlyTemplate(tileGeom) {
  return ee.Image.cat([
    ee.Image(0).rename('NDCI'),
    ee.Image(0).rename('NDTI'),
    ee.Image(0).rename('RRED')
  ]).updateMask(ee.Image(0)).clip(tileGeom);
}

// 5.2 Band-safe monthly composites for a tile (if empty month -> template)
function monthlyCompositesSafeTile(collection, startStr, endStr, tileGeom) {
  var start = ee.Date(startStr);
  var end = ee.Date(endStr);
  var nMonths = end.difference(start, 'month').subtract(1);
  var months = ee.List.sequence(0, nMonths);

  var monthlyTemplate = makeMonthlyTemplate(tileGeom);

  return ee.ImageCollection.fromImages(
    months.map(function(m) {
      var startM = start.advance(m, 'month');
      var endM = startM.advance(1, 'month');

      var monthColl = collection.filterDate(startM, endM);

      var comp = ee.Image(ee.Algorithms.If(
        monthColl.size().gt(0),
        monthColl.median().select(['NDCI','NDTI','RRED']),
        monthlyTemplate
      ));

      return comp
        .set('system:time_start', startM.millis())
        .set('year', startM.get('year'))
        .set('month', startM.get('month'));
    })
  );
}

// 5.3 Tile validity metric (cheap, coarse scale) for filtering empty months
function addValidPixelCountTile(img, tileGeom) {
  var anyValidMask = img.mask().reduce(ee.Reducer.max()).rename('valid');

  var validCount = anyValidMask.reduceRegion({
    reducer: ee.Reducer.sum(),
    geometry: tileGeom,
    scale: 120,        // coarse for speed in tiles
    bestEffort: true,
    maxPixels: 1e9
  }).getNumber('valid');

  validCount = ee.Number(ee.Algorithms.If(validCount, validCount, 0));
  return img.set('valid_count', validCount);
}

// 5.4 Build monthlyValid for a tile (reused by baseline + annual outputs)
function buildMonthlyValidForTile(tileGeom) {
  var stableWaterMask = occurrence.gte(10).clip(tileGeom);

  var s2Pre = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
    .filterBounds(tileGeom)
    .filterDate(startDate, endDate)
    .map(maskS2sr)
    .map(toReflectance)
    .map(function(img){ return img.updateMask(stableWaterMask); })
    .map(computeIndices);

  var monthly = monthlyCompositesSafeTile(s2Pre, startDate, endDate, tileGeom);

  var monthlyValid = monthly
    .map(function(img){ return addValidPixelCountTile(img, tileGeom); })
    .filter(ee.Filter.gt('valid_count', 0));

  return monthlyValid;
}



// =================================================================================================
// 6) PER-TILE OUTPUT BUILDERS (BASELINE 12-BAND + ANNUAL 3-BAND)
// =================================================================================================

// 6.1 OUTPUT 1 (per tile): baseline median climatology as 12-band image (m01..m12)
function buildBaseline12ForTile(tileGeom, climBandName, baseStart, baseEnd) {
  var monthlyValid = buildMonthlyValidForTile(tileGeom);

  var baselineMed12 = ee.ImageCollection.fromImages(
    ee.List.sequence(1, 12).map(function(m) {
      m = ee.Number(m);
      var mm = m.format('%02d');

      var monthImgs = monthlyValid
        .filterDate(baseStart, baseEnd)
        .filter(ee.Filter.eq('month', m))
        .select([climBandName]);

      var med = monthImgs.median().toFloat();
      var empty = ee.Image(0).toFloat().updateMask(ee.Image(0));

      var bandName = ee.String('baseline_median_m').cat(mm);

      return ee.Image(ee.Algorithms.If(
        monthImgs.size().gt(0),
        med.rename(bandName),
        empty.rename(bandName)
      ));
    })
  ).toBands();

  // Clean toBands() prefixes
  var cleanNames = ee.List.sequence(1, 12).map(function(m) {
    m = ee.Number(m);
    return ee.String('baseline_median_m').cat(m.format('%02d'));
  });

  return baselineMed12.rename(cleanNames).clip(tileGeom);
}

// 6.2 OUTPUT 2 (per tile, per year): annual multiband (exceed_count, hotspot_year, water_valid)
function buildAnnualExportForTile(tileGeom, yearToExport) {
  yearToExport = ee.Number(yearToExport).toInt();

  var monthlyValid = buildMonthlyValidForTile(tileGeom);
  var hasAnyMonth = monthlyValid.size().gt(0);

  // Template (prevents 0-band failures)
  var empty = ee.Image(0).updateMask(ee.Image(0)).clip(tileGeom);
  var annualTemplate = empty.rename('exceed_count').toByte()
    .addBands(empty.rename('hotspot_year').toByte())
    .addBands(empty.rename('water_valid').toByte());

  // Baseline (12-image collection)
  var baseline = baselineMonthlyMedian(monthlyValid, baselineStart, baselineEnd);

  // ---- Z-score (tile-local) ----
  function computeZscoreTile(img) {
    var month = ee.Number(img.get('month'));
    var bImg  = ee.Image(baseline.filter(ee.Filter.eq('month', month)).first());

    var meanImg = bImg.select(hotspotBand);

    var baseColl = monthlyValid
      .filterDate(baselineStart, baselineEnd)
      .filter(ee.Filter.eq('month', month))
      .select(hotspotBand);

    // Safe stdDev (ensures a band exists even if baseColl empty)
    var stdImg = ee.Image(ee.Algorithms.If(
      baseColl.size().gt(0),
      baseColl.reduce(ee.Reducer.stdDev()).select([hotspotBand + '_stdDev']),
      ee.Image(0).rename(hotspotBand + '_stdDev')
    ));

    var z = img.select(hotspotBand)
      .subtract(meanImg)
      .divide(stdImg.max(0.0001))
      .rename('z_' + hotspotBand);

    return img.addBands(z);
  }

  var monthlyZ = ee.ImageCollection(ee.Algorithms.If(
    hasAnyMonth,
    monthlyValid.map(computeZscoreTile),
    ee.ImageCollection([])
  ));

  // ---- Target year subset ----
  var yearStart = ee.Date.fromYMD(yearToExport, 1, 1);
  var yearEnd   = yearStart.advance(1, 'year');
  var monthsInYear = monthlyZ.filterDate(yearStart, yearEnd);

  // ---- Monthly exceedances ----
  var exceedColl = monthsInYear.map(function(img) {
    var month = ee.Number(img.get('month'));
    var baseMonthImg = ee.Image(baseline.filter(ee.Filter.eq('month', month)).first());
    var meanImg = baseMonthImg.select(hotspotBand);

    var denom = meanImg.max(1e-6);
    var effect = img.select(hotspotBand).subtract(meanImg).divide(denom);

    var exceedZ   = img.select('z_' + hotspotBand).gt(anomalyZThreshold);
    var exceedEff = effect.gt(effectThreshold);

    var exceed = exceedZ.and(exceedEff).rename('exceed');
    var validMask = img.select(hotspotBand).mask();
    return exceed.updateMask(validMask);
  });

  // SAFE sum + cast (avoid Long/Double export issues)
  var exceedTemplate = ee.Image(0).rename('exceed').updateMask(ee.Image(0)).clip(tileGeom);
  var exceedCount = ee.ImageCollection(exceedColl).merge(ee.ImageCollection([exceedTemplate]))
    .sum()
    .rename('exceed_count')
    .toByte();

  // Hotspot = persistence + cluster filter
  var hotspotBinary = exceedCount.gte(minMonthsPerYearForHotspot).selfMask();
  var conn = hotspotBinary.connectedPixelCount(8, true);
  var hotspotClusters = hotspotBinary.updateMask(conn.gte(minContiguousPixels)).toByte()
    .rename('hotspot_year');

  // Year validity mask (1 if valid at least once in the year)
  var waterValid = monthsInYear
    .select(hotspotBand)
    .map(function(i){ return i.mask().rename('valid'); })
    .max()
    .rename('water_valid')
    .toByte();

  var annualOut = exceedCount.addBands([hotspotClusters, waterValid]).clip(tileGeom);

  return ee.Image(ee.Algorithms.If(hasAnyMonth, annualOut, annualTemplate));
}



// =================================================================================================
// 7) EXPORT TASK CREATION 
// =================================================================================================

// Subset the tiles to export in this batch
var tilesList = tilesIntersectingAOI.toList(tilesIntersectingAOI.size());
var tileBatch = tilesList.slice(startTile, startTile + nTilesThisBatch);

print('Exporting tiles:', startTile, 'to', startTile + nTilesThisBatch - 1);
print('Chosen annual export year:', chosenYear);

// Client-side loop to create export tasks
// NOTE: This loop is acceptable because it only creates Export tasks.
//       All heavy computation is inside server-side functions already defined above.
for (var t = 0; t < nTilesThisBatch; t++) {

  var tileFeat = ee.Feature(tileBatch.get(t));
  var tileGeom = tileFeat.geometry();
  var tileId   = tileFeat.get('tile_id').getInfo(); // client-side string (used for task naming)

  // -----------------------------
  // EXPORT 1 (per tile): baseline median (12 bands)
  // -----------------------------
  var baseline12 = buildBaseline12ForTile(tileGeom, climBand, baselineStart, baselineEnd);

  Export.image.toDrive({
    image: baseline12,
    description: tileId + '_BaselineMedian_12Bands_' + climBand + '_' +
                 baselineStart.slice(0,4) + '-' + baselineEnd.slice(0,4),
    folder: exportFolder,
    region: tileGeom,
    scale: exportScale,
    maxPixels: exportMaxPixels
  });

  // -----------------------------
  // EXPORT 2 (per tile): annual 3-band output for ONE chosen year
  // -----------------------------
  var annualOut = buildAnnualExportForTile(tileGeom, chosenYear);

  Export.image.toDrive({
    image: annualOut, // band names: exceed_count, hotspot_year, water_valid
    description: tileId + '_AnnualHotspot_ExceedCount_ValidMask_' + chosenYear + '_' + hotspotBand,
    folder: exportFolder,
    region: tileGeom,
    scale: exportScale,
    maxPixels: exportMaxPixels
  });
}

