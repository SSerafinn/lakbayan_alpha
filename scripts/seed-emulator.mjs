// Populate the Emulator Suite with published sample content.
//
// The emulator starts empty after a reset, and an empty backend is
// indistinguishable from a broken connection when you are looking at the app:
// both give you a blank Explore tab. This puts real Cagayan destinations in
// front of you in a couple of seconds so the two can be told apart.
//
//   docker compose up -d emulators
//   cd scripts && npm install
//   node seed-emulator.mjs [admin@example.com]
//
// It also creates an admin account, because a reset wipes Auth too and the
// three things you need afterwards — an account, its `admin` claim, and some
// content — were three separate chores. `grant-admin.mjs` remains the tool for
// promoting a *real* person on a *real* project; this is the emulator shortcut.
//
// Re-runnable: documents are keyed by slug, so running it again overwrites
// rather than duplicates.
//
// Unlike scripts/import-content.mjs, this writes **published** documents. That
// is the whole point — the app only ever reads `status == 'published'`, so
// drafts would leave Explore just as empty as no data at all. It is also why
// this script has no `--live` flag and refuses to run against anything but a
// `demo-` project: publishing invented content straight into a real database
// is not a thing that should be one typo away.
//
// Use `import-content.mjs` for real content from the province. This is scaffolding.

import { deflateSync } from "node:zlib";

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

const PROJECT_ID = "demo-lakbayan";
const SCHEMA_VERSION = 2;

/** Emulator-only credentials. Safe to hardcode; see the guard below. */
const ADMIN_EMAIL = process.argv[2] ?? "test@gmail.com";
const ADMIN_PASSWORD = "password";

process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= "127.0.0.1:9199";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";

// Belt and braces. The env vars above are what actually route the Admin SDK at
// the emulator; this catches the case where someone has exported a different
// value in their shell and would otherwise seed a real project without noticing.
if (!PROJECT_ID.startsWith("demo-")) {
  console.error("Refusing to seed a non-demo project.");
  process.exit(1);
}

initializeApp({
  credential: applicationDefault(),
  projectId: PROJECT_ID,
  storageBucket: `${PROJECT_ID}.appspot.com`,
});

const db = getFirestore();
const bucket = getStorage().bucket();

// ---------------------------------------------------------------------------
// Preflight
//
// Without this the first Admin SDK call throws a raw ECONNREFUSED stack trace,
// which is a poor answer to "why is my app empty" from a script whose entire
// job is to make that question easy. Check all three up front and say which.
// ---------------------------------------------------------------------------

async function reachable(hostPort) {
  const [host, port] = hostPort.split(":");
  try {
    // Any HTTP response at all proves something is listening; the emulators
    // answer 404 or 501 on `/` depending on which one it is.
    await fetch(`http://${host}:${port}/`, {
      signal: AbortSignal.timeout(3000),
    });
    return true;
  } catch {
    return false;
  }
}

const PORTS = {
  Firestore: process.env.FIRESTORE_EMULATOR_HOST,
  Auth: process.env.FIREBASE_AUTH_EMULATOR_HOST,
  Storage: process.env.FIREBASE_STORAGE_EMULATOR_HOST,
};

const down = [];
for (const [name, hostPort] of Object.entries(PORTS)) {
  if (!(await reachable(hostPort))) down.push(`${name} (${hostPort})`);
}

if (down.length) {
  console.error(
    `Cannot reach the emulator suite: ${down.join(", ")}.\n\n` +
      "  docker compose up -d emulators\n\n" +
      "If the container reports healthy but ports are unreachable, check that\n" +
      "Docker actually published them — `docker port lakbayan-emulators`. On\n" +
      "Windows a port inside a reserved range makes the container start with\n" +
      "most ports unmapped, which looks like a network fault but is not:\n" +
      "  netsh interface ipv4 show excludedportrange protocol=tcp",
  );
  process.exit(1);
}

// ---------------------------------------------------------------------------
// An admin account
//
// Every content rule gates on `request.auth.token.admin`, so without this the
// CMS signs you in and then tells you that you are not an administrator.
// ---------------------------------------------------------------------------

async function ensureAdmin(email) {
  const auth = getAuth();
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (err) {
    if (err.code !== "auth/user-not-found") throw err;
    user = await auth.createUser({
      email,
      password: ADMIN_PASSWORD,
      emailVerified: true,
    });
  }

  // Read-modify-write: setCustomUserClaims replaces the whole object, so a
  // blind set would drop any other claim. Same reasoning as grant-admin.mjs.
  await auth.setCustomUserClaims(user.uid, {
    ...(user.customClaims ?? {}),
    admin: true,
  });
  return user;
}

const admin = await ensureAdmin(ADMIN_EMAIL);
console.log(
  `Admin: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}  (${admin.uid})\n` +
    "  If you were already signed in, sign out and back in — the claim is " +
    "baked into the ID token and will not appear until it is reissued.\n",
);

// ---------------------------------------------------------------------------
// A placeholder cover image per destination.
//
// Generated rather than committed: a handful of real photographs would be
// megabytes of binary in the repo for something that exists only to prove the
// image pipeline works. Each destination gets its own colour so the cards are
// distinguishable at a glance and a mis-wired image is obvious.
// ---------------------------------------------------------------------------

const CRC = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

/** A solid-colour PNG, 16:9 like the cards expect. */
function solidPng(width, height, [r, g, b]) {
  const stride = width * 3 + 1;
  const raw = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const row = y * stride;
    raw[row] = 0; // filter type: none
    for (let x = 0; x < width; x++) {
      raw[row + 1 + x * 3] = r;
      raw[row + 2 + x * 3] = g;
      raw[row + 3 + x * 3] = b;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // colour type: truecolour
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// ---------------------------------------------------------------------------
// The content
// ---------------------------------------------------------------------------

/** Same derivation as the CMS and the importer — see cms/src/types/destination.ts. */
function slugify(name) {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

const DESTINATIONS = [
  {
    name: "Callao Cave",
    town: "Peñablanca",
    category: "nature",
    description:
      "A seven-chamber limestone cave, one chamber fitted as a chapel, reached by a stairway up from the Pinacanauan river.",
    history:
      "The cave system sits in the Peñablanca Protected Landscape and Seascape. "
      + "The second chamber has been used as a chapel for decades, lit through a "
      + "natural opening in the rock. Nearby excavations produced the fossil remains "
      + "described in 2019 as a distinct hominin species.",
    coords: { lat: 17.7089, lng: 121.8226 },
    colour: [46, 92, 74],
    popular: true,
    featured: true,
    tags: ["caves", "river", "chapel"],
    practical: {
      entryFee: "PHP 20",
      openHours: "8:00am – 4:00pm daily",
      bestSeason: "Dry season, November to April",
      accessibility: "184 steps from the road; not wheelchair accessible",
    },
    segments: [
      {
        title: "The river crossing",
        description: "Where the trail begins.",
        ttsText:
          "You are standing on the bank of the Pinacanauan river. The boats "
          + "across are run by the local boatmen's association, and the crossing "
          + "takes about five minutes.",
      },
      {
        title: "The stairway",
        description: "184 steps up to the mouth.",
        ttsText:
          "The stairway ahead climbs 184 steps to the cave mouth. Take your "
          + "time — there are landings to rest on, and the view back over the "
          + "river is worth stopping for.",
      },
      {
        title: "The chapel chamber",
        description: "The second chamber.",
        ttsText:
          "This is the second chamber. The altar was built here because of the "
          + "opening above you, which lights the space for most of the day "
          + "without any electricity at all.",
      },
    ],
  },
  {
    name: "Basilica Minore de Nuestra Señora de Piat",
    town: "Piat",
    category: "church",
    description:
      "A seventeenth-century pilgrimage basilica housing the venerated image of Our Lady of Piat.",
    history:
      "The image was brought from Macau in 1604 and moved to Piat in 1622. The "
      + "basilica draws pilgrims from across the Cagayan Valley, most heavily "
      + "during the July feast.",
    coords: { lat: 17.7936, lng: 121.4789 },
    colour: [123, 92, 46],
    popular: true,
    featured: false,
    tags: ["pilgrimage", "heritage", "church"],
    practical: {
      entryFee: "Free",
      openHours: "6:00am – 6:00pm",
      bestSeason: "July, for the feast",
      accessibility: "Ramp at the side entrance",
    },
    segments: [
      {
        title: "The facade",
        description: "Approaching from the plaza.",
        ttsText:
          "The facade in front of you has been rebuilt more than once. What you "
          + "see now dates largely from the nineteenth century, though the "
          + "foundations are much older.",
      },
      {
        title: "The camarin",
        description: "Behind the altar.",
        ttsText:
          "Behind the altar is the camarin, where pilgrims climb to touch the "
          + "mantle of the image. Join the queue on the right-hand side.",
      },
    ],
  },
  {
    name: "Palaui Island",
    town: "Santa Ana",
    category: "nature",
    description:
      "A protected island off the northeastern tip of Luzon, with the Cape Engaño lighthouse on its headland.",
    history:
      "Palaui is a protected landscape and seascape reached by boat from San "
      + "Vicente. The Spanish-era Cape Engaño lighthouse stands on the northern "
      + "headland, above Anguib and Punta Verde beaches.",
    coords: { lat: 18.5486, lng: 122.1372 },
    colour: [38, 106, 122],
    popular: true,
    featured: true,
    tags: ["island", "beach", "lighthouse", "hiking"],
    practical: {
      entryFee: "Boat hire, shared or private",
      openHours: "Daylight crossings only",
      bestSeason: "March to May; crossings are weather-dependent",
      accessibility: "Boat transfer and a steep walk to the lighthouse",
    },
    segments: [],
  },
  {
    name: "Cagayan Museum and Historical Research Center",
    town: "Tuguegarao City",
    category: "museum",
    description:
      "The provincial museum, holding archaeological finds from the Cagayan valley alongside colonial-era records.",
    history:
      "The collection covers the valley's prehistory through the Spanish period, "
      + "including material recovered from the Peñablanca cave systems.",
    coords: { lat: 17.6132, lng: 121.727 },
    colour: [92, 60, 110],
    popular: false,
    featured: false,
    isMuseum: true,
    tags: ["museum", "history", "archaeology"],
    practical: {
      entryFee: "Free",
      openHours: "Monday to Friday, 8:00am – 5:00pm",
      accessibility: "Ground floor accessible",
    },
    segments: [],
  },
  {
    name: "St. Peter Metropolitan Cathedral",
    town: "Tuguegarao City",
    category: "heritage",
    description:
      "A red-brick baroque cathedral completed in 1767, the seat of the Archdiocese of Tuguegarao.",
    history:
      "Built by Dominican missionaries and completed in 1767, the cathedral is "
      + "among the largest brick churches in the Cagayan Valley.",
    coords: { lat: 17.6132, lng: 121.7269 },
    colour: [140, 68, 52],
    popular: false,
    featured: true,
    tags: ["heritage", "church", "baroque"],
    practical: { entryFee: "Free", openHours: "5:00am – 7:00pm" },
    segments: [],
  },
  {
    name: "Buntun Bridge",
    town: "Tuguegarao City",
    category: "landmark",
    description:
      "One of the longest river bridges in the Philippines, crossing the Cagayan river west of Tuguegarao.",
    history:
      "The bridge spans the Cagayan river, the country's longest, and is a "
      + "well-known vantage point for sunsets over the water.",
    coords: { lat: 17.6203, lng: 121.6906 },
    colour: [70, 84, 100],
    popular: false,
    featured: false,
    tags: ["bridge", "river", "sunset"],
    practical: { entryFee: "Free", openHours: "Open at all hours" },
    segments: [],
  },
];

// ---------------------------------------------------------------------------

let written = 0;

for (const d of DESTINATIONS) {
  const slug = slugify(d.name);
  // Slug as the document id. The CMS lets Firestore mint a random one, but a
  // deterministic id is what makes re-seeding overwrite instead of duplicate,
  // and it makes a document easy to find in the Emulator UI.
  const ref = db.collection("destinations").doc(slug);

  const imagePath = `destinations/${slug}/images/cover.png`;
  await bucket
    .file(imagePath)
    .save(solidPng(640, 360, d.colour), { contentType: "image/png" });

  await ref.set({
    name: d.name,
    slug,
    town: d.town,
    category: d.category,
    description: d.description,
    history: d.history,
    coords: d.coords,
    images: [imagePath],
    popular: d.popular ?? false,
    featured: d.featured ?? false,
    nearbyEligible: true,
    offlineEligible: true,
    isMuseum: d.isMuseum ?? false,
    hasAR: false,
    tags: d.tags ?? [],
    practical: d.practical ?? {},
    // The reason this script exists rather than reusing the importer.
    status: "published",
    schemaVersion: SCHEMA_VERSION,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: null,
  });

  // Replace the guide wholesale, so re-seeding after editing this file does not
  // leave yesterday's stops behind at the same `order`.
  const segCol = ref.collection("segments");
  for (const old of (await segCol.get()).docs) await old.ref.delete();
  for (const [i, s] of (d.segments ?? []).entries()) {
    await segCol.doc(`stop-${String(i + 1).padStart(2, "0")}`).set({
      title: s.title,
      description: s.description,
      ttsText: s.ttsText,
      order: i + 1,
    });
  }

  written++;
  console.log(
    `  ${d.name} (${slug}) — ${(d.segments ?? []).length} stops` +
      `${d.popular ? ", popular" : ""}${d.featured ? ", featured" : ""}`,
  );
}

console.log(
  `\nSeeded ${written} published destinations into the emulator ` +
    `(${process.env.FIRESTORE_EMULATOR_HOST}).`,
);
console.log("Emulator UI: http://localhost:4000/firestore");
