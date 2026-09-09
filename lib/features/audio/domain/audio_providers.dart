import "dart:async";

import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "../data/device_narrator.dart";
import "narration.dart";

part "audio_providers.g.dart";

/// Turns a Storage path into a playable URL.
///
/// A function rather than a repository so a test can substitute one line. It
/// lives here rather than reusing `storageUrlProvider` from
/// `core/widgets/storage_image.dart` on purpose: that one belongs to a widget,
/// and the domain layer importing a widget file to reach it would invert the
/// dependency the feature-first layout exists to keep straight.
typedef AudioUrlResolver = Future<String> Function(String storagePath);

@Riverpod(keepAlive: true)
AudioUrlResolver audioUrlResolver(Ref ref) =>
    (path) => FirebaseStorage.instance.ref(path).getDownloadURL();

/// The single narrator for the app.
///
/// `keepAlive` because there is exactly one pair of audio engines on a device
/// and playback must survive the screen that started it — leaving a stop mid
/// sentence when a list rebuilds would be its own bug. Overridden with a fake
/// in every widget test.
@Riverpod(keepAlive: true)
Narrator narrator(Ref ref) {
  final narrator = DeviceNarrator();
  ref.onDispose(narrator.dispose);
  return narrator;
}

/// What the audio guide is doing, for the UI to render.
@immutable
class GuidePlayback {
  const GuidePlayback({
    this.destinationId,
    this.segmentId,
    this.narrator = const NarratorState(),
  });

  /// Which destination's guide is loaded. Lets a second destination's list
  /// render idle while the first is still playing.
  final String? destinationId;

  final String? segmentId;
  final NarratorState narrator;

  bool isCurrent(String id) => segmentId == id;

  bool isPlaying(String id) =>
      isCurrent(id) && narrator.phase == NarratorPhase.playing;

  bool isLoading(String id) =>
      isCurrent(id) && narrator.phase == NarratorPhase.loading;

  GuidePlayback copyWith({
    String? destinationId,
    String? segmentId,
    NarratorState? narrator,
  }) => GuidePlayback(
    destinationId: destinationId ?? this.destinationId,
    segmentId: segmentId ?? this.segmentId,
    narrator: narrator ?? this.narrator,
  );
}

/// Drives the audio guide: what is playing, and what plays next.
///
/// Holds the queue as a field rather than in [state] because it is not
/// something the UI renders — the list on screen comes from Firestore, and
/// duplicating it into state would give two copies to keep in step.
@riverpod
class AudioGuideController extends _$AudioGuideController {
  List<Segment> _queue = const [];
  String? _destinationId;

  @override
  GuidePlayback build() {
    final narrator = ref.watch(narratorProvider);

    final sub = narrator.states.listen(_onNarratorState);
    ref.onDispose(sub.cancel);

    return const GuidePlayback();
  }

  void _onNarratorState(NarratorState next) {
    // The provider can be disposed while an engine is still emitting — the
    // same disposal race that made sign-out print errors on every attempt.
    if (!ref.mounted) return;

    state = state.copyWith(narrator: next);

    if (next.phase == NarratorPhase.completed) {
      unawaited(_advance());
    }
  }

  /// The next stop that can actually be played.
  ///
  /// Skips rather than stops on an unplayable stop: an editor can leave one
  /// with neither a recording nor a script, and halting the tour there would
  /// look like a crash to someone walking between two caves.
  Segment? _nextPlayableAfter(String? segmentId) {
    final from = _queue.indexWhere((s) => s.id == segmentId);
    if (from == -1) return null;
    for (var i = from + 1; i < _queue.length; i++) {
      if (_queue[i].isPlayable) return _queue[i];
    }
    return null;
  }

  Future<void> _advance() async {
    final next = _nextPlayableAfter(state.segmentId);
    if (next == null) {
      // End of the guide. Clear rather than leave the last stop looking
      // paused, which would invite a tap that restarts the whole thing.
      state = const GuidePlayback();
      return;
    }
    await play(_destinationId!, _queue, next);
  }

  /// Start [segment], making [segments] the queue for auto-advance.
  Future<void> play(
    String destinationId,
    List<Segment> segments,
    Segment segment,
  ) async {
    _queue = segments;
    _destinationId = destinationId;

    final source = await _sourceFor(segment);
    if (source == null) return;
    if (!ref.mounted) return;

    state = GuidePlayback(
      destinationId: destinationId,
      segmentId: segment.id,
      narrator: const NarratorState(phase: NarratorPhase.loading),
    );
    await ref.read(narratorProvider).play(source);
  }

  /// Recording if there is one, otherwise the script. Null when neither.
  ///
  /// The preference order is the data model's: `audioUrl` is a real narrator,
  /// `ttsText` is the device reading a script aloud, and a stop that has both
  /// should use the human.
  Future<NarrationSource?> _sourceFor(Segment segment) async {
    final path = segment.audioUrl;
    if (path != null && path.isNotEmpty) {
      try {
        final url = await ref.read(audioUrlResolverProvider)(path);
        return RecordedNarration(url);
      } catch (e) {
        // Fall through to the script rather than failing: a missing object in
        // Storage should not silence a stop that also has text.
        debugPrint("Audio for segment '${segment.id}' did not resolve: $e");
      }
    }
    final text = segment.ttsText;
    if (text != null && text.trim().isNotEmpty) return SpokenNarration(text);
    return null;
  }

  /// Play, pause or resume, depending on what this stop is already doing.
  Future<void> toggle(
    String destinationId,
    List<Segment> segments,
    Segment segment,
  ) async {
    final narrator = ref.read(narratorProvider);
    if (state.isCurrent(segment.id)) {
      switch (state.narrator.phase) {
        case NarratorPhase.playing:
          return narrator.pause();
        case NarratorPhase.paused:
          return narrator.resume();
        case NarratorPhase.idle:
        case NarratorPhase.loading:
        case NarratorPhase.completed:
        case NarratorPhase.failed:
          break;
      }
    }
    return play(destinationId, segments, segment);
  }

  /// Pause or resume whatever is running, without touching the queue.
  ///
  /// Separate from [toggle] because the player bar has no segment list to hand
  /// back: passing an empty one would clear the queue and silently kill
  /// auto-advance for the rest of the guide.
  Future<void> togglePlayPause() async {
    final narrator = ref.read(narratorProvider);
    switch (state.narrator.phase) {
      case NarratorPhase.playing:
        return narrator.pause();
      case NarratorPhase.paused:
        return narrator.resume();
      case NarratorPhase.idle:
      case NarratorPhase.loading:
      case NarratorPhase.completed:
      case NarratorPhase.failed:
        return;
    }
  }

  Future<void> stop() async {
    await ref.read(narratorProvider).stop();
    if (ref.mounted) state = const GuidePlayback();
  }

  Future<void> seek(Duration position) =>
      ref.read(narratorProvider).seek(position);

  Future<void> skipNext() async {
    final next = _nextPlayableAfter(state.segmentId);
    if (next != null) await play(_destinationId!, _queue, next);
  }

  Future<void> skipPrevious() async {
    final from = _queue.indexWhere((s) => s.id == state.segmentId);
    if (from <= 0) return;
    for (var i = from - 1; i >= 0; i--) {
      if (_queue[i].isPlayable) {
        await play(_destinationId!, _queue, _queue[i]);
        return;
      }
    }
  }
}
