import "dart:io";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/features/offline/data/asset_fetcher.dart";
import "package:lakbayan/features/offline/data/download_store.dart";
import "package:lakbayan/features/offline/data/town_downloader.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:path/path.dart" as p;

/// Serves bytes from a map, and can be told to fail on one path.
class FakeFetcher implements AssetFetcher {
  FakeFetcher(this.objects);

  final Map<String, int> objects;
  final fetched = <String>[];

  /// Path that throws when asked for, to exercise a mid-download failure.
  String? failOn;

  /// Called before each fetch, so a test can cancel partway.
  void Function(String path)? onFetch;

  @override
  Future<Uint8List> fetch(String storagePath) async {
    onFetch?.call(storagePath);
    if (storagePath == failOn) throw StateError("object-not-found");
    final size = objects[storagePath];
    if (size == null) throw StateError("no such object: $storagePath");
    fetched.add(storagePath);
    return Uint8List(size);
  }
}

void main() {
  late Directory root;
  late InMemoryDownloadStore store;
  late FakeFetcher fetcher;
  late TownDownloader downloader;

  const bundle = OfflineBundle(
    townId: "penablanca",
    name: "Peñablanca",
    tilePackRef: "tiles/penablanca/pack.pmtiles",
    version: "v1",
    destinationIds: ["callao"],
    size: 600,
    status: BundleStatus.ready,
  );

  const assets = [
    "destinations/callao/images/1.jpg",
    "destinations/callao/audio/s1.mp3",
  ];

  setUp(() {
    root = Directory.systemTemp.createTempSync("lakbayan-offline-");
    store = InMemoryDownloadStore();
    fetcher = FakeFetcher({
      "destinations/callao/images/1.jpg": 100,
      "destinations/callao/audio/s1.mp3": 200,
      "tiles/penablanca/pack.pmtiles": 300,
    });
    downloader = TownDownloader(fetcher: fetcher, root: root, store: store);
    addTearDown(() => root.deleteSync(recursive: true));
  });

  File localFile(String storagePath) => File(
    p.join(
      root.path,
      "offline",
      "penablanca",
      p.joinAll(p.posix.split(storagePath)),
    ),
  );

  Directory staging() =>
      Directory(p.join(root.path, "offline", "penablanca.partial"));

  group("a successful download", () {
    test("fetches every asset and the map pack", () async {
      await downloader.download(bundle, assetPaths: assets);

      expect(fetcher.fetched, containsAll(assets));
      expect(fetcher.fetched, contains(bundle.tilePackRef));
      for (final path in [...assets, bundle.tilePackRef]) {
        expect(localFile(path).existsSync(), isTrue, reason: path);
      }
    });

    test("mirrors Storage paths, so the pack lands at its tilePackRef", () {
      // The map layer reads the pack straight from this path. Hashing names
      // would work too, and would need a lookup table nobody would maintain.
      expect(
        downloader.localPathFor("penablanca", bundle.tilePackRef),
        endsWith(p.join("penablanca", "tiles", "penablanca", "pack.pmtiles")),
      );
    });

    test("records the version it downloaded, and the total bytes", () async {
      final record = await downloader.download(bundle, assetPaths: assets);

      expect(record.version, "v1");
      expect(record.bytes, 600);
      expect(store.recordFor("penablanca"), isNotNull);
      expect(File(record.packPath).existsSync(), isTrue);
    });

    test("leaves no staging directory behind", () async {
      await downloader.download(bundle, assetPaths: assets);
      expect(staging().existsSync(), isFalse);
    });

    test("de-duplicates an asset two destinations share", () async {
      await downloader.download(bundle, assetPaths: [...assets, assets.first]);
      // Paying twice for one object wastes somebody's data allowance.
      expect(fetcher.fetched.where((f) => f == assets.first).length, 1);
    });

    test("reports progress that ends complete", () async {
      final seen = <DownloadProgress>[];
      await downloader.download(
        bundle,
        assetPaths: assets,
        onProgress: seen.add,
      );

      expect(seen.first.fraction, 0);
      expect(seen.last.fraction, 1);
      expect(seen.last.filesDone, 3);
      expect(seen.last.bytesDone, 600);
    });
  });

  group("a download that does not finish", () {
    test("records nothing when an object is missing", () async {
      fetcher.failOn = "destinations/callao/audio/s1.mp3";

      await expectLater(
        downloader.download(bundle, assetPaths: assets),
        throwsA(isA<StateError>()),
      );

      // The whole promise of a bundle is that nothing is fetched later. A
      // half-downloaded town recorded as present would break that silently.
      expect(store.recordFor("penablanca"), isNull);
      expect(downloader.townDirectory("penablanca").existsSync(), isFalse);
      expect(staging().existsSync(), isFalse);
    });

    test("records nothing when cancelled", () async {
      final cancel = CancelToken();
      fetcher.onFetch = (_) => cancel.cancel();

      await expectLater(
        downloader.download(bundle, assetPaths: assets, cancel: cancel),
        throwsA(isA<DownloadCancelled>()),
      );

      expect(store.recordFor("penablanca"), isNull);
      expect(staging().existsSync(), isFalse);
    });

    test("does not resume a previous attempt's leftovers", () async {
      // A stale .partial cannot be trusted: there is no way to tell which of
      // its files came from which version of the bundle.
      final stale = File(p.join(staging().path, "junk.bin"))
        ..createSync(recursive: true)
        ..writeAsBytesSync(Uint8List(9));

      await downloader.download(bundle, assetPaths: assets);

      expect(stale.existsSync(), isFalse);
      expect(
        File(p.join(root.path, "offline", "penablanca", "junk.bin"))
            .existsSync(),
        isFalse,
      );
    });

    test("keeps the old town when a re-download fails", () async {
      await downloader.download(bundle, assetPaths: assets);
      expect(store.recordFor("penablanca"), isNotNull);

      fetcher.failOn = assets.first;
      await expectLater(
        downloader.download(bundle.copyWith(version: "v2"), assetPaths: assets),
        throwsA(isA<StateError>()),
      );

      // The failure happened in staging, so what was already on disk is
      // untouched and still usable offline.
      expect(store.recordFor("penablanca")!.version, "v1");
      expect(localFile(bundle.tilePackRef).existsSync(), isTrue);
    });
  });

  group("re-downloading", () {
    test("replaces the town and moves the recorded version", () async {
      await downloader.download(bundle, assetPaths: assets);
      final second = await downloader.download(
        bundle.copyWith(version: "v2"),
        assetPaths: assets,
      );

      expect(second.version, "v2");
      expect(store.recordFor("penablanca")!.version, "v2");
      expect(localFile(bundle.tilePackRef).existsSync(), isTrue);
    });
  });

  group("delete", () {
    test("removes the record and the files", () async {
      await downloader.download(bundle, assetPaths: assets);
      await downloader.delete("penablanca");

      expect(store.recordFor("penablanca"), isNull);
      expect(downloader.townDirectory("penablanca").existsSync(), isFalse);
    });

    test("is harmless on a town that was never downloaded", () async {
      await expectLater(downloader.delete("aparri"), completes);
    });
  });

  group("staleness", () {
    test("absent, current and stale are distinguished", () {
      expect(townStateFor(bundle, null), TownState.absent);

      final record = DownloadRecord(
        townId: "penablanca",
        version: "v1",
        bytes: 600,
        completedAt: DateTime(2026),
        packPath: "/tmp/pack.pmtiles",
      );
      expect(townStateFor(bundle, record), TownState.current);
      expect(
        townStateFor(bundle.copyWith(version: "v2"), record),
        TownState.stale,
      );
    });
  });

  group("the bundle model", () {
    test("only a ready bundle is offered as a download", () {
      expect(bundle.isDownloadable, isTrue);
      expect(
        bundle.copyWith(status: BundleStatus.pending).isDownloadable,
        isFalse,
      );
    });

    test("an unfamiliar status falls back rather than throwing", () {
      // A newer build may write a status this one has never heard of, and an
      // offline-first app has to read documents it does not fully understand.
      final decoded = OfflineBundle.fromJson({
        "townId": "aparri",
        "name": "Aparri",
        "tilePackRef": "tiles/aparri/pack.pmtiles",
        "version": "v9",
        "status": "archived",
      });
      expect(decoded.status, BundleStatus.unknown);
      expect(decoded.isDownloadable, isFalse);
    });
  });
}
