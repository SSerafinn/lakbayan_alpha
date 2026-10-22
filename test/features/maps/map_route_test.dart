import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/maps/domain/directions.dart";
import "package:lakbayan/features/maps/domain/map_route.dart";
import "package:lakbayan/features/maps/domain/tile_source.dart";
import "package:lakbayan/features/maps/presentation/map_screen.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:lakbayan/features/offline/domain/offline_providers.dart";

import "../../support/fake_destination_repository.dart";

const _noTiles = TileSource(
  urlTemplate: "https://tiles.invalid/{z}/{x}/{y}.png",
  attribution: "© OpenStreetMap contributors",
);

Destination _at(String id, {required double lat, required double lng}) =>
    testDestination(id: id, name: id).copyWith(
      coords: GeoPoint2(lat: lat, lng: lng),
    );

final _places = [
  _at("callao", lat: 17.70, lng: 121.80),
  _at("piat", lat: 17.79, lng: 121.48),
  _at("palaui", lat: 18.55, lng: 122.13),
];

void main() {
  /// The Map tab, with a container the test can drive the route through.
  Future<ProviderContainer> pumpTab(
    WidgetTester tester, {
    List<Destination>? places,
  }) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        destinationRepositoryProvider.overrideWithValue(
          FakeDestinationRepository(places ?? _places),
        ),
        tileSourceProvider.overrideWithValue(_noTiles),
        // The map layers downloaded packs over the basemap, which reaches
        // Firestore for the manifest. Left alone it throws in a test and
        // Riverpod schedules a retry, and the pending timer fails the test
        // for a reason that has nothing to do with routes.
        offlineBundlesProvider.overrideWith(
          (ref) => Stream.value(const <OfflineBundle>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: MapScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  Future<void> show(
    WidgetTester tester,
    ProviderContainer container,
    String label,
    List<String> stops,
  ) async {
    container.read(activeMapRouteProvider.notifier).show(label, stops);
    await tester.pump(const Duration(milliseconds: 50));
  }

  group("a route on the map", () {
    testWidgets("draws no line until a route is opened", (tester) async {
      await pumpTab(tester);

      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets("joins the stops in order once one is", (tester) async {
      final container = await pumpTab(tester);
      await show(tester, container, "Caves in a day", ["callao", "piat"]);

      expect(find.byType(PolylineLayer), findsOneWidget);
    });

    testWidgets("numbers the stops, because the order is the route", (
      tester,
    ) async {
      final container = await pumpTab(tester);
      // Deliberately not the order they were listed in: the number has to come
      // from the route, not from the destination list.
      await show(tester, container, "Caves in a day", ["piat", "callao"]);

      expect(find.text("1"), findsOneWidget);
      expect(find.text("2"), findsOneWidget);
      // A screen reader cannot see the line, so the position has to be said
      // rather than drawn.
      expect(find.bySemanticsLabel("Stop 1, piat"), findsOneWidget);
      expect(find.bySemanticsLabel("Stop 2, callao"), findsOneWidget);
    });

    testWidgets("one stop is a place, not a route, so no line is drawn", (
      tester,
    ) async {
      final container = await pumpTab(tester);
      await show(tester, container, "Just Callao", ["callao"]);

      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.text("Just Callao"), findsOneWidget);
    });

    testWidgets("a filter cannot break the line by hiding a stop", (
      tester,
    ) async {
      // The stops are resolved against every destination, not the filtered
      // results. Otherwise picking a category would redraw the trip as a
      // different, shorter trip — silently.
      final container = await pumpTab(
        tester,
        places: [
          testDestination(
            id: "callao",
            category: DestinationCategory.nature,
          ).copyWith(coords: const GeoPoint2(lat: 17.7, lng: 121.8)),
          testDestination(
            id: "piat",
            category: DestinationCategory.church,
          ).copyWith(coords: const GeoPoint2(lat: 17.79, lng: 121.48)),
        ],
      );
      await show(tester, container, "Caves in a day", ["callao", "piat"]);
      expect(find.byType(PolylineLayer), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, "Churches"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byType(PolylineLayer),
        findsOneWidget,
        reason: "the route is the trip, not whatever survived the chips",
      );
    });
  });

  group("the route banner", () {
    testWidgets("names the route; its numbered pins say the rest", (
      tester,
    ) async {
      final container = await pumpTab(tester);
      await show(tester, container, "Caves in a day", ["callao", "piat"]);

      expect(find.text("Caves in a day"), findsOneWidget);
    });

    testWidgets("dismissing it clears the route", (tester) async {
      final container = await pumpTab(tester);
      await show(tester, container, "Caves in a day", ["callao", "piat"]);

      await tester.tap(find.byTooltip("Stop showing this route"));
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(activeMapRouteProvider), isNull);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.text("Caves in a day"), findsNothing);
    });

    testWidgets("a tap on the basemap does not throw the route away", (
      tester,
    ) async {
      // Panning and tapping happen constantly while reading a route. Losing
      // the trip to one of them would be its own small betrayal — only the
      // banner's dismiss clears it.
      final container = await pumpTab(tester);
      await show(tester, container, "Caves in a day", ["callao", "piat"]);

      await tester.tapAt(const Offset(20, 300));
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(activeMapRouteProvider), isNotNull);
      expect(find.byType(PolylineLayer), findsOneWidget);
    });
  });

  group("the directions hand-off", () {
    test("asks for a marked destination, not just a centred map", () {
      // A bare `geo:lat,lng` centres a map on the coordinate and marks
      // nothing, leaving no destination to ask directions to. The `q` is what
      // makes it somewhere you can be taken.
      final uri = directionsUri(lat: 17.7, lng: 121.8, label: "Callao Cave");

      expect(uri.scheme, "geo");
      expect(uri.path, "17.7,121.8");
      expect(uri.queryParameters["q"], "17.7,121.8(Callao Cave)");
    });

    test("encodes a label containing the separator", () {
      // "Basilica Minore, Piat" carries a comma, and a comma separates the
      // coordinates inside `q`. Built through Uri so it is escaped rather
      // than parsed as another field.
      final uri = directionsUri(
        lat: 17.79,
        lng: 121.48,
        label: "Basilica Minore, Piat",
      );

      expect(uri.queryParameters["q"], "17.79,121.48(Basilica Minore, Piat)");
      expect(uri.toString(), isNot(contains("(Basilica Minore, Piat)")));
    });

    test("falls back to a web map a browser can open", () {
      final uri = directionsWebUri(lat: 17.7, lng: 121.8);

      expect(uri.scheme, "https");
      expect(uri.queryParameters["destination"], "17.7,121.8");
    });
  });
}
