import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase/firestore";
import { checkVersion, versionOf, whoChanged } from "./conflict";

describe("checkVersion", () => {
  it("lets the save through when nobody else has written", () => {
    expect(checkVersion(1000, { exists: true, updatedAt: 1000 })).toBeNull();
  });

  it("reports a later save, and by whom", () => {
    expect(
      checkVersion(1000, { exists: true, updatedAt: 2000, updatedBy: "uid-b" }),
    ).toEqual({ kind: "changed", updatedAt: 2000, updatedBy: "uid-b" });
  });

  it("treats any difference as a conflict, not only a later one", () => {
    // A restored backup can move updatedAt backwards. It is still not the
    // document this editor loaded.
    expect(checkVersion(2000, { exists: true, updatedAt: 1000 })?.kind).toBe(
      "changed",
    );
  });

  it("reports a deletion rather than writing into nothing", () => {
    expect(checkVersion(1000, { exists: false })).toEqual({ kind: "deleted" });
  });

  it("matches a document that has never had a timestamp", () => {
    // Written by hand or an old script: loaded as 0, still 0, nothing changed.
    expect(checkVersion(0, { exists: true })).toBeNull();
  });

  it("says who is unknown when the collection does not record it", () => {
    expect(checkVersion(0, { exists: true, updatedAt: 5 })).toMatchObject({
      updatedBy: null,
    });
  });
});

describe("versionOf", () => {
  it("is the timestamp in milliseconds, or 0 without one", () => {
    expect(versionOf(Timestamp.fromMillis(1234))).toBe(1234);
    expect(versionOf(undefined)).toBe(0);
    expect(versionOf(null)).toBe(0);
  });
});

describe("whoChanged", () => {
  const names = new Map([["uid-b", "maria@cagayan.gov.ph"]]);

  it("names another admin when it can", () => {
    expect(whoChanged("uid-b", "uid-a", names)).toBe("maria@cagayan.gov.ph");
  });

  it("says it was you, elsewhere, rather than someone else", () => {
    expect(whoChanged("uid-a", "uid-a", names)).toBe("You, in another window,");
  });

  it("falls back when the editor is unknown or no longer an admin", () => {
    expect(whoChanged(null, "uid-a", names)).toBe("Another admin");
    expect(whoChanged("uid-gone", "uid-a", names)).toBe("Another admin");
  });
});
