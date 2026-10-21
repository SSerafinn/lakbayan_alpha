import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  writeBatch,
} from "firebase/firestore";
import { deleteObject, ref, uploadBytes } from "firebase/storage";
import { db, storage } from "./firebase";
import { shrinkImage } from "./image";
import { uploadAudio } from "./segments";
import { extensionFor } from "../types/media";
import {
  exhibitFiles,
  fromExhibitDoc,
  planExhibitSave,
  type ExhibitDraft,
} from "../types/exhibit";

const exhibitsCol = (destinationId: string) =>
  collection(db, "destinations", destinationId, "exhibits");

/**
 * A Firestore document id, allocated locally without writing anything.
 *
 * For the reason `newSegmentId` gives: a marker and its narration are stored
 * under the exhibit's id, so a row needs one before its first save —
 * including the first exhibit of a museum that has not been saved yet.
 */
export function newExhibitId(): string {
  return doc(collection(db, "destinations")).id;
}

/** Every exhibit of a destination, in the no-camera list's order. */
export async function listExhibits(
  destinationId: string,
): Promise<ExhibitDraft[]> {
  const snap = await getDocs(
    query(exhibitsCol(destinationId), orderBy("order")),
  );
  return snap.docs.map((d) => fromExhibitDoc(d.id, d.data()));
}

/**
 * Write the exhibits: creates, updates and deletes in one batch.
 *
 * A batch for the reason `saveSegments` gives — a move renumbers every row
 * between the two positions, and half a renumbering reads as two exhibits
 * sharing an `order`. Unlike the guide, only the documents that changed are
 * written (`planExhibitSave`), so a museum's save does not rewrite thirty
 * exhibits to change the opening hours.
 */
export async function saveExhibits(
  destinationId: string,
  current: ExhibitDraft[],
  saved: ExhibitDraft[],
): Promise<void> {
  const { writes, deletes, orphans } = planExhibitSave(current, saved);

  if (writes.length > 0 || deletes.length > 0) {
    const batch = writeBatch(db);
    for (const w of writes) {
      batch.set(doc(exhibitsCol(destinationId), w.id), w.data);
    }
    for (const id of deletes) {
      batch.delete(doc(exhibitsCol(destinationId), id));
    }
    await batch.commit();
  }

  // Only after the documents land, as with the guide's recordings: a leftover
  // object costs pennies, while a marker deleted ahead of a write that then
  // failed leaves the saved exhibit pointing at nothing.
  await Promise.all(orphans.map(deleteExhibitFile));
}

/**
 * Delete every exhibit of a destination, with its marker and narration.
 *
 * Firestore does not cascade — see `deleteAllSegments`.
 */
export async function deleteAllExhibits(destinationId: string): Promise<void> {
  const existing = await listExhibits(destinationId);
  await Promise.all(
    existing.map((e) => deleteDoc(doc(exhibitsCol(destinationId), e.id))),
  );
  await Promise.all(existing.flatMap(exhibitFiles).map(deleteExhibitFile));
}

/**
 * Upload a marker image and return its Storage path.
 *
 * Shrunk like any photo (`shrinkImage`): 2000 px on the long edge is plenty
 * for ARCore, and the marker rides in the town's offline download like the
 * photos do.
 *
 * A fresh name per upload, `{exhibitId}-{timestamp}`, for the reasons on
 * `uploadCover` in `lib/tours.ts`: the marker it replaces stays where the
 * saved exhibit points until the save, so Discard still has it, and the bytes
 * under a path never change for a phone that has already downloaded them.
 */
export async function uploadMarker(
  destinationId: string,
  exhibitId: string,
  file: File,
): Promise<string> {
  const photo = await shrinkImage(file);
  const path = `ar/${destinationId}/markers/${exhibitId}-${Date.now()}.${extensionFor(photo.type)}`;
  await uploadBytes(ref(storage, path), photo, { contentType: photo.type });
  return path;
}

/**
 * Upload an exhibit's narration and return its Storage path,
 * `destinations/{destId}/audio/{exhibitId}.{ext}`.
 *
 * The guide's folder and the guide's upload: exhibit and segment ids are both
 * Firestore auto-ids and cannot collide (`docs/DATA_MODEL.md`), and the
 * content type comes from `AUDIO_TYPES` the same way.
 */
export function uploadExhibitAudio(
  destinationId: string,
  exhibitId: string,
  file: File,
): Promise<string> {
  return uploadAudio(destinationId, exhibitId, file);
}

async function deleteExhibitFile(path: string): Promise<void> {
  try {
    await deleteObject(ref(storage, path));
  } catch {
    // Already gone, or never uploaded. What matters is that no document
    // points at it any more.
  }
}
