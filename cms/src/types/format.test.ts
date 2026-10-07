import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase/firestore";
import { formatDate } from "./format";

describe("formatDate", () => {
  it("spells the month out, so day and month cannot be swapped", () => {
    // 7 October. The old output, "07/10/2026", is 10 July to a Filipino reader.
    expect(formatDate(new Date(2026, 9, 7, 12))).toBe("7 Oct 2026");
  });

  it("takes a Firestore timestamp", () => {
    expect(formatDate(Timestamp.fromDate(new Date(2026, 0, 31, 12)))).toBe(
      "31 Jan 2026",
    );
  });

  it("shows a dash for a missing date", () => {
    expect(formatDate(undefined)).toBe("—");
    expect(formatDate(null)).toBe("—");
  });
});
