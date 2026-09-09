import { collection, getDocs } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "./firebase";
import type { BundleManifest, OfflineBundle } from "../types/bundle";

/** Every bundle that has been generated, keyed by townId. */
export async function listBundles(): Promise<Map<string, OfflineBundle>> {
  const snap = await getDocs(collection(db, "offlineBundles"));
  return new Map(
    snap.docs.map((d) => [d.id, { townId: d.id, ...d.data() } as OfflineBundle]),
  );
}

const generateFn = httpsCallable<
  { town: string; dryRun?: boolean },
  BundleManifest
>(functions, "generateOfflineBundle");

/**
 * Build (or re-check) a town's bundle.
 *
 * `dryRun` computes the manifest without writing it, which is how the screen
 * answers "would regenerating change anything?" without bumping the version
 * and sending every phone off to re-download a town it already has.
 */
export async function generateBundle(
  town: string,
  { dryRun = false } = {},
): Promise<BundleManifest> {
  const res = await generateFn({ town, dryRun });
  return res.data;
}
