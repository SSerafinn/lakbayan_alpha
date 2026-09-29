import "package:flutter/foundation.dart";

/// What a narrator is being asked to say.
///
/// A sealed type rather than a nullable url plus a nullable text, because the
/// two are genuinely different things with different capabilities — one can be
/// scrubbed and one cannot — and a switch over this forces every call site to
/// decide what it does about that.
sealed class NarrationSource {
  const NarrationSource();
}

/// A recording, already resolved from a Storage path to a download URL.
///
/// Resolution happens in the controller, not here: it keeps the narrator free
/// of Firebase, which is what makes it fakeable in a widget test.
class RecordedNarration extends NarrationSource {
  const RecordedNarration(this.url);

  final String url;

  @override
  bool operator ==(Object other) =>
      other is RecordedNarration && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Text for the device's speech engine — the fallback when a stop has a script
/// but no recording. `docs/DATA_MODEL.md` allows either.
class SpokenNarration extends NarrationSource {
  const SpokenNarration(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is SpokenNarration && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

enum NarratorPhase {
  idle,

  /// Fetching or preparing. Recorded audio only — speech starts immediately.
  loading,
  playing,
  paused,

  /// Reached the end on its own, as opposed to being stopped. The controller
  /// uses this and only this to advance to the next stop.
  completed,
  failed,
}

/// What the narrator is doing right now.
///
/// [duration] and [canSeek] are **nullable and false respectively for speech**,
/// and that is the point rather than an oversight. A text-to-speech engine
/// reports no length and cannot be scrubbed, so a player that assumes both
/// would draw a progress bar that is a fabrication. The UI reads these and
/// degrades instead.
@immutable
class NarratorState {
  const NarratorState({
    this.phase = NarratorPhase.idle,
    this.position = Duration.zero,
    this.duration,
    this.canSeek = false,
    this.error,
  });

  final NarratorPhase phase;
  final Duration position;

  /// Null when unknown — speech, or a stream still loading its header.
  final Duration? duration;

  /// False for speech. Drives whether a scrubber is drawn at all.
  final bool canSeek;

  final String? error;

  NarratorState copyWith({
    NarratorPhase? phase,
    Duration? position,
    Duration? duration,
    bool? canSeek,
    String? error,
  }) => NarratorState(
    phase: phase ?? this.phase,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    canSeek: canSeek ?? this.canSeek,
    error: error ?? this.error,
  );
}

/// Plays one piece of narration at a time.
///
/// Deliberately knows nothing about segments, destinations or Firebase — it is
/// handed a [NarrationSource] and reports what it is doing. That boundary is
/// what lets the whole audio guide be driven by a fake in widget tests, which
/// matters here more than usual: the real implementation is two platform
/// plugins, and neither works in a test harness.
///
/// **Not wired to `audio_service` yet.** Background and lock-screen playback
/// need a foreground service, manifest entries and a background isolate; this
/// interface is the thing such a handler would delegate to when that lands.
abstract interface class Narrator {
  Stream<NarratorState> get states;

  /// Current state, for a listener that has just subscribed.
  NarratorState get state;

  Future<void> play(NarrationSource source);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  /// No-op when the current source cannot seek. Callers should check
  /// [NarratorState.canSeek] rather than relying on this failing quietly.
  Future<void> seek(Duration position);

  Future<void> dispose();
}
