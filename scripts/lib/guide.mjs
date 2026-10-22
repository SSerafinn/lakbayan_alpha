// What an import does to one destination's audio guide.

/**
 * The document id of the stop at `index` (0-based): `stop-01`, `stop-02` ….
 *
 * Fixed rather than random, so re-importing overwrites the same documents
 * instead of orphaning the old ones, and the audio path `{segmentId}.{ext}`
 * (docs/DATA_MODEL.md) stays stable across runs.
 */
export function stopId(index) {
  return `stop-${String(index + 1).padStart(2, "0")}`;
}

/**
 * The plan for a destination whose sheet lists `stopCount` stops, given the
 * ids of the stops it already has: which to write, and which to remove. Null
 * when there is nothing to do.
 *
 * For a place the sheet gives stops to, the sheet is the whole guide, and
 * anything else goes. For a place it gives none, the guide is left exactly
 * as it is — the same rule as photos. Silence in a sheet is not an
 * instruction to delete: those stops, and their recordings, may have been
 * made in the CMS since the last import. Emptying a guide is done in the CMS.
 */
export function planGuide(stopCount, existingIds) {
  if (!(stopCount > 0)) return null;
  const write = Array.from({ length: stopCount }, (_, i) => stopId(i));
  const kept = new Set(write);
  return { write, remove: existingIds.filter((id) => !kept.has(id)) };
}
