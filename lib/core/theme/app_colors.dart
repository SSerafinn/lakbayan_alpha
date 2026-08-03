import "package:flutter/material.dart";

/// Colour ramps from the Lakbayan design system (`tokens.json` v1.0.0).
///
/// Endless Fun, Cagayan: green for nature, blue for water, gold for warmth and
/// wonders. Ramp names match the design system exactly (`green/500`, `ink/900`)
/// so a value in Figma can be traced to a constant here without translation.
///
/// Prefer `Theme.of(context).colorScheme` and [LakbayanColors] in widgets — reach
/// for these raw constants only when building the theme itself.
abstract final class AppColors {
  // Primary — Cagayan Green.
  static const green900 = Color(0xFF0E2E1B);
  static const green700 = Color(0xFF123D24);
  static const green500 = Color(0xFF1E7A3E); // BASE
  static const green300 = Color(0xFF5AA575);
  static const green100 = Color(0xFFDCEBE0);
  static const green50 = Color(0xFFEFF6EF);

  // Secondary — River Blue. Links, map surfaces, secondary actions.
  static const blue700 = Color(0xFF0C4A7C);
  static const blue500 = Color(0xFF115E9C); // BASE
  static const blue300 = Color(0xFF4E90C6);
  static const blue100 = Color(0xFFDDEAF5);
  static const blue50 = Color(0xFFE9F1FA);

  // Accent — Cagayan Gold. Badges and highlights only; never a button.
  static const gold700 = Color(0xFFB87A08); // gold text on light
  static const gold500 = Color(0xFFE29A0C); // BASE
  static const gold300 = Color(0xFFF4C765);
  static const gold100 = Color(0xFFFBEFD2);

  // Neutrals.
  static const ink900 = Color(0xFF1E2733); // headings
  static const ink700 = Color(0xFF2C3A4B); // body
  static const slate500 = Color(0xFF6A7683); // secondary text
  static const slate300 = Color(0xFF9AA6B2); // placeholder / disabled
  static const line = Color(0xFFD9E4DA);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F9F6);

  // Semantic.
  static const success = green500;
  static const warning = gold500;
  static const error = Color(0xFFD14343);
  static const info = blue500;

  /// Green text on a light background must be /700 or darker to clear WCAG AA —
  /// green/500 on white is only 3.6:1. The design system calls this out
  /// explicitly; don't substitute [green500] here.
  static const textOnLightGreen = green700;

  // Dark mode (design system marks this v2 scope).
  static const darkBackground = Color(0xFF10201A);
  static const darkSurface = green900;
  static const darkText = Color(0xFFEAF2EC);

  // Additional fills used by badges in the specimen but absent from tokens.json.
  static const errorContainer = Color(0xFFFBE6E6);
  static const onErrorContainer = Color(0xFFB02F2F);
  static const disabledFill = Color(0xFFEDF1ED);
}
