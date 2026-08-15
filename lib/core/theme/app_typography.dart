import "package:flutter/material.dart";

import "app_colors.dart";

/// Type scale from the Lakbayan design system (`typography.*` in tokens.json).
///
/// Plus Jakarta Sans carries headings, Inter carries body. Both are bundled as
/// **variable** fonts — see `assets/fonts/`. That matters: on a variable font,
/// `fontWeight` alone selects the file's default instance, so every style also
/// sets the `wght` axis via [FontVariation]. Drop the variation and everything
/// renders at one weight, which is easy to miss on a small screen.
abstract final class AppTypography {
  static const headingFamily = "PlusJakartaSans";
  static const bodyFamily = "Inter";

  /// Display face for the landing page. Not part of the type scale — it is a
  /// brand voice for the first screen only, never body or UI text.
  static const brandFamily = "Barabara";

  static TextStyle _heading({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: headingFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation("wght", weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
    color: AppColors.ink900,
  );

  static TextStyle _body({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color color = AppColors.ink700,
  }) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation("wght", weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// Hero — 36 / Bold / 1.15. Design system notes a usable range of 32–40.
  static final display = _heading(
    size: 36,
    weight: FontWeight.w700,
    height: 1.15,
  );

  /// Landing-page hero.
  ///
  /// Barabara is a static OTF, so unlike the scale above there is no `wght`
  /// axis to set. Its cmap covers **A–Z, digits and punctuation only** — there
  /// are no lowercase glyphs, so any lowercase character silently falls back
  /// to another face. Copy set in this style must be uppercase.
  ///
  /// Sized to fit an eight-character line at 360dp of usable width; display
  /// faces sit tall in the line box, hence the generous `height`.
  static const brandDisplay = TextStyle(
    fontFamily: brandFamily,
    fontSize: 48,
    height: 1.16,
    letterSpacing: 1,
    color: AppColors.ink900,
  );

  /// The Lakbayan wordmark. Same face as [brandDisplay], a step down.
  ///
  /// Coloured at the call site, one span per syllable, from the `ef*Ink`
  /// values in [AppColors]: the province's own hues darkened until they clear
  /// contrast. Not part of the design system's type scale.
  static const brandWordmark = TextStyle(
    fontFamily: brandFamily,
    fontSize: 42,
    height: 1.1,
    letterSpacing: 1.5,
    color: AppColors.textOnLightGreen,
  );

  static final h1 = _heading(size: 28, weight: FontWeight.w700, height: 1.2);
  static final h2 = _heading(size: 22, weight: FontWeight.w600, height: 1.25);
  static final h3 = _heading(size: 18, weight: FontWeight.w600, height: 1.3);

  /// Subtitle — body family, not heading family.
  static final title = _body(
    size: 16,
    weight: FontWeight.w600,
    height: 1.4,
    color: AppColors.ink900,
  );

  static final bodyLarge = _body(
    size: 16,
    weight: FontWeight.w400,
    height: 1.5,
  );
  static final body = _body(size: 14, weight: FontWeight.w400, height: 1.5);

  /// Button / label — the +0.3 tracking is deliberate.
  static final label = _body(
    size: 14,
    weight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
    color: AppColors.ink900,
  );

  static final caption = _body(
    size: 12,
    weight: FontWeight.w500,
    height: 1.4,
    color: AppColors.slate500,
  );

  /// Overline — always render the text uppercase at the call site; Flutter has
  /// no `textCase` in TextStyle.
  static final overline = _body(
    size: 12,
    weight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 1.2,
    color: AppColors.slate500,
  );

  /// Material's [TextTheme], mapped onto the scale above so that stock widgets
  /// (AppBar, ListTile, buttons) inherit the design system without each call
  /// site restating a style.
  static TextTheme textTheme() => TextTheme(
    displayLarge: display,
    displayMedium: h1,
    displaySmall: h2,
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h3,
    titleLarge: h3,
    titleMedium: title,
    titleSmall: label,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: caption,
    labelSmall: overline,
  );

  /// Same scale recoloured for dark surfaces.
  static TextTheme darkTextTheme() {
    const onDark = AppColors.darkText;
    final muted = onDark.withValues(alpha: 0.78);
    return textTheme()
        .apply(bodyColor: onDark, displayColor: onDark)
        .copyWith(
          bodySmall: caption.copyWith(color: muted),
          labelMedium: caption.copyWith(color: muted),
          labelSmall: overline.copyWith(color: muted),
        );
  }
}
