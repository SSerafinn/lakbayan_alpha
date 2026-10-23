import "dart:io";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/exhibit.dart";
import "../../destinations/domain/destination_providers.dart";
import "../data/asset_fetcher.dart";
import "../data/bundle_repository.dart";
import "../data/download_store.dart";
import "../data/town_downloader.dart";
import "offline_bundle.dart";

part "offline_providers.g.dart";

@Riverpod(keepAlive: true)
BundleRepository bundleRepository(Ref ref) => BundleRepository(
  FirebaseFirestore.instance,
  reporter: ref.watch(errorReporterProvider),
);

@Riverpod(keepAlive: true)
AssetFetcher assetFetcher(Ref ref) => const StorageAssetFetcher();

/// Overridden in `main()` once Hive is open, and in every test.
///
/// Defaults to an in-memory store rather than throwing, for the same reason
/// `appPreferencesProvider` defaults to null: a widget test should not need a
/// temp directory to render a screen. In-memory reads as "nothing downloaded",
/// which is the safe default — it offers a download rather than claiming one.
@Riverpod(keepAlive: true)
DownloadStore downloadStore(Ref ref) => InMemoryDownloadStore();

/// Where downloads land. Overridden in `main()` with the documents directory.
@Riverpod(keepAlive: true)
Directory downloadRoot(Ref ref) => throw UnimplementedError(
  "downloadRootProvider must be overridden — main() supplies the "
  "application documents directory, and tests supply a temp directory.",
);

@Riverpod(keepAlive: true)
TownDownloader townDownloader(Ref ref) => TownDownloader(
  fetcher: ref.watch(assetFetcherProvider),
  root: ref.watch(downloadRootProvider),
  store: ref.watch(downloadStoreProvider),
);

@riverpod
Stream<List<OfflineBundle>> offlineBundles(Ref ref) =>
    ref.watch(bundleRepositoryProvider).watchAll();

/// Every Storage object a town's bundle implies.
///
/// Derived here rather than read from the manifest: the app already has the
/// destinations, their segments and their exhibits, and a second copy of the
/// paths in Firestore would drift from the first. Mirrors `collectAssetPaths`
/// in `functions/`.
Future<List<String>> assetPathsFor(Ref ref, OfflineBundle bundle) async {
  final repository = ref.read(destinationRepositoryProvider);
  final paths = <String>{};

  // Fetch all place documents, segments and exhibits in parallel.
  final places = await Future.wait([
    for (final id in bundle.destinationIds)
      Future.wait<Object?>([
        repository.watchById(id).first,
        repository.watchSegments(id).first,
        repository.watchExhibits(id).first,
      ]),
  ]);

  for (final [
        destination as Destination?,
        segments as List<Segment>,
        exhibits as List<Exhibit>,
      ]
      in places) {
    if (destination == null) continue;
    paths.addAll(destination.images.where((p) => p.isNotEmpty));
    for (final segment in segments) {
      final audio = segment.audioUrl;
      if (audio != null && audio.isNotEmpty) paths.add(audio);
    }
    // The AR scanner's markers and the exhibits' narration (D-18), so a
    // downloaded museum can be scanned with no signal.
    for (final exhibit in exhibits) {
      if (exhibit.markerPath.isNotEmpty) paths.add(exhibit.markerPath);
      final audio = exhibit.audioUrl;
      if (audio != null && audio.isNotEmpty) paths.add(audio);
    }
  }

  // Sorted so a download fetches objects in a stable order, which makes a
  // progress log comparable between runs.
  return paths.toList()..sort();
}

/// How each town on this device compares to its manifest.
@riverpod
Map<String, TownState> townStates(Ref ref) {
  final bundles = ref.watch(offlineBundlesProvider).value ?? const [];
  final store = ref.watch(downloadStoreProvider);
  return {
    for (final bundle in bundles)
      bundle.townId: townStateFor(bundle, store.recordFor(bundle.townId)),
  };
}

/// How many towns are on this phone, current or not: the count Profile and
/// Settings show on the way to Offline.
@riverpod
int townsOnPhone(Ref ref) {
  // Manifest availability must not erase the count of files on this phone.
  ref.watch(townStatesProvider);
  return ref.watch(downloadStoreProvider).all.length;
}

/// The pack for a town that is downloaded and current, if there is one.
///
/// Returns null for a stale town on purpose. Serving last month's map because
/// it happens to be on disk is how an offline feature quietly starts lying;
/// the download screen should say it is out of date instead.
File? currentPackFor(DownloadStore store, OfflineBundle bundle) {
  final record = store.recordFor(bundle.townId);
  if (record == null || record.version != bundle.version) return null;
  final file = File(record.packPath);
  return file.existsSync() ? file : null;
}
