import { describe, expect, it } from "vitest";
import { capitalise } from "./fuzzy";
import { defaultRow, suggestRows } from "./suggest";
import { CAGAYAN_TOWNS } from "./towns";

const towns = (text: string, existing: string[] = []) =>
  suggestRows(text, {
    candidates: CAGAYAN_TOWNS,
    existing,
    normalizeNew: capitalise,
  });
const townDefault = (text: string, existing: string[] = []) =>
  defaultRow(towns(text, existing), {
    newByDefault: false,
    newWarning: "not a Cagayan town",
  });

describe("the town field", () => {
  it("makes the official spelling the Enter choice for a misspelling", () => {
    const rows = towns("Penablanka");
    expect(rows[townDefault("Penablanka")!]).toMatchObject({
      kind: "match",
      value: "Peñablanca",
      corrects: true,
    });
  });

  it("offers a non-official name last, and never as the Enter choice", () => {
    const rows = towns("Testville");
    expect(rows).toEqual([{ kind: "new", value: "Testville" }]);
    expect(townDefault("Testville")).toBeNull();
  });

  it("says a town is already listed instead of offering it again", () => {
    expect(towns("penablanca", ["Peñablanca"])).toEqual([
      { kind: "taken", value: "Peñablanca" },
    ]);
  });

  it("capitalises a new name", () => {
    expect(towns("new town").at(-1)).toEqual({ kind: "new", value: "New Town" });
  });

  it("does not call a plain completion a correction", () => {
    expect(towns("Tugue")[0]).toMatchObject({
      value: "Tuguegarao City",
      corrects: false,
    });
  });
});

describe("the tag field", () => {
  const tags = (text: string, existing: string[] = []) =>
    suggestRows(text, {
      candidates: ["caves", "river"],
      existing,
      normalizeNew: (s) => s.toLowerCase(),
    });

  it("offers the existing tag ahead of a near-duplicate", () => {
    const rows = tags("cave");
    expect(rows[defaultRow(rows)!]).toMatchObject({ value: "caves" });
    expect(rows.at(-1)).toEqual({ kind: "new", value: "cave" });
  });

  it("makes a brand-new tag the Enter choice when nothing is close", () => {
    const rows = tags("waterfall");
    expect(rows[defaultRow(rows)!]).toEqual({ kind: "new", value: "waterfall" });
  });

  it("skips a tag the place already has", () => {
    const rows = tags("cave", ["caves"]);
    expect(rows[0]).toMatchObject({ value: "caves", taken: true });
    expect(rows[defaultRow(rows)!]).toEqual({ kind: "new", value: "cave" });
  });
});
