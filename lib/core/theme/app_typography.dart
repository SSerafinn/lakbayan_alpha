import "package:flutter/material.dart";

import "app_colors.dart";

/// The app's type ramp (`app.type` in tokens.json, 3.0.0). Two voices:
/// Cabinet Grotesk for headings, Satoshi for every word a person reads in the
/// UI. Styles are defined once here; colour is applied by the theme.
abstract final class AppTypography {
  static const family = "Satoshi";
  static const headingFamily = "CabinetGrotesk";

  /// The LAKBAYAN wordmark and the landing greetings. Not a ramp step, never
  /// body or UI text: it has no lowercase glyphs.
  static const brandFamily = "Barabara";

  /// Both faces are variable; `fontWeight` picks the named weight, `wght`
  /// carries the exact value.
  static TextStyle _style({
    required String face,
    required double size,
    required double weight,
    required double height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: face,
    fontSize: size,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation("wght", weight)],
    height: height,
    letterSpacing: letterSpacing,
  );

  // Headings, Cabinet Grotesk: tracking tightens as the size grows.

  /// A screen's large title, and a featured place's name on its card.
  static final display = _style(
    face: headingFamily,
    size: 28,
    weight: 800,
    height: 1.1,
    letterSpacing: -0.4,
  );

  /// A place's, a town's or a person's name on their own page.
  static final hero = _style(
    face: headingFamily,
    size: 26,
    weight: 800,
    height: 1.1,
    letterSpacing: -0.3,
  );

  /// A title in a bar or a sheet.
  static final titleLarge = _style(
    face: headingFamily,
    size: 20,
    weight: 700,
    height: 1.15,
    letterSpacing: -0.2,
  );

  /// A section heading, and a name on a photo tile.
  static final titleMedium = _style(
    face: headingFamily,
    size: 17,
    weight: 700,
    height: 1.2,
  );

  // UI words, Satoshi: 550 for reading, 650 for labels, never below 550.

  /// The small heading over a settings group.
  static final groupHeading = _style(
    face: family,
    size: 13,
    weight: 650,
    height: 1.3,
  );

  /// A row's, a card's or a small tile's name.
  static final titleSmall = _style(
    face: family,
    size: 15,
    weight: 650,
    height: 1.25,
  );

  /// Reading text: About, an exhibit's story, a narration's words.
  static final bodyLarge = _style(
    face: family,
    size: 15,
    weight: 550,
    height: 1.5,
  );

  /// The default body.
  static final bodyMedium = _style(
    face: family,
    size: 14,
    weight: 550,
    height: 1.4,
  );

  /// Buttons and controls.
  static final labelLarge = _style(
    face: family,
    size: 15,
    weight: 650,
    height: 1.2,
  );

  /// A detail's quieter second line and small metadata.
  static final secondLine = _style(
    face: family,
    size: 13,
    weight: 550,
    height: 1.3,
  );

  /// Chips, pills, a detail's label and the tab label.
  static final labelMedium = _style(
    face: family,
    size: 13,
    weight: 650,
    height: 1.3,
  );

  /// Captions.
  static final labelSmall = _style(
    face: family,
    size: 12,
    weight: 550,
    height: 1.3,
  );

  /// The landing greetings (Barabara). Uppercase only: lowercase glyphs fall
  /// back silently, so copy set here must be uppercase.
  static const brandDisplay = TextStyle(
    fontFamily: brandFamily,
    fontSize: 48,
    height: 1.16,
    letterSpacing: 1,
    color: AppColors.ink,
  );

  /// The LAKBAYAN wordmark. Same face as [brandDisplay], a step down.
  static const brandWordmark = TextStyle(
    fontFamily: brandFamily,
    fontSize: 42,
    height: 1.1,
    letterSpacing: 1.5,
    color: AppColors.ink,
  );

  /// Material [TextTheme] mapping, one ramp step per slot so stock widgets
  /// inherit the ramp. `headlineMedium` is a large app bar's expanded title.
  static TextTheme textTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: hero,
    headlineLarge: display,
    headlineMedium: display,
    headlineSmall: titleLarge,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: labelSmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}

/// Laid-out height of one line of a ramp step at the user's text size.
///
/// Scale each style independently — Android 14+ scales large text less than
/// small, so scaling a sum of heights as one font comes out short.
extension TextLineHeight on TextScaler {
  double lineHeightOf(TextStyle style) =>
      scale(style.fontSize!) * (style.height ?? 1);
}
