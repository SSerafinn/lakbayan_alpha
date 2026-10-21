import { describe, expect, it } from "vitest";
import { emptyDestination, readiness } from "./destination";
import {
  countExhibitProblems,
  emptyExhibit,
  exhibitProblems,
  fromExhibitDoc,
  isScannable,
  museumHasAR,
  planExhibitSave,
  toCentimetres,
  toExhibitDoc,
  toMetres,
  type ExhibitDraft,
} from "./exhibit";

/** A complete exhibit, overridable field by field. */
const exhibit = (over: Partial<ExhibitDraft> = {}): ExhibitDraft => ({
  id: "e1",
  title: "The Callao Man replica",
  markerPath: "ar/d1/markers/e1-1.webp",
  markerWidthM: 0.3,
  ...over,
});

describe("emptyExhibit", () => {
  it("starts with nothing to scan, and says what is missing", () => {
    const e = emptyExhibit("abc");
    expect(e).toEqual({
      id: "abc",
      title: "",
      markerPath: "",
      markerWidthM: 0,
    });
    expect(isScannable(e)).toBe(false);
    expect(Object.keys(exhibitProblems(e)).sort()).toEqual([
      "marker",
      "title",
      "width",
    ]);
  });
});

describe("exhibitProblems", () => {
  it("passes a complete exhibit", () => {
    expect(exhibitProblems(exhibit())).toEqual({});
  });

  it("needs a title, and whitespace is not one", () => {
    expect(exhibitProblems(exhibit({ title: "   " })).title).toBeDefined();
  });

  it("needs a marker photo", () => {
    expect(exhibitProblems(exhibit({ markerPath: "" })).marker).toBeDefined();
  });

  it("tells an unmeasured width from a wrong one", () => {
    const width = (m: number) =>
      exhibitProblems(exhibit({ markerWidthM: m })).width;
    const unmeasured = width(0);
    const cleared = width(Number.NaN);
    const tiny = width(0.04);
    expect(unmeasured).toMatch(/measure/i);
    expect(cleared).toBe(unmeasured);
    expect(tiny).toBe("Between 5 and 500 cm.");
  });

  it("takes 5 cm to 5 m, both ends included", () => {
    const width = (m: number) =>
      exhibitProblems(exhibit({ markerWidthM: m })).width;
    expect(width(0.05)).toBeUndefined();
    expect(width(5)).toBeUndefined();
    expect(width(5.01)).toBeDefined();
    expect(width(-0.3)).toBeDefined();
  });

  it("counts untitled and unmarked rows across a list", () => {
    expect(
      countExhibitProblems([
        exhibit(),
        exhibit({ id: "e2", title: "" }),
        exhibit({ id: "e3", markerPath: "" }),
        exhibit({ id: "e4", markerWidthM: 9 }),
      ]),
    ).toEqual({ untitled: 1, unmarked: 2 });
  });
});

describe("width conversions", () => {
  it("shows metres as centimetres", () => {
    expect(toCentimetres(0.3)).toBe(30);
    expect(toCentimetres(1.25)).toBe(125);
  });

  it("stores centimetres as metres", () => {
    expect(toMetres(30)).toBe(0.3);
    expect(toMetres(7.5)).toBe(0.075);
  });

  it("does not show binary noise", () => {
    // 0.333 * 100 is 33.300000000000004 in floating point.
    expect(toCentimetres(0.333)).toBe(33.3);
    expect(toMetres(33.3)).toBe(0.333);
  });

  it("round-trips to the millimetre", () => {
    for (const cm of [5, 12.5, 29.7, 42, 118.9, 500]) {
      expect(toCentimetres(toMetres(cm))).toBe(cm);
    }
    // Finer than a millimetre is rounded off, not kept out of sight.
    expect(toMetres(12.34)).toBe(0.123);
  });
});

describe("hasAR", () => {
  it("is on for a museum with an exhibit the scanner can find", () => {
    expect(museumHasAR(true, [exhibit()])).toBe(true);
  });

  it("is off when the place is not a museum, whatever its exhibits", () => {
    expect(museumHasAR(false, [exhibit()])).toBe(false);
  });

  it("is off when no exhibit has both a marker and a width", () => {
    expect(museumHasAR(true, [])).toBe(false);
    expect(
      museumHasAR(true, [
        exhibit({ markerPath: "" }),
        exhibit({ id: "e2", markerWidthM: 0 }),
      ]),
    ).toBe(false);
  });

  it("needs only one", () => {
    expect(
      museumHasAR(true, [exhibit({ markerPath: "" }), exhibit({ id: "e2" })]),
    ).toBe(true);
  });
});

describe("toExhibitDoc", () => {
  it("trims, and omits optional fields left blank", () => {
    expect(
      toExhibitDoc(
        exhibit({
          title: "  Jar burial  ",
          description: " ",
          story: "\nFirst.\n\nSecond.\n",
          ttsText: "",
        }),
        2,
      ),
    ).toEqual({
      title: "Jar burial",
      markerPath: "ar/d1/markers/e1-1.webp",
      markerWidthM: 0.3,
      // Inner blank lines survive: they are the paragraph breaks.
      story: "First.\n\nSecond.",
      order: 2,
    });
  });

  it("always writes the two required fields, blank or not", () => {
    expect(toExhibitDoc(emptyExhibit("x"), 1)).toEqual({
      title: "",
      markerPath: "",
      markerWidthM: 0,
      order: 1,
    });
    expect(
      toExhibitDoc(exhibit({ markerWidthM: Number.NaN }), 1).markerWidthM,
    ).toBe(0);
  });

  it("keeps narration", () => {
    expect(
      toExhibitDoc(
        exhibit({ audioUrl: "destinations/d1/audio/e1.m4a", ttsText: " Hi " }),
        1,
      ),
    ).toMatchObject({
      audioUrl: "destinations/d1/audio/e1.m4a",
      ttsText: "Hi",
    });
  });
});

describe("fromExhibitDoc", () => {
  it("reads back what toExhibitDoc wrote", () => {
    const e = exhibit({
      description: "A replica of the oldest human remains in the Philippines.",
      story: "First.\n\nSecond.",
      audioUrl: "destinations/d1/audio/e1.mp3",
      ttsText: "Hello.",
    });
    expect(fromExhibitDoc("e1", toExhibitDoc(e, 1))).toEqual(e);
  });

  it("opens a document written by hand instead of failing on it", () => {
    expect(fromExhibitDoc("e9", { title: 7, markerWidthM: "30" })).toEqual({
      id: "e9",
      title: "",
      description: undefined,
      story: undefined,
      markerPath: "",
      markerWidthM: 0,
      audioUrl: undefined,
      ttsText: undefined,
    });
  });
});

describe("planExhibitSave", () => {
  const a = exhibit({ id: "a", markerPath: "ar/d/markers/a-1.webp" });
  const b = exhibit({
    id: "b",
    markerPath: "ar/d/markers/b-1.webp",
    audioUrl: "destinations/d/audio/b.mp3",
  });
  const c = exhibit({ id: "c", markerPath: "ar/d/markers/c-1.webp" });

  it("writes nothing when nothing changed", () => {
    expect(planExhibitSave([a, b, c], [a, b, c])).toEqual({
      writes: [],
      deletes: [],
      orphans: [],
    });
  });

  it("writes only the exhibit that was edited", () => {
    const plan = planExhibitSave([a, { ...b, title: "New" }, c], [a, b, c]);
    expect(plan.writes.map((w) => w.id)).toEqual(["b"]);
    expect(plan.writes[0].data).toMatchObject({ title: "New", order: 2 });
  });

  it("renumbers the two that swapped, and only them", () => {
    const plan = planExhibitSave([b, a, c], [a, b, c]);
    expect(plan.writes.map((w) => [w.id, w.data.order])).toEqual([
      ["b", 1],
      ["a", 2],
    ]);
  });

  it("adds a new exhibit at the end", () => {
    const d = emptyExhibit("d");
    const plan = planExhibitSave([a, b, c, d], [a, b, c]);
    expect(plan.writes.map((w) => [w.id, w.data.order])).toEqual([["d", 4]]);
  });

  it("deletes a removed exhibit, closes the gap, and frees its files", () => {
    const plan = planExhibitSave([a, c], [a, b, c]);
    expect(plan.deletes).toEqual(["b"]);
    expect(plan.writes.map((w) => [w.id, w.data.order])).toEqual([["c", 2]]);
    expect(plan.orphans.sort()).toEqual([
      "ar/d/markers/b-1.webp",
      "destinations/d/audio/b.mp3",
    ]);
  });

  it("frees a replaced marker, never the new one", () => {
    const replaced = { ...a, markerPath: "ar/d/markers/a-2.webp" };
    expect(planExhibitSave([replaced, b, c], [a, b, c]).orphans).toEqual([
      "ar/d/markers/a-1.webp",
    ]);
  });

  it("frees a recording taken off, or swapped for another format", () => {
    const off = { ...b, audioUrl: undefined };
    expect(planExhibitSave([a, off, c], [a, b, c]).orphans).toEqual([
      "destinations/d/audio/b.mp3",
    ]);
    const m4a = { ...b, audioUrl: "destinations/d/audio/b.m4a" };
    expect(planExhibitSave([a, m4a, c], [a, b, c]).orphans).toEqual([
      "destinations/d/audio/b.mp3",
    ]);
  });

  it("keeps a file the new version still uses", () => {
    // A recording replaced by one of the same format lands on the same path.
    const again = { ...b, ttsText: "Changed." };
    expect(planExhibitSave([a, again, c], [a, b, c]).orphans).toEqual([]);
  });

  it("frees nothing while a new exhibit is still unsaved", () => {
    const d = exhibit({ id: "d", markerPath: "ar/d/markers/d-1.webp" });
    expect(planExhibitSave([a, b, c, d], [a, b, c]).orphans).toEqual([]);
  });
});

describe("readiness with exhibits", () => {
  const museum = {
    ...emptyDestination(),
    name: "Cagayan Museum",
    slug: "cagayan-museum",
    town: "Tuguegarao City",
    description: "The province's history in one building.",
    images: ["destinations/d/images/1.webp"],
    isMuseum: true,
  };
  const labels = (items: ReturnType<typeof readiness>) =>
    items.filter((i) => i.tab === "ar").map((i) => [i.label, i.ok]);

  it("asks nothing of a museum with no exhibits", () => {
    expect(labels(readiness(museum, [], []))).toEqual([]);
  });

  it("asks every exhibit for a name and a marker", () => {
    expect(
      labels(
        readiness(
          museum,
          [],
          [exhibit(), exhibit({ id: "e2", markerPath: "" })],
        ),
      ),
    ).toEqual([
      ["Every exhibit is named", true],
      ["Every exhibit has a marker", false],
    ]);
  });

  it("ignores exhibits on a place that is no longer a museum", () => {
    expect(
      labels(
        readiness({ ...museum, isMuseum: false }, [], [emptyExhibit("x")]),
      ),
    ).toEqual([]);
  });
});
