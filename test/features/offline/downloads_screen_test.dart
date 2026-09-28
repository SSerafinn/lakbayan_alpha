import "dart:io";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/offline/data/asset_fetcher.dart";
import "package:lakbayan/features/offline/data/bundle_repository.dart";
import "package:lakbayan/features/offline/data/download_store.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:lakbayan/features/offline/domain/offline_providers.dart";
import "package:lakbayan/features/offline/presentation/downloads_screen.dart";

import "../../support/fake_destination_repository.dart";

import "package:lakbayan/features/destinations/domain/destination_providers.dart";

class FakeBundleRepository implements BundleRepository {
  FakeBundleRepository(this.bundles);

  final List<OfflineBundle> bundles;

  @override
  Stream<List<OfflineBundle>> watchAll() => Stream.value(bundles);

  @override
  Stream<OfflineBundle?> watchById(String townId) =>
      Stream.value(bundles.where((b) => b.townId == townId).firstOrNull);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFetcher implements AssetFetcher {
  String? failOn;

  @override
  Future<Uint8List> fetch(String storagePath) async {
    if (storagePath == failOn) throw StateError("object-not-found");
    return Uint8List(10);
  }
}

void main() {
  late Directory root;
  late InMemoryDownloadStore store;
  late FakeFetcher fetcher;

  const ready = OfflineBundle(
    townId: "penablanca",
    name: "Peñablanca",
    tilePackRef: "tiles/penablanca/pack.pmtiles",
    version: "v1",
    destinationIds: ["callao"],
    size: 2 * 1024 * 1024,
    status: BundleStatus.ready,
  );

  const notReady = OfflineBundle(
    townId: "aparri",
    name: "Aparri",
    tilePackRef: "tiles/aparri/pack.pmtiles",
    version: "v1",
    destinationIds: ["aparri-lighthouse"],
    size: 1024,
    status: BundleStatus.pending,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync("lakbayan-dl-screen-");
    store = InMemoryDownloadStore();
    fetcher = FakeFetcher();
    addTearDown(() => root.deleteSync(recursive: true));
  });

  /// Tap something that starts a download, and let it actually finish.
  ///
  /// Two things make this awkward, and both are the code being right rather
  /// than the test fighting it:
  ///
  /// * The downloader writes real files. `testWidgets` runs inside a
  ///   fake-async zone where real I/O futures never complete, so the work has
  ///   to happen inside [WidgetTester.runAsync].
  /// * While it runs, the progress bar is an **indeterminate**
  ///   `LinearProgressIndicator`, which animates forever, so `pumpAndSettle`
  ///   would never return afterwards. Pump a bounded number of frames instead.
  Future<void> tapAndFinish(WidgetTester tester, Finder target) async {
    await tester.runAsync(() async {
      await tester.tap(target);
      // Long enough for a handful of small writes to a temp directory.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    List<OfflineBundle> bundles, {
    Iterable<DownloadRecord> downloaded = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = InMemoryDownloadStore(downloaded);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundleRepositoryProvider.overrideWithValue(
            FakeBundleRepository(bundles),
          ),
          downloadStoreProvider.overrideWithValue(store),
          downloadRootProvider.overrideWithValue(root),
          assetFetcherProvider.overrideWithValue(fetcher),
          destinationRepositoryProvider.overrideWithValue(
            FakeDestinationRepository(
              [testDestination(id: "callao")],
              segments: const {"callao": []},
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const DownloadsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("listing", () {
    testWidgets("shows a town, its size and place count", (tester) async {
      await pump(tester, [ready]);

      expect(find.text("Peñablanca"), findsOneWidget);
      expect(find.textContaining("2.0 MB"), findsOneWidget);
      expect(find.textContaining("1 place"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Download"), findsOneWidget);
    });

    testWidgets("refuses to offer a bundle the province has not finished", (
      tester,
    ) async {
      // `pending` means a file is missing — most often the map pack. Offering
      // it would download a town with no map and no way to say why.
      await pump(tester, [notReady]);

      expect(find.text("NOT READY"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Download"), findsNothing);
      expect(
        find.text("The province is still preparing this town."),
        findsOneWidget,
      );
    });

    testWidgets("says so when no town is ready at all", (tester) async {
      await pump(tester, const []);
      expect(find.textContaining("No towns are ready"), findsOneWidget);
    });
  });

  group("state on this phone", () {
    DownloadRecord recordAt(String version) => DownloadRecord(
      townId: "penablanca",
      version: version,
      bytes: 10,
      completedAt: DateTime(2026),
      packPath: "${root.path}/pack.pmtiles",
    );

    testWidgets("a current town says it is on the phone", (tester) async {
      await pump(tester, [ready], downloaded: [recordAt("v1")]);

      expect(find.text("ON THIS PHONE"), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, "Remove"), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, "Download again"),
        findsOneWidget,
      );
    });

    testWidgets("an edited town offers an update", (tester) async {
      // The province changed something since this phone downloaded it.
      await pump(tester, [ready], downloaded: [recordAt("v0")]);

      expect(find.text("UPDATE AVAILABLE"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Update"), findsOneWidget);
    });
  });

  group("downloading", () {
    testWidgets("a finished download flips the town to on-this-phone", (
      tester,
    ) async {
      await pump(tester, [ready]);

      await tapAndFinish(tester, find.widgetWithText(FilledButton, "Download"));

      expect(store.recordFor("penablanca"), isNotNull);
      expect(find.text("ON THIS PHONE"), findsOneWidget);
    });

    testWidgets("a failure says nothing was kept, and keeps nothing", (
      tester,
    ) async {
      fetcher.failOn = "tiles/penablanca/pack.pmtiles";
      await pump(tester, [ready]);

      await tapAndFinish(tester, find.widgetWithText(FilledButton, "Download"));

      expect(find.textContaining("nothing was kept"), findsOneWidget);
      expect(store.recordFor("penablanca"), isNull);
      // Still offered, because there is nothing half-done to repair.
      expect(find.widgetWithText(FilledButton, "Download"), findsOneWidget);
    });

    testWidgets("removing a town clears it", (tester) async {
      await pump(tester, [ready]);
      await tapAndFinish(tester, find.widgetWithText(FilledButton, "Download"));
      expect(find.text("ON THIS PHONE"), findsOneWidget);

      await tapAndFinish(tester, find.widgetWithText(OutlinedButton, "Remove"));

      expect(store.recordFor("penablanca"), isNull);
      expect(find.text("ON THIS PHONE"), findsNothing);
    });
  });
}
