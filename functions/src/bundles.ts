import { HttpsError, onCall } from "firebase-functions/https";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import type { CallableRequest } from "firebase-functions/https";

import {
  buildManifest,
  collectAssetPaths,
  parseGenerateRequest,
  tilePackRef,
  type BundleDestination,
} from "./bundle.js";
import { slugify } from "./slug.js";
import { REGION } from "./region.js";

/**
 * Builds a town's offline bundle manifest — `offlineBundles/{townId}`.
 *
 * A Cloud Function rather than CMS code because it has to read every published
 * destination in a town, walk their audio segments, and stat objects in
 * Storage. Doing that from a browser means either giving the CMS broad read
 * access it does not otherwise need, or trusting a client to report how big a
 * download is. The function also writes a document the *app* reads without
 * signing in, so it is the one place that should decide what "ready" means.
 */

function requireAdmin(req: CallableRequest<unknown>): void {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  if (req.auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Only an admin can build offline bundles.",
    );
  }
}

export const generateOfflineBundle = onCall({ region: REGION }, async (req) => {
  requireAdmin(req);

  let town: string;
  let dryRun: boolean;
  try {
    ({ town, dryRun } = parseGenerateRequest(req.data));
  } catch (err) {
    throw new HttpsError("invalid-argument", (err as Error).message);
  }

  const db = getFirestore();
  const snap = await db
    .collection("destinations")
    .where("town", "==", town)
    .where("status", "==", "published")
    .get();

  const destinations: BundleDestination[] = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    // An editor who cleared "include in offline bundles" has said this place
    // should not be part of a download. Same filter as extract-tiles.mjs, so
    // the tile pack and the manifest cover the same set of places.
    if (data.offlineEligible === false) continue;

    const segments = await doc.ref.collection("segments").get();
    destinations.push({
      id: doc.id,
      images: Array.isArray(data.images) ? data.images : [],
      audioPaths: segments.docs
        .map((s) => s.data().audioUrl)
        .filter((p): p is string => typeof p === "string" && p.length > 0),
      updatedAtMillis: data.updatedAt?.toMillis?.() ?? 0,
    });
  }

  if (destinations.length === 0) {
    throw new HttpsError(
      "not-found",
      `No published, offline-eligible destinations in "${town}". The town is ` +
        "matched exactly, accents included.",
    );
  }

  // Stat every object once. `exists` and `getMetadata` would be two round
  // trips per file; getMetadata alone tells us both, and a rejection is how a
  // missing object reports itself.
  const bucket = getStorage().bucket();
  const wanted = [
    ...collectAssetPaths(destinations),
    tilePackRef(slugify(town)),
  ];
  const sizes = new Map<string, number>();
  await Promise.all(
    wanted.map(async (path) => {
      try {
        const [meta] = await bucket.file(path).getMetadata();
        sizes.set(path, Number(meta.size ?? 0));
      } catch {
        // Left out of the map, which is what marks it missing downstream.
      }
    }),
  );

  const manifest = buildManifest(town, destinations, sizes);

  // dryRun answers "would regenerating change anything?" without touching the
  // document. The CMS uses it so an admin can check for staleness without
  // bumping a version and sending every client off to re-download.
  if (!dryRun) {
    const { missing: _missing, ...document } = manifest;
    await db
      .collection("offlineBundles")
      .doc(manifest.townId)
      .set({ ...document, generatedAt: new Date() });
  }

  return manifest;
});
