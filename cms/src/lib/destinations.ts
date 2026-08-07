import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import {
  ref,
  uploadBytes,
  getDownloadURL,
  deleteObject,
} from "firebase/storage";
import { auth, db, storage } from "./firebase";
import {
  DESTINATION_SCHEMA_VERSION,
  type Destination,
  type Status,
} from "../types/destination";

const COLLECTION = "destinations";

/**
 * Every destination, newest edit first.
 *
 * Note the CMS reads *all* statuses, which the app cannot — `firestore.rules`
 * only lets an admin past the `status == 'published'` gate. If this query ever
 * returns permission-denied, the signed-in user has lost the admin claim.
 */
export async function listDestinations(): Promise<Destination[]> {
  const snap = await getDocs(
    query(collection(db, COLLECTION), orderBy("updatedAt", "desc")),
  );
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as Destination);
}

export async function getDestination(id: string): Promise<Destination | null> {
  const snap = await getDoc(doc(db, COLLECTION, id));
  return snap.exists()
    ? ({ id: snap.id, ...snap.data() } as Destination)
    : null;
}

/**
 * Slugs appear in deep links, so a duplicate would make one destination
 * unreachable. Checked here rather than in rules — a uniqueness constraint
 * needs a query, and security rules cannot run one.
 */
export async function isSlugTaken(
  slug: string,
  exceptId?: string,
): Promise<boolean> {
  const snap = await getDocs(
    query(collection(db, COLLECTION), where("slug", "==", slug)),
  );
  return snap.docs.some((d) => d.id !== exceptId);
}

type Draft = Omit<Destination, "id">;

export async function createDestination(data: Draft): Promise<string> {
  const created = await addDoc(collection(db, COLLECTION), {
    ...data,
    schemaVersion: DESTINATION_SCHEMA_VERSION,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedBy: auth.currentUser?.uid ?? null,
  });
  return created.id;
}

export async function updateDestination(
  id: string,
  data: Partial<Draft>,
): Promise<void> {
  await updateDoc(doc(db, COLLECTION, id), {
    ...data,
    schemaVersion: DESTINATION_SCHEMA_VERSION,
    updatedAt: serverTimestamp(),
    updatedBy: auth.currentUser?.uid ?? null,
  });
}

/**
 * Publish or unpublish.
 *
 * Its own function rather than a field on a general save: this is the moment
 * content becomes publicly readable, and it should be greppable.
 */
export async function setStatus(id: string, status: Status): Promise<void> {
  await updateDestination(id, { status });
}

export async function deleteDestination(id: string): Promise<void> {
  await deleteDoc(doc(db, COLLECTION, id));
}

/**
 * Upload a photo and return its Storage path.
 *
 * Stores the **path**, not the download URL: `docs/DATA_MODEL.md` specifies
 * `/destinations/{id}/images/{timestamp}.{ext}`, and a path survives token rotation
 * whereas a download URL does not.
 */
export async function uploadImage(
  destinationId: string,
  file: File,
): Promise<string> {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "jpg";
  const path = `destinations/${destinationId}/images/${Date.now()}.${ext}`;
  await uploadBytes(ref(storage, path), file, { contentType: file.type });
  return path;
}

/** Resolve a stored path to something an <img> can display. */
export function imageUrl(path: string): Promise<string> {
  return getDownloadURL(ref(storage, path));
}

export async function deleteImage(path: string): Promise<void> {
  try {
    await deleteObject(ref(storage, path));
  } catch {
    // Already gone, or never uploaded. Removing it from the document is what
    // actually matters; a leftover blob is not worth blocking the save.
  }
}
