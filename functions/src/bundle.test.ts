import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import {
  buildManifest,
  bundleStatus,
  bundleVersion,
  collectAssetPaths,
  parseGenerateRequest,
  tilePackRef,
  type BundleDestination,
} from "./bundle.js";
import { slugify } from "./slug.js";

function place(
  id: string,
  overrides: Partial<BundleDestination> = {},
): BundleDestination {
  return {
    id,
    images: [`destinations/${id}/images/1.jpg`],
    audioPaths: [],
    exhibitPaths: [],
    updatedAtMillis: 1000,
    ...overrides,
  };
}

describe("slugify", () => {
  it("agrees with the shared contract fixture", () => {
    // The same file scripts/lib/slug.test.mjs and the CMS test read. Three
    // implementations exist because the packages do not share a build; this
    // is what stops them drifting into two ids for one town.
    const path = fileURLToPath(
      new URL("../../scripts/lib/slug-cases.json", import.meta.url),
    );
    const { cases } = JSON.parse(readFileSync(path, "utf8")) as {
      cases: { name?: string; slug: string }[];
    };
    let checked = 0;
    for (const { name, slug } of cases) {
      // Comment-only entries in the fixture carry no name.
      if (name === undefined) continue;
      assert.equal(slugify(name), slug, `slugify(${JSON.stringify(name)})`);
      checked++;
    }
    // Guard the guard: a fixture that stopped parsing into named cases would
    // otherwise make this test pass by checking nothing at all.
    assert.ok(checked > 0, "no cases were read from the fixture");
  });

  it("handles the town this project actually has", () => {
    assert.equal(slugify("Peñablanca"), "penablanca");
  });
});

describe("parseGenerateRequest", () => {
  it("trims the town and defaults dryRun to false", () => {
    assert.deepEqual(parseGenerateRequest({ town: "  Aparri " }), {
      town: "Aparri",
      dryRun: false,
    });
  });

  it("rejects a missing town", () => {
    assert.throws(() => parseGenerateRequest({}), /town/);
    assert.throws(() => parseGenerateRequest({ town: "   " }), /town/);
  });

  it("rejects a non-boolean dryRun rather than coercing", () => {
    assert.throws(
      () => parseGenerateRequest({ town: "Aparri", dryRun: "true" }),
      /true or false/,
    );
  });
});

describe("collectAssetPaths", () => {
  it("includes a museum's AR markers and their narration", () => {
    // D-18: the scanner has to work offline, so a downloaded museum carries
    // the images it recognises and what it then plays.
    const paths = collectAssetPaths([
      place("museum", {
        images: [],
        exhibitPaths: [
          "ar/museum/markers/e1.webp",
          "destinations/museum/audio/e1.m4a",
        ],
      }),
    ]);
    assert.deepEqual(paths, [
      "ar/museum/markers/e1.webp",
      "destinations/museum/audio/e1.m4a",
    ]);
  });

  it("gathers images and recordings together", () => {
    const paths = collectAssetPaths([
      place("callao", {
        images: ["a.jpg", "b.jpg"],
        audioPaths: ["destinations/callao/audio/s1.mp3"],
      }),
    ]);
    assert.deepEqual(paths, [
      "a.jpg",
      "b.jpg",
      "destinations/callao/audio/s1.mp3",
    ]);
  });

  it("de-duplicates a photo two destinations share", () => {
    // Paying to download the same object twice is a poor use of somebody's
    // data allowance, and the size estimate would be wrong as well.
    const paths = collectAssetPaths([
      place("a", { images: ["shared.jpg"] }),
      place("b", { images: ["shared.jpg"] }),
    ]);
    assert.deepEqual(paths, ["shared.jpg"]);
  });

  it("drops empty strings rather than asking Storage for them", () => {
    assert.deepEqual(collectAssetPaths([place("a", { images: ["", "x.jpg"] })]), [
      "x.jpg",
    ]);
  });
});

describe("bundleVersion", () => {
  it("does not move when nothing changed", () => {
    // The whole point: a version that changed on every generate would send
    // every client off to re-download a town it already has.
    const before = bundleVersion([place("a"), place("b")]);
    const after = bundleVersion([place("a"), place("b")]);
    assert.equal(before, after);
  });

  it("ignores the order Firestore happened to return", () => {
    assert.equal(
      bundleVersion([place("a"), place("b")]),
      bundleVersion([place("b"), place("a")]),
    );
  });

  it("moves when a destination is edited", () => {
    assert.notEqual(
      bundleVersion([place("a")]),
      bundleVersion([place("a", { updatedAtMillis: 2000 })]),
    );
  });

  it("moves when a destination is added or removed", () => {
    assert.notEqual(bundleVersion([place("a")]), bundleVersion([]));
    assert.notEqual(
      bundleVersion([place("a")]),
      bundleVersion([place("a"), place("b")]),
    );
  });
});

describe("bundleStatus", () => {
  it("is ready only when nothing is missing", () => {
    assert.equal(bundleStatus([]), "ready");
    assert.equal(bundleStatus(["tiles/penablanca/pack.pmtiles"]), "pending");
  });
});

describe("buildManifest", () => {
  const destinations = [
    place("callao", {
      images: ["destinations/callao/images/1.jpg"],
      audioPaths: ["destinations/callao/audio/s1.mp3"],
    }),
  ];

  it("sums only the objects that exist", () => {
    const manifest = buildManifest(
      "Peñablanca",
      destinations,
      new Map([
        ["destinations/callao/images/1.jpg", 100],
        ["destinations/callao/audio/s1.mp3", 200],
        ["tiles/penablanca/pack.pmtiles", 700],
      ]),
    );
    assert.equal(manifest.size, 1000);
    assert.equal(manifest.status, "ready");
    assert.deepEqual(manifest.missing, []);
    assert.equal(manifest.townId, "penablanca");
    assert.equal(manifest.tilePackRef, tilePackRef("penablanca"));
  });

  it("is pending, not ready, when the tile pack is not uploaded yet", () => {
    // The app would otherwise download a bundle, find no map, and have no way
    // to tell that apart from a broken download.
    const manifest = buildManifest(
      "Peñablanca",
      destinations,
      new Map([
        ["destinations/callao/images/1.jpg", 100],
        ["destinations/callao/audio/s1.mp3", 200],
      ]),
    );
    assert.equal(manifest.status, "pending");
    assert.deepEqual(manifest.missing, ["tiles/penablanca/pack.pmtiles"]);
    // Size still reports what is there, so the CMS can say how much is ready.
    assert.equal(manifest.size, 300);
  });

  it("keeps the display name and derives the id from it", () => {
    const manifest = buildManifest("Santa Ana", destinations, new Map());
    assert.equal(manifest.name, "Santa Ana");
    assert.equal(manifest.townId, "santa-ana");
  });
});
