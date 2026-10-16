// Storage security rules tests.
//
// storage.rules decides what may land in a public bucket that every phone
// downloads from: an oversized photo costs every tourist mobile data, and a
// file served under the wrong type is a web page on our domain. Run against
// the emulator, as firestore.test.mjs is:
//
//   docker compose up -d emulators
//   cd test_rules && npm install && npm test

import { after, before, describe, it } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import {
  deleteObject,
  getMetadata,
  listAll,
  ref,
  updateMetadata,
  uploadBytes,
} from "firebase/storage";

let env;

// The same project of its own as firestore.test.mjs, so its bucket is not the
// one the CMS uploads to on this machine.
const PROJECT_ID = "demo-lakbayan-rules";

const MB = 1024 * 1024;
const bytes = (n) => new Uint8Array(n);

// Writes a file past the rules, so that a test of a read, a metadata edit or a
// delete is not also a test of the upload that put the file there.
const seed = (path, contentType, size = 1024) =>
  env.withSecurityRulesDisabled((ctx) =>
    uploadBytes(ref(ctx.storage(), path), bytes(size), { contentType }),
  );

// Deletes every object in this project's bucket, folders included.
//
// Not env.clearStorage(), the counterpart of firestore.test.mjs's
// clearFirestore(): it deletes only what listAll() returns at the bucket root,
// and every fixture here sits in a folder, so it deleted nothing. Against the
// `docker compose` emulators, which export on exit and import on start, each
// run then saved its 50 MB map pack into the developer's .emulator-data.
// Safe to empty wholesale because nothing else uses this project's bucket.
const emptyBucket = () =>
  env.withSecurityRulesDisabled(async (ctx) => {
    const empty = async (folder) => {
      const { items, prefixes } = await listAll(folder);
      await Promise.all([...items.map(deleteObject), ...prefixes.map(empty)]);
    };
    await empty(ref(ctx.storage()));
  });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: readFileSync("../storage.rules", "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });

  await seed("destinations/callao-cave/images/seeded.webp", "image/webp");
  await seed("destinations/callao-cave/audio/seeded.m4a", "audio/mp4");
  await seed("tours/north-loop/seeded.jpg", "image/jpeg");
  await seed("ar/callao-cave/markers/seeded.jpg", "image/jpeg");
  await seed("tiles/penablanca/seeded.pmtiles", "application/octet-stream");
});

after(async () => {
  if (env) await emptyBucket();
  await env?.cleanup();
});

const admin = () => env.authenticatedContext("admin", { admin: true }).storage();
const user = () => env.authenticatedContext("tourist").storage();
const guest = () => env.unauthenticatedContext().storage();

const put = (storage, path, size, contentType) =>
  uploadBytes(ref(storage, path), bytes(size), { contentType });
const read = (storage, path) => getMetadata(ref(storage, path));
const remove = (storage, path) => deleteObject(ref(storage, path));

describe("photos", () => {
  const photo = "destinations/callao-cave/images/1700000000000.webp";

  it("an admin uploads a resized photo", async () => {
    await assertSucceeds(put(admin(), photo, 400 * 1024, "image/webp"));
  });

  it("…and a tour cover", async () => {
    await assertSucceeds(put(admin(), "tours/north-loop/cover.jpg", 400 * 1024, "image/jpeg"));
  });

  it("refuses a photo over 3 MB — one that skipped the resizing", async () => {
    await assertFails(put(admin(), photo, 3 * MB + 1, "image/jpeg"));
    await assertFails(put(admin(), "tours/north-loop/cover.jpg", 3 * MB + 1, "image/jpeg"));
  });

  it("refuses anything a browser would render as a page", async () => {
    await assertFails(put(admin(), photo, 1024, "text/html"));
    await assertFails(put(admin(), photo, 1024, "image/svg+xml"));
  });

  it("refuses a format the app cannot draw", async () => {
    await assertFails(put(admin(), photo, 1024, "image/heic"));
  });

  it("refuses anyone who is not an admin", async () => {
    await assertFails(put(user(), photo, 1024, "image/webp"));
    await assertFails(put(guest(), photo, 1024, "image/webp"));
  });

  it("is readable by anyone", async () => {
    await assertSucceeds(
      getMetadata(ref(guest(), "destinations/callao-cave/images/seeded.webp")),
    );
  });

  it("an admin deletes one, though a delete has no size or type", async () => {
    const path = "destinations/callao-cave/images/to-delete.webp";
    await seed(path, "image/webp", 10);
    await assertFails(deleteObject(ref(user(), path)));
    await assertSucceeds(deleteObject(ref(admin(), path)));
  });
});

describe("recordings", () => {
  const recording = "destinations/callao-cave/audio/seg1.m4a";

  it("an admin uploads one", async () => {
    await assertSucceeds(put(admin(), recording, 2 * MB, "audio/mp4"));
    await assertSucceeds(put(admin(), "destinations/callao-cave/audio/seg2.mp3", 2 * MB, "audio/mpeg"));
  });

  it("refuses one over 50 MB", async () => {
    await assertFails(put(admin(), recording, 50 * MB + 1, "audio/mp4"));
  });

  it("refuses anything that is not audio", async () => {
    await assertFails(put(admin(), recording, 1024, "text/html"));
    await assertFails(put(admin(), recording, 1024, "application/octet-stream"));
  });

  it("refuses anyone who is not an admin", async () => {
    const path = "destinations/callao-cave/audio/seg3.m4a";
    await assertFails(put(user(), path, 1024, "audio/mp4"));
    await assertFails(put(guest(), path, 1024, "audio/mp4"));
  });

  // A guest plays a narration without signing in, and the downloader fetches
  // it for offline use the same way.
  it("is readable by anyone", async () => {
    await assertSucceeds(read(guest(), "destinations/callao-cave/audio/seeded.m4a"));
  });

  it("an admin deletes one, and nobody else can", async () => {
    const path = "destinations/callao-cave/audio/to-delete.m4a";
    await seed(path, "audio/mp4");
    await assertFails(remove(user(), path));
    await assertFails(remove(guest(), path));
    await assertSucceeds(remove(admin(), path));
  });
});

describe("tour covers", () => {
  const cover = "tours/north-loop/cover-1700000000000.webp";

  it("refuses anyone who is not an admin", async () => {
    await assertFails(put(user(), cover, 1024, "image/webp"));
    await assertFails(put(guest(), cover, 1024, "image/webp"));
  });

  it("refuses anything that is not a photo", async () => {
    await assertFails(put(admin(), cover, 1024, "text/html"));
    await assertFails(put(admin(), cover, 1024, "image/svg+xml"));
    // The audio allowance belongs to destinations/{id}/audio, not here.
    await assertFails(put(admin(), cover, 1024, "audio/mpeg"));
  });

  it("refuses a cover a folder deeper than the rule matches", async () => {
    // `{image}` is a single path segment. docs/DATA_MODEL.md: a tour cover
    // written to any other path is rejected, not silently accepted.
    await assertFails(put(admin(), "tours/north-loop/old/cover.jpg", 1024, "image/jpeg"));
  });

  it("is readable by anyone", async () => {
    await assertSucceeds(read(guest(), "tours/north-loop/seeded.jpg"));
  });

  it("an admin deletes one, and nobody else can", async () => {
    const path = "tours/north-loop/to-delete.jpg";
    await seed(path, "image/jpeg");
    await assertFails(remove(user(), path));
    await assertFails(remove(guest(), path));
    await assertSucceeds(remove(admin(), path));
  });
});

describe("AR markers", () => {
  // Held to the photo limits (docs/DATA_MODEL.md): a marker is an image the
  // phone downloads like any other, before AR ever looks at it.
  const marker = "ar/callao-cave/markers/1.jpg";

  it("an admin uploads one", async () => {
    await assertSucceeds(put(admin(), marker, 400 * 1024, "image/jpeg"));
  });

  it("refuses one over 3 MB, or of a type a browser renders as a page", async () => {
    await assertFails(put(admin(), marker, 3 * MB + 1, "image/jpeg"));
    await assertFails(put(admin(), marker, 1024, "text/html"));
    await assertFails(put(admin(), marker, 1024, "image/svg+xml"));
  });

  it("refuses anyone who is not an admin", async () => {
    await assertFails(put(user(), marker, 1024, "image/jpeg"));
    await assertFails(put(guest(), marker, 1024, "image/jpeg"));
  });

  it("is readable by anyone", async () => {
    await assertSucceeds(read(guest(), "ar/callao-cave/markers/seeded.jpg"));
  });

  it("an admin deletes one, and nobody else can", async () => {
    const path = "ar/callao-cave/markers/to-delete.jpg";
    await seed(path, "image/jpeg");
    await assertFails(remove(user(), path));
    await assertFails(remove(guest(), path));
    await assertSucceeds(remove(admin(), path));
  });
});

describe("map packs", () => {
  const pack = "tiles/penablanca/pack.pmtiles";

  // The one path with no size or type check, on purpose: packs are tens of MB
  // and come from scripts/extract-tiles.mjs, not the CMS. This is the case
  // that would break if the photo or recording limits were copied onto it.
  it("an admin uploads one larger than any other path allows", async () => {
    await assertSucceeds(put(admin(), pack, 50 * MB + 1, "application/octet-stream"));
  });

  it("refuses anyone who is not an admin", async () => {
    await assertFails(put(user(), pack, 1024, "application/octet-stream"));
    await assertFails(put(guest(), pack, 1024, "application/octet-stream"));
  });

  // Downloading a town is open to guests, and the pack is most of it.
  it("is readable by anyone", async () => {
    await assertSucceeds(read(guest(), "tiles/penablanca/seeded.pmtiles"));
  });

  it("an admin deletes one, and nobody else can", async () => {
    const path = "tiles/penablanca/to-delete.pmtiles";
    await seed(path, "application/octet-stream");
    await assertFails(remove(user(), path));
    await assertFails(remove(guest(), path));
    await assertSucceeds(remove(admin(), path));
  });
});

describe("editing an existing file", () => {
  // Uploading over an existing object is a `create`, the same as the first
  // upload, so the suites above already hold an overwrite to the size and
  // type checks. `update` is a metadata change (updateMetadata) — the size
  // stays, but the type is whatever the request says. Re-typing a public
  // photo or recording as text/html is the same hole as uploading one, and
  // these pin that a later split of `create, update` cannot open it.
  const photo = "destinations/callao-cave/images/edit-me.webp";
  const recording = "destinations/callao-cave/audio/edit-me.m4a";
  const retype = (storage, path, contentType) =>
    updateMetadata(ref(storage, path), { contentType });

  before(async () => {
    await seed(photo, "image/webp");
    await seed(recording, "audio/mp4");
  });

  it("overwriting one is a create, held to the upload checks", async () => {
    await assertSucceeds(put(admin(), photo, 400 * 1024, "image/webp"));
    await assertFails(put(admin(), photo, 1024, "text/html"));
  });

  it("an admin corrects a file's type to another allowed one", async () => {
    await assertSucceeds(retype(admin(), photo, "image/png"));
    await assertSucceeds(retype(admin(), recording, "audio/mpeg"));
  });

  it("refuses re-typing one as anything a browser would render as a page", async () => {
    for (const path of [photo, recording]) {
      await assertFails(retype(admin(), path, "text/html"));
      await assertFails(retype(admin(), path, "image/svg+xml"));
    }
  });

  it("refuses a metadata change from anyone who is not an admin", async () => {
    await assertFails(retype(user(), photo, "image/webp"));
    await assertFails(retype(guest(), photo, "image/webp"));
    await assertFails(retype(user(), recording, "audio/mp4"));
    await assertFails(retype(guest(), recording, "audio/mp4"));
  });
});

describe("the admin claim", () => {
  // storage.rules keeps its own copy of isAdmin(), so the same case in
  // firestore.test.mjs says nothing about this file. A claim stored as the
  // string "true" or the number 1 grants nothing here either — least of all
  // on map packs, where the admin check is the only check.
  it("must be the boolean true, not a value that looks like it", async () => {
    for (const claim of ["true", 1]) {
      const pretender = env.authenticatedContext("pretender", { admin: claim }).storage();
      await assertFails(
        put(pretender, "destinations/callao-cave/images/pretender.webp", 1024, "image/webp"),
      );
      await assertFails(
        put(pretender, "tiles/penablanca/pretender.pmtiles", 1024, "application/octet-stream"),
      );
      await assertFails(remove(pretender, "tiles/penablanca/seeded.pmtiles"));
    }
  });
});

describe("everywhere else", () => {
  it("is closed, to admins too", async () => {
    await assertFails(put(admin(), "users/someone/photo.webp", 1024, "image/webp"));
  });

  // The point of enumerating paths instead of {allPaths=**}: a file that
  // lands somewhere new is private until somebody writes a rule for it.
  it("is closed to readers too, so a new path is never public by accident", async () => {
    const path = "exports/visitors.csv";
    await seed(path, "text/csv");
    await assertFails(read(guest(), path));
    await assertFails(read(admin(), path));
  });

  it("does not stretch a match to a folder deeper", async () => {
    await assertFails(
      put(admin(), "destinations/callao-cave/images/old/1.webp", 1024, "image/webp"),
    );
    await assertFails(
      put(admin(), "tiles/penablanca/old/pack.pmtiles", 1024, "application/octet-stream"),
    );
  });
});
