import "dart:async";

import "package:lakbayan/features/audio/domain/narration.dart";

/// A [Narrator] with no plugins behind it.
///
/// `just_audio` and `flutter_tts` are both platform channels, so neither runs
/// in a widget test — the whole reason the [Narrator] interface exists. This
/// records what it was asked to do and lets a test drive the phase by hand,
/// including the one transition that is hard to provoke for real: reaching the
/// end of a stop.
class FakeNarrator implements Narrator {
  final _controller = StreamController<NarratorState>.broadcast();

  /// Every source played, in order. The assertion surface for "did the guide
  /// choose the recording or the script".
  final played = <NarrationSource>[];

  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  Duration? lastSeek;
  bool disposed = false;

  /// Set to throw from [play], to exercise the failure path.
  Object? playError;

  /// While set, [play] holds at loading until this completes — a recording
  /// buffering on a slow connection.
  Completer<void>? buffering;

  NarratorState _state = const NarratorState();

  @override
  NarratorState get state => _state;

  @override
  Stream<NarratorState> get states => _controller.stream;

  void _emit(NarratorState next) {
    _state = next;
    _controller.add(next);
  }

  /// Pretend the current narration finished on its own — what makes the
  /// controller advance to the next stop.
  void complete() => _emit(_state.copyWith(phase: NarratorPhase.completed));

  /// Pretend the engine gave up, the way [Narrator] reports it: a phase and a
  /// message, not a throw.
  void fail(String message) =>
      _emit(NarratorState(phase: NarratorPhase.failed, error: message));

  /// Pretend a recording reported its length, so a scrubber can be drawn.
  void ready({Duration? duration, bool canSeek = true}) => _emit(
    NarratorState(
      phase: NarratorPhase.playing,
      duration: duration,
      canSeek: canSeek,
    ),
  );

  @override
  Future<void> play(NarrationSource source) async {
    if (playError case final e?) throw e;
    played.add(source);
    // The steps the real one takes: it stops whatever was going, which reads
    // as idle, then loads. The media session has to hold steady through both
    // between stops, so the fake walks through them too.
    _emit(const NarratorState());
    _emit(const NarratorState(phase: NarratorPhase.loading));
    await buffering?.future;
    // Speech reports no duration and cannot seek — the distinction the UI
    // reads, so the fake has to reproduce it or the tests prove nothing.
    _emit(
      NarratorState(
        phase: NarratorPhase.playing,
        canSeek: source is RecordedNarration,
        duration: source is RecordedNarration
            ? const Duration(minutes: 2)
            : null,
      ),
    );
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _emit(_state.copyWith(phase: NarratorPhase.paused));
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    _emit(_state.copyWith(phase: NarratorPhase.playing));
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _emit(const NarratorState());
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _emit(_state.copyWith(position: position));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}
