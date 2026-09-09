// Build an offline map tile pack for one town.
//
// Reads that town's published, offline-eligible destinations, works out the
// region worth covering, writes a GeoJSON region file, and prints (or runs)
// the `pmtiles extract` that produces the pack.
//
//   docker compose up -d emulators
//   cd scripts && npm install
//   node extract-tiles.mjs "Peñablanca"                 # plan only
//   node extract-tiles.mjs "Peñablanca" --run           # actually extract
//
// Against a real project:
//   node extract-tiles.mjs "Peñablanca" --live --project project-lakbayan
//
// `pmtiles` is a separate binary — https://docs.protomaps.com/pmtiles/cli —
// and is only needed with --run. Everything else works without it, which is
// the point: you can see the size of a pack before deciding to build it.
//
// WHY THIS SHAPE — docs/DECISIONS.md D-11. A whole municipality at maxzoom 16
// is 25-60 MB, and almost all of it is empty hillside. What a visitor needs is
// street-level detail *where the destinations are*, so the region is the union
// of ~2 km buffers around each one. Low zoom comes free: a z10 tile spans
// ~40 km, so the municipality is covered by the same tiles regardless.
//
// The pack this produces is renderer-neutral. Whether the app draws it with a
// vector or a raster renderer is D-11's open question — see
// docs/research/map-tiles.md. The extract is the same either way; only the
// --source archive differs.

import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { formatMB, planRegion, toRegionFeature } from "./lib/tile-region.mjs";
import { slugify } from "./lib/slug.mjs";

const args = process.argv.slice(2);
const town = args.find((a) => !a.startsWith("--"));
const live = args.includes("--live");
const run = args.includes("--run");

function flag(name, fallback) {
  const i = args.indexOf(`--${name}`);
  // Guard the -1: args[-1 + 1] is args[0], which is the town name.
  return i !== -1 && args[i + 1] && !args[i + 1].startsWith("--")
    ? args[i + 1]
    : fallback;
}

const projectId = flag("project", live ? "project-lakbayan" : "demo-lakbayan");
const bufferKm = Number(flag("buffer-km", "2"));
const maxZoom = Number(flag("maxzoom", "16"));
const outDir = resolve(flag("out", "../tiles"));

// The daily planet build. Dated rather than "latest" on purpose: a pack should
// be reproducible, and Protomaps rotates these.
const source = flag("source", "https://build.protomaps.com/20260901.pmtiles");

if (!town) {
  console.error(
    "Usage: node extract-tiles.mjs <town> [--run] [--buffer-km 2] " +
      "[--maxzoom 16] [--source <url|file>] [--out ../tiles] " +
      "[--live] [--project <id>]",
  );
  process.exit(1);
}
if (!Number.isFinite(bufferKm) || bufferKm <= 0) {
  console.error(`--buffer-km must be a positive number, got "${bufferKm}".`);
  process.exit(1);
}
if (!Number.isInteger(maxZoom) || maxZoom < 1 || maxZoom > 20) {
  console.error(`--maxzoom must be an integer 1-20, got "${maxZoom}".`);
  process.exit(1);
}

if (live) {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) {
    console.error(
      "--live needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service " +
        "account JSON. Firebase console -> Project settings -> Service accounts.",
    );
    process.exit(1);
  }
} else {
  process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
  console.log(
    `Emulator mode (${process.env.FIRESTORE_EMULATOR_HOST}), project "${projectId}".`,
  );
}

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();

// Published only, and offlineEligible only. Both matter: a draft is not
// readable by the app, and an editor who has cleared "include in offline
// bundles" has said this place should not pull tiles into the pack.
const snap = await db
  .collection("destinations")
  .where("town", "==", town)
  .where("status", "==", "published")
  .get();

const points = [];
const skipped = [];
for (const doc of snap.docs) {
  const d = doc.data();
  if (d.offlineEligible === false) {
    skipped.push(`${doc.id} (not offline-eligible)`);
    continue;
  }
  const lat = d.coords?.lat;
  const lng = d.coords?.lng;
  if (typeof lat !== "number" || typeof lng !== "number") {
    skipped.push(`${doc.id} (no usable coords)`);
    continue;
  }
  points.push({ id: doc.id, lat, lng });
}

if (points.length === 0) {
  console.error(
    `No published, offline-eligible destinations with coordinates in "${town}".\n` +
      (snap.empty
        ? "That town has no published destinations at all — check the spelling " +
          "against the CMS; it is matched exactly, accents included."
        : `Found ${snap.size}, but none usable:\n  ${skipped.join("\n  ")}`),
  );
  process.exit(1);
}

const plan = planRegion(points, { bufferKm, maxZoom });
const townId = slugify(town);
const regionPath = resolve(outDir, `${townId}.geojson`);
const packPath = resolve(outDir, `${townId}.pmtiles`);

mkdirSync(dirname(regionPath), { recursive: true });
writeFileSync(
  regionPath,
  `${JSON.stringify(
    toRegionFeature(plan.boxes, {
      town,
      townId,
      bufferKm,
      maxZoom,
      destinations: points.map((p) => p.id),
      generated: new Date().toISOString(),
      source,
    }),
    null,
    2,
  )}\n`,
);

console.log(`
Town        ${town}  (${townId})
Places      ${points.length} published and offline-eligible${
  skipped.length ? `, ${skipped.length} skipped` : ""
}
Region      ${plan.boxes.length} area${plan.boxes.length === 1 ? "" : "s"} after merging ${bufferKm} km buffers
Zoom        0-${maxZoom}
Tiles       ${plan.total.toLocaleString()}
Size        ~${formatMB(plan.bytes.low)}-${formatMB(plan.bytes.high)} as raster; a vector pack is materially smaller
Region file ${regionPath}`);

if (skipped.length > 0) {
  console.log(`\nSkipped:\n  ${skipped.join("\n  ")}`);
}

// The tail of the curve is where the money goes — worth showing, because it is
// the argument for dropping maxzoom by one when a pack comes out too big.
const tail = plan.perZoom.slice(-3);
console.log(
  `\nTiles by zoom (last three): ${tail
    .map((z) => `z${z.zoom}=${z.tiles.toLocaleString()}`)
    .join("  ")}`,
);

const command = [
  "pmtiles",
  "extract",
  source,
  packPath,
  `--region=${regionPath}`,
  `--maxzoom=${maxZoom}`,
];

if (!run) {
  console.log(`\nTo build the pack:\n\n  ${command.join(" ")}\n`);
  console.log(
    "Re-run with --run to execute it here. `pmtiles` must be on PATH:\n" +
      "  https://docs.protomaps.com/pmtiles/cli\n",
  );
  process.exit(0);
}

console.log(`\n$ ${command.join(" ")}\n`);
const result = spawnSync(command[0], command.slice(1), { stdio: "inherit" });

if (result.error?.code === "ENOENT") {
  console.error(
    "\n`pmtiles` is not on PATH. Install it from " +
      "https://docs.protomaps.com/pmtiles/cli, or drop --run and execute the " +
      "command above wherever the binary lives.",
  );
  process.exit(1);
}
if (result.status !== 0) {
  console.error(`\npmtiles extract exited ${result.status}.`);
  process.exit(result.status ?? 1);
}

console.log(`\nWrote ${packPath}`);
console.log(
  "Upload it to Storage at `/tiles/<townId>/pack.pmtiles` — the path " +
    "docs/DATA_MODEL.md already reserves.",
);
