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
import { deleteObject, getMetadata, ref, uploadBytes } from "firebase/storage";

let env;

// The same project of its own as firestore.test.mjs, so its bucket is not the
// one the CMS uploads to on this machine.
const PROJECT_ID = "demo-lakbayan-rules";

const MB = 1024 * 1024;
const bytes = (n) => new Uint8Array(n);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: readFileSync("../storage.rules", "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });

  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(
      ref(ctx.storage(), "destinations/callao-cave/images/seeded.webp"),
      bytes(1024),
      { contentType: "image/webp" },
    );
  });
});

after(async () => {
  await env?.cleanup();
});

const admin = () => env.authenticatedContext("admin", { admin: true }).storage();
const user = () => env.authenticatedContext("tourist").storage();
const guest = () => env.unauthenticatedContext().storage();

const put = (storage, path, size, contentType) =>
  uploadBytes(ref(storage, path), bytes(size), { contentType });

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
    await env.withSecurityRulesDisabled((ctx) =>
      uploadBytes(ref(ctx.storage(), path), bytes(10), { contentType: "image/webp" }),
    );
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
});

describe("everywhere else", () => {
  it("is closed, to admins too", async () => {
    await assertFails(put(admin(), "users/someone/photo.webp", 1024, "image/webp"));
  });
});
