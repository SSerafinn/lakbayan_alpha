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
import { auth, db } from "./firebase";
import { writeIfUnchanged } from "./versioned";
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
    updatedBy: auth.currentUser?.uid ?? null,
  });
  return created.id;
}

/** With `expected`, only if nobody has saved this guide since — see destinations.ts. */
export async function updateGuide(
  id: string,
  data: Partial<GuideDraft>,
  { expected }: { expected?: number } = {},
): Promise<void> {
  const ref = doc(db, COLLECTION, id);
  const payload = {
    ...data,
    updatedAt: serverTimestamp(),
    updatedBy: auth.currentUser?.uid ?? null,
  };
  if (expected === undefined) await updateDoc(ref, payload);
  else await writeIfUnchanged(ref, expected, (tx) => tx.update(ref, payload));
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
