import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
} from "firebase/firestore";
import { db } from "./firebase";
import type { Guide, GuideDraft } from "../types/guide";

const COLLECTION = "guides";

/**
 * The whole directory, alphabetically.
 *
 * Ordered by name rather than by last edit, unlike destinations. A directory is
 * something you look a person up in; recency is meaningless when you are
 * scanning for "Santos".
 */
export async function listGuides(): Promise<Guide[]> {
  const snap = await getDocs(query(collection(db, COLLECTION), orderBy("name")));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as Guide);
}

export async function createGuide(data: GuideDraft): Promise<string> {
  const created = await addDoc(collection(db, COLLECTION), {
    ...data,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return created.id;
}

export async function updateGuide(
  id: string,
  data: Partial<GuideDraft>,
): Promise<void> {
  await updateDoc(doc(db, COLLECTION, id), {
    ...data,
    updatedAt: serverTimestamp(),
  });
}

/**
 * Remove someone from the directory.
 *
 * A hard delete, deliberately. Guides have no `status` to fall back on, and
 * "unpublish" is not a thing this collection supports — the moment a document
 * exists, every signed-in user can read the person's phone number. Somebody
 * withdrawing consent needs their details *gone*, not flagged.
 */
export async function deleteGuide(id: string): Promise<void> {
  await deleteDoc(doc(db, COLLECTION, id));
}

/** Its own function so the accreditation flip is greppable, as with publish. */
export async function setVerified(
  id: string,
  verified: boolean,
): Promise<void> {
  await updateGuide(id, { verified });
}
