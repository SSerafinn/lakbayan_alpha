import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/models/itinerary.dart";
import "package:lakbayan/core/theme/app_icons.dart";
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
              // Two points, not one: the route preview fits the map to the
              // stops, and a zero-area fit has no finite zoom.
              testDestination(id: "callao", name: "Callao Cave"),
              testDestination(
                id: "palaui",
                name: "Palaui Island",
                town: "Santa Ana",
                coords: const GeoPoint2(lat: 18.55, lng: 122.15),
              ),
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

      expect(find.text("Plans Need an Account"), findsOneWidget);
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
      // The action is the emerald + beside the title (D-19), not a FAB.
      expect(find.byTooltip("New trip"), findsOneWidget);
    });

    testWidgets("lists itineraries with their dates", (tester) async {
      itineraries = FakeItineraryRepository({
        "ana": [
          Itinerary(
            id: "it-1",
            name: "Two days in Peñablanca",
            destinationIds: const ["callao", "palaui"],
            startDate: DateTime(2026, 10, 14),
            endDate: DateTime(2026, 10, 15),
          ),
        ],
      });
      await pump(tester, const Scaffold(body: ItinerariesTab()));

      expect(find.text("Two days in Peñablanca"), findsOneWidget);
      expect(find.text("Oct 14 to 15"), findsOneWidget);
    });

    testWidgets("puts nothing under a name that has no dates", (tester) async {
      // A stop count under a name is a dangling number and "no dates yet" is
      // a hint dressed as metadata, so an undated trip is just its name.
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

      expect(find.text("Just one"), findsOneWidget);
      expect(find.textContaining("stop"), findsNothing);
    });

    testWidgets("separates saved province tours from the user's own", (
      tester,
    ) async {
      // Different collections, and the screen has to say so — `tours` is
      // admin-written, so a visitor's plan could never live there.
      await pump(tester, const Scaffold(body: ItinerariesTab()));

      expect(find.text("Trips"), findsOneWidget);
      expect(find.text("Saved Tours"), findsOneWidget);
      expect(
        find.textContaining("Tours you save from the province's list"),
        findsOneWidget,
      );
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

    /// The move and remove controls only appear while reordering; at rest
    /// the rows are plain so the list reads as the route, not as a form.
    Future<void> startReordering(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(TextButton, "Reorder"));
      await tester.pumpAndSettle();
    }

    testWidgets("keeps the stops in order, because the order is the route", (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text("Callao Cave"), findsOneWidget);
      expect(find.text("Palaui Island"), findsOneWidget);
      expect(
        tester.getTopLeft(find.text("Callao Cave")).dy,
        lessThan(tester.getTopLeft(find.text("Palaui Island")).dy),
      );
      // Two stops can be reordered; the control is there to say so.
      expect(find.widgetWithText(TextButton, "Reorder"), findsOneWidget);
    });

    testWidgets("moving a stop rewrites the whole order", (tester) async {
      await pumpScreen(tester);
      await startReordering(tester);

      await tester.tap(find.byTooltip("Move later").first);
      await tester.pumpAndSettle();

      expect(itineraries.forUid("ana").single.destinationIds, [
        "palaui",
        "callao",
      ]);
    });

    testWidgets("the first stop cannot move earlier", (tester) async {
      await pumpScreen(tester);
      await startReordering(tester);

      final up = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, AppIcons.chevronUp).first,
      );
      expect(up.onPressed, isNull);
    });

    testWidgets("removing a stop takes it out", (tester) async {
      await pumpScreen(tester);
      await startReordering(tester);

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

      // Delete sits behind the overflow menu, so it is two taps away.
      await tester.tap(find.byTooltip("More"));
      await tester.pumpAndSettle();
      // The menu is `AppMenu`, not a stock `MenuAnchor`, so the item is
      // found by its label.
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();
      expect(find.text("Delete Weekend?"), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, "Keep It"));
      await tester.pumpAndSettle();
      expect(itineraries.forUid("ana"), hasLength(1));
    });
  });
}
