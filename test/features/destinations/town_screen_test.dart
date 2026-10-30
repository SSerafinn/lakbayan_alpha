import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/router/app_router.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/presentation/town_screen.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:lakbayan/features/offline/domain/offline_providers.dart";

import "../../support/fake_destination_repository.dart";

/// A town's own page (D-19): its places as photos, the kinds it has as a
/// rail, and the way to take it offline.
void main() {
  final tuguegarao = [
    testDestination(
      id: "museum",
      name: "Cagayan Museum",
      town: "Tuguegarao City",
      category: DestinationCategory.museum,
    ),
    testDestination(
      id: "bridge",
      name: "Buntun Bridge",
      town: "Tuguegarao City",
      category: DestinationCategory.landmark,
    ),
    testDestination(
      id: "pancit",
      name: "Pancit Batil Patung",
      town: "Tuguegarao City",
      category: DestinationCategory.food,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required String town,
    List<Destination>? places,
    List<OfflineBundle> bundles = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: Routes.town(town),
      routes: [
        GoRoute(path: "/", builder: (_, _) => const Text("Home")),
        GoRoute(
          path: "/town/:name",
          builder: (_, state) =>
              TownScreen(name: state.pathParameters["name"]!),
        ),
        GoRoute(
          path: "/destination/:id",
          builder: (_, state) => Text("Place ${state.pathParameters["id"]}"),
        ),
        GoRoute(
          path: Routes.downloads,
          builder: (_, _) => const Text("Offline page"),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationRepositoryProvider.overrideWithValue(
            FakeDestinationRepository(places ?? tuguegarao),
          ),
          offlineBundlesProvider.overrideWith((ref) => Stream.value(bundles)),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("shows the town and every place in it as a photo", (
    tester,
  ) async {
    await pump(tester, town: "Tuguegarao City");

    expect(find.text("Tuguegarao City"), findsOneWidget);
    for (final name in [
      "Cagayan Museum",
      "Buntun Bridge",
      "Pancit Batil Patung",
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    // The kinds it has, after All: nothing for a kind it has none of.
    expect(find.text("All"), findsOneWidget);
    expect(find.text("Museums"), findsOneWidget);
    expect(find.text("Food"), findsOneWidget);
    expect(find.text("Churches"), findsNothing);
  });

  testWidgets("a kind narrows the places, and All brings them back", (
    tester,
  ) async {
    await pump(tester, town: "Tuguegarao City");

    await tester.tap(find.text("Food"));
    await tester.pumpAndSettle();
    expect(find.text("Pancit Batil Patung"), findsOneWidget);
    expect(find.text("Buntun Bridge"), findsNothing);
    expect(find.text("Cagayan Museum"), findsNothing);

    await tester.tap(find.text("All"));
    await tester.pumpAndSettle();
    expect(find.text("Buntun Bridge"), findsOneWidget);
    expect(find.text("Cagayan Museum"), findsOneWidget);
  });

  testWidgets("a town of one kind has no rail to choose from", (tester) async {
    await pump(
      tester,
      town: "Peñablanca",
      places: [
        testDestination(id: "callao", name: "Callao Cave"),
        testDestination(id: "river", name: "Pinacanauan River"),
      ],
    );

    expect(find.text("Callao Cave"), findsOneWidget);
    expect(find.text("Pinacanauan River"), findsOneWidget);
    expect(find.text("All"), findsNothing);
  });

  testWidgets("a place opens its page", (tester) async {
    await pump(tester, town: "Tuguegarao City");

    await tester.tap(find.text("Buntun Bridge"));
    await tester.pumpAndSettle();

    expect(find.text("Place bridge"), findsOneWidget);
  });

  testWidgets("a town with nothing in it says so", (tester) async {
    await pump(tester, town: "Calayan");

    expect(find.text("There are no places in this town yet."), findsOneWidget);
  });

  testWidgets("with no bundle ready, the corner opens Offline", (tester) async {
    // Not hidden: Offline is where a town that cannot be saved yet is
    // explained.
    await pump(tester, town: "Tuguegarao City");

    await tester.tap(find.byTooltip("Offline towns"));
    await tester.pumpAndSettle();

    expect(find.text("Offline page"), findsOneWidget);
  });
}
