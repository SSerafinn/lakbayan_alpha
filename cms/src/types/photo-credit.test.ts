import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { emptyDestination, publishBlockers, readiness } from "./destination";
import {
  creditsToSave,
  isPublicLicence,
  needsAttribution,
  photoCreditLine,
  withCredit,
} from "./photo-credit";

/**
 * The CMS half of the credit line. The app's half is
 * `test/features/destinations/photo_credit_test.dart`, on the same fixture:
 * the Photos tab previews the line the app shows, and a preview that drifts
 * from the app tells an editor something untrue.
 */
const here = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(
  readFileSync(join(here, "photo-credit-cases.json"), "utf8"),
) as { cases: { credit?: string; licence?: string; line: string | null }[] };

describe("photoCreditLine", () => {
  it("has cases to check", () => {
    expect(fixture.cases.length).toBeGreaterThan(10);
  });

  it.each(fixture.cases)(
    "$credit + $licence -> $line",
    ({ credit, licence, line }) => {
      expect(photoCreditLine({ credit, licence })).toBe(line);
    },
  );

  it("no credit recorded is no line", () => {
    expect(photoCreditLine(undefined)).toBeNull();
  });
});

describe("licences", () => {
  it("knows a public licence from a permission note", () => {
    expect(isPublicLicence("CC BY-SA 4.0")).toBe(true);
    expect(isPublicLicence("Public domain")).toBe(true);
    expect(isPublicLicence("Province-owned; approved for the app")).toBe(false);
  });

  it("asks for a name under every Creative Commons licence but CC0", () => {
    expect(needsAttribution("CC BY 2.0")).toBe(true);
    expect(needsAttribution("CC BY-SA 4.0")).toBe(true);
    expect(needsAttribution("Creative Commons Attribution 4.0")).toBe(true);
    expect(needsAttribution("CC0 1.0")).toBe(false);
    expect(needsAttribution("Creative Commons Zero")).toBe(false);
    expect(needsAttribution("Public domain")).toBe(false);
    expect(needsAttribution("Province-owned; approved for the app")).toBe(false);
    expect(needsAttribution("")).toBe(false);
  });
});

describe("withCredit", () => {
  const path = "destinations/d/images/1.webp";

  it("sets one field and keeps the other", () => {
    const one = withCredit({}, path, { credit: "Patrickroque01" });
    const both = withCredit(one, path, { licence: "CC BY-SA 4.0" });
    expect(both).toEqual({
      [path]: { credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
    });
  });

  it("keeps text as typed, so the box does not fight the cursor", () => {
    expect(withCredit({}, path, { credit: "Elmer " })[path]).toEqual({
      credit: "Elmer ",
    });
  });

  it("drops an entry once both boxes are cleared", () => {
    const set = withCredit(undefined, path, { credit: "A", licence: "B" });
    const cleared = withCredit(
      withCredit(set, path, { credit: "" }),
      path,
      { licence: "" },
    );
    expect(cleared).toEqual({});
  });

  it("leaves other photos' credits alone", () => {
    const other = { "destinations/d/images/2.webp": { credit: "Someone" } };
    expect(withCredit(other, path, { credit: "A" })).toEqual({
      ...other,
      [path]: { credit: "A" },
    });
  });
});

describe("creditsToSave", () => {
  it("keeps only photos still on the place, trimmed", () => {
    expect(
      creditsToSave(["a.webp", "b.webp"], {
        "a.webp": { credit: " Patrickroque01 ", licence: "CC BY-SA 4.0 " },
        "b.webp": { credit: "  ", licence: "" },
        "gone.webp": { credit: "Removed with its photo" },
      }),
    ).toEqual({
      "a.webp": { credit: "Patrickroque01", licence: "CC BY-SA 4.0" },
    });
  });

  it("is empty for a document from before v5", () => {
    expect(creditsToSave(["a.webp"], undefined)).toEqual({});
  });
});

describe("readiness", () => {
  const place = (credits: Record<string, { credit?: string; licence?: string }>) => ({
    ...emptyDestination(),
    name: "Callao Cave",
    slug: "callao-cave",
    town: "Peñablanca",
    description: "Seven chambers.",
    coords: { lat: 17.7, lng: 121.8 },
    images: ["a.webp", "b.webp"],
    imageCredits: credits,
  });
  const item = (d: ReturnType<typeof place>) =>
    readiness(d).find((r) => r.label === "Every Creative Commons photo is credited");

  it("asks nothing of a place with no Creative Commons photo", () => {
    expect(item(place({}))).toBeUndefined();
    expect(
      item(
        place({
          "a.webp": {
            credit: "Cagayan Provincial Tourism Office",
            licence: "Province-owned; approved for the app",
          },
        }),
      ),
    ).toBeUndefined();
  });

  it("will not publish a Creative Commons photo nobody is credited for", () => {
    const d = place({ "b.webp": { licence: "CC BY 2.0" } });
    expect(item(d)).toMatchObject({ ok: false, tab: "media" });
    expect(publishBlockers(d)).toContainEqual(
      expect.stringContaining("1 photo is under a Creative Commons licence"),
    );
  });

  it("passes once it is", () => {
    const d = place({ "b.webp": { credit: "mkirader", licence: "CC BY 2.0" } });
    expect(item(d)).toMatchObject({ ok: true });
    expect(publishBlockers(d)).toEqual([]);
  });

  it("ignores a credit whose photo is gone", () => {
    expect(item(place({ "gone.webp": { licence: "CC BY 2.0" } }))).toBeUndefined();
  });
});
