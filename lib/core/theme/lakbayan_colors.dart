import "package:flutter/material.dart";

import "../models/destination.dart";
import "app_colors.dart";

/// Brand tokens that Material's [ColorScheme] has no slot for.
///
/// Gold is the clearest example: it is the FEATURED badge and deliberately
/// *never* a button, so mapping it onto `ColorScheme.tertiary` would invite
/// Material to use it as an action colour. Keeping it here makes the design
/// system's "gold is never a button" rule structural rather than a convention
/// people have to remember. The same goes for [spatial] blue (never a fill),
/// [closed] red (never an alert colour) and [save] red (the heart, nothing
/// else).
///
/// Everything that *does* have a scheme role (surfaces, outlines, secondary
/// text, tints) lives in the scheme since 2.0.0.
///
/// Access with `Theme.of(context).extension<LakbayanColors>()!`, or the
/// `context.lakbayan` getter below.
@immutable
class LakbayanColors extends ThemeExtension<LakbayanColors> {
  const LakbayanColors({
    required this.gold,
    required this.goldText,
    required this.goldContainer,
    required this.onGoldContainer,
    required this.textOnLightGreen,
    required this.spatial,
    required this.onSpatial,
    required this.closed,
    required this.save,
    required this.featured,
    required this.onFeatured,
    required this.earth,
    required this.badgeNeutralFill,
    required this.badgeNeutralText,
    required this.badgeErrorFill,
    required this.badgeErrorText,
    required this.scheme,
  });

  /// Accent fill: AR and Featured badges only.
  final Color gold;

  /// Gold *text* on a light background. Steps down to gold/700 for AA.
  final Color goldText;
  final Color goldContainer;

  /// Ink on the gold container tint, in both brightnesses.
  final Color onGoldContainer;

  /// The FEATURED badge fill and its label. Deep gold with white on light
  /// (gold/700, 4.6:1); the /300 tint with ink on dark. White sits on gold
  /// only at /700, never on the /500 base.
  final Color featured;
  final Color onFeatured;

  /// Green text on a light surface must be /700 or /900, never the /500 base.
  final Color textOnLightGreen;

  /// Anything spatial: map pins, distances, getting there, AR, offline and
  /// download, the inline "See all". Text and glyphs on white, or the AR
  /// badge fill with [onSpatial]. Never a button.
  final Color spatial;
  final Color onSpatial;

  /// The CLOSED badge and Sign out. An error is still the error border.
  final Color closed;

  /// The saved heart, filled. The one place red means "kept", so it is its
  /// own role even though it shares a value with [closed].
  final Color save;

  /// The Heritage category glyph. A glyph colour, never a fill.
  final Color earth;

  final Color badgeNeutralFill;
  final Color badgeNeutralText;
  final Color badgeErrorFill;
  final Color badgeErrorText;

  /// The scheme this extension was built for; [categoryColor] reads it.
  final ColorScheme scheme;

  static LakbayanColors light(ColorScheme scheme) => LakbayanColors(
    gold: AppColors.gold500,
    goldText: AppColors.gold700,
    goldContainer: AppColors.gold100,
    onGoldContainer: AppColors.ink,
    textOnLightGreen: AppColors.green700,
    spatial: AppColors.blue500,
    onSpatial: AppColors.surface,
    closed: AppColors.red500,
    save: AppColors.red500,
    featured: AppColors.gold700,
    onFeatured: AppColors.surface,
    earth: AppColors.earth700,
    badgeNeutralFill: AppColors.green100,
    badgeNeutralText: AppColors.green700,
    badgeErrorFill: AppColors.errorContainer,
    badgeErrorText: AppColors.onErrorContainer,
    scheme: scheme,
  );

  /// Dark mode is v2 scope in the design system; these follow its stated rule
  /// that interactive colour steps to the /300 tints on dark surfaces.
  static LakbayanColors dark(ColorScheme scheme) => LakbayanColors(
    gold: AppColors.gold300,
    goldText: AppColors.gold300,
    goldContainer: const Color(0xFF3D2E08),
    onGoldContainer: AppColors.gold100,
    textOnLightGreen: AppColors.green300,
    spatial: AppColors.blue300,
    onSpatial: AppColors.darkSurface,
    closed: const Color(0xFFF07A74),
    save: const Color(0xFFF07A74),
    featured: AppColors.gold300,
    onFeatured: AppColors.ink,
    earth: const Color(0xFFD9A15A),
    badgeNeutralFill: const Color(0xFF1A3D28),
    badgeNeutralText: AppColors.green300,
    badgeErrorFill: const Color(0xFF4A1F1F),
    badgeErrorText: const Color(0xFFF0A5A5),
    scheme: scheme,
  );

  /// The colour a category's glyph carries on Home's strip. Identity, not
  /// state: selection still looks like a solid green circle.
  Color categoryColor(DestinationCategory category) => switch (category) {
    DestinationCategory.nature => scheme.primary,
    DestinationCategory.church => scheme.onSurface,
    DestinationCategory.heritage => earth,
    DestinationCategory.museum => scheme.onSurface,
    DestinationCategory.food => closed,
    DestinationCategory.landmark => spatial,
    DestinationCategory.unknown => scheme.onSurfaceVariant,
  };

  @override
  LakbayanColors copyWith({
    Color? gold,
    Color? goldText,
    Color? goldContainer,
    Color? onGoldContainer,
    Color? textOnLightGreen,
    Color? spatial,
    Color? onSpatial,
    Color? closed,
    Color? save,
    Color? featured,
    Color? onFeatured,
    Color? earth,
    Color? badgeNeutralFill,
    Color? badgeNeutralText,
    Color? badgeErrorFill,
    Color? badgeErrorText,
    ColorScheme? scheme,
  }) => LakbayanColors(
    gold: gold ?? this.gold,
    goldText: goldText ?? this.goldText,
    goldContainer: goldContainer ?? this.goldContainer,
    onGoldContainer: onGoldContainer ?? this.onGoldContainer,
    textOnLightGreen: textOnLightGreen ?? this.textOnLightGreen,
    spatial: spatial ?? this.spatial,
    onSpatial: onSpatial ?? this.onSpatial,
    closed: closed ?? this.closed,
    save: save ?? this.save,
    featured: featured ?? this.featured,
    onFeatured: onFeatured ?? this.onFeatured,
    earth: earth ?? this.earth,
    badgeNeutralFill: badgeNeutralFill ?? this.badgeNeutralFill,
    badgeNeutralText: badgeNeutralText ?? this.badgeNeutralText,
    badgeErrorFill: badgeErrorFill ?? this.badgeErrorFill,
    badgeErrorText: badgeErrorText ?? this.badgeErrorText,
    scheme: scheme ?? this.scheme,
  );

  @override
  LakbayanColors lerp(covariant LakbayanColors? other, double t) {
    if (other == null) return this;
    return LakbayanColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      goldContainer: Color.lerp(goldContainer, other.goldContainer, t)!,
      onGoldContainer: Color.lerp(onGoldContainer, other.onGoldContainer, t)!,
      textOnLightGreen: Color.lerp(
        textOnLightGreen,
        other.textOnLightGreen,
        t,
      )!,
      spatial: Color.lerp(spatial, other.spatial, t)!,
      onSpatial: Color.lerp(onSpatial, other.onSpatial, t)!,
      closed: Color.lerp(closed, other.closed, t)!,
      save: Color.lerp(save, other.save, t)!,
      featured: Color.lerp(featured, other.featured, t)!,
      onFeatured: Color.lerp(onFeatured, other.onFeatured, t)!,
      earth: Color.lerp(earth, other.earth, t)!,
      badgeNeutralFill: Color.lerp(
        badgeNeutralFill,
        other.badgeNeutralFill,
        t,
      )!,
      badgeNeutralText: Color.lerp(
        badgeNeutralText,
        other.badgeNeutralText,
        t,
      )!,
      badgeErrorFill: Color.lerp(badgeErrorFill, other.badgeErrorFill, t)!,
      badgeErrorText: Color.lerp(badgeErrorText, other.badgeErrorText, t)!,
      scheme: ColorScheme.lerp(scheme, other.scheme, t),
    );
  }
}

extension LakbayanThemeX on BuildContext {
  /// Brand tokens outside Material's [ColorScheme].
  LakbayanColors get lakbayan => Theme.of(this).extension<LakbayanColors>()!;
}
