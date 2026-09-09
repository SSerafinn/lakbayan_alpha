// Geometry for offline tile packs. Pure functions, no Firebase, no I/O — the
// half of extract-tiles.mjs that is worth unit-testing.
//
// The shape this builds comes from docs/DECISIONS.md D-11: bundle the union of
// small buffers around a town's destinations at high zoom, NOT the whole
// municipality. A municipality at maxzoom 16 is 25-60 MB; the buffers are
// single-digit MB and still give street-level detail where somebody is
// actually standing. Low-zoom context comes free, because one z10 tile spans
// ~40 km and therefore covers the municipality anyway.

/** Metres per degree of latitude. Constant enough at this scale. */
const KM_PER_DEG_LAT = 111.32;

/**
 * A square buffer around a point, in degrees.
 *
 * A square rather than a circle: `pmtiles extract` rasterises the region to
 * whole tiles regardless, so the extra precision of a circle buys nothing and
 * costs a polygon library. Longitude is scaled by cos(latitude) — a degree of
 * longitude is ~106 km in Cagayan, not 111.
 */
export function bufferBox({ lat, lng }, km) {
  const dLat = km / KM_PER_DEG_LAT;
  // Guard the poles: cos -> 0 would make dLng infinite. Irrelevant for Cagayan,
  // but a NaN region file is a miserable thing to debug.
  const cos = Math.max(Math.cos((lat * Math.PI) / 180), 0.01);
  const dLng = km / (KM_PER_DEG_LAT * cos);
  return {
    minLat: lat - dLat,
    maxLat: lat + dLat,
    minLng: lng - dLng,
    maxLng: lng + dLng,
  };
}

export function boxesIntersect(a, b) {
  return !(
    a.maxLat < b.minLat ||
    b.maxLat < a.minLat ||
    a.maxLng < b.minLng ||
    b.maxLng < a.minLng
  );
}

function union(a, b) {
  return {
    minLat: Math.min(a.minLat, b.minLat),
    maxLat: Math.max(a.maxLat, b.maxLat),
    minLng: Math.min(a.minLng, b.minLng),
    maxLng: Math.max(a.maxLng, b.maxLng),
  };
}

/**
 * Collapse overlapping buffers into one box each.
 *
 * Iterates to a fixpoint rather than merging in a single pass: merging two
 * boxes produces a larger box, which can then overlap a third that neither
 * original touched. A single pass leaves those behind, and the resulting
 * MultiPolygon has overlapping members — which is invalid GeoJSON and which
 * some tools accept silently and others reject.
 */
export function mergeBoxes(boxes) {
  const out = boxes.map((b) => ({ ...b }));
  let merged = true;
  while (merged) {
    merged = false;
    outer: for (let i = 0; i < out.length; i++) {
      for (let j = i + 1; j < out.length; j++) {
        if (boxesIntersect(out[i], out[j])) {
          out[i] = union(out[i], out[j]);
          out.splice(j, 1);
          merged = true;
          break outer;
        }
      }
    }
  }
  return out;
}

/** GeoJSON winding is counter-clockwise for an outer ring. */
function ring({ minLat, maxLat, minLng, maxLng }) {
  return [
    [minLng, minLat],
    [maxLng, minLat],
    [maxLng, maxLat],
    [minLng, maxLat],
    [minLng, minLat],
  ];
}

/**
 * The region file handed to `pmtiles extract --region`.
 *
 * A Feature, not a bare geometry: the CLI accepts either, and a Feature leaves
 * somewhere to record what this was built from. Anyone opening the file six
 * months from now can see the town and the buffer without re-deriving it.
 */
export function toRegionFeature(boxes, properties = {}) {
  return {
    type: "Feature",
    properties,
    geometry: {
      type: "MultiPolygon",
      coordinates: boxes.map((b) => [ring(b)]),
    },
  };
}

// --- Web Mercator tile arithmetic -----------------------------------------
// Standard slippy-map maths. Kept here rather than pulled from a package so
// the estimate cannot drift from the numbers in docs/research/map-tiles.md.

export function lngToTileX(lng, zoom) {
  return Math.floor(((lng + 180) / 360) * 2 ** zoom);
}

export function latToTileY(lat, zoom) {
  // Clamp to the Web Mercator limit; tan() diverges at the poles.
  const clamped = Math.max(Math.min(lat, 85.0511), -85.0511);
  const rad = (clamped * Math.PI) / 180;
  return Math.floor(
    ((1 - Math.asinh(Math.tan(rad)) / Math.PI) / 2) * 2 ** zoom,
  );
}

/**
 * Distinct tiles covering these boxes from z0 to [maxZoom], inclusive.
 *
 * Counts a **set** rather than summing per box. At low zoom every box lands on
 * the same handful of tiles, so summing would report several times the real
 * figure exactly where the pack is cheapest — and an estimate that is wrong in
 * the reassuring direction is worse than none.
 */
export function countTiles(boxes, maxZoom) {
  const perZoom = [];
  let total = 0;
  for (let z = 0; z <= maxZoom; z++) {
    const seen = new Set();
    for (const b of boxes) {
      const x1 = lngToTileX(b.minLng, z);
      const x2 = lngToTileX(b.maxLng, z);
      // Tile Y grows southward, so the northern edge gives the smaller index.
      const y1 = latToTileY(b.maxLat, z);
      const y2 = latToTileY(b.minLat, z);
      for (let x = x1; x <= x2; x++) {
        for (let y = y1; y <= y2; y++) seen.add(`${x}/${y}`);
      }
    }
    perZoom.push({ zoom: z, tiles: seen.size });
    total += seen.size;
  }
  return { total, perZoom };
}

/**
 * Bytes, as a range rather than a number.
 *
 * The per-tile figures are the raster bounds from docs/research/map-tiles.md
 * (8-20 KB). Vector tiles are materially smaller — Protomaps reports 70%+ from
 * de-duplication — so for a vector pack treat this as a ceiling, and read the
 * real size off the file once it exists.
 */
export function estimateBytes(tileCount) {
  return { low: tileCount * 8 * 1024, high: tileCount * 20 * 1024 };
}

export function formatMB(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/**
 * Everything the CLI needs, from the destinations of one town.
 *
 * [points] is `{ id, lat, lng }`. Returns the merged region, the counts, and
 * the estimate, so the caller can print a plan before anything is downloaded.
 */
export function planRegion(points, { bufferKm, maxZoom }) {
  const boxes = mergeBoxes(points.map((p) => bufferBox(p, bufferKm)));
  const counts = countTiles(boxes, maxZoom);
  return { boxes, ...counts, bytes: estimateBytes(counts.total) };
}
