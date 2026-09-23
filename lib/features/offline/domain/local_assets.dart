import "dart:io";

import "package:riverpod_annotation/riverpod_annotation.dart";

import "../data/download_store.dart";
import "../data/town_downloader.dart";
import "offline_providers.dart";

part "local_assets.g.dart";

/// The downloaded copy of a Storage object, if this device has one.
///
/// [TownDownloader] mirrors each object's Storage path under the town's
/// directory, so the local path is derivable — no lookup table, and no second
/// record to keep in step with the files. What is *not* derivable is which town
/// an object belongs to: a Storage path says `destinations/{id}/...`, and the
/// mapping from destination to town lives in Firestore. So this asks each
/// downloaded town in turn. There are a handful at most, and a miss is one
/// `stat` call.
///
/// **Not gated on the town being current**, unlike [currentPackFor]. A stale
/// pack is the wrong map for today's town and must not be served; a photo is
/// different, because the CMS writes every upload to a fresh
/// `{timestamp}.{ext}` path. An edited town's new photo is a new path, which
/// misses here and falls through to the network — so what is on disk under a
/// given path is still the right bytes for that path. The one exception is
/// `scripts/import-content.mjs`, which keys on the source filename and would
/// overwrite in place; a re-import of a changed file under the same name would
/// be served stale until the town is downloaded again.
File? localAssetFor(
  DownloadStore store,
  TownDownloader downloader,
  String storagePath,
) {
  if (storagePath.isEmpty) return null;
  for (final record in store.all) {
    final file = File(downloader.localPathFor(record.townId, storagePath));
    if (file.existsSync()) return file;
  }
  return null;
}

/// [localAssetFor] as a provider, for widgets.
///
/// The empty-store check is what keeps this usable everywhere. With nothing
/// downloaded there is nothing to look up, and returning early means
/// [downloadRootProvider] — which throws until `main()` overrides it — is never
/// read. Every widget test that renders a photo would otherwise have to supply
/// a temp directory to prove a negative.
@riverpod
File? localAsset(Ref ref, String storagePath) {
  final store = ref.watch(downloadStoreProvider);
  if (store.all.isEmpty) return null;
  return localAssetFor(store, ref.watch(townDownloaderProvider), storagePath);
}
