import "package:path_provider/path_provider.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "../../../core/models/exhibit.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../offline/domain/local_assets.dart";
import "../../offline/domain/offline_providers.dart";
import "../data/channel_exhibit_scanner.dart";
import "../data/marker_cache.dart";
import "exhibit_scanner.dart";

part "ar_providers.g.dart";

/// The camera side of the AR pilot (D-18). A fake in every widget test.
@Riverpod(keepAlive: true)
ExhibitScanner exhibitScanner(Ref ref) => const ChannelExhibitScanner();

/// Asked once a run: a phone does not gain or lose ARCore support between
/// two museums, and the answer is what decides whether a museum's page
/// offers the camera at all.
@Riverpod(keepAlive: true)
Future<ArSupport> arSupport(Ref ref) =>
    ref.watch(exhibitScannerProvider).support();

/// A museum's AR exhibits, in order. From the cache first, like every read.
@riverpod
Stream<List<Exhibit>> destinationExhibits(Ref ref, String id) =>
    ref.watch(destinationRepositoryProvider).watchExhibits(id);

/// Turns a marker's Storage path into a file on this phone, or null when it
/// is not here and cannot be fetched. A function, as `audioUrlResolver` is,
/// so a test substitutes one line.
typedef MarkerFileResolver = Future<String?> Function(String storagePath);

@Riverpod(keepAlive: true)
MarkerFileResolver markerFileResolver(Ref ref) {
  final cache = MarkerCache(
    cacheRoot: getApplicationCacheDirectory,
    fetch: (path) => ref.read(assetFetcherProvider).fetch(path),
    downloaded: (path) {
      // Nothing downloaded, nothing to look up — and `downloadRoot`, which
      // throws until `main()` supplies it, is never read.
      final store = ref.read(downloadStoreProvider);
      if (store.all.isEmpty) return null;
      return localAssetFor(store, ref.read(townDownloaderProvider), path);
    },
  );
  return (path) async => (await cache.fileFor(path))?.path;
}

/// What the scan screen looks for among [exhibits]: each one with a marker of
/// a known size whose image is on this phone, in the exhibits' order.
///
/// An exhibit whose image is missing is left out rather than failing the
/// scan; the rest can still be found, and the list has them all.
Future<List<ScanMarker>> scanMarkersFor(
  List<Exhibit> exhibits,
  MarkerFileResolver resolve,
) async {
  final scannable = exhibits.where((e) => e.isScannable).toList();
  final files = await Future.wait([
    for (final exhibit in scannable) resolve(exhibit.markerPath),
  ]);
  return [
    for (final (index, exhibit) in scannable.indexed)
      if (files[index] case final path?)
        ScanMarker(
          exhibitId: exhibit.id,
          filePath: path,
          widthM: exhibit.markerWidthM,
          title: exhibit.title,
          description: exhibit.description,
        ),
  ];
}

/// An exhibit's narration as the audio guide plays it: a stop of its own,
/// on its own queue, so nothing plays after it. The id is prefixed so it
/// can never be mistaken for one of the guide's stops.
Segment exhibitNarration(Exhibit exhibit) => Segment(
  id: "exhibit:${exhibit.id}",
  title: exhibit.title,
  order: exhibit.order,
  audioUrl: exhibit.audioUrl,
  ttsText: exhibit.ttsText,
);
