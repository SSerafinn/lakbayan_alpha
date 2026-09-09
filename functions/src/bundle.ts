import { createHash } from "node:crypto";

import { slugify } from "./slug.js";

/**
 * The pure half of `generateOfflineBundle` — everything decidable without
 * Firestore or Storage, and therefore everything worth a unit test.
 */

export type BundleDestination = {
  id: string;
  images: string[];
  /** Storage paths of the audio guide's recordings. */
  audioPaths: string[];
  /** Millis. Part of the version, so an edit invalidates the bundle. */
  updatedAtMillis: number;
};

export type GenerateRequest = { town: string; dryRun: boolean };

export function parseGenerateRequest(data: unknown): GenerateRequest {
  if (typeof data !== "object" || data === null) {
    throw new Error("Expected { town }.");
  }
  const { town, dryRun } = data as Record<string, unknown>;
  if (typeof town !== "string" || !town.trim()) {
    throw new Error("town is required.");
  }
  if (dryRun !== undefined && typeof dryRun !== "boolean") {
    throw new Error("dryRun must be true or false.");
  }
  return { town: town.trim(), dryRun: dryRun === true };
}

/** Where a town's map pack lives. Mirrors `docs/DATA_MODEL.md`. */
export function tilePackRef(townId: string): string {
  return `tiles/${townId}/pack.pmtiles`;
}

/**
 * Every Storage object a client needs to have this town offline.
 *
 * De-duplicated, because two destinations can legitimately reference the same
 * image and paying to download it twice is a poor use of somebody's data.
 * Sorted so the list — and therefore the version below — does not change when
 * Firestore returns the same documents in a different order.
 */
export function collectAssetPaths(destinations: BundleDestination[]): string[] {
  const paths = new Set<string>();
  for (const d of destinations) {
    for (const p of d.images) if (p) paths.add(p);
    for (const p of d.audioPaths) if (p) paths.add(p);
  }
  return [...paths].sort();
}

/**
 * A short, deterministic fingerprint of what the bundle contains.
 *
 * The client stores the version it downloaded and compares: different means
 * its copy is stale. So this has to change when the content changes and **not**
 * change otherwise — a version that moved on every generate would make every
 * client re-download the town for nothing.
 *
 * Built from the destination ids and their `updatedAt`, sorted. Adding,
 * removing or editing a destination moves it; regenerating an unchanged town
 * does not. Note it does **not** cover the tile pack: a pack is uploaded once
 * per town and replacing it is a deliberate act, which
 * `docs/DATA_MODEL.md` records as a reason to bump by hand.
 */
export function bundleVersion(destinations: BundleDestination[]): string {
  const material = destinations
    .map((d) => `${d.id}:${d.updatedAtMillis}`)
    .sort()
    .join("|");
  return createHash("sha256").update(material).digest("hex").slice(0, 12);
}

export type BundleStatus = "pending" | "ready" | "stale";

/**
 * `ready` only when everything a client needs is actually in Storage.
 *
 * A bundle whose tile pack has not been uploaded yet is `pending`, not
 * `ready` — the app would download it, find no map, and have no way to tell
 * that from a broken download. Missing photos count too: the point of an
 * offline bundle is that nothing is fetched later.
 */
export function bundleStatus(missing: string[]): BundleStatus {
  return missing.length === 0 ? "ready" : "pending";
}

export type BundleManifest = {
  townId: string;
  name: string;
  destinationIds: string[];
  tilePackRef: string;
  size: number;
  version: string;
  status: BundleStatus;
  /** Storage paths that were expected and are not there. */
  missing: string[];
};

/** Assemble the document, given sizes already looked up from Storage. */
export function buildManifest(
  town: string,
  destinations: BundleDestination[],
  sizes: Map<string, number>,
): BundleManifest {
  const townId = slugify(town);
  const pack = tilePackRef(townId);
  const wanted = [...collectAssetPaths(destinations), pack];

  const missing = wanted.filter((p) => !sizes.has(p));
  const size = wanted.reduce((total, p) => total + (sizes.get(p) ?? 0), 0);

  return {
    townId,
    name: town,
    // Sorted for the same reason the asset list is: a stable document is
    // easier to diff, and Firestore's ordering is not a promise.
    destinationIds: destinations.map((d) => d.id).sort(),
    tilePackRef: pack,
    size,
    version: bundleVersion(destinations),
    status: bundleStatus(missing),
    missing,
  };
}
