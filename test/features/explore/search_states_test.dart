import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/errors/error_copy.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/explore/domain/home_tab.dart";
import "package:lakbayan/features/explore/presentation/home_chrome_layer.dart";

import "../../support/fake_destination_repository.dart";
import "../../support/flaky_destination_repository.dart";

/// The search surface when the places it searches could not be read: it
/// says so, before a search and during one, instead of a blank or "nothing
/// matches".
void main() {
  Future<ProviderContainer> openSearch(
    WidgetTester tester,
    FlakyDestinationRepository repo,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      // No automatic retries, so a failure stays put until asked again.
      retry: (_, _) => null,
      overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: HomeChromeLayer(tab: HomeTab.explore, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Search"));
    await tester.pumpAndSettle();
    return container;
  }

  final places = [
    testDestination(id: "callao", name: "Callao Cave"),
    testDestination(id: "palaui", name: "Palaui Island", town: "Santa Ana"),
  ];

  testWidgets("before a search, the failure is said where the towns go", (
    tester,
  ) async {
    final repo = FlakyDestinationRepository(places, failAll: true);
    await openSearch(tester, repo);

    expect(
      find.text("Couldn't load the towns. $genericErrorHint"),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, "Try again"), findsOneWidget);
  });

  testWidgets("a search over places that failed says so, offline", (
    tester,
  ) async {
    final repo = FlakyDestinationRepository(
      places,
      failAll: true,
      error: unreachable,
    );
    final container = await openSearch(tester, repo);

    container
        .read(searchCategoryProvider.notifier)
        .toggle(DestinationCategory.nature);
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't search places. $offlineErrorHint"),
      findsOneWidget,
    );
    expect(find.textContaining("Nothing matches"), findsNothing);

    repo.failAll = false;
    await tester.tap(find.widgetWithText(TextButton, "Try again"));
    await tester.pumpAndSettle();
    expect(find.text("Callao Cave"), findsOneWidget);
  });
}
