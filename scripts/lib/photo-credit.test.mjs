// What an import writes to `imageCredits`.
//
//   cd scripts && node --test

import { strict as assert } from "node:assert";
import { describe, it } from "node:test";

import { creditEntry, needsAttribution, planCredits } from "./photo-credit.mjs";

const A = "destinations/d/images/alc-001-01.jpg";
const B = "destinations/d/images/alc-001-02.jpg";
const CMS = "destinations/d/images/1731900000000.webp";

describe("needsAttribution", () => {
  it("is every Creative Commons licence but CC0", () => {
    assert.equal(needsAttribution("CC BY 2.0"), true);
    assert.equal(needsAttribution("CC BY-SA 4.0"), true);
    assert.equal(needsAttribution("cc-by-sa-4.0"), true);
    assert.equal(needsAttribution("Creative Commons Attribution 4.0"), true);
    assert.equal(needsAttribution("CC0 1.0"), false);
    assert.equal(needsAttribution("Creative Commons Zero"), false);
    assert.equal(needsAttribution("Public domain"), false);
    assert.equal(needsAttribution("Province-owned; approved for the app"), false);
    assert.equal(needsAttribution(""), false);
    assert.equal(needsAttribution(undefined), false);
  });
});

describe("creditEntry", () => {
  it("trims, and leaves out what is blank", () => {
    assert.deepEqual(creditEntry(" Patrickroque01 ", "CC BY-SA 4.0 "), {
      credit: "Patrickroque01",
      licence: "CC BY-SA 4.0",
    });
    assert.deepEqual(creditEntry("", "Province-owned"), { licence: "Province-owned" });
    assert.equal(creditEntry("  ", ""), null);
  });
});

describe("planCredits", () => {
  it("leaves the field alone for a place the sheet gives no photos", () => {
    assert.equal(
      planCredits({ photos: [], uploaded: true, previousImages: [], existing: {} }),
      null,
    );
  });

  it("is exactly the sheet's when this run uploaded the photos", () => {
    const plan = planCredits({
      photos: [
        { path: A, credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
        { path: B, credit: "", licence: "" },
      ],
      uploaded: true,
      previousImages: [CMS],
      // The CMS upload this import replaced, and its credit with it.
      existing: { [CMS]: { credit: "An editor" } },
    });
    assert.deepEqual(plan, {
      [A]: { credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
    });
  });

  it("without --media, credits only the photos already uploaded", () => {
    const plan = planCredits({
      photos: [
        { path: A, credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
        // Named in the sheet, never uploaded: nothing to credit.
        { path: B, credit: "Elmer Domingo", licence: "CC BY-SA 4.0" },
      ],
      uploaded: false,
      previousImages: [A, CMS],
      existing: { [CMS]: { credit: "An editor" } },
    });
    assert.deepEqual(plan, {
      [CMS]: { credit: "An editor" },
      [A]: { credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
    });
  });

  it("a corrected spelling replaces the old credit", () => {
    const plan = planCredits({
      photos: [{ path: A, credit: "Patrickroque01", licence: "CC BY-SA 4.0" }],
      uploaded: false,
      previousImages: [A],
      existing: { [A]: { credit: "Patrickroqe01", licence: "CC BY-SA 4.0" } },
    });
    assert.deepEqual(plan, {
      [A]: { credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
    });
  });

  it("a row with both columns blank clears its photo's credit", () => {
    const plan = planCredits({
      photos: [{ path: A, credit: "", licence: "" }],
      uploaded: false,
      previousImages: [A],
      existing: { [A]: { credit: "Somebody" } },
    });
    assert.deepEqual(plan, {});
  });

  it("is null when nothing would change", () => {
    const existing = { [A]: { credit: "mkirader", licence: "CC BY 2.0" } };
    for (const uploaded of [true, false]) {
      assert.equal(
        planCredits({
          photos: [{ path: A, credit: "mkirader", licence: "CC BY 2.0" }],
          uploaded,
          previousImages: [A],
          existing,
        }),
        null,
      );
    }
  });

  it("reads a missing or malformed map as empty", () => {
    for (const existing of [undefined, null, "oops"]) {
      assert.deepEqual(
        planCredits({
          photos: [{ path: A, credit: "mkirader", licence: "CC BY 2.0" }],
          uploaded: true,
          previousImages: [],
          existing,
        }),
        { [A]: { credit: "mkirader", licence: "CC BY 2.0" } },
      );
    }
  });
});
