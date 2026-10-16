import "package:flutter/foundation.dart";

import "narration.dart";

/// What the system's media controls can ask the guide to do.
///
/// These are the in-app player's own verbs, and `AudioGuideController`
/// implements them, so a press on the lock screen, the notification or a
/// headset runs exactly the code a tap in the app does. A session that kept
/// its own copy of "what is playing" would sooner or later disagree with the
/// screen, and there is no good answer to which of the two is lying.
abstract interface class GuideTransport {
  /// Pause what is playing, or the stop about to play. Nothing otherwise.
  Future<void> pause();

  /// Carry on with a paused stop. Never starts one from scratch.
  Future<void> resume();

  Future<void> stop();

  /// Does nothing for speech, which cannot be scrubbed.
  Future<void> seek(Duration position);

  Future<void> skipNext();
  Future<void> skipPrevious();
}

/// The stop the system should show, as the guide sees it.
@immutable
class NowPlaying {
  const NowPlaying({
    required this.id,
    required this.stopTitle,
    required this.narrator,
    this.placeName,
  });

  /// Destination and stop together, unique across every guide.
  final String id;

  final String stopTitle;

  /// Null until the place has been read. The lock screen shows the stop alone
  /// rather than waiting for it.
  final String? placeName;

  final NarratorState narrator;
}

/// The lock screen, notification and headset buttons, seen from the guide.
///
/// An interface for the same reason [Narrator] is one: the real thing is
/// `audio_service`, a platform plugin that does nothing in a test, and the
/// guide should not have to know it is there. Null in the provider tree when
/// the service would not start, and the guide then plays in the app only.
abstract interface class GuideMediaSession {
  /// Route the system's commands to [transport] from now on.
  void attach(GuideTransport transport);

  /// Stop routing to [transport], and clear what the system shows. Ignored
  /// unless [transport] is the one attached.
  void detach(GuideTransport transport);

  /// Mirror [now] into the system. Null when nothing is loaded.
  void show(NowPlaying? now);
}
