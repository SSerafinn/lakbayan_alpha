import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/errors/error_copy.dart";
import "package:lakbayan/core/models/itinerary.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/chrome/app_sheet.dart";
import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/itineraries/domain/itinerary_providers.dart";
import "package:lakbayan/features/itineraries/presentation/itinerary_screen.dart";

import "../../support/fake_auth_repository.dart";
import "../../support/fake_destination_repository.dart";
import "../../support/fake_itinerary_repository.dart";
import "../../support/flaky_destination_repository.dart";

/// Add a stop while the places it offers are loading or could not be read.
/// It used to say "Every place is already on this trip." in both cases.
void main() {
  const ana = AppUser(uid: "ana", email: "ana@example.com");

  Future<void> openAddStops(
    WidgetTester tester,
    FlakyDestinationRepository repo, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initialUser: ana),
          ),
          itineraryRepositoryProvider.overrideWithValue(
            FakeItineraryRepository({
              "ana": [
                const Itinerary(
                  id: "it-1",
                  name: "Weekend",
                  destinationIds: ["callao"],
                ),
              ],
            }),
          ),
          tourRepositoryProvider.overrideWithValue(FakeTourRepository()),
          destinationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ItineraryScreen(id: "it-1"),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Add a stop"));
    await tester.tap(find.text("Add a stop"));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A spinner never settles, so the sheet's rise is counted by hand.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(AppSheet), matching: finder);

  final places = [
    testDestination(id: "callao", name: "Callao Cave"),
    testDestination(id: "palaui", name: "Palaui Island"),
  ];

  testWidgets("a failed load says so and offers another try", (tester) async {
    final repo = FlakyDestinationRepository(places, failAll: true);
    await openAddStops(tester, repo);

    expect(
      inSheet(find.text("Couldn't load places to add. $genericErrorHint")),
      findsOneWidget,
    );
    expect(find.textContaining("already on this trip"), findsNothing);

    repo.failAll = false;
    await tester.tap(inSheet(find.widgetWithText(TextButton, "Try again")));
    await tester.pumpAndSettle();
    expect(inSheet(find.text("Palaui Island")), findsOneWidget);
  });

  testWidgets("still loading shows progress, not a full trip", (tester) async {
    final repo = FlakyDestinationRepository(places, holdAll: true);
    await openAddStops(tester, repo, settle: false);

    expect(inSheet(find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(find.textContaining("already on this trip"), findsNothing);
  });
}
