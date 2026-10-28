import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:lakbayan/core/models/exhibit.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/ar/domain/ar_providers.dart";
import "package:lakbayan/features/ar/domain/exhibit_scanner.dart";
import "package:lakbayan/features/ar/presentation/exhibits_screen.dart";
import "package:lakbayan/features/audio/domain/audio_providers.dart";
import "package:lakbayan/features/audio/domain/narration.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/presentation/destination_detail_screen.dart";

import "../../support/fake_destination_repository.dart";
import "../../support/fake_exhibit_scanner.dart";
import "../../support/fake_narrator.dart";

/// A museum's exhibits on its page (D-18), with a fake in place of the
/// native scan screen: what the camera's answer leads to, and that every
/// way the camera can fail still ends at the exhibits.
void main() {
  late FakeExhibitScanner scanner;
  late FakeNarrator narrator;

  setUp(() {
    scanner = FakeExhibitScanner();
    narrator = FakeNarrator();
  });

  const bell = Exhibit(
    id: "e1",
    title: "The bell",
    order: 1,
    markerPath: "ar/museum/markers/e1-1.webp",
    markerWidthM: 0.3,
    description: "Cast in Manila in 1890.",
    story: "It hung in the old church.\n\nIt rang for the town's founding.",
    ttsText: "It hung in the old church.",
  );
  const stone = Exhibit(
    id: "e2",
    title: "The founding stone",
    order: 2,
    markerPath: "ar/museum/markers/e2-1.webp",
    markerWidthM: 0.4,
  );

  Future<void> pump(
    WidgetTester tester, {
    bool hasAR = true,
    List<Exhibit> exhibits = const [bell, stone],
    MarkerFileResolver? markers,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeDestinationRepository(
      [
        testDestination(
          id: "museum",
          name: "Cagayan Museum",
          town: "Tuguegarao City",
          hasAR: hasAR,
        ),
      ],
      exhibits: {"museum": exhibits},
    );
    final router = GoRouter(
      initialLocation: "/destination/museum",
      routes: [
        GoRoute(
          path: "/destination/:id/exhibits",
          builder: (context, state) => ExhibitsScreen(
            destinationId: state.pathParameters["id"]!,
            why:
                ExhibitsWhy.values
                    .asNameMap()[state.uri.queryParameters["why"]] ??
                ExhibitsWhy.browse,
          ),
        ),
        GoRoute(
          path: "/destination/:id",
          builder: (context, state) => Scaffold(
            body: DestinationDetailScreen(id: state.pathParameters["id"]!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationRepositoryProvider.overrideWithValue(repo),
          exhibitScannerProvider.overrideWithValue(scanner),
          narratorProvider.overrideWithValue(narrator),
          markerFileResolverProvider.overrideWithValue(
            markers ?? (path) async => "/cache/$path",
          ),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets("a place without AR has no exhibits section", (tester) async {
    await pump(tester, hasAR: false);

    expect(find.text("Cagayan Museum"), findsWidgets);
    expect(find.text("Exhibits"), findsNothing);
    expect(find.text("Scan an exhibit"), findsNothing);
  });

  testWidgets("a museum with no exhibits yet shows none", (tester) async {
    await pump(tester, exhibits: const []);

    expect(find.text("Exhibits"), findsNothing);
  });

  group("on a phone that scans", () {
    testWidgets("a recognised exhibit opens its story, and Listen narrates", (
      tester,
    ) async {
      scanner.outcome = const ExhibitRecognised("e1");
      await pump(tester);

      await tapButton(tester, "Scan an exhibit");

      // The scan screen was given the museum and both markers, as files.
      expect(scanner.lastPlaceName, "Cagayan Museum");
      expect(scanner.scans.single.map((m) => m.filePath), [
        "/cache/ar/museum/markers/e1-1.webp",
        "/cache/ar/museum/markers/e2-1.webp",
      ]);
      expect(scanner.scans.single.first.title, "The bell");

      // The sheet: its line and both paragraphs of the story.
      expect(find.text("The bell"), findsOneWidget);
      expect(find.text("Cast in Manila in 1890."), findsOneWidget);
      expect(find.text("It rang for the town's founding."), findsOneWidget);

      await tester.tap(find.text("Listen"));
      await tester.pump();
      expect(narrator.played.single, isA<SpokenNarration>());
      expect(find.text("Pause"), findsOneWidget);
    });

    testWidgets("closing the camera stays on the page", (tester) async {
      await pump(tester);

      await tapButton(tester, "Scan an exhibit");

      expect(scanner.scans, hasLength(1));
      expect(find.byType(ExhibitsScreen), findsNothing);
      expect(find.text("Scan an exhibit"), findsOneWidget);
    });

    testWidgets("See all lists every exhibit, and a row opens it", (
      tester,
    ) async {
      await pump(tester);

      await tapButton(tester, "See All");

      expect(find.byType(ExhibitsScreen), findsOneWidget);
      expect(find.text("The founding stone"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey("exhibit-e1")));
      await tester.pumpAndSettle();
      expect(find.text("It hung in the old church."), findsOneWidget);
    });

    testWidgets("a refused camera lands on the list, saying why", (
      tester,
    ) async {
      scanner.outcome = const ScanUnavailable(ScanProblem.cameraDenied);
      await pump(tester);

      await tapButton(tester, "Scan an exhibit");

      expect(find.byType(ExhibitsScreen), findsOneWidget);
      expect(find.textContaining("can't use the camera"), findsOneWidget);
      expect(find.text("The bell"), findsOneWidget);
    });

    testWidgets("markers not on the phone: the list, and no camera", (
      tester,
    ) async {
      await pump(tester, markers: (_) async => null);

      await tapButton(tester, "Scan an exhibit");

      expect(scanner.scans, isEmpty);
      expect(find.byType(ExhibitsScreen), findsOneWidget);
      expect(find.textContaining("Download Tuguegarao City"), findsOneWidget);
    });

    testWidgets("scans for the exhibits whose photos it has", (tester) async {
      await pump(
        tester,
        markers: (path) async => path.contains("e2") ? "/cache/$path" : null,
      );

      await tapButton(tester, "Scan an exhibit");

      expect(scanner.scans.single.map((m) => m.exhibitId), ["e2"]);
    });
  });

  testWidgets("a phone that cannot scan gets the exhibits as a list", (
    tester,
  ) async {
    scanner.supports = ArSupport.unsupported;
    await pump(tester);

    expect(find.text("Scan an exhibit"), findsNothing);
    expect(find.text("2 exhibits, each with its story."), findsOneWidget);

    await tapButton(tester, "See the exhibits");

    expect(find.byType(ExhibitsScreen), findsOneWidget);
    // Chosen, not a failure: no note above the list.
    expect(find.textContaining("as a list"), findsNothing);
    expect(scanner.scans, isEmpty);
  });
}
