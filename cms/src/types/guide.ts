import type { Timestamp } from "firebase/firestore";

/**
 * `guides/{id}` — the accredited local guide directory.
 *
 * Mirrors `docs/DATA_MODEL.md`. There is no Dart model yet; the app's Guides
 * screen arrives later, and this is the CMS half of the contract.
 *
 * **Every row is a real person's contact details.** `firestore.rules` requires
 * sign-in to read this collection for exactly that reason — it is the one
 * content collection that is not world-readable. Treat additions as publishing
 * someone's phone number, because that is what they are.
 */
export type Guide = {
  id: string;
  name: string;
  /** Municipality they work in. Same vocabulary as destinations. */
  town: string;
  specialties: string[];
  /** Free text: a phone number, an email, or both. */
  contact: string;
  /** The province vouches for them. Drives the verified marker. */
  verified: boolean;
  featured: boolean;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  /** uid of the last editor. Absent on guides written before 2026-10. */
  updatedBy?: string | null;
};

export type GuideDraft = Omit<Guide, "id">;

export function emptyGuide(): GuideDraft {
  return {
    name: "",
    town: "",
    specialties: [],
    contact: "",
    verified: false,
    featured: false,
  };
}

/**
 * Blocking problems, keyed by field. Empty means saveable.
 *
 * Stricter than the destination editor, which lets you save a half-finished
 * draft. Guides have no draft state — `firestore.rules` exposes the collection
 * to every signed-in user the moment a document exists, so there is no
 * half-finished state to save *into*. Either the entry is fit to be read or it
 * should not be written.
 */
export function validate(g: GuideDraft): Record<string, string> {
  const errors: Record<string, string> = {};
  if (!g.name.trim()) errors.name = "Required.";
  if (!g.town.trim()) errors.town = "Required.";
  if (!g.contact.trim()) {
    errors.contact = "Required — a directory entry nobody can reach is no use.";
  }
  return errors;
}
