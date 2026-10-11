import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase/firestore";
import {
  announcementState,
  cleanHotlines,
  dateInputFromUntil,
  hotlineProblem,
  normalizeTowns,
  renameTag,
  tagUsage,
  townsNotListed,
  untilFromDateInput,
} from "./settings";

describe("normalizeTowns", () => {
  it("trims, drops blanks and sorts", () => {
    expect(normalizeTowns([" Piat", "", "Aparri ", "  "])).toEqual([
      "Aparri",
      "Piat",
    ]);
  });

  it("keeps one spelling of a town written two ways — the first", () => {
    // The whole point: two spellings become two offline bundles.
    expect(normalizeTowns(["Peñablanca", "Penablanca", "peñablanca"])).toEqual([
      "Peñablanca",
    ]);
  });
});

describe("townsNotListed", () => {
  it("finds towns destinations use that the list lacks, with counts", () => {
    expect(
      townsNotListed(
        [{ town: "Penablanca" }, { town: "Penablanca" }, { town: "Piat" }, { town: " " }],
        ["Piat"],
      ),
    ).toEqual([{ town: "Penablanca", count: 2 }]);
  });
});

describe("tags", () => {
  it("counts tags in use, most used first", () => {
    expect(
      tagUsage([{ tags: ["caves", "river"] }, { tags: ["caves"] }, { tags: [] }]),
    ).toEqual([
      { tag: "caves", count: 2 },
      { tag: "river", count: 1 },
    ]);
  });

  it("renames a tag in place", () => {
    expect(renameTag(["caves", "river"], "caves", "Cave")).toEqual([
      "cave",
      "river",
    ]);
  });

  it("merges when the new name is already there", () => {
    expect(renameTag(["caves", "cave", "river"], "caves", "cave")).toEqual([
      "cave",
      "river",
    ]);
  });

  it("removes the tag when the new name is empty", () => {
    expect(renameTag(["caves", "river"], "caves", "")).toEqual(["river"]);
  });
});

describe("announcement", () => {
  const now = new Date(2026, 9, 12, 9).getTime();
  const at = (d: Date) => Timestamp.fromDate(d);

  it("is off with no text, whatever its date", () => {
    expect(announcementState(null, now)).toBe("off");
    expect(announcementState({ text: " " }, now)).toBe("off");
  });

  it("is live with text and no end, or an end still ahead", () => {
    expect(announcementState({ text: "Closed Monday" }, now)).toBe("live");
    expect(
      announcementState({ text: "x", until: at(new Date(2026, 9, 13)) }, now),
    ).toBe("live");
  });

  it("has ended once its end has passed", () => {
    expect(
      announcementState({ text: "x", until: at(new Date(2026, 9, 12)) }, now),
    ).toBe("ended");
  });

  it("runs through the whole day picked, ending at the next midnight", () => {
    expect(untilFromDateInput("2026-10-20")).toEqual(new Date(2026, 9, 21));
    expect(untilFromDateInput("")).toBeNull();
  });

  it("shows a stored end as the day picked", () => {
    expect(dateInputFromUntil(new Date(2026, 9, 21))).toBe("2026-10-20");
    expect(dateInputFromUntil(null)).toBe("");
  });
});

describe("hotlines", () => {
  it("flags a label without a number, and a number without a label", () => {
    expect(hotlineProblem([{ label: "MDRRMO", number: " " }])).toBe(
      '"MDRRMO" has no number.',
    );
    expect(hotlineProblem([{ label: "", number: "911" }])).toBe(
      "A number (911) has no label.",
    );
    expect(hotlineProblem([{ label: "Emergency", number: "911" }])).toBeNull();
  });

  it("drops rows left wholly blank", () => {
    expect(
      cleanHotlines([
        { label: " Emergency ", number: "911 " },
        { label: "", number: "" },
      ]),
    ).toEqual([{ label: "Emergency", number: "911" }]);
  });
});
