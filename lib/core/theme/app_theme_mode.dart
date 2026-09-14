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

extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => "System",
    ThemeMode.light => "Light",
    ThemeMode.dark => "Dark",
  };
}
