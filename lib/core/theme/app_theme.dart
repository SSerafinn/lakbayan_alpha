import "package:flutter/material.dart";

// Endless Fun, Cagayan palette — never hardcode these elsewhere; use Theme.of(context).
const cagayanGreen = Color(0xFF1E7A3E);
const cagayanBlue = Color(0xFF115E9C);
const cagayanGold = Color(0xFFE29A0C);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: cagayanGreen,
    primary: cagayanGreen,
    secondary: cagayanBlue,
    tertiary: cagayanGold,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF6F9F6),
    appBarTheme: const AppBarTheme(centerTitle: true),
  );
}
