import "dart:async";

import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    show ProviderSubscription;
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../offline/domain/local_assets.dart";
import "../../offline/domain/offline_providers.dart";
import "../data/device_narrator.dart";
import "media_session.dart";
import "narration.dart";

part "audio_providers.g.dart";

/// Turns a Storage path into a playable URL.
///
/// A function rather than a repository so a test can substitute one line. It
/// lives here rather than reusing `storageUrlProvider` from
/// `core/widgets/content/storage_image.dart` on purpose: that one belongs to a
/// widget, and the domain layer importing a widget file to reach it would
/// invert the dependency the feature-first layout exists to keep straight.
typedef AudioUrlResolver = Future<String> Function(String storagePath);

/// Downloaded recording if there is one, otherwise a Storage download URL.
///
/// The local branch returns a `file://` URI rather than a bare path because
/// that is what `just_audio` parses — [DeviceNarrator] hands whatever comes
/// back to `setUrl`, and a plain path is not a URI it can resolve. Keeping the
/// return type a single string is what lets the narrator stay ignorant of where
/// a recording came from.
@Riverpod(keepAlive: true)
AudioUrlResolver audioUrlResolver(Ref ref) => (path) async {
  final store = ref.read(downloadStoreProvider);
  if (store.all.isNotEmpty) {
    final local = localAssetFor(store, ref.read(townDownloaderProvider), path);
    if (local != null) return local.uri.toString();
  }
  return FirebaseStorage.instance.ref(path).getDownloadURL();
};

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

/// The lock screen, notification and headset buttons, when `main()` managed
/// to start them.
///
/// Null by default, and in every test that does not ask for one — the same as
/// a phone where the service would not start, where the guide plays in the
/// app and nothing else changes. See `startGuideMediaSession`.
@Riverpod(keepAlive: true)
GuideMediaSession? guideMediaSession(Ref ref) => null;

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
///
/// Also the [GuideTransport] the media session drives, so the lock screen's
/// buttons run this class's methods and nothing of their own.
@riverpod
class AudioGuideController extends _$AudioGuideController
    implements GuideTransport {
  List<Segment> _queue = const [];
  String? _destinationId;

  /// Moved on by every start and every [stop]. A start that finds it moved
  /// while a recording's URL resolved — offline, Storage can retry for
  /// minutes — has been overtaken and starts nothing, so a guide the visitor
  /// stopped does not pipe up again with the screen off.
  int _generation = 0;

  /// A [pause] that came before there was anything to pause: a stop still
  /// loading, or the moment between one stop and the next. The lock screen
  /// offers Pause through both, so it is held and applied once the narrator
  /// plays rather than dropped.
  bool _pauseWhenPlaying = false;

  GuideMediaSession? _session;

  /// The place whose name the lock screen shows under the stop. Followed
  /// only while there is a session to show it.
  ProviderSubscription<AsyncValue<Destination?>>? _place;
  String? _placeId;

  /// Kept as it arrives rather than read on demand: [_nowPlaying] runs on
  /// every position tick, several a second, and the name rarely changes.
  String? _placeName;

  @override
  GuidePlayback build() {
    final narrator = ref.watch(narratorProvider);

    final sub = narrator.states.listen(_onNarratorState);
    ref.onDispose(sub.cancel);

    final session = _session = ref.watch(guideMediaSessionProvider);
    if (session != null) _join(session);

    return const GuidePlayback();
  }

  /// Hands [session] this controller's verbs and mirrors every state into it.
  ///
  /// Also keeps the controller alive while there is a session. Without one it
  /// still goes with the place screen, as it always has, and the guide falls
  /// quiet after the stop in progress. The notification outlives the screen,
  /// though, and a controller gone with it would leave the notification on a
  /// stop nothing advances from, its buttons reaching a fresh controller with
  /// no queue.
  void _join(GuideMediaSession session) {
    ref.keepAlive();
    session.attach(this);
    listenSelf((_, next) => session.show(_nowPlaying(next)));
    ref.onDispose(() {
      // ref.listen subscriptions close themselves on dispose; the id would
      // not, and would stop the next build from following the place again.
      _place = null;
      _placeId = null;
      _placeName = null;
      session.detach(this);
    });
  }

  /// Follows the place's document for its name, for as long as its guide is
  /// loaded. A listen rather than a one-off read, so a name still on its way
  /// lands when it arrives. It is the provider Place detail already watches,
  /// so this opens no second listener, and it reads from the cache offline.
  void _followPlace(String destinationId) {
    if (_placeId == destinationId) return;
    _place?.close();
    _placeId = destinationId;
    final provider = destinationByIdProvider(destinationId);
    final place = _place = ref.listen(provider, (_, next) {
      _placeName = next.value?.name;
      _session?.show(_nowPlaying(state));
    });
    _placeName = place.read().value?.name;
  }

  /// What the media session shows for [playback]. Null when no stop is loaded.
  NowPlaying? _nowPlaying(GuidePlayback playback) {
    final id = playback.segmentId;
    if (id == null) return null;
    final stop = _queue.where((s) => s.id == id).firstOrNull;
    return NowPlaying(
      id: "${playback.destinationId}/$id",
      stopTitle: stop?.title ?? "Audio guide",
      placeName: _placeName,
      narrator: playback.narrator,
    );
  }

  void _onNarratorState(NarratorState next) {
    // The provider can be disposed while an engine is still emitting — the
    // same disposal race that made sign-out print errors on every attempt.
    if (!ref.mounted) return;

    state = state.copyWith(narrator: next);

    if (next.phase == NarratorPhase.playing && _pauseWhenPlaying) {
      _pauseWhenPlaying = false;
      unawaited(ref.read(narratorProvider).pause());
    } else if (next.phase == NarratorPhase.completed) {
      unawaited(_advance());
    }
  }

  /// The stops after [segmentId] that can actually be played, in order.
  ///
  /// Skips rather than stops on an unplayable stop: an editor can leave one
  /// with neither a recording nor a script, and halting the tour there would
  /// look like a crash to someone walking between two caves.
  Iterable<Segment> _playableAfter(String? segmentId) {
    final from = _queue.indexWhere((s) => s.id == segmentId);
    if (from == -1) return const [];
    return _queue.skip(from + 1).where((s) => s.isPlayable);
  }

  /// The stops before [segmentId] that can be played, nearest first.
  Iterable<Segment> _playableBefore(String? segmentId) {
    final from = _queue.indexWhere((s) => s.id == segmentId);
    if (from <= 0) return const [];
    return _queue.sublist(0, from).reversed.where((s) => s.isPlayable);
  }

  Future<void> _advance() async {
    final next = _playableAfter(state.segmentId);
    if (next.isEmpty) {
      // End of the guide. Clear rather than leave the last stop looking
      // paused, which would invite a tap that restarts the whole thing.
      state = const GuidePlayback();
      return;
    }
    await _startFirst(_destinationId!, _queue, next);
  }

  /// Start [segment], making [segments] the queue for auto-advance.
  Future<void> play(
    String destinationId,
    List<Segment> segments,
    Segment segment,
  ) {
    _pauseWhenPlaying = false;
    return _startFirst(destinationId, segments, [segment]);
  }

  /// Starts the first of [candidates] that has something to say, making
  /// [segments] the queue from then on.
  ///
  /// Playable on paper is not always playable: a recording with no script,
  /// in a town not downloaded, with no signal, resolves to nothing. That stop
  /// is passed over like an empty one. When none of [candidates] has
  /// anything and the stop on show had already finished, the guide ends
  /// here. Left on `completed`, the media session would go on reporting
  /// playing, and hold its foreground service and wake lock with the screen
  /// off and nothing but Stop that answers.
  ///
  /// The queue and the place change only once a stop starts. Until then the
  /// old stop is the one playing, and the one auto-advance moves on from.
  Future<void> _startFirst(
    String destinationId,
    List<Segment> segments,
    Iterable<Segment> candidates,
  ) async {
    final generation = ++_generation;
    for (final segment in candidates) {
      final source = await _sourceFor(segment);
      if (generation != _generation || !ref.mounted) return;
      if (source == null) continue;

      _queue = segments;
      _destinationId = destinationId;
      if (_session != null) _followPlace(destinationId);
      state = GuidePlayback(
        destinationId: destinationId,
        segmentId: segment.id,
        narrator: const NarratorState(phase: NarratorPhase.loading),
      );
      await ref.read(narratorProvider).play(source);
      return;
    }
    if (state.narrator.phase == NarratorPhase.completed) {
      state = const GuidePlayback();
    }
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
    switch (state.narrator.phase) {
      case NarratorPhase.playing:
        return pause();
      case NarratorPhase.paused:
        return resume();
      case NarratorPhase.idle:
      case NarratorPhase.loading:
      case NarratorPhase.completed:
      case NarratorPhase.failed:
        return;
    }
  }

  /// Pause what is playing, or the stop about to play.
  ///
  /// A stop still loading, or the moment after one finishes, has nothing to
  /// pause yet: the narrator would start the next sound anyway, and the
  /// screen would say paused over a voice. The lock screen shows both as
  /// playing, with Pause, so the press is held until the narrator plays and
  /// applied then — see [_pauseWhenPlaying].
  @override
  Future<void> pause() async {
    switch (state.narrator.phase) {
      case NarratorPhase.playing:
        await ref.read(narratorProvider).pause();
      case NarratorPhase.loading:
      case NarratorPhase.completed:
      case NarratorPhase.idle:
        // Idle with no stop loaded is a guide at rest, not between stops.
        _pauseWhenPlaying = state.segmentId != null;
      case NarratorPhase.paused:
      case NarratorPhase.failed:
        break;
    }
  }

  /// Carry on with a paused stop, or call off a pause still waiting for one.
  /// Never starts a stop: that needs the list it came from, which only the
  /// screen has.
  @override
  Future<void> resume() async {
    _pauseWhenPlaying = false;
    if (state.narrator.phase == NarratorPhase.paused) {
      await ref.read(narratorProvider).resume();
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _pauseWhenPlaying = false;
    await ref.read(narratorProvider).stop();
    if (ref.mounted) state = const GuidePlayback();
  }

  @override
  Future<void> seek(Duration position) =>
      ref.read(narratorProvider).seek(position);

  @override
  Future<void> skipNext() => _skipTo(_playableAfter(state.segmentId));

  @override
  Future<void> skipPrevious() => _skipTo(_playableBefore(state.segmentId));

  /// Walks to the first of [stops] that will play, past any that will not,
  /// as auto-advance does. Does nothing at either end of the guide.
  Future<void> _skipTo(Iterable<Segment> stops) async {
    if (stops.isEmpty) return;
    _pauseWhenPlaying = false;
    await _startFirst(_destinationId!, _queue, stops);
  }
}
