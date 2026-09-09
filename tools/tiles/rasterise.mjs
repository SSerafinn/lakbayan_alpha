// Turn a Protomaps VECTOR pack into the RASTER pack the app ships.
//
// D-11 settled the renderer as raster; Protomaps publishes vector. This is the
// step in between, and the cost that decision accepted.
//
//   docker compose --profile tiles run --rm tiles \
//     node rasterise.mjs --source /app/out/penablanca.pmtiles \
//                        --region /app/out/penablanca.geojson
//
// --source may be a local file or an https URL; PMTiles is range-readable, so
// a remote planet build works without downloading it.
//
// Region files come from `scripts/extract-tiles.mjs`, which is also what
// decides *which* tiles are worth having — see D-11's buffer union.

import { open, readFile, rm, stat } from "node:fs/promises";
import { basename, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { DatabaseSync } from "node:sqlite";

import mbgl from "@maplibre/maplibre-gl-native";
import { layers, namedFlavor } from "@protomaps/basemaps";
import { PMTiles, FetchSource } from "pmtiles";
import { PNG } from "pngjs";

import {
  countTiles,
  tileCentre,
  tilesForBoxes,
  xyzToTmsRow,
} from "../../scripts/lib/tile-region.mjs";

// --- arguments -------------------------------------------------------------

const args = process.argv.slice(2);
function flag(name, fallback) {
  const i = args.indexOf(`--${name}`);
  return i !== -1 && args[i + 1] && !args[i + 1].startsWith("--")
    ? args[i + 1]
    : fallback;
}

const source = flag("source");
const regionPath = flag("region");
const maxZoom = Number(flag("maxzoom", "16"));
const flavour = flag("flavour", "light");
// 512, not 256. MapLibre's zoom is defined against 512px tiles, so a 512px
// render at zoom z is exactly tile z and the styling is correct for that zoom.
// Producing 256px would mean rendering at z-1, which draws every tile with the
// label sizes and feature filters of the zoom below it.
const tileSize = Number(flag("tile-size", "512"));
const outDir = flag("out-dir", "/app/out");

if (!source || !regionPath) {
  console.error(
    "Usage: node rasterise.mjs --source <file|url> --region <file.geojson>\n" +
      "       [--maxzoom 16] [--flavour light] [--tile-size 512] [--out-dir /app/out]",
  );
  process.exit(1);
}
if (!Number.isInteger(maxZoom) || maxZoom < 1 || maxZoom > 20) {
  console.error(`--maxzoom must be an integer 1-20, got "${maxZoom}".`);
  process.exit(1);
}

// --- the source archive ----------------------------------------------------

/** Range reads over a local file, the shape `pmtiles` expects of a source. */
class FileSource {
  constructor(path) {
    this.path = path;
    this.handle = null;
  }

  getKey() {
    return this.path;
  }

  async getBytes(offset, length) {
    this.handle ??= await open(this.path, "r");
    const buffer = Buffer.alloc(length);
    await this.handle.read(buffer, 0, length, offset);
    // A copy, not a view: pmtiles keeps the ArrayBuffer, and Buffer.alloc can
    // hand back a slice of a shared pool whose neighbours it would then see.
    return {
      data: buffer.buffer.slice(
        buffer.byteOffset,
        buffer.byteOffset + buffer.byteLength,
      ),
    };
  }

  async close() {
    await this.handle?.close();
  }
}

const isUrl = /^https?:\/\//i.test(source);
const fileSource = isUrl ? null : new FileSource(resolve(source));
const archive = new PMTiles(isUrl ? new FetchSource(source) : fileSource);

const header = await archive.getHeader();
console.log(
  `Source      ${source}\n` +
    `            zoom ${header.minZoom}-${header.maxZoom}, ` +
    `tile type ${header.tileType}`,
);

// --- what to render --------------------------------------------------------

const region = JSON.parse(await readFile(regionPath, "utf8"));
const geometry = region.geometry ?? region;
if (geometry.type !== "MultiPolygon" && geometry.type !== "Polygon") {
  console.error(
    `Expected a Polygon or MultiPolygon region, got "${geometry.type}".`,
  );
  process.exit(1);
}

/** Each polygon's bounding box. The regions we generate are rectangles. */
const boxes = (
  geometry.type === "Polygon" ? [geometry.coordinates] : geometry.coordinates
).map((polygon) => {
  const ring = polygon[0];
  const lngs = ring.map((p) => p[0]);
  const lats = ring.map((p) => p[1]);
  return {
    minLng: Math.min(...lngs),
    maxLng: Math.max(...lngs),
    minLat: Math.min(...lats),
    maxLat: Math.max(...lats),
  };
});

const tiles = tilesForBoxes(boxes, maxZoom);
const planned = countTiles(boxes, maxZoom).total;
if (tiles.length !== planned) {
  // Belt and braces: the planner prints one number and this renders another
  // list. They come from the same function, and if that ever stops being true
  // the operator should hear about it here rather than from a short pack.
  console.error(`Tile list (${tiles.length}) disagrees with plan (${planned}).`);
  process.exit(1);
}
console.log(
  `Region      ${boxes.length} area${boxes.length === 1 ? "" : "s"}, ` +
    `zoom 0-${maxZoom}\nTiles       ${tiles.length.toLocaleString()} at ${tileSize}px`,
);

// --- the renderer ----------------------------------------------------------

const SOURCE_NAME = "protomaps";
const ASSETS = "https://protomaps.github.io/basemaps-assets";

const style = {
  version: 8,
  // Glyphs and sprites are fetched over the network at render time. That makes
  // this step online-only, which is fine — it is build-time tooling, and the
  // pack it produces is what has to work offline.
  glyphs: `${ASSETS}/fonts/{fontstack}/{range}.pbf`,
  sprite: `${ASSETS}/sprites/v4/${flavour}`,
  sources: {
    [SOURCE_NAME]: {
      type: "vector",
      // A scheme of our own, so the request handler can tell tile reads from
      // the archive apart from ordinary asset fetches.
      tiles: ["pack://{z}/{x}/{y}"],
      minzoom: header.minZoom,
      maxzoom: header.maxZoom,
    },
  },
  layers: layers(SOURCE_NAME, namedFlavor(flavour), { lang: "en" }),
};

const map = new mbgl.Map({
  ratio: 1,
  request: (req, callback) => {
    const packTile = /^pack:\/\/(\d+)\/(\d+)\/(\d+)/.exec(req.url);
    if (packTile) {
      const [, z, x, y] = packTile;
      archive
        .getZxy(Number(z), Number(x), Number(y))
        .then((tile) =>
          // An absent tile is normal, not an error: the region is a rectangle
          // and the archive only holds what the extract covered. Reporting it
          // as a failure makes the renderer retry and log for every empty
          // square of sea.
          callback(null, tile ? { data: Buffer.from(tile.data) } : {}),
        )
        .catch(callback);
      return;
    }
    fetch(req.url)
      .then(async (res) =>
        res.ok
          ? callback(null, { data: Buffer.from(await res.arrayBuffer()) })
          : callback(new Error(`${res.status} for ${req.url}`)),
      )
      .catch(callback);
  },
});
map.load(style);

function render(tile) {
  const { lat, lng } = tileCentre(tile.z, tile.x, tile.y);
  return new Promise((resolvePng, reject) => {
    map.render(
      { zoom: tile.z, width: tileSize, height: tileSize, center: [lng, lat] },
      (err, buffer) => (err ? reject(err) : resolvePng(buffer)),
    );
  });
}

// --- write --------------------------------------------------------------

const name = basename(regionPath).replace(/\.geojson$/i, "");
const mbtilesPath = join(outDir, `${name}.mbtiles`);
const pmtilesPath = join(outDir, `${name}.raster.pmtiles`);

// A fresh database each run. Appending to a previous one leaves tiles from a
// region that is no longer being asked for, and they are invisible until
// somebody wonders why the pack is bigger than the plan said.
await rm(mbtilesPath, { force: true });

const db = new DatabaseSync(mbtilesPath);
db.exec(`
  CREATE TABLE metadata (name text, value text);
  CREATE TABLE tiles (
    zoom_level integer, tile_column integer, tile_row integer, tile_data blob
  );
  CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);
`);

const bounds = [
  Math.min(...boxes.map((b) => b.minLng)),
  Math.min(...boxes.map((b) => b.minLat)),
  Math.max(...boxes.map((b) => b.maxLng)),
  Math.max(...boxes.map((b) => b.maxLat)),
];
const insertMeta = db.prepare("INSERT INTO metadata VALUES (?, ?)");
for (const [k, v] of [
  ["name", name],
  ["format", "png"],
  ["type", "baselayer"],
  ["version", "1"],
  ["minzoom", "0"],
  ["maxzoom", String(maxZoom)],
  ["bounds", bounds.join(",")],
  // Recorded because it is not the default. A reader that assumes 256 draws
  // every tile at twice its proper size.
  ["tilesize", String(tileSize)],
  ["attribution", "© OpenStreetMap contributors · Protomaps"],
]) {
  insertMeta.run(k, v);
}

const insertTile = db.prepare("INSERT INTO tiles VALUES (?, ?, ?, ?)");

let done = 0;
let blank = 0;
for (const tile of tiles) {
  const raw = await render(tile);
  const png = new PNG({ width: tileSize, height: tileSize });
  raw.copy(png.data);
  const encoded = PNG.sync.write(png);
  insertTile.run(tile.z, tile.x, xyzToTmsRow(tile.z, tile.y), encoded);

  // Track fully-transparent renders. A pack of blanks means the style never
  // saw the source — the most likely failure, and one that otherwise produces
  // a perfectly valid, perfectly empty archive.
  if (raw.every((byte, i) => i % 4 !== 3 || byte === 0)) blank++;

  done++;
  if (done % 50 === 0 || done === tiles.length) {
    process.stdout.write(`\r  rendered ${done}/${tiles.length}`);
  }
}
process.stdout.write("\n");

db.close();
map.release();
await fileSource?.close();

if (blank === tiles.length) {
  console.error(
    "\nEvery tile came out empty. The style rendered nothing at all, which " +
      "usually means the source archive was not reached — check --source and " +
      "the zoom range printed above.",
  );
  process.exit(1);
}
if (blank > 0) console.log(`  ${blank} tiles were empty (sea or outside cover)`);

// --- convert ---------------------------------------------------------------

console.log(`\n$ pmtiles convert ${mbtilesPath} ${pmtilesPath}`);
await rm(pmtilesPath, { force: true });
const convert = spawnSync("pmtiles", ["convert", mbtilesPath, pmtilesPath], {
  stdio: "inherit",
});
if (convert.status !== 0) {
  console.error(`pmtiles convert exited ${convert.status}.`);
  process.exit(convert.status ?? 1);
}

const { size } = await stat(pmtilesPath);
console.log(
  `\nWrote ${pmtilesPath}  (${(size / 1024 / 1024).toFixed(1)} MB)\n` +
    "Upload it to Storage at `/tiles/<townId>/pack.pmtiles` — the path " +
    "docs/DATA_MODEL.md reserves.",
);

// Keep the intermediate; it is what `pmtiles convert` is checked against when
// a pack looks wrong, and deleting it turns a two-minute diagnosis into a
// re-render.
console.log(`Intermediate MBTiles kept at ${mbtilesPath}`);
