/**
 * Audio guide stops — `destinations/{id}/segments/{sid}`.
 *
 * Mirrors `docs/DATA_MODEL.md` and the `Segment` class in
 * `lib/core/models/destination.dart`. Same three-representations rule as
 * `destination.ts`: when the shape changes, all three move together.
 *
 * There is deliberately **no** `status` field. Visibility is inherited from the
 * parent destination in `firestore.rules`; a second status here would drift
 * from the first and leak draft narration.
 */

/**
 * A segment as the editor holds it.
 *
 * `id` is always a real Firestore document id, including for rows that have
 * never been written — see `newSegmentId` in `lib/segments.ts`. Audio uploads
 * are keyed by segment id, so a row with a placeholder id would have nowhere
 * to put a file.
 *
 * `order` is **not** stored here. The array position is the order, and it is
 * computed on save. Keeping a number in state alongside an ordered array gives
 * you two sources of truth that disagree the first time a row moves.
 */
export type SegmentDraft = {
  id: string;
  title: string;
  description?: string;
  /** Storage path, not a download URL — paths survive token rotation. */
  audioUrl?: string;
  /** Spoken by `flutter_tts` when there is no recording. */
  ttsText?: string;
};

/** As stored, once the array position has been resolved to a number. */
export type SegmentDoc = Omit<SegmentDraft, "id"> & { order: number };

export function emptySegment(id: string): SegmentDraft {
  return { id, title: "" };
}

/**
 * Can the app actually play this stop?
 *
 * Matches `Segment.isPlayable` in the Dart model. A segment with neither a
 * recording nor TTS text is silent in the player — the listener hears the
 * guide skip a stop with no explanation.
 */
export function isPlayable(s: SegmentDraft): boolean {
  return (s.audioUrl ?? "") !== "" || (s.ttsText ?? "").trim() !== "";
}

/** How a row narrates itself, for the row summary and the readiness copy. */
export function narrationSource(s: SegmentDraft): "recording" | "tts" | "none" {
  if ((s.audioUrl ?? "") !== "") return "recording";
  if ((s.ttsText ?? "").trim() !== "") return "tts";
  return "none";
}

/** Rows that would ship broken. Empty means the guide is publishable. */
export function segmentProblems(segments: SegmentDraft[]): {
  untitled: number;
  silent: number;
} {
  return {
    untitled: segments.filter((s) => s.title.trim() === "").length,
    silent: segments.filter((s) => !isPlayable(s)).length,
  };
}
