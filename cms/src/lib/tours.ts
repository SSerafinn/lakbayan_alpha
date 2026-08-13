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
import { db, storage } from "./firebase";
import { slugify } from "../types/destination";
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
): Promise<string> {
  const id = existingId ?? tourId(data.title);
  await setDoc(
    doc(db, COLLECTION, id),
    {
      ...data,
      title: data.title.trim(),
      description: data.description?.trim() ?? "",
      updatedAt: serverTimestamp(),
      ...(existingId ? {} : { createdAt: serverTimestamp() }),
    },
    { merge: true },
  );
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
 * Named `cover` rather than by timestamp: a tour has exactly one, so replacing
 * it should overwrite rather than accumulate. The extension varies, which is
 * why the old object is deleted when the format changes.
 */
export async function uploadCover(
  id: string,
  file: File,
  previous?: string,
): Promise<string> {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "jpg";
  const path = `tours/${id}/cover.${ext}`;
  await uploadBytes(ref(storage, path), file, { contentType: file.type });
  if (previous && previous !== path) await deleteCover(previous);
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
