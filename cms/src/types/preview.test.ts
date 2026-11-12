import { describe, expect, it } from "vitest";
import { emptyDestination } from "./destination";
import { entryPrice, placeTags, tidyFact } from "./preview";

describe("tidyFact, as the app tidies the editor's words", () => {
  it("writes times as 8 AM and a leading PHP as ₱", () => {
    expect(tidyFact("8:00am – 4:00pm")).toEqual({
      value: "8:00 AM – 4:00 PM",
      note: null,
    });
    expect(tidyFact("php 20")).toEqual({ value: "₱20", note: null });
  });

  it("puts what follows the first comma on its own line", () => {
    expect(tidyFact("PHP 50, children free")).toEqual({
      value: "₱50",
      note: "Children free",
    });
  });

  it("moves a closing daily to the second line", () => {
    expect(tidyFact("8am to 5pm daily")).toEqual({
      value: "8 AM to 5 PM",
      note: "Daily",
    });
  });

  it("is nothing for an empty field", () => {
    expect(tidyFact("   ")).toBeNull();
    expect(tidyFact(undefined)).toBeNull();
  });
});

describe("entryPrice", () => {
  it("is Free, or short words with a number", () => {
    expect(entryPrice("free")).toBe("Free");
    expect(entryPrice("PHP 20")).toBe("₱20");
    expect(entryPrice("PHP 50, children free")).toBe("₱50");
  });

  it("is nothing for a sentence or words that are not a price", () => {
    expect(entryPrice("Boat hire")).toBeNull();
    expect(entryPrice("₱50 for adults and ₱20 for children")).toBeNull();
    expect(entryPrice("")).toBeNull();
  });
});

describe("placeTags", () => {
  const place = (over = {}) => ({ ...emptyDestination(), ...over });

  it("says price, then scan, then popular, two at most", () => {
    const d = place({ popular: true, practical: { entryFee: "PHP 20" } });
    expect(placeTags(d, true)).toEqual([
      { kind: "price", label: "₱20" },
      { kind: "scan" },
    ]);
    expect(placeTags(d, false)).toEqual([
      { kind: "price", label: "₱20" },
      { kind: "popular" },
    ]);
  });

  it("drops what the section says already", () => {
    const d = place({ popular: true });
    expect(placeTags(d, false, { hide: ["popular"] })).toEqual([]);
  });

  it("keeps one beside a heart on a small photo", () => {
    const d = place({ popular: true, practical: { entryFee: "Free" } });
    expect(placeTags(d, true, { most: 1 })).toEqual([
      { kind: "price", label: "Free" },
    ]);
  });

  it("says nothing about a place with nothing to say", () => {
    expect(placeTags(place(), false)).toEqual([]);
  });
});
