import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/content/page_dots.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/presentation/featured_deck.dart";

import "../../support/fake_destination_repository.dart";

/// Explore's featured places as a deck (D-19): the front card, dealing the
/// next, gathering the deck back after the last, and opening a place.
void main() {
  final featured = [
    testDestination(id: "callao", name: "Callao Cave", popular: true),
    testDestination(id: "palaui", name: "Palaui Island"),
    testDestination(id: "piat", name: "Piat Basilica"),
  ];

  Future<void> pump(WidgetTester tester, List<Destination> places) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: FeaturedDeck(places: places),
            ),
          ),
        ),
        GoRoute(
          path: "/destination/:id",
          builder: (_, state) => Text("Place ${state.pathParameters["id"]}"),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationRepositoryProvider.overrideWithValue(
            FakeDestinationRepository(places),
          ),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  int front(WidgetTester tester) =>
      tester.widget<PageDots>(find.byType(PageDots)).current;

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel("Next featured place"));
    await tester.pumpAndSettle();
  }

  testWidgets("starts on the first place, each card saying what it is", (
    tester,
  ) async {
    await pump(tester, featured);

    expect(front(tester), 0);
    expect(find.text("Callao Cave"), findsOneWidget);
    // The `featured` flag is what puts a place in the deck, so every card
    // carries the tag, the waiting ones too.
    expect(find.text("Popular This Season"), findsNWidgets(featured.length));
  });

  testWidgets("deals the next place, and gathers the deck after the last", (
    tester,
  ) async {
    await pump(tester, featured);

    await next(tester);
    expect(front(tester), 1);
    await next(tester);
    expect(front(tester), 2);
    await next(tester);
    expect(front(tester), 0);
  });

  testWidgets("a swipe deals the next place", (tester) async {
    await pump(tester, featured);

    await tester.fling(find.text("Callao Cave"), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();

    expect(front(tester), 1);
  });

  testWidgets("one place is a card, not a deck to deal", (tester) async {
    await pump(tester, featured.take(1).toList());

    expect(find.text("Callao Cave"), findsOneWidget);
    expect(find.bySemanticsLabel("Next featured place"), findsNothing);
  });

  testWidgets("the front card opens its place", (tester) async {
    await pump(tester, featured);

    await tester.tap(find.text("Callao Cave"));
    await tester.pumpAndSettle();

    expect(find.text("Place callao"), findsOneWidget);
  });
}
