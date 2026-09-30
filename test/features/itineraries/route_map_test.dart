import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/itineraries/presentation/route_map.dart";
import "package:lakbayan/features/maps/domain/tile_source.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:lakbayan/features/offline/domain/offline_providers.dart";

import "../../support/fake_destination_repository.dart";

const _noTiles = TileSource(
  urlTemplate: "https://tiles.invalid/{z}/{x}/{y}.png",
  attribution: "© OpenStreetMap contributors",
);

void main() {
  final stops = <RouteStop>[
    (
      number: 1,
      place: testDestination(
        id: "callao",
        name: "Callao Cave",
      ).copyWith(coords: const GeoPoint2(lat: 17.70, lng: 121.80)),
    ),
    (
      number: 2,
      place: testDestination(
        id: "piat",
        name: "Piat",
      ).copyWith(coords: const GeoPoint2(lat: 17.79, lng: 121.48)),
    ),
  ];

  Future<void> pump(WidgetTester tester, {required bool expanded}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const frame = Size(400, 280);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tileSourceProvider.overrideWithValue(_noTiles),
          // The basemap layers downloaded packs, which reads the manifest
          // from Firestore; that throws in a test and leaves a retry timer.
          offlineBundlesProvider.overrideWith(
            (ref) => Stream.value(const <OfflineBundle>[]),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox.fromSize(
              size: frame,
              child: RouteMap(
                stops: stops,
                expanded: expanded,
                frame: frame,
                restPadding: const EdgeInsets.all(24),
                expandedPadding: const EdgeInsets.all(24),
                restCreditInset: 24,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets("credits OpenStreetMap at rest, where the header shows it", (
    tester,
  ) async {
    // ODbL wants credit wherever the tiles appear. The trip header at rest
    // is where they appear most, and it used to carry none.
    await pump(tester, expanded: false);

    expect(find.text("© OpenStreetMap contributors"), findsOneWidget);
    // Plain text, not the attribution control: at rest the header ignores
    // touches, so a button there would be dead.
    expect(find.byType(RichAttributionWidget), findsNothing);
  });

  testWidgets("expanded, the full attribution control takes over", (
    tester,
  ) async {
    await pump(tester, expanded: true);

    expect(find.byType(RichAttributionWidget), findsOneWidget);
  });
}
