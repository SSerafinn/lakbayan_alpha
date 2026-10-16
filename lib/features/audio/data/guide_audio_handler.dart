import "dart:async";

import "package:audio_service/audio_service.dart";
import "package:flutter/foundation.dart";

import "../domain/media_session.dart";
import "../domain/narration.dart";

/// Registers the audio guide with the system's media session, or returns null.
///
/// Never throws, and gives up after [timeout]: a lock screen is worth having,
/// but not worth an app that will not open. Null leaves the guide exactly as it
/// was before there was a session — it plays in the app, and stops being heard
/// once the system decides a backgrounded app has had long enough. The
/// Android side needs the service, receiver and permissions in
/// `AndroidManifest.xml` and `MainActivity` extending `AudioServiceActivity`;
/// without them this fails here, with a line in the log, rather than later.
///
/// A start that times out may still finish later. Its handler then has no
/// guide attached and shows nothing, and the plugin will not start twice, so
/// that launch goes without a lock screen. `main()` starts this first and
/// waits for it last, so the timeout mostly runs out behind the rest of the
/// boot rather than in front of the splash.
Future<GuideAudioHandler?> startGuideMediaSession({
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    return await AudioService.init(
      builder: GuideAudioHandler.new,
      config: const AudioServiceConfig(
        // Named once and kept: Android files the user's notification settings
        // under this id, and renaming it strands them on an orphaned channel.
        androidNotificationChannelId: "ph.gov.cagayan.lakbayan.audio",
        androidNotificationChannelName: "Audio guide",
        androidNotificationChannelDescription:
            "The stop playing, with its controls, while the audio guide runs.",
        // `androidStopForegroundOnPause` stays at its default, true: a paused
        // guide lets go of its wake lock and its notification can be swiped
        // away. The price is that `playing` must not fall between stops, or
        // the service drops out of the foreground — see guidePlaybackState.
      ),
    ).timeout(timeout);
  } catch (e) {
    debugPrint(
      "Media session unavailable, the guide plays in the app only: $e",
    );
    return null;
  }
}

/// The audio guide as `audio_service` sees it: the lock screen, the
/// notification and headset or Bluetooth buttons.
///
/// It owns no playback and keeps no queue. Every command goes to the attached
/// [GuideTransport] — the controller the in-app player drives — and what the
/// system shows is whatever that controller last [show]ed, translated. So the
/// screen and the lock screen cannot disagree: there is one source of truth,
/// and this is a view of it.
///
/// Built with no arguments because `AudioService.init` builds it before the
/// provider tree exists; the controller attaches itself once it does.
class GuideAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements GuideMediaSession {
  GuideTransport? _transport;
  NowPlaying? _now;

  @override
  void attach(GuideTransport transport) => _transport = transport;

  @override
  void detach(GuideTransport transport) {
    if (!identical(_transport, transport)) return;
    _transport = null;
    show(null);
  }

  @override
  void show(NowPlaying? now) {
    _now = now;

    final item = guideMediaItem(now);
    if (!_sameItem(mediaItem.value, item)) mediaItem.add(item);

    final current = playbackState.value;
    final next = guidePlaybackState(now, wasPlaying: current.playing);
    if (!_sameState(current, next)) playbackState.add(next);
  }

  @override
  Future<void> play() async => await _transport?.resume();

  @override
  Future<void> pause() async => await _transport?.pause();

  /// With nothing attached there is nothing to stop, but the system may still
  /// believe something is playing, so it is told otherwise.
  @override
  Future<void> stop() async {
    final transport = _transport;
    if (transport == null) {
      show(null);
      return;
    }
    await transport.stop();
  }

  /// Dropped for speech, which has no timeline. No seek bar is offered for
  /// it, but a headset's fast-forward can still arrive.
  @override
  Future<void> seek(Duration position) async {
    if (_now?.narrator.canSeek ?? false) await _transport?.seek(position);
  }

  @override
  Future<void> skipToNext() async => await _transport?.skipNext();

  @override
  Future<void> skipToPrevious() async => await _transport?.skipPrevious();
}

/// What the lock screen shows for [now]: the stop, and the place under it.
///
/// [MediaItem.duration] is the narrator's, so null for speech — Android draws
/// a progress bar only when there is a duration, and a script read aloud has
/// none to give.
@visibleForTesting
MediaItem? guideMediaItem(NowPlaying? now) => now == null
    ? null
    : MediaItem(
        id: now.id,
        title: now.stopTitle,
        artist: now.placeName,
        album: "Audio guide",
        duration: now.narrator.duration,
      );

/// The narrator's state, in the session's terms.
///
/// [wasPlaying] is the `playing` last published, and it matters for the two
/// phases that sit *between* stops. The narrator passes through idle at every
/// change of stop — `DeviceNarrator.play` begins by stopping — and reports
/// completed just before the controller moves on. Neither may flip `playing`.
/// `audio_service` takes a fall in `playing` as the cue to drop the
/// foreground service, and Android 12 and later will not let a backgrounded
/// app start it again, so the next stop would never be heard. For the same
/// reason idle maps to idle only when nothing is loaded at all: the plugin
/// tears the whole service down on entering idle.
///
/// Speech cannot be scrubbed, so it gets no seek actions and no position;
/// projecting progress for it would be the fabrication the in-app player
/// already refuses to draw.
@visibleForTesting
PlaybackState guidePlaybackState(NowPlaying? now, {required bool wasPlaying}) {
  if (now == null) return PlaybackState();

  final narrator = now.narrator;
  final (processing, playing) = switch (narrator.phase) {
    NarratorPhase.loading => (AudioProcessingState.buffering, true),
    NarratorPhase.playing => (AudioProcessingState.ready, true),
    NarratorPhase.paused => (AudioProcessingState.ready, false),
    NarratorPhase.completed => (AudioProcessingState.completed, wasPlaying),
    NarratorPhase.idle => (AudioProcessingState.buffering, wasPlaying),
    NarratorPhase.failed => (AudioProcessingState.error, false),
  };
  final failed = narrator.phase == NarratorPhase.failed;
  final seekable = narrator.canSeek && narrator.duration != null;

  return PlaybackState(
    processingState: processing,
    playing: playing,
    // The in-app player's transport, in its order. A failed stop has no play
    // button here because it has none that works in the app either: resume
    // only carries on, and there is nothing to carry on.
    controls: [
      MediaControl.skipToPrevious,
      if (!failed) playing ? MediaControl.pause : MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ],
    // Previous, play or pause, next; stop waits for the expanded view.
    androidCompactActionIndices: failed ? const [0, 1, 2] : const [0, 1, 3],
    systemActions: seekable
        ? const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          }
        : const {},
    updatePosition: seekable ? narrator.position : Duration.zero,
    errorMessage: failed
        ? (narrator.error ?? "This stop would not play.")
        : null,
  );
}

/// How far the reported position may stray from the session's projection
/// before it is sent again.
const _drift = Duration(seconds: 1);

/// Whether [next] tells the system nothing [current] has not.
///
/// The narrator reports its position several times a second, and the plugin
/// asks that the session not: listeners project position from the last update.
/// So a state that differs only by how far playback has got is dropped, unless
/// it has strayed from that projection — a seek in the app, or a stall.
bool _sameState(PlaybackState current, PlaybackState next) =>
    current.processingState == next.processingState &&
    current.playing == next.playing &&
    listEquals(current.controls, next.controls) &&
    listEquals(
      current.androidCompactActionIndices,
      next.androidCompactActionIndices,
    ) &&
    setEquals(current.systemActions, next.systemActions) &&
    current.errorMessage == next.errorMessage &&
    (!next.systemActions.contains(MediaAction.seek) ||
        (current.position - next.updatePosition).abs() < _drift);

/// [MediaItem]'s own `==` compares ids only, which would miss the place name
/// arriving or a recording reporting its length.
bool _sameItem(MediaItem? a, MediaItem? b) =>
    a?.id == b?.id &&
    a?.title == b?.title &&
    a?.artist == b?.artist &&
    a?.duration == b?.duration;
