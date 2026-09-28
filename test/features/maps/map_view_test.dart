import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/maps/domain/tile_source.dart";
import "package:lakbayan/features/maps/presentation/map_screen.dart";
import "package:lakbayan/features/maps/presentation/map_view.dart";

import "../../support/fake_destination_repository.dart";

/// A source pointing nowhere.
///
/// `flutter_map` fetches tiles as soon as it lays out, and the test HTTP client
/// fails every request anyway — this makes that explicit rather than incidental,
/// so a future change that starts hitting a real host is a visible one.
const _noTiles = TileSource(
  urlTemplate: "https://tiles.invalid/{z}/{x}/{y}.png",
  attribution: "© OpenStreetMap contributors",
);

/// Pins are addressed by key: `Marker` is a data class in flutter_map, not a
/// widget, so `find.byType(Marker)` finds nothing at all.
Finder pins() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith("pin-"),
);

void main() {
  Destination at(String id, {required double lat, required double lng}) =>
      testDestination(id: id, name: id).copyWith(
        coords: GeoPoint2(lat: lat, lng: lng),
      );

  Future<void> pumpMap(WidgetTester tester, List<Destination> items) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tileSourceProvider.overrideWithValue(_noTiles)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: MapView(destinations: items)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  group("map view", () {
    testWidgets("drops a pin for every destination", (tester) async {
      await pumpMap(tester, [
        at("callao", lat: 17.70, lng: 121.80),
        at("palaui", lat: 18.55, lng: 122.13),
      ]);

      expect(pins(), findsNWidgets(2));
    });

    testWidgets("tapping a pin names it, tapping the basemap clears it", (
      tester,
    ) async {
      // Selection is the pin growing and carrying its name; there is no card
      // on the map itself, the places sheet does that job.
      await pumpMap(tester, [at("callao", lat: 17.70, lng: 121.80)]);

      expect(find.text("callao"), findsNothing);

      await tester.tap(
        find.byKey(const Key("pin-callao")),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text("callao"), findsOneWidget);

      // The same gesture that dismisses a sheet: a tap on the empty map. The
      // map waits out its double-tap window before it calls a tap a tap.
      await tester.tapAt(const Offset(20, 700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text("callao"), findsNothing);
    });

    testWidgets("still draws the map when there is nothing to pin", (
      tester,
    ) async {
      // Deliberately still a map, not a blank panel: an empty screen where a
      // map belongs reads as a failure to load rather than an empty result.
      await pumpMap(tester, const []);

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(pins(), findsNothing);
    });

    testWidgets("credits OpenStreetMap, which the licence requires", (
      tester,
    ) async {
      await pumpMap(tester, [at("callao", lat: 17.70, lng: 121.80)]);

      expect(
        find.textContaining("OpenStreetMap"),
        findsOneWidget,
        reason: "ODbL obliges attribution wherever the tiles appear",
      );
    });
  });

  group("the Map tab", () {
    /// The tab lands on the map; `MapScreen` is the host that swaps it for
    /// the Browse grid and back.
    Future<void> pumpTab(
      WidgetTester tester,
      FakeDestinationRepository repo,
    ) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            destinationRepositoryProvider.overrideWithValue(repo),
            tileSourceProvider.overrideWithValue(_noTiles),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: MapScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets("says so when the filters match nothing", (tester) async {
      // The map stays; the sheet under it carries the message.
      await pumpTab(tester, FakeDestinationRepository([]));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text("Nothing matches those filters."), findsOneWidget);
      expect(pins(), findsNothing);
    });

    testWidgets("swaps the map for the grid and back", (tester) async {
      await pumpTab(
        tester,
        FakeDestinationRepository([at("callao", lat: 17.70, lng: 121.80)]),
      );

      expect(find.byType(FlutterMap), findsOneWidget);

      await tester.tap(find.byTooltip("Show as a grid"));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text("Browse"), findsOneWidget);

      await tester.tap(find.byTooltip("Show on the map"));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets("the map obeys the category filter", (tester) async {
      // The toggle changes how results are drawn, not which results they are.
      // If the two views ever disagree, the toggle stops being a view switch.
      await pumpTab(
        tester,
        FakeDestinationRepository([
          testDestination(
            id: "callao",
            category: DestinationCategory.nature,
          ).copyWith(coords: const GeoPoint2(lat: 17.7, lng: 121.8)),
          testDestination(
            id: "piat",
            category: DestinationCategory.church,
          ).copyWith(coords: const GeoPoint2(lat: 17.8, lng: 121.5)),
        ]),
      );

      expect(pins(), findsNWidgets(2));

      await tester.tap(find.widgetWithText(ChoiceChip, "Churches"));
      await tester.pump(const Duration(milliseconds: 50));
      expect(pins(), findsOneWidget);
    });
  });
}
