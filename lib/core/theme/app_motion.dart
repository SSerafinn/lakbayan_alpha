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
}
