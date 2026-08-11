import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  writeBatch,
} from "firebase/firestore";
import {
  deleteObject,
  getDownloadURL,
  ref,
  uploadBytes,
} from "firebase/storage";
import { db, storage } from "./firebase";
import type { SegmentDoc, SegmentDraft } from "../types/segment";

const segmentsCol = (destinationId: string) =>
  collection(db, "destinations", destinationId, "segments");

/**
 * A Firestore document id, allocated locally without writing anything.
 *
 * Segments need an id before they are saved because audio uploads are keyed by
 * it — `/destinations/{id}/audio/{segmentId}.{ext}`. Letting `addDoc` mint the
 * id on save would mean either uploading to a temporary path and moving the
 * object afterwards (Storage has no move; it is a copy and a delete) or
 * refusing uploads until the row has been saved once. Both are worse than
 * asking the SDK for an id up front, which is an entirely offline operation.
 *
 * Takes no destination: ids are random 20-character strings that carry no path
 * information, so one can be minted before the destination that will hold it
 * exists. That is what lets the very first stop of a brand-new destination
 * accept a recording.
 */
export function newSegmentId(): string {
  return doc(collection(db, "destinations")).id;
}

/** Every segment of a destination, in player order. */
export async function listSegments(
  destinationId: string,
): Promise<SegmentDraft[]> {
  const snap = await getDocs(
    query(segmentsCol(destinationId), orderBy("order")),
  );
  return snap.docs.map((d) => {
    const data = d.data() as SegmentDoc;
    return {
      id: d.id,
      title: data.title ?? "",
      description: data.description ?? undefined,
      audioUrl: data.audioUrl ?? undefined,
      ttsText: data.ttsText ?? undefined,
    };
  });
}

/**
 * Write the whole guide: creates, updates and deletes in one batch.
 *
 * A batch rather than a write per row, because reordering touches every
 * segment below the one that moved. Row-at-a-time would fire a dozen writes
 * for one drag and leave the sequence half-renumbered if the tab closed
 * midway — which the app reads as two stops sharing an `order`.
 *
 * `order` is derived from array position here and nowhere else, so the list on
 * screen is by definition the list in the player.
 */
export async function saveSegments(
  destinationId: string,
  segments: SegmentDraft[],
  previous: SegmentDraft[],
): Promise<void> {
  const batch = writeBatch(db);
  const live = new Set(segments.map((s) => s.id));

  segments.forEach((s, i) => {
    // `undefined` is rejected by the SDK, and null would have to be handled by
    // every reader; omitting the key leaves the Dart model's nullable fields
    // to default, which is what "no recording" already means.
    const data: SegmentDoc = { title: s.title.trim(), order: i + 1 };
    if (s.description?.trim()) data.description = s.description.trim();
    if (s.audioUrl) data.audioUrl = s.audioUrl;
    if (s.ttsText?.trim()) data.ttsText = s.ttsText.trim();
    batch.set(doc(segmentsCol(destinationId), s.id), data);
  });

  for (const gone of previous.filter((s) => !live.has(s.id))) {
    batch.delete(doc(segmentsCol(destinationId), gone.id));
  }

  await batch.commit();

  // Storage is not transactional with Firestore, so orphaned recordings are
  // cleaned up after the documents land. A leftover object costs pennies; a
  // deleted recording whose document write then failed cannot be recovered.
  await Promise.all(
    previous
      .filter((s) => !live.has(s.id) && s.audioUrl)
      .map((s) => deleteAudio(s.audioUrl!)),
  );
}

/**
 * Delete every segment of a destination.
 *
 * Firestore does not cascade — deleting a destination leaves its subcollection
 * behind as orphaned documents that no rule and no query will ever reach
 * again.
 */
export async function deleteAllSegments(destinationId: string): Promise<void> {
  const existing = await listSegments(destinationId);
  await Promise.all(
    existing.map((s) => deleteDoc(doc(segmentsCol(destinationId), s.id))),
  );
  await Promise.all(
    existing.filter((s) => s.audioUrl).map((s) => deleteAudio(s.audioUrl!)),
  );
}

/** Extensions the mobile player can decode via just_audio on Android. */
export const AUDIO_EXTENSIONS = ["mp3", "m4a", "aac", "wav", "ogg"] as const;

/**
 * Upload narration and return its Storage path.
 *
 * `docs/DATA_MODEL.md` gives this path as `{segmentId}.mp3`; the extension is
 * whatever was actually uploaded, because a `.mp3` suffix on an m4a file
 * misleads everything downstream that sniffs by name.
 */
export async function uploadAudio(
  destinationId: string,
  segmentId: string,
  file: File,
): Promise<string> {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "mp3";
  const path = `destinations/${destinationId}/audio/${segmentId}.${ext}`;
  await uploadBytes(ref(storage, path), file, { contentType: file.type });
  return path;
}

/** Resolve a stored path to something an `<audio>` element can play. */
export function audioDownloadUrl(path: string): Promise<string> {
  return getDownloadURL(ref(storage, path));
}

export async function deleteAudio(path: string): Promise<void> {
  try {
    await deleteObject(ref(storage, path));
  } catch {
    // Already gone, or never uploaded. Same reasoning as `deleteImage`: what
    // matters is that the document no longer points at it.
  }
}
