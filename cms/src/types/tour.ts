import type { Timestamp } from "firebase/firestore";

/**
 * `tours/{id}` — a curated multi-stop itinerary.
 *
 * Mirrors `docs/DATA_MODEL.md`. No Dart model yet; the app's Tours screen
 * arrives with Phase 3's itineraries work.
 *
 * **The document id is `slugify(title)`, not a random id.** Destinations carry
 * a `slug` field and get a random id; tours put the slug in the id instead,
 * and `scripts/import-content.mjs` derives it identically. That is what makes
 * importing a tour the CMS already has an update rather than a second copy.
 */
export type Tour = {
  id: string;
  title: string;
  description?: string;
  /** Destination document ids, in visiting order. Order is the content. */
  stops: string[];
  /** Storage path, not a download URL — see the note in destinations.ts. */
  coverImg?: string;
  featured: boolean;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  /** uid of the last editor. Absent on tours written before 2026-10. */
  updatedBy?: string | null;
};

export type TourDraft = Omit<Tour, "id">;

export function emptyTour(): TourDraft {
  return { title: "", description: "", stops: [], featured: false };
}

/**
 * Blocking problems, keyed by field. Empty means saveable.
 *
 * As strict as the guides editor and for the same reason: `firestore.rules`
 * makes a tour public the moment the document exists, so unlike a destination
 * there is no draft state to park an unfinished one in. A tour with no stops
 * is not a tour, and it would be live.
 */
export function validate(t: TourDraft): Record<string, string> {
  const errors: Record<string, string> = {};
  if (!t.title.trim()) errors.title = "Required.";
  if (t.stops.length === 0) {
    errors.stops = "Add at least one stop — a tour with none is live and empty.";
  }
  return errors;
}
