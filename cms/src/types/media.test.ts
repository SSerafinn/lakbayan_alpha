import { describe, expect, it } from "vitest";
import {
  audioExtension,
  extensionFor,
  fitWithin,
  keepOriginal,
  MAX_EDGE,
} from "./media";

describe("fitWithin", () => {
  it("scales a phone photo down to fit on its longer edge", () => {
    expect(fitWithin(4000, 3000)).toEqual({ width: 2000, height: 1500 });
    expect(fitWithin(3024, 4032)).toEqual({ width: 1500, height: 2000 });
  });

  it("never scales a small photo up", () => {
    expect(fitWithin(1200, 800)).toEqual({ width: 1200, height: 800 });
  });

  it("keeps a sliver at least a pixel wide", () => {
    expect(fitWithin(40000, 10)).toEqual({ width: 2000, height: 1 });
  });
});

describe("keepOriginal", () => {
  const photo = { type: "image/jpeg", size: 300_000, width: 1600, height: 900 };

  it("keeps a photo that already fits and is smaller than the copy", () => {
    expect(keepOriginal(photo, 350_000)).toBe(true);
  });

  it("takes the copy when it is smaller", () => {
    expect(keepOriginal(photo, 200_000)).toBe(false);
  });

  it("takes the copy when the photo is too large to show", () => {
    expect(keepOriginal({ ...photo, width: MAX_EDGE + 1 }, 999_999)).toBe(false);
  });

  it("takes the copy of a PNG, however small", () => {
    // A PNG photo is several times a JPEG of it; the copy is the one to ship.
    expect(keepOriginal({ ...photo, type: "image/png" }, 999_999)).toBe(false);
  });
});

describe("file names", () => {
  it("names a photo for what it is", () => {
    expect(extensionFor("image/webp")).toBe("webp");
    expect(extensionFor("image/jpeg")).toBe("jpg");
  });

  it("recognises narration by extension, whatever its case", () => {
    expect(audioExtension("Callao Cave.M4A")).toBe("m4a");
    expect(audioExtension("notes.txt")).toBeNull();
    // Not fooled by names that happen to be object properties.
    expect(audioExtension("x.constructor")).toBeNull();
  });
});
