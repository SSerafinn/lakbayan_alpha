// Import a filled-in content intake workbook into Firestore.
//
// Reads docs/data-intake/Lakbayan-content-intake.xlsx as returned by the
// Provincial Tourism Office and writes destinations, audio guide segments,
// tours and local guides. See docs/data-intake/README.md for the sheet format
// and docs/DATA_MODEL.md for the schema it writes.
//
// Usage (emulator — the default, and safe):
//   cd scripts && npm install
//   node import-content.mjs ../docs/data-intake/Lakbayan-content-intake.xlsx
//
// That is a DRY RUN. It validates everything, prints what it would do, and
// writes nothing. Add --commit to actually write:
//   node import-content.mjs <workbook> --commit
//
// With photos and recordings, where <dir> holds the files named in the sheets:
//   node import-content.mjs <workbook> --media ../intake-media --commit
//
// Against a real project (deliberate):
//   $env:GOOGLE_APPLICATION_CREDENTIALS="C:/path/serviceAccount.json"
//   node import-content.mjs <workbook> --live --project project-lakbayan --commit
//
// Three properties worth knowing before you run it:
//
//   1. Everything imports as `status: "draft"`. Nothing becomes visible in the
//      app until an administrator publishes it in the CMS. An import is never
//      a live mistake.
//   2. It is idempotent on `slug`, which is derived from the name exactly as
//      the CMS derives it. Re-running updates the destination that already has
//      that slug rather than creating a second one — so a corrected sheet can
//      simply be re-imported. Slugs are unique because they appear in deep
//      links; that existing constraint is what makes this safe, and it is why
//      no intake-only id is written to the documents.
//   3. Validation is all-or-nothing. If any row has a hard error, nothing is
//      written at all. A half-imported province is worse than an unimported
//      one, because you cannot tell by looking which half arrived.

import { readFileSync } from "node:fs";
import { basename, extname, join } from "node:path";
import { existsSync, readdirSync } from "node:fs";

import ExcelJS from "exceljs";
import { applicationDefault, cert, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

// The slug is this importer's identity key — it is how a sheet row is matched
// to a destination the CMS already created. Shared rather than reimplemented
// for that reason; see the note in lib/slug.mjs.
import { slugify } from "./lib/slug.mjs";

// ---------------------------------------------------------------------------
// Contract constants. These mirror the CMS and docs/DATA_MODEL.md; when the
// schema moves, they move with it.
// ---------------------------------------------------------------------------

const DESTINATION_SCHEMA_VERSION = 2;
const MAX_DESCRIPTION = 140;
const CATEGORIES = ["church", "nature", "heritage", "museum", "food", "landmark"];
const AUDIO_EXTENSIONS = ["mp3", "m4a", "aac", "wav", "ogg"];
const IMAGE_EXTENSIONS = ["jpg", "jpeg", "png", "webp"];

// Where a new destination's pin starts in the CMS, used when the sheet has no
// coordinates. A draft is allowed to lack a real location; publishing is not,
// so the CMS will still stop it going live until someone sets the pin.
const CAGAYAN_CENTRE = { lat: 17.6132, lng: 121.727 };

const SHEETS = {
  destinations: "1 Destinations",
  segments: "2 Audio guide",
  tours: "3 Tours",
  guides: "4 Local guides",
  photos: "5 Photos",
};

// ---------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const workbookPath = args.find((a) => !a.startsWith("--"));
const commit = args.includes("--commit");
const live = args.includes("--live");

function flagValue(name) {
  const i = args.indexOf(name);
  // Guard the -1: args[args.indexOf(x) + 1] silently resolves to args[0] — the
  // workbook path — when the flag is absent.
  return i !== -1 && args[i + 1] && !args[i + 1].startsWith("--")
    ? args[i + 1]
    : null;
}

const mediaDir = flagValue("--media");
const projectId =
  flagValue("--project") ?? (live ? "project-lakbayan" : "demo-lakbayan");

if (!workbookPath) {
  console.error(
    "Usage: node import-content.mjs <workbook.xlsx> [--commit] [--media <dir>] " +
      "[--live] [--project <id>]",
  );
  process.exit(1);
}
if (!existsSync(workbookPath)) {
  console.error(`No such workbook: ${workbookPath}`);
  process.exit(1);
}
if (mediaDir && !existsSync(mediaDir)) {
  console.error(`No such media directory: ${mediaDir}`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Small helpers for reading sheet cells
// ---------------------------------------------------------------------------

const text = (v) => (v === null || v === undefined ? "" : String(v).trim());

/** Sheet booleans are `yes`/`no`; blank falls back to the column's default. */
function bool(v, fallback = false) {
  const s = text(v).toLowerCase();
  if (s === "yes" || s === "true" || s === "y") return true;
  if (s === "no" || s === "false" || s === "n") return false;
  return fallback;
}

function list(v) {
  return text(v)
    .split(";")
    .map((s) => s.trim())
    .filter(Boolean);
}

function num(v) {
  const s = text(v);
  if (s === "") return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : NaN;
}

/** Drop keys with empty values — an absent field beats a field holding "". */
function compact(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([, v]) => v !== undefined && v !== "" && v !== null),
  );
}

// ---------------------------------------------------------------------------
// Reading the workbook
// ---------------------------------------------------------------------------

/**
 * A sheet as an array of `{ column: value, __row: n }`.
 *
 * Row 1 is the note, row 2 the headers, row 3 onward the data — the layout the
 * workbook builder writes. Rows whose cells are all blank are skipped, because
 * the template pre-formats 300 of them and almost all come back empty. The
 * EXAMPLE row is skipped too: the README says to delete it, and people
 * reasonably often do not.
 *
 * The EXAMPLE test looks at the **first column only**, and anchors to the
 * start. Scanning every cell for the substring seems more thorough and is
 * actively wrong: `example.com` is the standard placeholder email domain, so a
 * guide row reading `maria@example.com` matched and the whole person vanished
 * from the import without a word. A row is the template's example when its ref
 * says so, which is exactly what the template writes.
 */
function sheetRows(worksheet) {
  if (!worksheet) return [];
  const headers = [];
  worksheet.getRow(2).eachCell({ includeEmpty: true }, (cell, col) => {
    // Headers in the workbook are decorated for humans — "ref *",
    // "short description *  (max 140 chars)". Normalise back to a key.
    headers[col] = text(cell.value)
      .replace(/\*/g, "")
      .replace(/\(.*?\)/g, "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
  });

  const firstKey = headers.find(Boolean);
  const rows = [];
  worksheet.eachRow({ includeEmpty: false }, (row, n) => {
    if (n < 3) return;
    const record = { __row: n };
    let any = false;
    row.eachCell({ includeEmpty: false }, (cell, col) => {
      const key = headers[col];
      if (!key) return;
      let v = cell.value;
      // ExcelJS hands back objects for rich text, hyperlinks and formulas.
      if (v && typeof v === "object") {
        if ("text" in v) v = v.text;
        else if ("result" in v) v = v.result;
        else if ("richText" in v) v = v.richText.map((r) => r.text).join("");
        else v = String(v);
      }
      const s = text(v);
      if (s !== "") any = true;
      record[key] = s;
    });
    if (!any) return;
    if (/^example/i.test(text(record[firstKey]))) return;
    rows.push(record);
  });
  return rows;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

const errors = [];
const warnings = [];
const err = (sheet, row, msg) => errors.push(`${sheet} row ${row}: ${msg}`);
const warn = (sheet, row, msg) => warnings.push(`${sheet} row ${row}: ${msg}`);

function validateDestinations(rows) {
  const byRef = new Map();
  const slugs = new Map();

  for (const r of rows) {
    const where = [SHEETS.destinations, r.__row];
    const ref = text(r.ref);
    const name = text(r.name);

    if (!ref) err(...where, "ref is required — it is how the other sheets point here.");
    else if (byRef.has(ref)) {
      err(...where, `ref "${ref}" is already used on row ${byRef.get(ref).__row}.`);
    }

    if (!name) err(...where, "name is required.");
    if (!text(r.town)) err(...where, "town is required.");

    const category = text(r.category).toLowerCase();
    if (!category) err(...where, "category is required.");
    else if (!CATEGORIES.includes(category)) {
      err(...where, `category "${category}" is not one of ${CATEGORIES.join(", ")}.`);
    }

    const description = text(r.short_description);
    if (!description) err(...where, "short description is required.");
    else if (description.length > MAX_DESCRIPTION) {
      err(
        ...where,
        `short description is ${description.length} characters; the card layout ` +
          `allows ${MAX_DESCRIPTION}. Move the rest into the history column.`,
      );
    }

    const lat = num(r.latitude);
    const lng = num(r.longitude);
    if (Number.isNaN(lat)) err(...where, `latitude "${r.latitude}" is not a number.`);
    if (Number.isNaN(lng)) err(...where, `longitude "${r.longitude}" is not a number.`);
    if ((lat === null) !== (lng === null)) {
      err(...where, "latitude and longitude must be given together or not at all.");
    }
    if (typeof lat === "number" && (lat < 16.8 || lat > 19.2)) {
      err(...where, `latitude ${lat} is outside Cagayan. Swapped with longitude?`);
    }
    if (typeof lng === "number" && (lng < 120.7 || lng > 122.6)) {
      err(...where, `longitude ${lng} is outside Cagayan. Swapped with latitude?`);
    }
    if (lat === null && lng === null) {
      warn(
        ...where,
        `no coordinates — importing with the province centre as a placeholder. ` +
          `It cannot be published until someone sets the real pin.`,
      );
    }

    if (name) {
      const slug = slugify(name);
      if (!slug) {
        err(...where, `name "${name}" produces an empty slug.`);
      } else if (slugs.has(slug)) {
        err(
          ...where,
          `name "${name}" makes the slug "${slug}", already used by ` +
            `"${slugs.get(slug)}". Slugs appear in deep links and must be unique.`,
        );
      } else slugs.set(slug, name);
    }

    if (ref && !byRef.has(ref)) byRef.set(ref, r);
  }
  return byRef;
}

function validateSegments(rows, destsByRef) {
  const byDest = new Map();
  for (const r of rows) {
    const where = [SHEETS.segments, r.__row];
    const ref = text(r.destination_ref);
    if (!ref) {
      err(...where, "destination ref is required.");
      continue;
    }
    if (!destsByRef.has(ref)) {
      err(...where, `destination ref "${ref}" is not on the Destinations sheet.`);
      continue;
    }
    if (!text(r.stop_title)) err(...where, "stop title is required.");

    const order = num(r.stop_number);
    if (order === null || Number.isNaN(order)) {
      err(...where, "stop number is required and must be a number.");
    }

    const script = text(r.narration_script);
    const recording = text(r.recording_filename);
    if (!script && !recording) {
      err(
        ...where,
        "a stop needs either a narration script or a recording. With neither it " +
          "is silent in the player, and the destination cannot be published.",
      );
    }
    if (recording) {
      const ext = extname(recording).slice(1).toLowerCase();
      if (!AUDIO_EXTENSIONS.includes(ext)) {
        err(...where, `"${recording}" is not one of ${AUDIO_EXTENSIONS.join(", ")}.`);
      }
    }

    const bucket = byDest.get(ref) ?? [];
    if (bucket.some((s) => num(s.stop_number) === order)) {
      err(...where, `stop number ${order} is used twice for "${ref}".`);
    }
    bucket.push(r);
    byDest.set(ref, bucket);
  }

  // Order is rewritten from position on import, so a gap is harmless — but it
  // usually means a row was deleted by accident rather than deliberately.
  for (const [ref, stops] of byDest) {
    const numbers = stops.map((s) => num(s.stop_number)).sort((a, b) => a - b);
    const expected = numbers.map((_, i) => i + 1);
    if (JSON.stringify(numbers) !== JSON.stringify(expected)) {
      warn(
        SHEETS.segments,
        stops[0].__row,
        `"${ref}" has stop numbers ${numbers.join(", ")} — renumbering to ` +
          `1..${numbers.length} in the order given.`,
      );
    }
  }
  return byDest;
}

function validatePhotos(rows, destsByRef) {
  const byDest = new Map();
  for (const r of rows) {
    const where = [SHEETS.photos, r.__row];
    const ref = text(r.destination_ref);
    const filename = text(r.filename);

    if (!ref) {
      err(...where, "destination ref is required.");
      continue;
    }
    if (!destsByRef.has(ref)) {
      err(...where, `destination ref "${ref}" is not on the Destinations sheet.`);
      continue;
    }
    if (!filename) {
      err(...where, "filename is required.");
      continue;
    }

    const ext = extname(filename).slice(1).toLowerCase();
    if (!IMAGE_EXTENSIONS.includes(ext)) {
      err(...where, `"${filename}" is not one of ${IMAGE_EXTENSIONS.join(", ")}.`);
    }
    if (!text(r.licence_or_permission)) {
      err(
        ...where,
        `no licence or permission recorded for "${filename}". The app is a ` +
          `public release; an image nobody has cleared cannot ship.`,
      );
    }

    const bucket = byDest.get(ref) ?? [];
    bucket.push(r);
    byDest.set(ref, bucket);
  }

  for (const [ref, photos] of byDest) {
    const covers = photos.filter((p) => bool(p.use_as_cover));
    if (covers.length > 1) {
      err(
        SHEETS.photos,
        covers[1].__row,
        `"${ref}" has ${covers.length} cover photos. Exactly one is the card image.`,
      );
    }
    if (covers.length === 0) {
      warn(
        SHEETS.photos,
        photos[0].__row,
        `"${ref}" has no cover marked — using "${text(photos[0].filename)}".`,
      );
    }
  }
  return byDest;
}

function validateTours(rows, destsByRef) {
  for (const r of rows) {
    const where = [SHEETS.tours, r.__row];
    if (!text(r.ref)) err(...where, "ref is required.");
    if (!text(r.title)) err(...where, "title is required.");

    const stops = list(r.stop_refs_in_order);
    if (stops.length === 0) err(...where, "a tour needs at least one stop.");
    for (const s of stops) {
      if (!destsByRef.has(s)) {
        err(...where, `stop "${s}" is not on the Destinations sheet.`);
      }
    }
    if (!text(r.route_file)) {
      warn(
        ...where,
        "no route file. The app draws the route the province authors rather " +
          "than computing one, so this tour will show pins with no line between them.",
      );
    }
  }
  return rows;
}

function validateGuides(rows) {
  for (const r of rows) {
    const where = [SHEETS.guides, r.__row];
    if (!text(r.ref)) err(...where, "ref is required.");
    if (!text(r.name)) err(...where, "name is required.");
    if (!text(r.town)) err(...where, "town is required.");
    if (!text(r.contact_phone) && !text(r.contact_email)) {
      err(...where, "a guide needs a phone number or an email address.");
    }
    if (!bool(r.consent_to_publish)) {
      err(
        ...where,
        `"${text(r.name)}" has not consented to publication. This row lists a ` +
          `real person's contact details and is not imported without consent.`,
      );
    }
  }
  return rows;
}

// ---------------------------------------------------------------------------
// Media
// ---------------------------------------------------------------------------

/**
 * A Storage-safe object name derived from the sheet's filename.
 *
 * Deliberately **not** the CMS's `{timestamp}.{ext}`. That convention exists so
 * an interactive delete never renumbers the surviving photos; an import
 * replaces the whole set at once and has no such problem. What it does have is
 * the opposite problem: a fresh timestamp every run means re-importing a
 * corrected sheet uploads new objects and strands the old ones. A name derived
 * from the source file overwrites in place, so re-import is idempotent in
 * Storage as well as Firestore — and an object can be traced back to the row
 * that produced it.
 */
function objectName(filename) {
  const ext = extname(filename).slice(1).toLowerCase();
  const stem = basename(filename, extname(filename))
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
  return `${stem || "image"}.${ext}`;
}

/** Filenames in the media directory, matched case-insensitively. */
function indexMedia(dir) {
  const index = new Map();
  if (!dir) return index;
  for (const name of readdirSync(dir)) {
    index.set(name.toLowerCase(), join(dir, name));
  }
  return index;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const workbook = new ExcelJS.Workbook();
await workbook.xlsx.readFile(workbookPath);

const rows = Object.fromEntries(
  Object.entries(SHEETS).map(([key, title]) => [
    key,
    sheetRows(workbook.getWorksheet(title)),
  ]),
);

for (const [key, title] of Object.entries(SHEETS)) {
  if (!workbook.getWorksheet(title)) {
    console.error(
      `The workbook has no sheet named "${title}". Sheets found: ` +
        workbook.worksheets.map((w) => w.name).join(", "),
    );
    process.exit(1);
  }
  void key;
}

const destsByRef = validateDestinations(rows.destinations);
const segmentsByDest = validateSegments(rows.segments, destsByRef);
const photosByDest = validatePhotos(rows.photos, destsByRef);
validateTours(rows.tours, destsByRef);
validateGuides(rows.guides);

const media = indexMedia(mediaDir);
if (mediaDir) {
  for (const [, photos] of photosByDest) {
    for (const p of photos) {
      if (!media.has(text(p.filename).toLowerCase())) {
        err(SHEETS.photos, p.__row, `"${text(p.filename)}" is not in ${mediaDir}.`);
      }
    }
  }
  for (const [, stops] of segmentsByDest) {
    for (const s of stops) {
      const f = text(s.recording_filename);
      if (f && !media.has(f.toLowerCase())) {
        err(SHEETS.segments, s.__row, `"${f}" is not in ${mediaDir}.`);
      }
    }
  }
} else {
  const wanted =
    [...photosByDest.values()].flat().length +
    [...segmentsByDest.values()].flat().filter((s) => text(s.recording_filename)).length;
  if (wanted > 0) {
    warnings.push(
      `${wanted} media file${wanted === 1 ? " is" : "s are"} named in the sheets ` +
        `but --media was not given, so no files will be uploaded. The rows import ` +
        `without them; re-run with --media to attach them.`,
    );
  }
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

console.log(`\nWorkbook: ${basename(workbookPath)}`);
console.log(
  `Rows read — destinations ${rows.destinations.length}, stops ${rows.segments.length}, ` +
    `tours ${rows.tours.length}, guides ${rows.guides.length}, photos ${rows.photos.length}`,
);

if (warnings.length) {
  console.log(`\n${warnings.length} warning${warnings.length === 1 ? "" : "s"}:`);
  for (const w of warnings) console.log(`  ~ ${w}`);
}

if (errors.length) {
  console.log(`\n${errors.length} error${errors.length === 1 ? "" : "s"}:`);
  for (const e of errors) console.log(`  x ${e}`);
  console.log(
    "\nNothing was written. Validation is all-or-nothing on purpose: a " +
      "half-imported province is worse than an unimported one, because you " +
      "cannot tell by looking which half arrived.",
  );
  process.exit(1);
}

if (!commit) {
  console.log("\nDRY RUN — nothing written. Would import:");
  for (const [ref, d] of destsByRef) {
    const stops = segmentsByDest.get(ref)?.length ?? 0;
    const pics = photosByDest.get(ref)?.length ?? 0;
    console.log(
      `  ${ref.padEnd(12)} ${text(d.name).padEnd(34)} ` +
        `slug=${slugify(text(d.name)).padEnd(28)} ${stops} stops, ${pics} photos`,
    );
  }
  console.log(`  ${rows.tours.length} tours, ${rows.guides.length} guides`);
  console.log("\nRe-run with --commit to write.");
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Write
// ---------------------------------------------------------------------------

if (live) {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) {
    console.error(
      "\n--live needs GOOGLE_APPLICATION_CREDENTIALS pointing at a service " +
        "account JSON. Firebase console -> Project settings -> Service accounts.",
    );
    process.exit(1);
  }
  console.warn(
    `\n!!  LIVE project "${projectId}". Content imports as draft, but it is ` +
      `real data in the real database.\n`,
  );
  initializeApp({
    credential: cert(JSON.parse(readFileSync(keyPath, "utf8"))),
    projectId,
    storageBucket: `${projectId}.firebasestorage.app`,
  });
} else {
  // The Admin SDK reaches the emulators purely through these, and needs no
  // credentials when they are set. Ports match firebase.json.
  process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= "127.0.0.1:9199";
  console.log(
    `\nEmulator mode (firestore ${process.env.FIRESTORE_EMULATOR_HOST}, ` +
      `storage ${process.env.FIREBASE_STORAGE_EMULATOR_HOST}), project "${projectId}".`,
  );
  initializeApp({
    credential: applicationDefault(),
    projectId,
    storageBucket: `${projectId}.appspot.com`,
  });
}

const db = getFirestore();
const bucket = mediaDir ? getStorage().bucket() : null;

async function upload(localPath, destPath, contentType) {
  await bucket.upload(localPath, {
    destination: destPath,
    metadata: contentType ? { contentType } : undefined,
  });
  return destPath;
}

const IMAGE_MIME = {
  jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp",
};
const AUDIO_MIME = {
  mp3: "audio/mpeg", m4a: "audio/mp4", aac: "audio/aac",
  wav: "audio/wav", ogg: "audio/ogg",
};

/** Find the existing destination with this slug, if any. */
async function findBySlug(slug) {
  const snap = await db.collection("destinations").where("slug", "==", slug).get();
  return snap.empty ? null : snap.docs[0];
}

let created = 0;
let updated = 0;

for (const [ref, r] of destsByRef) {
  const name = text(r.name);
  const slug = slugify(name);
  const lat = num(r.latitude);
  const lng = num(r.longitude);

  const practical = compact({
    entryFee: text(r.entry_fee),
    openHours: text(r.open_hours),
    bestSeason: text(r.best_season),
    accessibility: text(r.accessibility),
  });

  const doc = {
    name,
    slug,
    town: text(r.town),
    category: text(r.category).toLowerCase(),
    description: text(r.short_description),
    coords:
      lat !== null && lng !== null ? { lat, lng } : { ...CAGAYAN_CENTRE },
    popular: bool(r.show_in_popular, false),
    featured: bool(r.featured, false),
    nearbyEligible: bool(r.eligible_for_nearby, true),
    offlineEligible: bool(r.include_in_offline, true),
    isMuseum: bool(r.is_museum, false),
    // Set by the AR editor when a marker exists, never by intake.
    hasAR: false,
    tags: list(r.tags).map((t) => t.toLowerCase()),
    status: "draft",
    schemaVersion: DESTINATION_SCHEMA_VERSION,
    updatedAt: FieldValue.serverTimestamp(),
    // No `updatedBy`: this was not a person editing in the CMS, and writing a
    // uid here would misattribute the change to whoever ran the script.
    updatedBy: null,
  };
  if (text(r.history)) doc.history = text(r.history);
  if (Object.keys(practical).length) doc.practical = practical;

  const existing = await findBySlug(slug);
  const destRef = existing ? existing.ref : db.collection("destinations").doc();
  const previousImages = existing ? (existing.data().images ?? []) : [];

  if (!existing) {
    doc.createdAt = FieldValue.serverTimestamp();
    doc.images = [];
    created++;
  } else {
    updated++;
  }

  // Photos first, so `images` is written in the same update as everything else
  // rather than leaving a window where the destination exists with no card.
  //
  // A destination with no photo rows is left entirely alone — images and
  // Storage both. The sheet is authoritative only for what it actually
  // mentions; treating silence as "delete the photos" would wipe anything an
  // administrator had uploaded through the CMS.
  const photos = photosByDest.get(ref) ?? [];
  let imagePaths = null;
  if (bucket && photos.length) {
    const ordered = [...photos].sort(
      (a, b) => Number(bool(b.use_as_cover)) - Number(bool(a.use_as_cover)),
    );
    imagePaths = [];
    for (const p of ordered) {
      const filename = text(p.filename);
      const ext = extname(filename).slice(1).toLowerCase();
      const destPath = `destinations/${destRef.id}/images/${objectName(filename)}`;
      imagePaths.push(
        await upload(media.get(filename.toLowerCase()), destPath, IMAGE_MIME[ext]),
      );
    }
    doc.images = imagePaths;
  }

  await destRef.set(doc, { merge: true });

  // Only now that the document no longer points at them. The reverse order
  // would leave a live document referencing a deleted object if the write
  // failed — a broken image in the app rather than a wasted one in the bucket.
  if (imagePaths) {
    for (const stale of previousImages.filter((p) => !imagePaths.includes(p))) {
      await bucket.file(stale).delete().catch(() => {});
    }
  }

  // Segments: the sheet is the whole guide, so anything left over from a
  // previous import goes. Ids are `stop-01`, `stop-02` … rather than random,
  // for two reasons: re-importing overwrites the same documents instead of
  // orphaning the old ones, and the audio path stays `{segmentId}.{ext}` per
  // docs/DATA_MODEL.md while still being stable across runs.
  const stops = (segmentsByDest.get(ref) ?? []).sort(
    (a, b) => num(a.stop_number) - num(b.stop_number),
  );
  const segCol = destRef.collection("segments");
  const existingSegs = await segCol.get();
  const previousAudio = existingSegs.docs
    .map((d) => d.data().audioUrl)
    .filter(Boolean);
  const audioById = new Map(
    existingSegs.docs
      .filter((d) => d.data().audioUrl)
      .map((d) => [d.id, d.data().audioUrl]),
  );

  const batch = db.batch();
  const keep = new Set();
  const liveAudio = [];

  for (const [i, s] of stops.entries()) {
    const id = `stop-${String(i + 1).padStart(2, "0")}`;
    keep.add(id);
    const segRef = segCol.doc(id);
    const seg = { title: text(s.stop_title), order: i + 1 };
    if (text(s.stop_caption)) seg.description = text(s.stop_caption);
    if (text(s.narration_script)) seg.ttsText = text(s.narration_script);

    const recording = text(s.recording_filename);
    if (bucket && recording) {
      const ext = extname(recording).slice(1).toLowerCase();
      seg.audioUrl = await upload(
        media.get(recording.toLowerCase()),
        `destinations/${destRef.id}/audio/${id}.${ext}`,
        AUDIO_MIME[ext],
      );
      liveAudio.push(seg.audioUrl);
    } else if (recording && audioById.has(id)) {
      // The sheet still names a recording but this run has no --media, so the
      // file already uploaded stands. Without this the full-overwrite below
      // would quietly strip `audioUrl` and the stop would fall back to TTS —
      // re-importing a corrected spelling would silently unpublish the audio.
      seg.audioUrl = audioById.get(id);
      liveAudio.push(seg.audioUrl);
    }
    // A full overwrite, not a merge: a stop that loses its recording must lose
    // `audioUrl` too, or the player keeps reaching for a file the sheet no
    // longer claims exists.
    batch.set(segRef, seg);
  }

  for (const old of existingSegs.docs) {
    if (!keep.has(old.id)) batch.delete(old.ref);
  }
  await batch.commit();

  if (bucket) {
    for (const stale of previousAudio.filter((p) => !liveAudio.includes(p))) {
      await bucket.file(stale).delete().catch(() => {});
    }
  }

  console.log(
    `  ${existing ? "updated" : "created"}  ${name} (${slug}) — ` +
      `${stops.length} stops, ${doc.images?.length ?? "existing"} photos`,
  );
}

// Tours reference destinations by document id, so they are written after every
// destination exists.
const idByRef = new Map();
for (const [ref, r] of destsByRef) {
  const found = await findBySlug(slugify(text(r.name)));
  if (found) idByRef.set(ref, found.id);
}

for (const t of rows.tours) {
  const stops = list(t.stop_refs_in_order).map((s) => idByRef.get(s)).filter(Boolean);
  await db
    .collection("tours")
    .doc(slugify(text(t.title)))
    .set(
      compact({
        title: text(t.title),
        description: text(t.description),
        stops,
        coverImg: "",
        featured: bool(t.featured, false),
        updatedAt: FieldValue.serverTimestamp(),
      }),
      { merge: true },
    );
  console.log(`  tour     ${text(t.title)} — ${stops.length} stops`);
}

for (const g of rows.guides) {
  await db
    .collection("guides")
    .doc(slugify(text(g.name)))
    .set(
      compact({
        name: text(g.name),
        town: text(g.town),
        specialties: list(g.specialties),
        // The schema carries one contact field; the sheet collects phone and
        // email separately because that is how the accreditation unit holds it.
        contact: [text(g.contact_phone), text(g.contact_email)]
          .filter(Boolean)
          .join(" · "),
        verified: bool(g.accredited, false),
        featured: bool(g.featured, false),
        updatedAt: FieldValue.serverTimestamp(),
      }),
      { merge: true },
    );
  console.log(`  guide    ${text(g.name)}`);
}

console.log(
  `\nDone. ${created} destination${created === 1 ? "" : "s"} created, ` +
    `${updated} updated, ${rows.tours.length} tours, ${rows.guides.length} guides.`,
);
console.log(
  "Everything is a draft. Open the CMS to review and publish — nothing is " +
    "visible in the app until you do.",
);
