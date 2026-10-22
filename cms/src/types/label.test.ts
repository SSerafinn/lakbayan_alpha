import { describe, expect, it } from "vitest";
import {
  labelMarkerWidthM,
  labelSizeOf,
  printedPicture,
  qrPath,
  sheetsOf,
  visitUrl,
} from "./label";

describe("printedPicture", () => {
  it("fills the square with a landscape photo's width", () => {
    expect(printedPicture(4 / 3, "a6")).toEqual({ widthMm: 66, heightMm: 49.5 });
  });

  it("fills it with a portrait photo's height, narrower than the square", () => {
    expect(printedPicture(3 / 4, "a5")).toEqual({ widthMm: 84, heightMm: 112 });
  });

  it("takes a photo of unknown shape as square", () => {
    expect(printedPicture(Number.NaN, "a6")).toEqual({ widthMm: 66, heightMm: 66 });
    expect(printedPicture(0, "a5")).toEqual({ widthMm: 112, heightMm: 112 });
  });
});

describe("the width a label gives the scanner", () => {
  it("is the printed picture's width in metres, to the millimetre", () => {
    expect(labelMarkerWidthM(4 / 3, "a6")).toBe(0.066);
    expect(labelMarkerWidthM(2 / 3, "a5")).toBe(0.075);
  });

  it("is read back as the label it came from", () => {
    for (const aspect of [16 / 9, 1, 3 / 4]) {
      expect(labelSizeOf(labelMarkerWidthM(aspect, "a6"), aspect)).toBe("a6");
      expect(labelSizeOf(labelMarkerWidthM(aspect, "a5"), aspect)).toBe("a5");
    }
  });

  it("is no label at all when it was measured by hand", () => {
    // An exhibit's own placard, 30 cm across.
    expect(labelSizeOf(0.3, 4 / 3)).toBeNull();
  });
});

describe("visitUrl", () => {
  it("names the place and the exhibit, whatever the base ends with", () => {
    expect(visitUrl("https://visit.example/", "museum", "e1")).toBe(
      "https://visit.example/e/museum/e1",
    );
  });

  it("keeps an id from breaking out of its segment", () => {
    expect(visitUrl("https://visit.example", "a/b", "c?d")).toBe(
      "https://visit.example/e/a%2Fb/c%3Fd",
    );
  });
});

describe("qrPath", () => {
  it("draws a code with its quiet zone", () => {
    const { size, d } = qrPath("https://visit.example/e/museum/e1");
    // Version 3 at level M is 29 modules, plus two on each side.
    expect(size).toBe(33);
    // The finder pattern's corner module, inside the quiet zone.
    expect(d.startsWith("M2 2h1v1h-1z")).toBe(true);
  });
});

describe("sheetsOf", () => {
  it("fills A4 sheets with four A6 labels or two A5, A6 first", () => {
    const labels = [
      { id: "1", size: "a5" as const },
      { id: "2", size: "a6" as const },
      { id: "3", size: "a6" as const },
      { id: "4", size: "a6" as const },
      { id: "5", size: "a6" as const },
      { id: "6", size: "a6" as const },
      { id: "7", size: "a5" as const },
      { id: "8", size: "a5" as const },
    ];
    expect(sheetsOf(labels).map((s) => s.map((l) => l.id))).toEqual([
      ["2", "3", "4", "5"],
      ["6"],
      ["1", "7"],
      ["8"],
    ]);
  });
});
