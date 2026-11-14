import type { Destination } from "./destination";
import type { ExhibitDraft } from "./exhibit";
import type { SegmentDraft } from "./segment";

/**
 * Unsaved edits kept in this browser, so a crash, a closed tab or a laptop
 * that slept through the afternoon does not cost a long history text, after
 * GitHub's and Gmail's drafts.
 *
 * Kept in `localStorage`, not `sessionStorage`: closing the tab is one of the
 * accidents this is for, and a session's storage goes with its tab. Kept per
 * admin and per place, cleared the moment the edits are saved or discarded,
 * and ignored after a week.
 *
 * Never written to Firestore. A recovered copy goes back through the editor
 * as unsaved edits, and its save is checked against the version the edits
 * started from like any other, so it cannot quietly replace a newer save.
 */

type Draft = Omit<Destination, "id">;

/** The fields an editor can change: the stamps are the server's, and are not JSON. */
export type RecoverableDraft = Omit<Draft, "createdAt" | "updatedAt" | "updatedBy">;

export type Recovery = {
  v: 1;
  /** When this copy was written, in ms. */
  at: number;
  /** The version (`updatedAt` in ms) the edits started from; 0 for a new place. */
  basedOn: number;
  draft: RecoverableDraft;
  segments: SegmentDraft[];
  exhibits: ExhibitDraft[];
};

/** A week: long enough for a weekend, short enough not to offer last month's typing. */
export const RECOVERY_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** Per admin, so a colleague on the same computer is never offered someone else's edits. */
export function recoveryKey(uid: string, destinationId: string): string {
  return `lakbayan-cms:recovery:${uid}:destination:${destinationId}`;
}

export function stripStamps(d: Draft): RecoverableDraft {
  const { createdAt: _c, updatedAt: _u, updatedBy: _b, ...rest } = d;
  return rest;
}

export function makeRecovery(
  parts: { draft: Draft; segments: SegmentDraft[]; exhibits: ExhibitDraft[] },
  basedOn: number,
  now: number,
): Recovery {
  return {
    v: 1,
    at: now,
    basedOn,
    draft: stripStamps(parts.draft),
    segments: parts.segments,
    exhibits: parts.exhibits,
  };
}

/**
 * A stored copy, if it is one this code wrote and it is not too old. Null for
 * anything else, so a corrupt or foreign value is ignored, never a crash.
 */
export function readRecovery(raw: string | null, now: number): Recovery | null {
  if (!raw) return null;
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    return null;
  }
  const r = value as Partial<Recovery> | null;
  if (
    !r ||
    r.v !== 1 ||
    typeof r.at !== "number" ||
    typeof r.basedOn !== "number" ||
    typeof r.draft !== "object" ||
    r.draft === null ||
    !Array.isArray(r.segments) ||
    !Array.isArray(r.exhibits)
  ) {
    return null;
  }
  if (now - r.at > RECOVERY_TTL_MS) return null;
  return r as Recovery;
}

/** Whether the copy holds anything the page does not already show. */
export function differsFrom(
  r: Recovery,
  current: { draft: Draft; segments: SegmentDraft[]; exhibits: ExhibitDraft[] },
): boolean {
  return (
    JSON.stringify(r.draft) !== JSON.stringify(stripStamps(current.draft)) ||
    JSON.stringify(r.segments) !== JSON.stringify(current.segments) ||
    JSON.stringify(r.exhibits) !== JSON.stringify(current.exhibits)
  );
}

/**
 * The page's draft with the copy's edits on it: the stamps stay the loaded
 * document's, everything an editor can change comes from the copy.
 */
export function applyRecovery(loaded: Draft, r: Recovery): Draft {
  return { ...loaded, ...r.draft };
}
