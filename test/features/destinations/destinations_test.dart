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
        child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: screen)),
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

    testWidgets("keeps the build-a-tour hero even with no content",
        (tester) async {
      // The wireframe is explicit that the hero is never dismissible.
      await pump(
        tester,
        const ExploreScreen(),
        repo: FakeDestinationRepository([]),
      );

      expect(find.text("Create your own tour"), findsOneWidget);
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

      await tester.tap(find.widgetWithText(FilterChip, "Churches"));
      await tester.pumpAndSettle();

      expect(find.text("Piat Basilica"), findsOneWidget);
      expect(find.text("Callao Cave"), findsNothing);
    });

    testWidgets("search filters in place, after the debounce", (tester) async {
      final repo = FakeDestinationRepository([
        testDestination(id: "callao", name: "Callao Cave"),
        testDestination(id: "palaui", name: "Palaui Island"),
      ]);

      await pump(tester, const BrowseScreen(), repo: repo);

      await tester.enterText(find.byType(TextField), "palaui");
      // Typing alone must not filter — the wireframe calls for a debounce.
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
      await tester.enterText(find.byType(TextField), "zzzz");
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text("No matches"), findsOneWidget);
      expect(find.text("Clear filters"), findsOneWidget);
    });
  });

  group("Destination detail", () {
    testWidgets("renders the destination and its audio segments",
        (tester) async {
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
      expect(find.text("1 · History"), findsOneWidget);
      expect(find.text("2 · The Chapel"), findsOneWidget);
    });

    testWidgets("handles a destination that is gone or unpublished",
        (tester) async {
      // Unpublishing in the CMS makes a document unreadable to the app, so a
      // deep link to it must degrade rather than hang or crash.
      final repo = FakeDestinationRepository([
        testDestination(
          id: "hidden",
          status: DestinationStatus.draft,
        ),
      ]);

      await pump(
        tester,
        const DestinationDetailScreen(id: "hidden"),
        repo: repo,
      );

      expect(
        find.textContaining("no longer available"),
        findsOneWidget,
      );
    });
  });
}
