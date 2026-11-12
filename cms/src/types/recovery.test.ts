import { describe, expect, it } from "vitest";
import { Timestamp } from "firebase/firestore";
import { emptyDestination } from "./destination";
import {
  RECOVERY_TTL_MS,
  applyRecovery,
  differsFrom,
  makeRecovery,
  readRecovery,
  recoveryKey,
} from "./recovery";

const NOW = 1_800_000_000_000;

const loaded = {
  ...emptyDestination(),
  name: "Callao Cave",
  history: "The cave system sits in the Peñablanca Protected Landscape.",
  createdAt: Timestamp.fromMillis(1_000),
  updatedAt: Timestamp.fromMillis(2_000),
  updatedBy: "uid-maria",
};
const stop = { id: "s1", title: "The river crossing", ttsText: "You are standing…" };

describe("recoveryKey", () => {
  it("is per admin and per place", () => {
    expect(recoveryKey("u1", "callao-cave")).not.toBe(recoveryKey("u2", "callao-cave"));
    expect(recoveryKey("u1", "callao-cave")).not.toBe(recoveryKey("u1", "new"));
  });
});

describe("a stored copy", () => {
  const edited = { ...loaded, history: loaded.history + " Bring a light." };
  const copy = makeRecovery({ draft: edited, segments: [stop], exhibits: [] }, 2_000, NOW);

  it("survives the trip through storage, without the server's stamps", () => {
    const back = readRecovery(JSON.stringify(copy), NOW + 60_000)!;
    expect(back.draft.history).toBe(edited.history);
    expect(back.segments).toEqual([stop]);
    expect(back.basedOn).toBe(2_000);
    expect("updatedAt" in back.draft).toBe(false);
  });

  it("is ignored once it is more than a week old", () => {
    expect(readRecovery(JSON.stringify(copy), NOW + RECOVERY_TTL_MS + 1)).toBeNull();
    expect(readRecovery(JSON.stringify(copy), NOW + RECOVERY_TTL_MS - 1)).not.toBeNull();
  });

  it("is ignored when it is not one this code wrote", () => {
    expect(readRecovery(null, NOW)).toBeNull();
    expect(readRecovery("{not json", NOW)).toBeNull();
    expect(readRecovery(JSON.stringify({ ...copy, v: 2 }), NOW)).toBeNull();
    expect(readRecovery(JSON.stringify({ ...copy, segments: "x" }), NOW)).toBeNull();
    expect(readRecovery("null", NOW)).toBeNull();
  });

  it("is offered only when it holds something the page does not show", () => {
    const back = readRecovery(JSON.stringify(copy), NOW)!;
    expect(differsFrom(back, { draft: loaded, segments: [stop], exhibits: [] })).toBe(true);
    expect(differsFrom(back, { draft: edited, segments: [stop], exhibits: [] })).toBe(false);
    // A stamp the copy never had is not a difference.
    expect(
      differsFrom(back, {
        draft: { ...edited, updatedAt: Timestamp.fromMillis(9_000) },
        segments: [stop],
        exhibits: [],
      }),
    ).toBe(false);
  });

  it("restores the edits and keeps the loaded document's stamps", () => {
    const back = readRecovery(JSON.stringify(copy), NOW)!;
    const restored = applyRecovery(loaded, back);
    expect(restored.history).toBe(edited.history);
    expect(restored.updatedAt).toBe(loaded.updatedAt);
    expect(restored.updatedBy).toBe("uid-maria");
  });
});
