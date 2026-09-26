import "dart:convert";
import "dart:io";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/content/storage_image.dart";
import "package:lakbayan/features/audio/domain/audio_providers.dart";
import "package:lakbayan/features/offline/data/asset_fetcher.dart";
import "package:lakbayan/features/offline/data/download_store.dart";
import "package:lakbayan/features/offline/data/town_downloader.dart";
import "package:lakbayan/features/offline/domain/local_assets.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:lakbayan/features/offline/domain/offline_providers.dart";

/// A real 1×1 PNG, so `Image.file` has something it can actually decode.
final _png = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
  "+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
);

const _photo = "destinations/callao/images/1.jpg";
const _recording = "destinations/callao/audio/s1.mp3";

void main() {
  late Directory root;
  late InMemoryDownloadStore store;
  late TownDownloader downloader;

  setUp(() {
    root = Directory.systemTemp.createTempSync("lakbayan-local-assets-");
    store = InMemoryDownloadStore();
    downloader = TownDownloader(
      // Never called: nothing here downloads anything, it only reads what a
      // download would have left behind.
      fetcher: const StorageAssetFetcher(),
      root: root,
      store: store,
    );
    addTearDown(() => root.deleteSync(recursive: true));
  });

  /// Record [townId] as downloaded and put [paths] on disk where the downloader
  /// would have written them.
  void downloadedTown(String townId, List<String> paths, {List<int>? bytes}) {
    store.save(
      DownloadRecord(
        townId: townId,
        version: "v1",
        bytes: 0,
        completedAt: DateTime(2026),
        packPath: downloader.localPathFor(townId, "tiles/$townId/pack.pmtiles"),
      ),
    );
    for (final path in paths) {
      final file = File(downloader.localPathFor(townId, path));
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes ?? _png);
    }
  }

  group("finding a downloaded object", () {
    test("returns the file the download wrote", () {
      downloadedTown("penablanca", [_photo]);

      final found = localAssetFor(store, downloader, _photo);

      expect(found, isNotNull);
      expect(found!.existsSync(), isTrue);
      expect(found.path, downloader.localPathFor("penablanca", _photo));
    });

    test("returns null for an object that town did not include", () {
      downloadedTown("penablanca", [_photo]);

      expect(
        localAssetFor(store, downloader, "destinations/palaui/images/9.jpg"),
        isNull,
      );
    });

    test("returns null when nothing has been downloaded", () {
      expect(localAssetFor(store, downloader, _photo), isNull);
    });

    test("searches every downloaded town, not just the first", () {
      // A Storage path says which *destination* an object belongs to, never
      // which town, so the answer can only be found by asking each of them.
      downloadedTown("aparri", ["destinations/lighthouse/images/1.jpg"]);
      downloadedTown("penablanca", [_photo]);

      expect(
        localAssetFor(store, downloader, _photo)?.path,
        downloader.localPathFor("penablanca", _photo),
      );
    });

    test("a record whose files are gone reads as not downloaded", () {
      // `remove` drops the record before the directory, but a phone can lose a
      // directory on its own. Claiming a file that is not there would hand a
      // broken path to the image decoder instead of falling back.
      downloadedTown("penablanca", [_photo]);
      Directory(downloader.townDirectory("penablanca").path)
          .deleteSync(recursive: true);

      expect(localAssetFor(store, downloader, _photo), isNull);
    });
  });

  group("the audio resolver", () {
    test("plays a downloaded recording off disk, as a file URI", () async {
      downloadedTown("penablanca", [_recording]);

      final container = ProviderContainer(
        overrides: [
          downloadStoreProvider.overrideWithValue(store),
          downloadRootProvider.overrideWithValue(root),
        ],
      );
      addTearDown(container.dispose);

      final url = await container.read(audioUrlResolverProvider)(_recording);

      // A `file://` URI rather than a bare path: just_audio parses what it is
      // handed, and a Windows drive letter would not survive otherwise. That
      // this returned at all is the point — the Storage branch would have
      // thrown, because Firebase is not initialised in a test.
      expect(url, startsWith("file://"));
      expect(
        File.fromUri(Uri.parse(url)).path,
        downloader.localPathFor("penablanca", _recording),
      );
    });
  });

  group("StorageImage", () {
    testWidgets("draws a downloaded photo from disk, not from the network", (
      tester,
    ) async {
      downloadedTown("penablanca", [_photo]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadStoreProvider.overrideWithValue(store),
            downloadRootProvider.overrideWithValue(root),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: StorageImage(path: _photo)),
          ),
        ),
      );
      await tester.pump();

      // No `CachedNetworkImage`, and so no `getDownloadURL` round trip: in a
      // cave neither would ever resolve, which is the whole point of having
      // downloaded the town.
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
