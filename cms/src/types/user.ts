import type { Timestamp } from "firebase/firestore";

/**
 * `users/{uid}` — mirrors `docs/DATA_MODEL.md` and the app's `UserProfile`.
 *
 * Read-only in the CMS. `firestore.rules` lets an admin read any profile but
 * write none of them: the document is the user's, and there is no field on it
 * the province has business editing. Note the deliberate absence of a `role`
 * field — admin rights are a custom claim, and are listed separately below.
 */
export type AppUser = {
  uid: string;
  email?: string | null;
  displayName?: string | null;
  photoUrl?: string | null;
  savedTourIds: string[];
  downloadedTownIds: string[];
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
};

/**
 * Someone holding the `admin` custom claim, as reported by the `listAdmins`
 * callable. Comes from Auth, not Firestore: an admin who has only ever signed
 * in to the CMS has no `users/` document, so the two lists do not coincide.
 */
export type AdminMember = {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoUrl: string | null;
};
