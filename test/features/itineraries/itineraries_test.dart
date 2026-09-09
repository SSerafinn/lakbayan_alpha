import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/itinerary.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/itineraries/domain/itinerary_providers.dart";
import "package:lakbayan/features/itineraries/presentation/itineraries_tab.dart";
import "package:lakbayan/features/itineraries/presentation/itinerary_screen.dart";

import "../../support/fake_auth_repository.dart";
import "../../support/fake_destination_repository.dart";
import "../../support/fake_itinerary_repository.dart";

void main() {
  const ana = AppUser(uid: "ana", email: "ana@example.com");

  late FakeItineraryRepository itineraries;
  late FakeTourRepository tours;

  setUp(() {
    itineraries = FakeItineraryRepository();
    tours = FakeTourRepository();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    AppUser? user = ana,
  }) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initialUser: user),
          ),
          itineraryRepositoryProvider.overrideWithValue(itineraries),
          tourRepositoryProvider.overrideWithValue(tours),
          destinationRepositoryProvider.overrideWithValue(
            FakeDestinationRepository([
              testDestination(id: "callao", name: "Callao Cave"),
              testDestination(id: "palaui", name: "Palaui Island"),
            ]),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("the tab", () {
    testWidgets("a guest is told what an account buys, not just refused", (
      tester,
    ) async {
      // Browsing and downloading both work signed out, so a bare "sign in"
      // would read as an arbitrary gate.
      await pump(tester, const Scaffold(body: ItinerariesTab()), user: null);

      expect(find.text("Plans need an account"), findsOneWidget);
      expect(
        find.textContaining("follow you to another phone"),
        findsOneWidget,
      );
      expect(find.textContaining("without signing in"), findsOneWidget);
    });

    testWidgets("shows an empty state that says how to fill it", (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: ItinerariesTab()));

      expect(find.textContaining("Nothing planned yet"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "New"), findsOneWidget);
    });

    testWidgets("lists itineraries with their stop count", (tester) async {
      itineraries = FakeItineraryRepository({
        "ana": [
          const Itinerary(
            id: "it-1",
            name: "Two days in Peñablanca",
            destinationIds: ["callao", "palaui"],
          ),
        ],
      });
      await pump(tester, const Scaffold(body: ItinerariesTab()));

      expect(find.text("Two days in Peñablanca"), findsOneWidget);
      expect(find.textContaining("2 stops"), findsOneWidget);
    });

    testWidgets("nudges a one-stop itinerary, which cannot be a route", (
      tester,
    ) async {
      itineraries = FakeItineraryRepository({
        "ana": [
          const Itinerary(
            id: "it-1",
            name: "Just one",
            destinationIds: ["callao"],
          ),
        ],
      });
      await pump(tester, const Scaffold(body: ItinerariesTab()));

      expect(
        find.textContaining("add one more to draw a route"),
        findsOneWidget,
      );
    });

    testWidgets("separates saved province tours from the user's own", (
      tester,
    ) async {
      // Different collections, and the screen has to say so — `tours` is
      // admin-written, so a visitor's plan could never live there.
      await pump(tester, const Scaffold(body: ItinerariesTab()));

      expect(find.text("My itineraries"), findsOneWidget);
      expect(find.text("Saved tours"), findsOneWidget);
    });
  });

  group("editing one", () {
    Future<void> pumpScreen(WidgetTester tester) =>
        pump(tester, const ItineraryScreen(id: "it-1"));

    setUp(() {
      itineraries = FakeItineraryRepository({
        "ana": [
          const Itinerary(
            id: "it-1",
            name: "Weekend",
            destinationIds: ["callao", "palaui"],
          ),
        ],
      });
    });

    testWidgets("numbers the stops, because the order is the route", (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text("1."), findsOneWidget);
      expect(find.text("2."), findsOneWidget);
      expect(find.text("Callao Cave"), findsOneWidget);
    });

    testWidgets("moving a stop rewrites the whole order", (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip("Move later").first);
      await tester.pumpAndSettle();

      expect(itineraries.forUid("ana").single.destinationIds, [
        "palaui",
        "callao",
      ]);
    });

    testWidgets("the first stop cannot move earlier", (tester) async {
      await pumpScreen(tester);

      final up = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward).first,
      );
      expect(up.onPressed, isNull);
    });

    testWidgets("removing a stop takes it out", (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip("Remove this stop").first);
      await tester.pumpAndSettle();

      expect(itineraries.forUid("ana").single.destinationIds, ["palaui"]);
    });

    testWidgets("a stop that was unpublished says so instead of vanishing", (
      tester,
    ) async {
      // Somebody can add a destination the province later unpublishes. A blank
      // row would look broken and leave no way to remove it.
      itineraries = FakeItineraryRepository({
        "ana": [
          const Itinerary(
            id: "it-1",
            name: "Weekend",
            destinationIds: ["gone"],
          ),
        ],
      });
      await pumpScreen(tester);

      expect(find.text("No longer available"), findsOneWidget);
      expect(find.byTooltip("Remove this stop"), findsOneWidget);
    });

    testWidgets("deleting asks first", (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip("Delete this itinerary"));
      await tester.pumpAndSettle();
      expect(find.text("Delete Weekend?"), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, "Keep it"));
      await tester.pumpAndSettle();
      expect(itineraries.forUid("ana"), hasLength(1));
    });
  });
}
