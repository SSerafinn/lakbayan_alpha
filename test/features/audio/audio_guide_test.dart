import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/audio/domain/audio_providers.dart";
import "package:lakbayan/features/audio/domain/narration.dart";
import "package:lakbayan/features/audio/presentation/audio_guide_section.dart";

import "../../support/fake_narrator.dart";

void main() {
  late FakeNarrator narrator;

  setUp(() => narrator = FakeNarrator());

  const recorded = Segment(
    id: "s1",
    title: "The mouth of the cave",
    order: 1,
    audioUrl: "destinations/callao/audio/s1.mp3",
  );
  const spoken = Segment(
    id: "s2",
    title: "The chapel",
    order: 2,
    ttsText: "Seven chambers open ahead of you.",
  );
  const silent = Segment(id: "s3", title: "Not written yet", order: 3);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Segment> segments, {
    String destinationId = "callao",
    Future<String> Function(String)? resolver,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        narratorProvider.overrideWithValue(narrator),
        audioUrlResolverProvider.overrideWithValue(
          resolver ?? (path) async => "https://example.test/$path",
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AudioGuideSection(
                destinationId: destinationId,
                segments: segments,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Pump a bounded number of frames instead of `pumpAndSettle`.
  ///
  /// While speech is playing the bar is an **indeterminate**
  /// `LinearProgressIndicator` — it animates forever by design, because the
  /// engine reports no length — so `pumpAndSettle` never returns. That is the
  /// feature working, not a fault to design around.
  /// Past the player's grow and fold, which ride `AppMotion.chrome` (350 ms),
  /// so a tap lands on a settled card and a cleared player is really gone.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> openGuide(WidgetTester tester) async {
    if (find.byKey(const ValueKey("stop-s1")).evaluate().isNotEmpty ||
        find.byKey(const ValueKey("stop-s2")).evaluate().isNotEmpty ||
        find.byKey(const ValueKey("stop-s3")).evaluate().isNotEmpty) {
      return;
    }
    await tester.tap(find.text("Audio guide"));
    await settle(tester);
  }

  /// By segment id. Not by title: once a stop is playing the player bar
  /// repeats that title, and the finder would match two widgets.
  ///
  /// The guide rests as one bar and lists its stops once opened (D-16), so
  /// the bar is tapped first when the stops are not showing yet.
  Future<void> tapStop(WidgetTester tester, String segmentId) async {
    await openGuide(tester);
    await tester.tap(find.byKey(Key("stop-$segmentId")), warnIfMissed: false);
    await settle(tester);
  }

  group("choosing what to play", () {
    testWidgets("prefers the recording when a stop has both", (tester) async {
      const both = Segment(
        id: "s1",
        title: "Both",
        order: 1,
        audioUrl: "destinations/callao/audio/s1.mp3",
        ttsText: "A script that should not win.",
      );
      await pump(tester, const [both]);
      await tapStop(tester, "s1");

      expect(narrator.played.single, isA<RecordedNarration>());
    });

    testWidgets("reads the script aloud when there is no recording", (
      tester,
    ) async {
      await pump(tester, const [spoken]);
      await tapStop(tester, "s2");

      expect(
        narrator.played.single,
        const SpokenNarration("Seven chambers open ahead of you."),
      );
    });

    testWidgets("says which stops the device will read out", (tester) async {
      await pump(tester, const [recorded, spoken]);
      await openGuide(tester);
      // Only the script-only stop carries the note.
      expect(find.text("Read aloud by your device"), findsOneWidget);
    });

    testWidgets("falls back to the script when the recording will not resolve", (
      tester,
    ) async {
      // A Storage object can be missing while the document still points at it.
      // Silencing a stop that also has text would be the wrong call.
      const both = Segment(
        id: "s1",
        title: "Both",
        order: 1,
        audioUrl: "destinations/callao/audio/gone.mp3",
        ttsText: "The script still works.",
      );
      await pump(tester, const [
        both,
      ], resolver: (_) async => throw Exception("object-not-found"));
      await tapStop(tester, "s1");

      expect(narrator.played.single, isA<SpokenNarration>());
    });

    testWidgets("cannot play a stop with neither recording nor script", (
      tester,
    ) async {
      await pump(tester, const [silent]);
      await openGuide(tester);
      expect(find.text("No recording or script yet"), findsOneWidget);

      await tapStop(tester, "s3");
      expect(narrator.played, isEmpty);
    });
  });

  group("transport", () {
    testWidgets("a second tap pauses, a third resumes", (tester) async {
      await pump(tester, const [recorded]);

      await tapStop(tester, "s1");
      expect(narrator.played, hasLength(1));

      await tapStop(tester, "s1");
      expect(narrator.pauseCount, 1);

      await tapStop(tester, "s1");
      expect(narrator.resumeCount, 1);
      // Still one play: pause and resume must not restart the recording.
      expect(narrator.played, hasLength(1));
    });

    testWidgets("draws a scrubber for a recording but not for speech", (
      tester,
    ) async {
      await pump(tester, const [recorded, spoken]);

      await tapStop(tester, "s1");
      expect(find.byType(Slider), findsOneWidget);

      await tapStop(tester, "s2");
      // Speech reports no length and cannot seek. A draggable bar over it
      // would be an invention.
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets("the player belongs to the destination that started it", (
      tester,
    ) async {
      final container = await pump(tester, const [recorded]);
      await tapStop(tester, "s1");
      expect(find.byIcon(AppIcons.skipNext), findsOneWidget);

      // Same container, a different destination's sheet: audio keeps playing,
      // but this screen must not present transport for it.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: AudioGuideSection(
                destinationId: "palaui",
                segments: [recorded],
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.byIcon(AppIcons.skipNext), findsNothing);
    });
  });

  group("running the guide", () {
    testWidgets("moves to the next stop when one finishes", (tester) async {
      await pump(tester, const [recorded, spoken]);
      await tapStop(tester, "s1");

      narrator.complete();
      await settle(tester);

      expect(narrator.played, hasLength(2));
      expect(narrator.played.last, isA<SpokenNarration>());
    });

    testWidgets("skips a stop that has nothing to play", (tester) async {
      // An editor can leave a stop empty. Halting the tour there would look
      // like a crash to somebody walking between two caves.
      await pump(tester, const [recorded, silent, spoken]);
      await tapStop(tester, "s1");

      narrator.complete();
      await settle(tester);

      expect(narrator.played.last, isA<SpokenNarration>());
    });

    testWidgets("clears the player at the end of the guide", (tester) async {
      await pump(tester, const [recorded]);
      await tapStop(tester, "s1");
      expect(find.byIcon(AppIcons.skipNext), findsOneWidget);

      narrator.complete();
      await settle(tester);

      // Not left looking paused on the last stop, which would invite a tap
      // that restarts the whole guide.
      expect(find.byIcon(AppIcons.skipNext), findsNothing);
    });

    testWidgets("skip next and previous walk the stops", (tester) async {
      await pump(tester, const [recorded, spoken]);
      await tapStop(tester, "s1");

      await tester.tap(find.byIcon(AppIcons.skipNext));
      await settle(tester);
      expect(narrator.played.last, isA<SpokenNarration>());

      await tester.tap(find.byIcon(AppIcons.skipPrevious));
      await settle(tester);
      expect(narrator.played.last, isA<RecordedNarration>());
    });

    testWidgets("stop clears the player", (tester) async {
      await pump(tester, const [recorded]);
      await tapStop(tester, "s1");

      await tester.tap(find.byIcon(AppIcons.stop));
      await settle(tester);

      expect(narrator.stopCount, greaterThan(0));
      expect(find.byIcon(AppIcons.skipNext), findsNothing);
    });
  });

  group("empty state", () {
    testWidgets("says so when a destination has no guide", (tester) async {
      await pump(tester, const []);
      expect(find.text("No audio guide for this stop yet."), findsOneWidget);
    });
  });
}
