import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
} from "firebase/firestore";
import { deleteObject, ref, uploadBytes } from "firebase/storage";
import { auth, db, storage } from "./firebase";
import { shrinkImage } from "./image";
import { writeIfUnchanged } from "./versioned";
import { slugify } from "../types/destination";
import { extensionFor } from "../types/media";
import type { Tour, TourDraft } from "../types/tour";

const COLLECTION = "tours";

/** Every tour, newest edit first — this is a working list, not a directory. */
export async function listTours(): Promise<Tour[]> {
  const snap = await getDocs(
    query(collection(db, COLLECTION), orderBy("updatedAt", "desc")),
  );
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as Tour);
}

/**
 * The id a tour with this title will have.
 *
 * Exposed so the editor can warn before a save silently overwrites an existing
 * tour — `setDoc` with a derived id has no notion of "already taken", unlike
 * the destination editor's slug check.
 */
export function tourId(title: string): string {
  return slugify(title);
}

/**
 * Create, or overwrite in place.
 *
 * `setDoc` at a derived id rather than `addDoc`, so that importing a tour the
 * CMS already holds updates it instead of creating a second copy. See
 * docs/DATA_MODEL.md.
 *
 * `existingId` is passed when editing: the id is derived from the *original*
 * title and deliberately does not follow a rename, since anything already
 * pointing at the tour would be orphaned by re-keying it.
 */
export async function saveTour(
  data: TourDraft,
  existingId?: string,
  { expected }: { expected?: number } = {},
): Promise<string> {
  const id = existingId ?? tourId(data.title);
  const target = doc(db, COLLECTION, id);
  const payload = {
    ...data,
    title: data.title.trim(),
    description: data.description?.trim() ?? "",
    updatedAt: serverTimestamp(),
    // Recorded so a conflict, and the dashboard's feed, can say who.
    updatedBy: auth.currentUser?.uid ?? null,
    ...(existingId ? {} : { createdAt: serverTimestamp() }),
  };
  // An edit is checked against the version that was opened; a new tour has
  // nothing to conflict with (the page checks the derived id is free).
  if (existingId && expected !== undefined) {
    await writeIfUnchanged(target, expected, (tx) =>
      tx.set(target, payload, { merge: true }),
    );
  } else {
    await setDoc(target, payload, { merge: true });
  }
  return id;
}

export async function deleteTour(id: string): Promise<void> {
  await deleteDoc(doc(db, COLLECTION, id));
}

/**
 * Upload a cover and return its Storage path.
 *
 * `storage.rules` enumerates permitted paths and denies everything else, so
 * this location exists there too — writing anywhere else is rejected rather
 * than quietly accepted.
 *
 * A fresh name each time, as destination photos have, and the cover it
 * replaces is left alone: the tour still points at that one until it is
 * saved, so deleting or overwriting it here broke the cover of any tour whose
 * edit was then cancelled. The editor deletes the old one after the save.
 * A fresh name also keeps true what the app's offline copies rely on — the
 * bytes under a path never change.
 */
export async function uploadCover(id: string, file: File): Promise<string> {
  const photo = await shrinkImage(file);
  const path = `tours/${id}/cover-${Date.now()}.${extensionFor(photo.type)}`;
  await uploadBytes(ref(storage, path), photo, { contentType: photo.type });
  return path;
}

export async function deleteCover(path: string): Promise<void> {
  try {
    await deleteObject(ref(storage, path));
  } catch {
    // Already gone, or never uploaded. What matters is that the document no
    // longer points at it.
  }
}
