import "package:flutter/material.dart" show ThemeMode;
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../prefs/app_preferences.dart";

part "app_theme_mode.g.dart";

/// System, light or dark, chosen on the Profile tab and kept on the device.
@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() =>
      ref.watch(appPreferencesProvider)?.themeMode ?? ThemeMode.system;

  void select(ThemeMode mode) {
    state = mode;
    ref.read(appPreferencesProvider)?.setThemeMode(mode);
  }
}

/// Calmer motion, chosen in Settings. Added to the phone's own setting in
/// the app's builder (`disableAnimations`), so every motion widget that
/// already honours the phone honours this too, with nothing else to change.
@Riverpod(keepAlive: true)
class ReduceMotion extends _$ReduceMotion {
  @override
  bool build() => ref.watch(appPreferencesProvider)?.reduceMotion ?? false;

  void set(bool value) {
    state = value;
    ref.read(appPreferencesProvider)?.setReduceMotion(value);
  }
}

extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => "System",
    ThemeMode.light => "Light",
    ThemeMode.dark => "Dark",
  };
}
