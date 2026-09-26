import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/presentation/browse_screen.dart";
import "package:lakbayan/features/destinations/presentation/destination_detail_screen.dart";
import "package:lakbayan/features/destinations/presentation/explore_screen.dart";

import "../../support/fake_destination_repository.dart";

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required FakeDestinationRepository repo,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("Explore", () {
    testWidgets("shows popular destinations", (tester) async {
      final repo = FakeDestinationRepository([
        testDestination(id: "callao", name: "Callao Cave", popular: true),
        testDestination(id: "palaui", name: "Palaui Island", featured: true),
        testDestination(id: "buntun", name: "Buntun Bridge"),
      ]);

      await pump(tester, const ExploreScreen(), repo: repo);

      expect(find.text("Callao Cave"), findsOneWidget);
      // Not popular and not featured, so it belongs in neither rail.
      expect(find.text("Buntun Bridge"), findsNothing);
    });

    testWidgets("keeps its frame even with no content", (tester) async {
      // With nothing published the screen still has to say where things
      // will go, rather than paint a blank scroll. The swipe entry is the one
      // block that hides: it fans real covers and has none to show.
      await pump(
        tester,
        const ExploreScreen(),
        repo: FakeDestinationRepository([]),
      );

      expect(find.text("Popular this week"), findsOneWidget);
      expect(find.text("Nothing here yet."), findsOneWidget);
      // Rows of photos hide when they have nothing to show (D-16).
      expect(find.text("Towns"), findsNothing);
      expect(find.text("Not sure where to go?"), findsNothing);
    });
  });

  group("Browse", () {
    testWidgets("filters by category", (tester) async {
      final repo = FakeDestinationRepository([
        testDestination(
          id: "callao",
          name: "Callao Cave",
          category: DestinationCategory.nature,
        ),
        testDestination(
          id: "piat",
          name: "Piat Basilica",
          category: DestinationCategory.church,
        ),
      ]);

      await pump(tester, const BrowseScreen(), repo: repo);
      expect(find.text("Callao Cave"), findsOneWidget);
      expect(find.text("Piat Basilica"), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, "Churches"));
      await tester.pumpAndSettle();

      expect(find.text("Piat Basilica"), findsOneWidget);
      expect(find.text("Callao Cave"), findsNothing);
    });

    // Browse has no search field of its own since D-16: a town picked on
    // Explore or in search arrives as the filter, shown as a clearable chip.
    testWidgets("a town picked elsewhere filters in place", (tester) async {
      final repo = FakeDestinationRepository([
        testDestination(id: "callao", name: "Callao Cave"),
        testDestination(id: "palaui", name: "Palaui Island"),
      ]);

      await pump(tester, const BrowseScreen(), repo: repo);
      ProviderScope.containerOf(tester.element(find.byType(BrowseScreen)))
          .read(browseQueryProvider.notifier)
          .update("palaui");
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text("Palaui Island"), findsOneWidget);
      expect(find.text("Callao Cave"), findsNothing);
    });

    testWidgets("offers a way out of an empty filtered state", (tester) async {
      final repo = FakeDestinationRepository([
        testDestination(id: "callao", name: "Callao Cave"),
      ]);

      await pump(tester, const BrowseScreen(), repo: repo);
      ProviderScope.containerOf(tester.element(find.byType(BrowseScreen)))
          .read(browseQueryProvider.notifier)
          .update("zzzz");
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text("No matches"), findsOneWidget);
      expect(find.text("Clear filters"), findsOneWidget);
    });
  });

  group("malformed documents", () {
    test("a bad row is skipped instead of failing the whole list", () {
      // Regression: a seeding script left a published document with no
      // `category` or `coords`. Because the snapshot was mapped eagerly, that
      // single row threw and Explore rendered empty — the user's own content
      // was fine and simply never appeared.
      final decoded = <Destination>[];
      for (final raw in [
        {
          "id": "good",
          "name": "Callao Cave",
          "town": "Peñablanca",
          "category": "nature",
          "description": "Seven chambers.",
          "coords": {"lat": 17.7, "lng": 121.8},
          "status": "published",
        },
        // Missing category, description and coords — all required.
        {"id": "bad", "name": "Half-written", "status": "published"},
      ]) {
        try {
          decoded.add(Destination.fromJson(raw));
        } catch (_) {
          // The repository's _decodeAll does exactly this, with a log.
        }
      }

      expect(decoded, hasLength(1));
      expect(decoded.single.name, "Callao Cave");
    });

    test("an unrecognised category falls back rather than throwing", () {
      // A newer client may write a category this build has never heard of.
      final d = Destination.fromJson({
        "id": "x",
        "name": "Somewhere New",
        "town": "Aparri",
        "category": "waterfall",
        "description": "Written by a newer client.",
        "coords": {"lat": 18.3, "lng": 121.6},
        "status": "published",
      });

      expect(d.category, DestinationCategory.unknown);
      expect(d.category.label, "Other");
    });
  });

  group("Destination detail", () {
    testWidgets("renders the destination and its audio segments", (
      tester,
    ) async {
      final repo = FakeDestinationRepository(
        [testDestination(id: "callao", name: "Callao Cave")],
        segments: {
          "callao": const [
            Segment(id: "s1", title: "History", order: 1),
            Segment(id: "s2", title: "The Chapel", order: 2),
          ],
        },
      );

      await pump(
        tester,
        const DestinationDetailScreen(id: "callao"),
        repo: repo,
      );

      expect(find.text("Callao Cave"), findsOneWidget);
      // The guide rests as one bar; opened, it lists the stops in visiting
      // order (D-16).
      await tester.ensureVisible(find.text("Audio guide"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Audio guide"));
      await tester.pumpAndSettle();
      expect(find.text("History"), findsOneWidget);
      expect(find.text("The Chapel"), findsOneWidget);
      expect(
        tester.getTopLeft(find.text("History")).dy,
        lessThan(tester.getTopLeft(find.text("The Chapel")).dy),
      );
    });

    testWidgets("handles a destination that is gone or unpublished", (
      tester,
    ) async {
      // Unpublishing in the CMS makes a document unreadable to the app, so a
      // deep link to it must degrade rather than hang or crash.
      final repo = FakeDestinationRepository([
        testDestination(id: "hidden", status: DestinationStatus.draft),
      ]);

      await pump(
        tester,
        const DestinationDetailScreen(id: "hidden"),
        repo: repo,
      );

      expect(find.textContaining("no longer available"), findsOneWidget);
    });
  });
}
