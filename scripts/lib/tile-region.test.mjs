import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  boxesIntersect,
  bufferBox,
  countTiles,
  latToTileY,
  lngToTileX,
  mergeBoxes,
  planRegion,
  toRegionFeature,
} from "./tile-region.mjs";

// Callao Cave, near enough.
const callao = { lat: 17.7, lng: 121.8 };

describe("bufferBox", () => {
  it("is wider in longitude than in latitude away from the equator", () => {
    const b = bufferBox(callao, 2);
    const latSpan = b.maxLat - b.minLat;
    const lngSpan = b.maxLng - b.minLng;
    assert.ok(
      lngSpan > latSpan,
      "a degree of longitude is shorter than a degree of latitude at 17N, " +
        "so the same distance spans more of them",
    );
  });

  it("puts 2 km either side of the point", () => {
    const b = bufferBox(callao, 2);
    // 2 km / 111.32 km per degree.
    assert.ok(Math.abs(b.maxLat - callao.lat - 0.01796) < 1e-4);
  });

  it("does not blow up at the pole", () => {
    const b = bufferBox({ lat: 90, lng: 0 }, 2);
    assert.ok(Number.isFinite(b.maxLng) && Number.isFinite(b.minLng));
  });
});

describe("mergeBoxes", () => {
  it("leaves distant buffers alone", () => {
    const boxes = mergeBoxes([
      bufferBox({ lat: 17.7, lng: 121.8 }, 2),
      bufferBox({ lat: 18.6, lng: 121.6 }, 2), // ~100 km north
    ]);
    assert.equal(boxes.length, 2);
  });

  it("collapses overlapping buffers into one", () => {
    const boxes = mergeBoxes([
      bufferBox({ lat: 17.7, lng: 121.8 }, 2),
      bufferBox({ lat: 17.705, lng: 121.805 }, 2), // a few hundred metres away
    ]);
    assert.equal(boxes.length, 1);
  });

  it("merges a chain transitively", () => {
    // A-B overlap and B-C overlap, but A and C do not. A single pass would
    // leave two boxes that themselves overlap — invalid GeoJSON.
    const boxes = mergeBoxes([
      bufferBox({ lat: 17.7, lng: 121.8 }, 2),
      bufferBox({ lat: 17.73, lng: 121.8 }, 2),
      bufferBox({ lat: 17.76, lng: 121.8 }, 2),
    ]);
    assert.equal(boxes.length, 1);
  });

  it("returns boxes that never overlap each other", () => {
    const points = [
      { lat: 17.7, lng: 121.8 },
      { lat: 17.71, lng: 121.81 },
      { lat: 18.35, lng: 121.63 },
      { lat: 18.36, lng: 121.64 },
    ];
    const boxes = mergeBoxes(points.map((p) => bufferBox(p, 2)));
    for (let i = 0; i < boxes.length; i++) {
      for (let j = i + 1; j < boxes.length; j++) {
        assert.ok(!boxesIntersect(boxes[i], boxes[j]));
      }
    }
  });

  it("does not mutate its input", () => {
    const original = bufferBox(callao, 2);
    const copy = { ...original };
    mergeBoxes([original, bufferBox({ lat: 17.702, lng: 121.802 }, 2)]);
    assert.deepEqual(original, copy);
  });
});

describe("tile arithmetic", () => {
  it("agrees with the known slippy-map origin", () => {
    assert.equal(lngToTileX(-180, 0), 0);
    assert.equal(latToTileY(85.0511, 0), 0);
    // Greenwich / equator at z1 is the boundary of the four world tiles.
    assert.equal(lngToTileX(0, 1), 1);
    assert.equal(latToTileY(0, 1), 1);
  });

  it("clamps beyond the Mercator limit rather than returning NaN", () => {
    assert.ok(Number.isFinite(latToTileY(90, 10)));
  });
});

describe("countTiles", () => {
  it("counts one tile per zoom for a small region at low zoom", () => {
    const boxes = [bufferBox(callao, 2)];
    const { perZoom } = countTiles(boxes, 4);
    assert.equal(perZoom[0].tiles, 1, "the whole world is one tile at z0");
  });

  it("does not double-count where two boxes share a tile", () => {
    // Two buffers 100 km apart land on the same z0-z4 tiles. Summing per box
    // would report 2 for the whole world.
    const boxes = [
      bufferBox({ lat: 17.7, lng: 121.8 }, 2),
      bufferBox({ lat: 18.6, lng: 121.6 }, 2),
    ];
    const { perZoom } = countTiles(boxes, 6);
    assert.equal(perZoom[0].tiles, 1);
  });

  it("grows roughly fourfold per zoom level once the region spans tiles", () => {
    const boxes = [bufferBox(callao, 20)];
    const { perZoom } = countTiles(boxes, 14);
    const z13 = perZoom[13].tiles;
    const z14 = perZoom[14].tiles;
    assert.ok(z14 >= z13 * 2, `expected growth, got ${z13} -> ${z14}`);
  });
});

describe("planRegion", () => {
  it("keeps a realistic town pack far below a whole-municipality extract", () => {
    // Six destinations clustered in one town, the shape seed-emulator.mjs
    // produces. D-11's whole point is that this is single-digit MB where the
    // municipality at the same zoom is 25-60 MB.
    const points = [
      { id: "a", lat: 17.7, lng: 121.8 },
      { id: "b", lat: 17.71, lng: 121.82 },
      { id: "c", lat: 17.69, lng: 121.79 },
      { id: "d", lat: 17.72, lng: 121.83 },
      { id: "e", lat: 17.68, lng: 121.81 },
      { id: "f", lat: 17.7, lng: 121.85 },
    ];
    const plan = planRegion(points, { bufferKm: 2, maxZoom: 16 });
    assert.ok(
      plan.bytes.high < 25 * 1024 * 1024,
      `upper bound ${plan.bytes.high} should undercut a municipality extract`,
    );
    assert.ok(plan.total > 0);
  });
});

describe("toRegionFeature", () => {
  it("closes every ring, as GeoJSON requires", () => {
    const f = toRegionFeature([bufferBox(callao, 2)]);
    for (const polygon of f.geometry.coordinates) {
      for (const r of polygon) {
        assert.deepEqual(r.at(0), r.at(-1));
      }
    }
  });

  it("emits [longitude, latitude], not the other way round", () => {
    // The single most common GeoJSON mistake, and it silently extracts a
    // region in the sea off Somalia rather than failing.
    const f = toRegionFeature([bufferBox(callao, 2)]);
    const [lng, lat] = f.geometry.coordinates[0][0][0];
    assert.ok(lng > 121 && lng < 122, `expected a Cagayan longitude, got ${lng}`);
    assert.ok(lat > 17 && lat < 18, `expected a Cagayan latitude, got ${lat}`);
  });

  it("carries the properties it was given", () => {
    const f = toRegionFeature([bufferBox(callao, 2)], { town: "Peñablanca" });
    assert.equal(f.properties.town, "Peñablanca");
  });
});
