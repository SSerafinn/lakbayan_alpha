import type { Timestamp } from "firebase/firestore";

/**
 * `offlineBundles/{townId}` — the manifest a phone reads before downloading a
 * town. Mirrors `docs/DATA_MODEL.md`.
 *
 * Written only by the `generateOfflineBundle` Cloud Function. Nothing in the
 * CMS writes it directly: deciding what "ready" means requires statting every
 * object in Storage, and a browser doing that would be both slow and
 * untrustworthy.
 */
export type OfflineBundle = {
  townId: string;
  /** The town's display name, exactly as it appears on destinations. */
  name: string;
  destinationIds: string[];
  tilePackRef: string;
  /** Total bytes a phone will download, assets and map pack together. */
  size: number;
  /** Fingerprint of the content. A phone compares it to decide it is stale. */
  version: string;
  status: BundleStatus;
  generatedAt?: Timestamp;
};

/**
 * `ready` means every asset and the map pack are in Storage. `pending` means
 * something is missing — most often the map pack, which is uploaded by hand
 * after `tools/tiles` renders it.
 *
 * `stale` is a **phone-side** verdict, not one this document carries: it is
 * what a client concludes when the version it downloaded differs from the
 * version here. The function never writes it.
 */
export type BundleStatus = "pending" | "ready" | "stale";

/** What `generateOfflineBundle` hands back, including its dry-run form. */
export type BundleManifest = Omit<OfflineBundle, "generatedAt"> & {
  /** Storage paths that were expected and are not there. */
  missing: string[];
};

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}
