import "dart:async";

import "package:audio_service/audio_service.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/features/audio/data/guide_audio_handler.dart";
import "package:lakbayan/features/audio/domain/audio_providers.dart";
import "package:lakbayan/features/audio/domain/media_session.dart";
import "package:lakbayan/features/audio/domain/narration.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";

import "../../support/fake_destination_repository.dart";
import "../../support/fake_narrator.dart";

/// The media session, driven the way the lock screen drives it.
///
/// The handler is real — `BaseAudioHandler` is only streams until
/// `AudioService.init` hands it to the platform, which nothing here does — and
/// the controller behind it is the one the in-app player uses, over a fake
/// narrator. So "a lock-screen pause pauses the narrator, and the screen says
/// paused" is asserted end to end rather than against a stand-in.
void main() {
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
  const stops = [recorded, spoken];

  late FakeNarrator narrator;
  late GuideAudioHandler handler;

  ProviderContainer containerWith({
    GuideMediaSession? session,
    AudioUrlResolver? resolver,
  }) {
    final container = ProviderContainer(
      overrides: [
        narratorProvider.overrideWithValue(narrator),
        audioUrlResolverProvider.overrideWithValue(
          resolver ?? (path) async => "https://example.test/$path",
        ),
        guideMediaSessionProvider.overrideWithValue(session),
        destinationRepositoryProvider.overrideWithValue(
          FakeDestinationRepository([
            testDestination(id: "callao", name: "Callao Cave"),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  late ProviderContainer container;

  setUp(() {
    narrator = FakeNarrator();
    handler = GuideAudioHandler();
    container = containerWith(session: handler);
  });

  GuidePlayback playback() => container.read(audioGuideControllerProvider);

  Future<void> start(Segment stop) async {
    await container
        .read(audioGuideControllerProvider.notifier)
        .play("callao", stops, stop);
    await pumpEventQueue();
  }

  /// Every command is async and the fake narrator reports on a broadcast
  /// stream, so the session's view lands a few microtasks after the call.
  Future<void> run(Future<void> Function() command) async {
    await command();
    await pumpEventQueue();
  }

  PlaybackState session() => handler.playbackState.value;

  group("what the lock screen shows", () {
    test("the stop, its place, and the recording's length", () async {
      await start(recorded);

      final item = handler.mediaItem.value!;
      expect(item.title, "The mouth of the cave");
      expect(item.artist, "Callao Cave");
      expect(item.duration, const Duration(minutes: 2));

      expect(session().processingState, AudioProcessingState.ready);
      expect(session().playing, isTrue);
      expect(session().systemActions, contains(MediaAction.seek));
    });

    test("speech has no length and nothing to seek", () async {
      await start(spoken);

      expect(handler.mediaItem.value!.duration, isNull);
      expect(session().systemActions, isEmpty);
      expect(session().updatePosition, Duration.zero);

      // A headset's fast-forward can still arrive. It must not reach the
      // narrator as though the script had a timeline.
      await run(() => handler.seek(const Duration(seconds: 30)));
      expect(narrator.lastSeek, isNull);
    });

    test("a failed stop is an error, with nothing to resume", () async {
      await start(recorded);
      narrator.fail("The recording would not load.");
      await pumpEventQueue();

      expect(session().processingState, AudioProcessingState.error);
      expect(session().errorMessage, "The recording would not load.");
      expect(session().playing, isFalse);
      expect(
        session().controls,
        isNot(anyOf(contains(MediaControl.play), contains(MediaControl.pause))),
      );
    });

    test("stop clears the session and the in-app player together", () async {
      await start(recorded);
      await run(handler.stop);

      expect(narrator.stopCount, greaterThan(0));
      expect(playback().segmentId, isNull);
      expect(session().processingState, AudioProcessingState.idle);
      expect(handler.mediaItem.value, isNull);
    });
  });

  group("commands go through the in-app controller", () {
    test("pause and play, and the screen agrees", () async {
      await start(recorded);

      await run(handler.pause);
      expect(narrator.pauseCount, 1);
      expect(playback().narrator.phase, NarratorPhase.paused);
      expect(session().playing, isFalse);
      expect(session().controls, contains(MediaControl.play));

      await run(handler.play);
      expect(narrator.resumeCount, 1);
      expect(playback().narrator.phase, NarratorPhase.playing);
      expect(session().playing, isTrue);
      // Resumed, not restarted.
      expect(narrator.played, hasLength(1));
    });

    test("a headset click pauses, and a second resumes", () async {
      await start(spoken);

      await run(handler.click);
      expect(narrator.pauseCount, 1);

      await run(handler.click);
      expect(narrator.resumeCount, 1);
    });

    test("play with nothing loaded starts nothing", () async {
      await run(handler.play);
      expect(narrator.played, isEmpty);
      expect(narrator.resumeCount, 0);
    });

    test("skip walks the stops the screen walks", () async {
      await start(recorded);

      await run(handler.skipToNext);
      expect(narrator.played.last, isA<SpokenNarration>());
      expect(playback().segmentId, "s2");
      expect(handler.mediaItem.value!.title, "The chapel");

      await run(handler.skipToPrevious);
      expect(narrator.played.last, isA<RecordedNarration>());
      expect(playback().segmentId, "s1");
    });

    test("a recording seeks", () async {
      await start(recorded);
      await run(() => handler.seek(const Duration(seconds: 30)));
      expect(narrator.lastSeek, const Duration(seconds: 30));
      expect(session().updatePosition, const Duration(seconds: 30));
    });

    test("position ticks are not re-sent; a jump is", () async {
      // Listeners project position from the last update, and the plugin asks
      // not to be told what they can work out. A tick in step with that
      // projection is noise; a seek made in the app is news.
      await start(recorded);
      final sent = <PlaybackState>[];
      final sub = handler.playbackState.skip(1).listen(sent.add);
      addTearDown(sub.cancel);

      // The fake's seek is the only way to make it report a position; called
      // directly, it stands in for the engine's own tick.
      await narrator.seek(
        session().position + const Duration(milliseconds: 100),
      );
      await pumpEventQueue();
      expect(sent, isEmpty);

      await narrator.seek(const Duration(seconds: 50));
      await pumpEventQueue();
      expect(sent.single.updatePosition, const Duration(seconds: 50));
    });

    test("moving to the next stop never reads as a pause", () async {
      // A fall in `playing` is audio_service's cue to drop the foreground
      // service, which a backgrounded app may not start again. Between stops
      // it has to stay up, or the next one would never be heard.
      await start(recorded);
      final seen = <bool>[];
      final sub = handler.playbackState.listen((s) => seen.add(s.playing));
      addTearDown(sub.cancel);
      final phases = <NarratorPhase>[];
      container.listen(
        audioGuideControllerProvider,
        (_, next) => phases.add(next.narrator.phase),
      );

      narrator.complete();
      await pumpEventQueue();

      expect(narrator.played.last, isA<SpokenNarration>());
      // Through idle and loading, as the real narrator goes, and the
      // session never once said it had stopped playing.
      expect(
        phases,
        containsAllInOrder([
          NarratorPhase.completed,
          NarratorPhase.idle,
          NarratorPhase.loading,
          NarratorPhase.playing,
        ]),
      );
      expect(seen, everyElement(isTrue));
    });

    test("a pause pressed while a stop loads is kept until it plays", () async {
      // The lock screen shows a loading stop as playing, with Pause. A press
      // dropped there would leave the recording starting anyway.
      narrator.buffering = Completer();
      final starting = container
          .read(audioGuideControllerProvider.notifier)
          .play("callao", stops, recorded);
      await pumpEventQueue();
      expect(session().processingState, AudioProcessingState.buffering);
      expect(session().controls, contains(MediaControl.pause));

      await run(handler.pause);
      expect(narrator.pauseCount, 0);

      narrator.buffering!.complete();
      await starting;
      await pumpEventQueue();

      expect(narrator.pauseCount, 1);
      expect(playback().narrator.phase, NarratorPhase.paused);
      expect(session().playing, isFalse);
    });
  });

  group("between stops", () {
    // A recording with no script, in a town not downloaded, with no signal:
    // playable on paper, and nothing to say once its URL will not resolve.
    const offline = Segment(
      id: "s3",
      title: "The upper chamber",
      order: 3,
      audioUrl: "destinations/callao/audio/s3.mp3",
    );
    const after = Segment(
      id: "s4",
      title: "The way out",
      order: 4,
      ttsText: "Mind the steps on the way down.",
    );

    /// Plays the spoken stop over [resolver], then lets it finish.
    Future<void> finishFirstOf(
      List<Segment> queue,
      AudioUrlResolver resolver,
    ) async {
      container = containerWith(session: handler, resolver: resolver);
      await run(
        () => container
            .read(audioGuideControllerProvider.notifier)
            .play("callao", queue, spoken),
      );
      narrator.complete();
      await pumpEventQueue();
    }

    Future<String> unreachable(String path) async =>
        throw Exception("storage/retry-limit-exceeded");

    test("a stop that will not load is passed over", () async {
      await finishFirstOf(const [spoken, offline, after], unreachable);

      expect(
        narrator.played.last,
        const SpokenNarration("Mind the steps on the way down."),
      );
      expect(playback().segmentId, "s4");
      expect(session().playing, isTrue);
    });

    test("with nothing after it that loads, the guide ends", () async {
      // Left on the finished stop, the session would go on saying playing,
      // and hold the foreground service and its wake lock with the screen
      // off — with Pause and a headset click both doing nothing.
      await finishFirstOf(const [spoken, offline], unreachable);

      expect(narrator.played, hasLength(1));
      expect(playback().segmentId, isNull);
      expect(session().processingState, AudioProcessingState.idle);
      expect(session().playing, isFalse);
      expect(handler.mediaItem.value, isNull);
    });

    test("a stop pressed while the next one resolves stays stopped", () async {
      // Offline, Storage can retry for minutes before it answers.
      final url = Completer<String>();
      await finishFirstOf(const [spoken, recorded], (_) => url.future);

      await run(handler.stop);
      url.complete("https://example.test/late.mp3");
      await pumpEventQueue();

      expect(narrator.played, hasLength(1));
      expect(playback().segmentId, isNull);
      expect(session().processingState, AudioProcessingState.idle);
      expect(session().playing, isFalse);
    });

    test("a pause pressed in the gap pauses the next stop", () async {
      final url = Completer<String>();
      await finishFirstOf(const [spoken, recorded], (_) => url.future);
      expect(session().processingState, AudioProcessingState.completed);
      expect(session().controls, contains(MediaControl.pause));

      await run(handler.pause);
      url.complete("https://example.test/s1.mp3");
      await pumpEventQueue();

      expect(narrator.played.last, isA<RecordedNarration>());
      expect(narrator.pauseCount, 1);
      expect(playback().segmentId, "s1");
      expect(playback().narrator.phase, NarratorPhase.paused);
      expect(session().playing, isFalse);
    });
  });

  group("lifetime", () {
    Future<void> playThenLeave(ProviderContainer container) async {
      final screen = container.listen(audioGuideControllerProvider, (_, _) {});
      await container
          .read(audioGuideControllerProvider.notifier)
          .play("callao", stops, recorded);
      await pumpEventQueue();
      screen.close();
      await container.pump();
    }

    test("the guide outlives the screen while a session shows it", () async {
      await playThenLeave(container);
      expect(container.read(audioGuideControllerProvider).segmentId, "s1");
    });

    test("without a session it goes with the screen, as before", () async {
      final plain = containerWith();
      await playThenLeave(plain);
      expect(plain.read(audioGuideControllerProvider).segmentId, isNull);
    });

    test("disposing the guide clears the session and detaches it", () async {
      await start(recorded);
      container.dispose();

      expect(session().processingState, AudioProcessingState.idle);
      await run(handler.play);
      expect(narrator.resumeCount, 0);
    });
  });

  group("narrator phase to session state", () {
    NowPlaying at(
      NarratorPhase phase, {
      Duration? duration,
      bool canSeek = false,
      Duration position = Duration.zero,
      String? error,
    }) => NowPlaying(
      id: "callao/s1",
      stopTitle: "The mouth of the cave",
      narrator: NarratorState(
        phase: phase,
        duration: duration,
        canSeek: canSeek,
        position: position,
        error: error,
      ),
    );

    test("nothing loaded is idle, with no controls", () {
      final s = guidePlaybackState(null, wasPlaying: true);
      expect(s.processingState, AudioProcessingState.idle);
      expect(s.playing, isFalse);
      expect(s.controls, isEmpty);
    });

    test("loading is buffering, on its way to playing", () {
      final s = guidePlaybackState(
        at(NarratorPhase.loading),
        wasPlaying: false,
      );
      expect(s.processingState, AudioProcessingState.buffering);
      expect(s.playing, isTrue);
      expect(s.controls, contains(MediaControl.pause));
    });

    test("paused is ready and not playing, with play offered", () {
      final s = guidePlaybackState(at(NarratorPhase.paused), wasPlaying: true);
      expect(s.processingState, AudioProcessingState.ready);
      expect(s.playing, isFalse);
      expect(s.controls, [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ]);
    });

    test("between stops, playing is left as it was", () {
      for (final was in [true, false]) {
        final idle = guidePlaybackState(
          at(NarratorPhase.idle),
          wasPlaying: was,
        );
        expect(idle.processingState, AudioProcessingState.buffering);
        expect(idle.playing, was);
      }
      final done = guidePlaybackState(
        at(NarratorPhase.completed),
        wasPlaying: true,
      );
      expect(done.processingState, AudioProcessingState.completed);
      expect(done.playing, isTrue);
    });

    test("a recording can seek and reports where it is", () {
      final s = guidePlaybackState(
        at(
          NarratorPhase.playing,
          duration: const Duration(minutes: 2),
          canSeek: true,
          position: const Duration(seconds: 40),
        ),
        wasPlaying: true,
      );
      expect(
        s.systemActions,
        containsAll([
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        ]),
      );
      expect(s.updatePosition, const Duration(seconds: 40));
    });

    test("speech offers no seeking and claims no progress", () {
      final s = guidePlaybackState(at(NarratorPhase.playing), wasPlaying: true);
      expect(s.processingState, AudioProcessingState.ready);
      expect(s.systemActions, isEmpty);
      expect(s.updatePosition, Duration.zero);
      expect(guideMediaItem(at(NarratorPhase.playing))!.duration, isNull);
    });

    test("failed is an error, carrying the narrator's message", () {
      final s = guidePlaybackState(
        at(NarratorPhase.failed, error: "No engine."),
        wasPlaying: true,
      );
      expect(s.processingState, AudioProcessingState.error);
      expect(s.playing, isFalse);
      expect(s.errorMessage, "No engine.");
      expect(s.controls, [
        MediaControl.skipToPrevious,
        MediaControl.stop,
        MediaControl.skipToNext,
      ]);
    });
  });
}
