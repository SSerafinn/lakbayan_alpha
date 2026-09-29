import "package:flutter/material.dart";

import "app_colors.dart";

/// The app's type ramp. One face (Satoshi, variable) with styles defined once
/// here so every widget picks from the same set. Colour is applied by the theme.
abstract final class AppTypography {
  static const family = "Satoshi";

  /// Brand voice for the landing greetings and the LAKBAYAN wordmark. Not a
  /// ramp step, never body or UI text: it is a Philippine tourism trademark
  /// face, and it has no lowercase glyphs.
  static const brandFamily = "Barabara";

  /// Headings tighten as they grow; the repo's own scale says the same.
  static TextStyle _heading({
    required double size,
    required double weight,
    required double height,
    required double letterSpacing,
  }) => _style(
    size: size,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle _body({
    required double size,
    required double weight,
    required double height,
    double letterSpacing = 0,
  }) => _style(
    size: size,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Satoshi is variable; `fontWeight` picks the named weight, `wght` carries the exact value.
  static TextStyle _style({
    required double size,
    required double weight,
    required double height,
    required double letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation("wght", weight)],
    height: height,
    letterSpacing: letterSpacing,
  );

  // Headings: negative tracking that eases as the size drops.

  /// An editorial opener. One per screen at most.
  static final display = _heading(
    size: 38,
    weight: 800,
    height: 1.05,
    letterSpacing: -1.1,
  );

  /// A place name over its photo.
  static final hero = _heading(
    size: 28,
    weight: 750,
    height: 1.1,
    letterSpacing: -0.6,
  );

  /// The screen's title.
  static final titleLarge = _heading(
    size: 24,
    weight: 750,
    height: 1.1,
    letterSpacing: -0.4,
  );

  /// A section heading.
  static final titleMedium = _heading(
    size: 19,
    weight: 750,
    height: 1.15,
    letterSpacing: -0.2,
  );

  /// A heading over a grouped section.
  static final groupHeading = _heading(
    size: 17,
    weight: 750,
    height: 1.25,
    letterSpacing: -0.1,
  );

  /// A card or row title.
  static final titleSmall = _heading(
    size: 17,
    weight: 650,
    height: 1.25,
    letterSpacing: -0.1,
  );

  // Reading text and labels: Satoshi 550 for body, 650 for labels. Anything
  // lighter reads thin at phone sizes.

  /// Reading text: descriptions, stories, narration transcripts.
  static final bodyLarge = _body(size: 17, weight: 550, height: 1.4);

  /// A place's one-sentence pitch (`type.lede`): larger than reading text
  /// and lighter than a heading, the page's one emphasised line.
  static final lede = _body(
    size: 20,
    weight: 550,
    height: 1.35,
    letterSpacing: -0.2,
  );

  /// The default body.
  static final bodyMedium = _body(size: 15, weight: 550, height: 1.35);

  /// Buttons, tab labels, row titles that are not headings.
  static final labelLarge = _body(size: 15, weight: 650, height: 1.2);

  /// A row's second line and small metadata: one step lighter than a label
  /// so the title above it keeps the weight.
  static final secondLine = _body(size: 13, weight: 550, height: 1.25);

  /// Metadata and chips.
  static final labelMedium = _body(size: 13, weight: 650, height: 1.3);

  /// Captions.
  static final labelSmall = _body(size: 12, weight: 550, height: 1.3);

  /// Badges and all-caps labels: 11, 700, wide tracking. Render the text
  /// uppercase at the call site; Flutter has no `textCase`.
  static final caps = _body(
    size: 11,
    weight: 750,
    height: 1,
    letterSpacing: 0.8,
  );

  /// Landing-page hero face (Barabara). Uppercase-only font — lowercase glyphs
  /// fall back silently, so copy set here must be uppercase.
  static const brandDisplay = TextStyle(
    fontFamily: brandFamily,
    fontSize: 48,
    height: 1.16,
    letterSpacing: 1,
    color: AppColors.ink,
  );

  /// The Lakbayan wordmark. Same face as [brandDisplay], a step down.
  ///
  /// Coloured at the call site, one span per syllable. Not part of the ramp.
  static const brandWordmark = TextStyle(
    fontFamily: brandFamily,
    fontSize: 42,
    height: 1.1,
    letterSpacing: 1.5,
    color: AppColors.textOnLightGreen,
  );

  /// Material [TextTheme] mapping — one ramp step per slot so stock widgets inherit the ramp.
  static TextTheme textTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: titleLarge,
    headlineLarge: titleLarge,
    headlineMedium: titleMedium,
    headlineSmall: titleSmall,
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
