import "package:flutter/material.dart";
import "package:motor/motor.dart";

/// The app's motion: two springs and one fade (`my-docs/design/PREFERENCES.md`).
/// Both snap to their end so a settled `t` is exactly 0 or 1, and both
/// overshoot on the way, so clamp anything that feeds an `Opacity`.
///
/// Reach for these first. A screen that genuinely needs a third motion
/// declares it in its own presentation file with a comment saying why; it
/// is not added here.
abstract final class AppMotion {
  /// The interface changing on its own: tab bar, search capsule, chrome.
  static const chrome = CupertinoMotion.snappy(
    duration: Duration(milliseconds: 350),
    snapToEnd: true,
  );

  /// Something arriving with weight: a card landing, a thumbnail popping in.
  static const arrive = CupertinoMotion.bouncy(
    duration: Duration(milliseconds: 400),
    snapToEnd: true,
  );

  /// Opacity fades only: the scroll edge, the reduced-motion cross-fade.
  static const edge = Durations.short4;

  /// A quick nudge that follows a drag: the sign-in sheet settling back.
  /// Half of [edge]; still a fade-length, not a third spring.
  static const nudge = Durations.short2;

  /// How far a pressed card, tile or button sinks under the finger. Not a
  /// motion: `chrome` carries it there and back (`Pressable`).
  static const pressScale = 0.96;

  /// How long a built-in that takes a duration runs when it is handed a
  /// spring as a `SpringCurve` (a page step, a dialog, a scroll, a fold):
  /// long enough for `chrome` to settle inside it. Not a third motion.
  static const span = Duration(milliseconds: 420);

  /// A release faster than this, in px/s, is a deliberate fling: it decides
  /// whatever the distance (the swipe deck, dismissing the player sheet).
  static const flingSpeed = 700.0;
}
