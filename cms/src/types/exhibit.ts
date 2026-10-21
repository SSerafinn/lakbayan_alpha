/**
 * AR exhibits — `destinations/{id}/exhibits/{eid}` (D-18).
 *
 * Mirrors `docs/DATA_MODEL.md` and the `Exhibit` class in
 * `lib/core/models/exhibit.dart`. Same three-representations rule as
 * `destination.ts`: when the shape changes, all three move together.
 *
 * As with segments there is **no** `status` field: visibility follows the
 * parent destination in `firestore.rules`. Exhibits only mean anything on a
 * museum, which is why the editor's AR tab opens only under `isMuseum`.
 */

/**
 * An exhibit as the editor holds it.
 *
 * `id` is a real Firestore document id from the moment the row exists — see
 * `newExhibitId` in `lib/exhibits.ts`. Markers and narration are stored under
 * it, so a placeholder id would leave an upload nowhere to go.
 *
 * `order` is **not** held here, for the reason `SegmentDraft` gives: the array
 * position is the order, resolved to a number on save.
 *
 * `markerPath` and `markerWidthM` are required by the schema, so they are
 * always present: `""` and `0` until the editor uploads and measures. The app
 * reads those as "nothing to scan for" (`Exhibit.isScannable`) rather than
 * failing on a missing key.
 */
export type ExhibitDraft = {
  id: string;
  title: string;
  /** One line, on the card that appears when the camera finds the exhibit. */
  description?: string;
  /** The exhibit sheet. Blank lines split paragraphs. */
  story?: string;
  /** Storage path of the image the camera matches, under `ar/{destId}/`. */
  markerPath: string;
  /** The marker's real width in metres. The editor shows centimetres. */
  markerWidthM: number;
  /** Storage path, not a download URL — paths survive token rotation. */
  audioUrl?: string;
  /** Spoken by `flutter_tts` when there is no recording. */
  ttsText?: string;
};

/** As stored, once the array position has been resolved to a number. */
export type ExhibitDoc = Omit<ExhibitDraft, "id"> & { order: number };

/**
 * The widths the editor accepts, in metres. Below 5 cm a marker is too small
 * for a phone to pick out from a step away; above 5 m it is a wall, not an
 * exhibit, and the figure is more likely a slip of the unit.
 */
export const MIN_MARKER_WIDTH_M = 0.05;
export const MAX_MARKER_WIDTH_M = 5;

export function emptyExhibit(id: string): ExhibitDraft {
  return { id, title: "", markerPath: "", markerWidthM: 0 };
}

/**
 * Metres as the editor shows them: centimetres, to the millimetre.
 *
 * Rounded because the two units do not convert exactly in binary — 0.333 m
 * times 100 is 33.300000000000004, which is what the field would show.
 */
export function toCentimetres(metres: number): number {
  return Math.round(metres * 1000) / 10;
}

/** Centimetres as typed, in the metres stored — to the millimetre, as above. */
export function toMetres(centimetres: number): number {
  return Math.round(centimetres * 10) / 1000;
}

/** What stands between one exhibit and the scanner, keyed by field. */
export type ExhibitProblems = {
  title?: string;
  marker?: string;
  width?: string;
};

/** Empty means the exhibit is complete. */
export function exhibitProblems(e: ExhibitDraft): ExhibitProblems {
  const problems: ExhibitProblems = {};
  if (!e.title.trim()) problems.title = "Required.";
  if (!e.markerPath) problems.marker = "Upload a marker photo.";
  // Zero is "not measured yet", and NaN is a field cleared mid-edit: both are
  // a width nobody has entered, which reads differently from a wrong one.
  if (!e.markerWidthM) {
    problems.width = "Measure the marker's real width.";
  } else if (
    !(
      e.markerWidthM >= MIN_MARKER_WIDTH_M &&
      e.markerWidthM <= MAX_MARKER_WIDTH_M
    )
  ) {
    problems.width = `Between ${toCentimetres(MIN_MARKER_WIDTH_M)} and ${toCentimetres(MAX_MARKER_WIDTH_M)} cm.`;
  }
  return problems;
}

/** Rows that would ship broken, counted for the checklist and the tab. */
export function countExhibitProblems(exhibits: ExhibitDraft[]): {
  untitled: number;
  /** No marker photo, or no width the scanner can use. */
  unmarked: number;
} {
  const all = exhibits.map(exhibitProblems);
  return {
    untitled: all.filter((p) => p.title).length,
    unmarked: all.filter((p) => p.marker || p.width).length,
  };
}

/**
 * Can the scanner look for it? Matches `Exhibit.isScannable` in the Dart
 * model: a marker image of a known size.
 */
export function isScannable(e: ExhibitDraft): boolean {
  return e.markerPath !== "" && e.markerWidthM > 0;
}

/**
 * The destination's `hasAR`, derived rather than edited (D-18).
 *
 * It drives the AR badge in the app, which is a promise that pointing the
 * camera at something will work. A switch could make that promise for a
 * museum with nothing to scan; this cannot.
 */
export function museumHasAR(
  isMuseum: boolean,
  exhibits: ExhibitDraft[],
): boolean {
  return isMuseum && exhibits.some(isScannable);
}

/** Every Storage object an exhibit points at. */
export function exhibitFiles(e: ExhibitDraft): string[] {
  return [e.markerPath, e.audioUrl ?? ""].filter((p) => p !== "");
}

/**
 * The document to store for an exhibit at a 1-based position.
 *
 * Optional fields are omitted when blank rather than written as `""` or
 * `null`, as segments do — the Dart model's nullable fields then default.
 * The two required ones are written whatever they hold.
 */
export function toExhibitDoc(e: ExhibitDraft, order: number): ExhibitDoc {
  const data: ExhibitDoc = {
    title: e.title.trim(),
    markerPath: e.markerPath,
    markerWidthM: Number.isFinite(e.markerWidthM) ? e.markerWidthM : 0,
    order,
  };
  if (e.description?.trim()) data.description = e.description.trim();
  if (e.story?.trim()) data.story = e.story.trim();
  if (e.audioUrl) data.audioUrl = e.audioUrl;
  if (e.ttsText?.trim()) data.ttsText = e.ttsText.trim();
  return data;
}

/**
 * A stored document as the editor holds it.
 *
 * Tolerant of a document written by hand or by a script: a missing or
 * non-numeric field becomes the blank the editor would have started with, so
 * the row opens and says what is missing instead of breaking the tab.
 */
export function fromExhibitDoc(
  id: string,
  data: Partial<Record<keyof ExhibitDoc, unknown>>,
): ExhibitDraft {
  const text = (v: unknown) => (typeof v === "string" ? v : undefined);
  const width = data.markerWidthM;
  return {
    id,
    title: text(data.title) ?? "",
    description: text(data.description),
    story: text(data.story),
    markerPath: text(data.markerPath) ?? "",
    markerWidthM:
      typeof width === "number" && Number.isFinite(width) ? width : 0,
    audioUrl: text(data.audioUrl),
    ttsText: text(data.ttsText),
  };
}

/**
 * What a save has to do to turn the stored exhibits, `saved`, into the ones on
 * screen, `current`.
 *
 * Only documents that differ are written, position included: moving one
 * exhibit rewrites the ones whose number changed and leaves the rest alone.
 * `order` comes from the array here and nowhere else, so it is contiguous
 * from 1 by construction. `saved` is taken to be what is stored — as
 * `listExhibits` read it, or as the last save wrote it.
 *
 * `orphans` are the files the saved version pointed at and this one does not:
 * a removed exhibit's, a replaced marker, a recording taken off. They are
 * deleted only once the save has landed, never on Remove or Replace, so
 * Discard always finds the saved files where it left them.
 */
export function planExhibitSave(
  current: ExhibitDraft[],
  saved: ExhibitDraft[],
): {
  writes: { id: string; data: ExhibitDoc }[];
  deletes: string[];
  orphans: string[];
} {
  const before = new Map(
    saved.map((e, i) => [e.id, JSON.stringify(toExhibitDoc(e, i + 1))]),
  );
  const writes = current
    .map((e, i) => ({ id: e.id, data: toExhibitDoc(e, i + 1) }))
    .filter((w) => before.get(w.id) !== JSON.stringify(w.data));

  const live = new Set(current.map((e) => e.id));
  const deletes = saved.filter((e) => !live.has(e.id)).map((e) => e.id);

  const kept = new Set(current.flatMap(exhibitFiles));
  const orphans = [
    ...new Set(saved.flatMap(exhibitFiles).filter((p) => !kept.has(p))),
  ];

  return { writes, deletes, orphans };
}
