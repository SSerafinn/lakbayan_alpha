import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_tts/flutter_tts.dart";
import "package:just_audio/just_audio.dart";

import "../domain/narration.dart";

/// The real [Narrator]: `just_audio` for recordings, `flutter_tts` for scripts.
///
/// One class rather than two behind a dispatcher, because the two engines are
/// not independent — starting one **must** stop the other, and splitting them
/// makes that the caller's problem to remember. Here it is structural: every
/// [play] begins by stopping whatever was going.
///
/// Neither plugin works in a widget test — both are platform channels — which
/// is why [Narrator] exists at all and why every test uses a fake.
class DeviceNarrator implements Narrator {
  DeviceNarrator({AudioPlayer? player, FlutterTts? tts})
    : _player = player ?? AudioPlayer(),
      _tts = tts ?? FlutterTts() {
    _wireRecorded();
    _wireSpeech();
  }

  final AudioPlayer _player;
  final FlutterTts _tts;

  final _controller = StreamController<NarratorState>.broadcast();
  NarratorState _state = const NarratorState();

  /// Which engine owns the current source. Speech reports no duration and
  /// cannot seek, so the state we publish differs by more than the phase.
  bool _speaking = false;

  /// Set when a pause had to be faked by stopping.
  ///
  /// Android TTS has no native pause. `flutter_tts` works around it using
  /// `onRangeStart`, which needs **API 26 or newer**; below that its `pause()`
  /// reports failure. A silent no-op would leave the UI showing "paused" over
  /// a voice that is still talking, so when it fails we stop instead and
  /// re-speak from the top of the stop on resume. Losing your place in a
  /// paragraph is a smaller lie than a button that does nothing.
  bool _resumeBySpeakingAgain = false;
  String? _lastSpokenText;

  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  Stream<NarratorState> get states => _controller.stream;

  @override
  NarratorState get state => _state;

  void _emit(NarratorState next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  void _wireRecorded() {
    _subscriptions.add(
      _player.playerStateStream.listen((s) {
        if (_speaking) return;
        final phase = switch (s.processingState) {
          ProcessingState.idle => NarratorPhase.idle,
          ProcessingState.loading ||
          ProcessingState.buffering => NarratorPhase.loading,
          // `completed` outranks `playing`: just_audio leaves `playing` true
          // when a track ends, and reading it first would mean the guide never
          // advanced to the next stop.
          ProcessingState.completed => NarratorPhase.completed,
          ProcessingState.ready =>
            s.playing ? NarratorPhase.playing : NarratorPhase.paused,
        };
        _emit(_state.copyWith(phase: phase));
      }),
    );

    _subscriptions.add(
      _player.positionStream.listen((p) {
        if (!_speaking) _emit(_state.copyWith(position: p));
      }),
    );

    _subscriptions.add(
      _player.durationStream.listen((d) {
        if (!_speaking && d != null) _emit(_state.copyWith(duration: d));
      }),
    );
  }

  void _wireSpeech() {
    _tts
      ..setStartHandler(() {
        if (_speaking) _emit(_state.copyWith(phase: NarratorPhase.playing));
      })
      ..setCompletionHandler(() {
        if (_speaking) _emit(_state.copyWith(phase: NarratorPhase.completed));
      })
      // `dynamic`, not Object: flutter_tts declares
      // `typedef ErrorHandler = void Function(dynamic message)`, and a
      // narrower parameter type will not satisfy it.
      ..setErrorHandler((dynamic message) {
        if (_speaking) {
          _emit(
            _state.copyWith(
              phase: NarratorPhase.failed,
              error: "The device could not read this out: $message",
            ),
          );
        }
      });
  }

  @override
  Future<void> play(NarrationSource source) async {
    await stop();
    // Reset rather than copyWith: the previous source's duration and seekability
    // must not leak into this one. A recording followed by a script would keep
    // drawing the recording's scrubber.
    _emit(const NarratorState(phase: NarratorPhase.loading));

    try {
      switch (source) {
        case RecordedNarration(:final url):
          _speaking = false;
          final duration = await _player.setUrl(url);
          _emit(
            _state.copyWith(
              duration: duration,
              canSeek: true,
              phase: NarratorPhase.playing,
            ),
          );
          // NOT awaited: just_audio's play() completes when playback *ends*,
          // so awaiting it here would hold this method open for the length of
          // the recording and make the caller think it was still loading.
          unawaited(_player.play());

        case SpokenNarration(:final text):
          _speaking = true;
          _lastSpokenText = text;
          _resumeBySpeakingAgain = false;
          // Duration stays null and canSeek stays false — the engine reports
          // neither, and the player draws an indeterminate bar because of it.
          _emit(_state.copyWith(phase: NarratorPhase.playing));
          await _tts.speak(text);
      }
    } catch (e) {
      _emit(
        NarratorState(
          phase: NarratorPhase.failed,
          error: "This narration would not play. $e",
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    if (_speaking) {
      var paused = false;
      try {
        // flutter_tts returns 1 for success on the platforms that support it.
        paused = await _tts.pause() == 1;
      } catch (_) {
        paused = false;
      }
      if (!paused) {
        await _tts.stop();
        _resumeBySpeakingAgain = true;
      }
    } else {
      await _player.pause();
    }
    _emit(_state.copyWith(phase: NarratorPhase.paused));
  }

  @override
  Future<void> resume() async {
    if (_speaking) {
      if (_resumeBySpeakingAgain && _lastSpokenText != null) {
        _resumeBySpeakingAgain = false;
        _emit(_state.copyWith(phase: NarratorPhase.playing));
        await _tts.speak(_lastSpokenText!);
        return;
      }
      await _tts.speak(_lastSpokenText ?? "");
    } else {
      unawaited(_player.play());
    }
    _emit(_state.copyWith(phase: NarratorPhase.playing));
  }

  @override
  Future<void> stop() async {
    // Both, unconditionally. `_speaking` says which engine *should* be running;
    // if it is ever wrong the other one keeps talking over the next stop, and
    // that failure is far worse than a redundant call to an idle plugin.
    await _tts.stop();
    await _player.stop();
    _resumeBySpeakingAgain = false;
    _emit(const NarratorState());
  }

  @override
  Future<void> seek(Duration position) async {
    if (_speaking) return; // No seeking in speech. Callers check canSeek.
    await _player.seek(position);
  }

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    try {
      await _tts.stop();
      await _player.dispose();
    } catch (e) {
      debugPrint("Narrator disposal: $e");
    }
    await _controller.close();
  }
}
