import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/errors/error_copy.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/presentation/destination_detail_screen.dart";
import "package:lakbayan/features/destinations/presentation/explore_screen.dart";

import "../../support/fake_destination_repository.dart";
import "../../support/flaky_destination_repository.dart";

/// What Explore and Place detail say while their data is loading or failed,
/// rather than the "nothing here" a derived list used to fall back to; and
/// that what is already on screen stays when a later read fails.
void main() {
  /// [retries] keeps Riverpod's own retry, as the app has it. Off, the reads
  /// a test counts are the ones it asked for.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required FlakyDestinationRepository repo,
    bool retries = false,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        retry: retries ? ProviderContainer.defaultRetry : (_, _) => null,
        overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final callao = testDestination(id: "callao", name: "Callao Cave");

  group("Explore's matches for a kind", () {
    testWidgets("a failed load says so and offers another try", (tester) async {
      final repo = FlakyDestinationRepository([callao], failAll: true);
      await pump(tester, const ExploreScreen(), repo: repo);

      await tester.tap(find.text("Nature"));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load places. $genericErrorHint"),
        findsOneWidget,
      );
      expect(find.textContaining("Nothing matches"), findsNothing);
      // The exception is for the log, not the screen.
      expect(find.textContaining("permission"), findsNothing);

      // Try again reopens every place, and this time it arrives.
      final reads = repo.allReads;
      repo.failAll = false;
      await tester.tap(find.widgetWithText(TextButton, "Try again"));
      await tester.pumpAndSettle();

      expect(repo.allReads, greaterThan(reads));
      expect(find.text("Callao Cave"), findsOneWidget);
      expect(find.textContaining("Couldn't load"), findsNothing);
    });

    testWidgets("offline, it says so rather than something broke", (
      tester,
    ) async {
      final repo = FlakyDestinationRepository(
        [callao],
        failAll: true,
        error: unreachable,
      );
      await pump(tester, const ExploreScreen(), repo: repo);

      await tester.tap(find.text("Nature"));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load places. $offlineErrorHint"),
        findsOneWidget,
      );
    });

    testWidgets("still loading shows progress, not an empty result", (
      tester,
    ) async {
      final repo = FlakyDestinationRepository([callao], holdAll: true);
      await pump(tester, const ExploreScreen(), repo: repo);

      await tester.tap(find.text("Nature"));
      // A spinner never settles, so the frames are counted by hand.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining("Nothing matches"), findsNothing);
    });

    testWidgets("loaded and empty is the only time it says nothing matches", (
      tester,
    ) async {
      final repo = FlakyDestinationRepository([callao]);
      await pump(tester, const ExploreScreen(), repo: repo);

      await tester.tap(find.text("Churches"));
      await tester.pumpAndSettle();

      expect(find.text("Nothing matches. Try another kind."), findsOneWidget);
    });

    testWidgets("places on screen stay through a later failure and its "
        "retries", (tester) async {
      final live = StreamController<List<Destination>>.broadcast();
      addTearDown(live.close);
      final repo = FlakyDestinationRepository([callao], liveAll: live);
      await pump(tester, const ExploreScreen(), repo: repo, retries: true);
      live.add([callao]);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Nature"));
      await tester.pumpAndSettle();
      expect(find.text("Callao Cave"), findsOneWidget);

      // Riverpod retries, reading as loading meanwhile: neither a spinner
      // nor the error takes the rows' place.
      live.addError(refused);
      await tester.pump();
      expect(find.text("Callao Cave"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining("Couldn't load"), findsNothing);

      // Nor once a retry has listened again and heard nothing yet.
      await tester.pump(const Duration(seconds: 1));
      expect(repo.allReads, greaterThan(1));
      expect(find.text("Callao Cave"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets("Try again shows progress while it runs", (tester) async {
      final repo = FlakyDestinationRepository([callao], failAll: true);
      await pump(tester, const ExploreScreen(), repo: repo);
      await tester.tap(find.text("Nature"));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't load places."), findsOneWidget);

      // This attempt takes its time, as on a slow connection.
      repo
        ..failAll = false
        ..holdAll = true;
      await tester.tap(find.widgetWithText(TextButton, "Try again"));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining("Couldn't load"), findsNothing);
    });
  });

  group("Place detail's audio guide", () {
    const stops = {
      "callao": [Segment(id: "s1", title: "History", order: 1)],
    };

    testWidgets("a failed read says so, and Try again brings it back", (
      tester,
    ) async {
      final repo = FlakyDestinationRepository(
        [callao],
        segments: stops,
        failSegments: true,
      );
      await pump(
        tester,
        const DestinationDetailScreen(id: "callao"),
        repo: repo,
      );

      // The page itself is there; only the guide could not be read.
      expect(find.text("Callao Cave"), findsOneWidget);
      expect(
        find.text("Couldn't load the audio guide. $genericErrorHint"),
        findsOneWidget,
      );
      expect(find.text("Audio Guide"), findsNothing);

      final reads = repo.segmentReads;
      repo.failSegments = false;
      await tester.ensureVisible(find.text("Try again"));
      await tester.tap(find.text("Try again"));
      await tester.pumpAndSettle();

      expect(repo.segmentReads, greaterThan(reads));
      expect(find.text("Audio Guide"), findsOneWidget);
      expect(find.textContaining("Couldn't load"), findsNothing);
    });

    testWidgets("stops on screen stay through a later failure and its "
        "retries", (tester) async {
      final live = StreamController<List<Segment>>.broadcast();
      addTearDown(live.close);
      final repo = FlakyDestinationRepository([callao], liveSegments: live);
      await pump(
        tester,
        const DestinationDetailScreen(id: "callao"),
        repo: repo,
        retries: true,
      );
      live.add(stops["callao"]!);
      await tester.pumpAndSettle();
      expect(find.text("Audio Guide"), findsOneWidget);

      // Read straight from its provider, not derived: the guide stays while
      // Riverpod retries and reads as loading.
      live.addError(refused);
      await tester.pump();
      expect(find.text("Audio Guide"), findsOneWidget);
      expect(find.textContaining("Couldn't load"), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(repo.segmentReads, greaterThan(1));
      expect(find.text("Audio Guide"), findsOneWidget);
    });

    testWidgets("a place with no stops has no guide and no message", (
      tester,
    ) async {
      final repo = FlakyDestinationRepository([callao]);
      await pump(
        tester,
        const DestinationDetailScreen(id: "callao"),
        repo: repo,
      );

      expect(find.text("Callao Cave"), findsOneWidget);
      expect(find.text("Audio Guide"), findsNothing);
      expect(find.textContaining("Couldn't load"), findsNothing);
    });
  });
}
