import { describe, expect, it } from "vitest";
import { capitalise, distance, fold, suggest } from "./fuzzy";
import { CAGAYAN_TOWNS } from "./towns";

describe("fold", () => {
  it("ignores case, accents and how words are joined", () => {
    expect(fold("  Peñablanca ")).toBe("penablanca");
    expect(fold("Lal-lo")).toBe("lal lo");
    expect(fold("Santo  Niño")).toBe("santo nino");
  });
});

describe("distance", () => {
  it("counts edits, with a swapped pair as one", () => {
    expect(distance("cave", "caves")).toBe(1);
    expect(distance("penablanca", "penalbanca")).toBe(1);
    expect(distance("piat", "piat")).toBe(0);
  });
});

describe("suggest, against the real town list", () => {
  const first = (q: string) => suggest(q, CAGAYAN_TOWNS)[0];

  it("finds the official spelling of a town typed without its ñ", () => {
    expect(first("Penablanca")).toEqual({ value: "Peñablanca", kind: "exact" });
  });

  it("finds it through a typo too", () => {
    expect(first("Penablanka")).toEqual({ value: "Peñablanca", kind: "close" });
    expect(first("Tugeugarao")?.value).toBe("Tuguegarao City");
  });

  it("completes the start of a name, including a later word", () => {
    expect(first("tugue")).toEqual({ value: "Tuguegarao City", kind: "prefix" });
    expect(suggest("ana", CAGAYAN_TOWNS).map((m) => m.value)).toContain("Santa Ana");
  });

  it("does not stretch short words into anything", () => {
    // Three letters with no prefix match must not "mean" a random town.
    expect(suggest("xyz", CAGAYAN_TOWNS)).toEqual([]);
  });

  it("offers nothing for an empty field", () => {
    expect(suggest("  ", CAGAYAN_TOWNS)).toEqual([]);
  });
});

describe("suggest, against tags", () => {
  it("offers the existing tag for a near-duplicate", () => {
    expect(suggest("cave", ["caves", "river"])[0]).toEqual({
      value: "caves",
      kind: "prefix",
    });
    expect(suggest("rivers", ["caves", "river"])[0]?.value).toBe("river");
  });
});

describe("capitalise", () => {
  it("capitalises each word of a new proper noun", () => {
    expect(capitalise("santa ana")).toBe("Santa Ana");
    expect(capitalise("  new   town ")).toBe("New Town");
  });

  it("leaves letters after a hyphen alone", () => {
    expect(capitalise("lal-lo")).toBe("Lal-lo");
  });

  it("handles accented first letters", () => {
    expect(capitalise("ñipa")).toBe("Ñipa");
  });
});
