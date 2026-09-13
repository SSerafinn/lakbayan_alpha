import "package:flutter/material.dart";

import "app_colors.dart";

/// The type ramp (`type.*` in tokens.json 2.0.0, D-13).
///
/// Type carries structure on its own (design doc 03). One face, **Satoshi**,
/// set heavy: 900 for the display step, 800 for headings, 700 for labels,
/// 600 for body; lighter reads thin on a phone. Barabara is the one loud voice.
///
/// Satoshi is a **variable** font: `fontWeight` alone picks the file's default
/// instance, so every style also sets the `wght` axis. Colour is not in the
/// ramp; the theme applies `onSurface` and a call site colours only what
/// means something. Use only these steps.
abstract final class AppTypography {
  static const family = "Satoshi";

  /// Brand voice for the landing greetings and the LAKBAYAN wordmark. Not a
  /// ramp step, never body or UI text: it is a Philippine tourism trademark
  /// face, and it has no lowercase glyphs.
  static const brandFamily = "Barabara";

  /// Headings tighten as they grow; the repo's own scale says the same.
  static TextStyle _heading({
    required double size,
    required FontWeight weight,
    required double height,
    required double letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation("wght", weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle _body({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation("wght", weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
  );

  // Headings: negative tracking that eases as the size drops.

  /// An editorial opener. One per screen at most.
  static final display = _heading(
    size: 38,
    weight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -1.1,
  );

  /// A place name over its photo.
  static final hero = _heading(
    size: 28,
    weight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.6,
  );

  /// The screen's title.
  static final titleLarge = _heading(
    size: 24,
    weight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.4,
  );

  /// A section heading.
  static final titleMedium = _heading(
    size: 19,
    weight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.2,
  );

  /// A heading over a grouped section.
  static final groupHeading = _heading(
    size: 17,
    weight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.1,
  );

  /// A card or row title.
  static final titleSmall = _heading(
    size: 17,
    weight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.1,
  );

  // Reading text and labels: Satoshi 600 for body, 700 for labels. Anything
  // lighter reads thin at phone sizes.

  /// Reading text: descriptions, stories, narration transcripts.
  static final bodyLarge = _body(
    size: 17,
    weight: FontWeight.w600,
    height: 1.5,
  );

  /// The default body.
  static final bodyMedium = _body(
    size: 15,
    weight: FontWeight.w600,
    height: 1.45,
  );

  /// Buttons, tab labels, row titles that are not headings.
  static final labelLarge = _body(
    size: 15,
    weight: FontWeight.w700,
    height: 1.2,
  );

  /// A row's second line and small metadata: one step lighter than a label
  /// so the title above it keeps the weight.
  static final secondLine = _body(
    size: 13,
    weight: FontWeight.w600,
    height: 1.3,
  );

  /// Metadata and chips.
  static final labelMedium = _body(
    size: 13,
    weight: FontWeight.w700,
    height: 1.3,
  );

  /// The label under a category glyph on Home's strip.
  static final glyphLabel = _body(
    size: 12,
    weight: FontWeight.w700,
    height: 1.2,
  );

  /// A tab bar label under its glyph; the selected one steps up a weight.
  static final tabLabel = _body(size: 11, weight: FontWeight.w700, height: 1.2);
  static final tabLabelSelected = _body(
    size: 11,
    weight: FontWeight.w800,
    height: 1.2,
  );

  /// Captions.
  static final labelSmall = _body(
    size: 12,
    weight: FontWeight.w600,
    height: 1.3,
  );

  /// Badges and all-caps labels: 11, 700, wide tracking. Render the text
  /// uppercase at the call site; Flutter has no `textCase`.
  static final caps = _body(
    size: 11,
    weight: FontWeight.w800,
    height: 1,
    letterSpacing: 0.8,
  );

  /// Landing-page hero.
  ///
  /// Barabara is a static OTF, so unlike the ramp above there is no `wght`
  /// axis to set. Its cmap covers **A to Z, digits and punctuation only**:
  /// there are no lowercase glyphs, so any lowercase character silently falls
  /// back to another face. Copy set in this style must be uppercase.
  ///
  /// Sized to fit an eight-character line at 360dp of usable width; display
  /// faces sit tall in the line box, hence the generous `height`.
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

  /// Material's [TextTheme], one ramp step per slot, so stock widgets inherit
  /// the ramp without each call site restating a style. Colour is applied by
  /// the theme, not here.
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
