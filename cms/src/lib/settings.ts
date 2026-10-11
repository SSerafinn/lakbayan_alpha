import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
} from "firebase/firestore";
import { auth, db } from "./firebase";
import { writeIfUnchanged } from "./versioned";
import {
  SETTINGS_SCHEMA_VERSION,
  type SettingsId,
  type Stamped,
} from "../types/settings";
import { versionOf } from "../types/conflict";

const COLLECTION = "settings";

/**
 * One settings document and the version it was read at.
 *
 * `data` is null when nobody has saved it yet — a fresh project starts with
 * no settings, and each screen supplies its own defaults.
 */
export async function getSettings<T>(
  id: SettingsId,
): Promise<{ data: (T & Stamped) | null; version: number }> {
  const snap = await getDoc(doc(db, COLLECTION, id));
  if (!snap.exists()) return { data: null, version: 0 };
  const data = snap.data() as T & Stamped;
  return { data, version: versionOf(data.updatedAt) };
}

/**
 * Save a settings document and return the version it now has.
 *
 * Replaces the document rather than merging: every field the screen shows
 * is written, so a field the admin cleared really is cleared. `extra` carries
 * sentinels the caller decides on — a policy's "last updated" moves only when
 * its text did.
 *
 * With `expected`, refused (ConflictError) if anyone else saved since; a
 * first save, at version 0, may create the document. Without it — the
 * conflict dialog's "Overwrite with mine" — it writes regardless.
 */
export async function saveSettings(
  id: SettingsId,
  data: object,
  { expected, extra = {} }: { expected?: number; extra?: object } = {},
): Promise<number> {
  const ref = doc(db, COLLECTION, id);
  const payload = {
    ...data,
    ...extra,
    schemaVersion: SETTINGS_SCHEMA_VERSION,
    updatedAt: serverTimestamp(),
    updatedBy: auth.currentUser?.uid ?? null,
  };
  if (expected === undefined) {
    await setDoc(ref, payload);
  } else {
    await writeIfUnchanged(ref, expected, (tx) => tx.set(ref, payload), {
      allowMissing: true,
    });
  }
  // Read back: updatedAt is a server timestamp, and the next save is checked
  // against it.
  const after = await getDoc(ref);
  return versionOf(after.data()?.updatedAt);
}

/** The sentinel for "this text changed now", used for a policy's date. */
export const nowStamp = () => serverTimestamp();

/** A Date as a Firestore timestamp, for the announcement's end. */
export const toTimestamp = (d: Date) => Timestamp.fromDate(d);
