import "package:flutter/material.dart";

import "../models/destination.dart";
import "app_colors.dart";

/// Brand tokens that Material's [ColorScheme] has no slot for.
///
/// Each has one job, and keeping it out of the scheme keeps Material from
/// reaching for it: [spatial] blue is the route and your position, never a
/// fill; [save] red is the heart; [closed] red is destructive words; the
/// pastels are a kind's surface and quiet brand moments, never a button.
///
/// Access with `Theme.of(context).extension<LakbayanColors>()!`, or the
/// `context.lakbayan` getter below.
@immutable
class LakbayanColors extends ThemeExtension<LakbayanColors> {
  const LakbayanColors({
    required this.textOnLightGreen,
    required this.tint,
    required this.spatial,
    required this.onSpatial,
    required this.closed,
    required this.save,
    required this.featured,
    required this.onFeatured,
    required this.mint,
    required this.sky,
    required this.butter,
    required this.blush,
    required this.glass,
    required this.onGlass,
    required this.badgeErrorFill,
    required this.badgeErrorText,
  });

  /// Emerald for words: links and text buttons. The fill shade is too light
  /// for text on paper.
  final Color textOnLightGreen;

  /// A quiet emerald wash behind an emerald word (Directions, Scan an
  /// Exhibit). Never behind a primary action, which is solid.
  final Color tint;

  /// The route on a map and your own position, and nothing else. Never a
  /// button.
  final Color spatial;
  final Color onSpatial;

  /// Destructive words (Sign Out, Delete) and the CLOSED badge.
  final Color closed;

  /// The saved heart, filled.
  final Color save;

  /// The FEATURED badge, until the featured cards drop it (D-19).
  final Color featured;
  final Color onFeatured;

  /// Pastels, ink on top: nature, museums and landmarks, churches and
  /// heritage, food. Also the landing washes and empty states.
  final Color mint;
  final Color sky;
  final Color butter;
  final Color blush;

  /// A control's own surface over a photo (back, the heart, a distance), and
  /// what sits on it.
  final Color glass;
  final Color onGlass;

  final Color badgeErrorFill;
  final Color badgeErrorText;

  static const light = LakbayanColors(
    textOnLightGreen: AppColors.emeraldText,
    tint: AppColors.emeraldTint,
    spatial: AppColors.blue,
    onSpatial: AppColors.white,
    closed: AppColors.redText,
    save: AppColors.red,
    featured: AppColors.gold700,
    onFeatured: AppColors.white,
    mint: AppColors.mint,
    sky: AppColors.sky,
    butter: AppColors.butter,
    blush: AppColors.blush,
    glass: Color(0xE6FFFFFF),
    onGlass: AppColors.ink,
    badgeErrorFill: AppColors.errorContainer,
    badgeErrorText: AppColors.onErrorContainer,
  );

  static const dark = LakbayanColors(
    textOnLightGreen: AppColors.emeraldDark,
    tint: AppColors.emeraldTintDark,
    spatial: AppColors.blueDark,
    onSpatial: AppColors.charcoal,
    closed: AppColors.redDark,
    save: AppColors.redDark,
    featured: AppColors.gold300,
    onFeatured: AppColors.ink,
    mint: AppColors.mintDark,
    sky: AppColors.skyDark,
    butter: AppColors.butterDark,
    blush: AppColors.blushDark,
    glass: Color(0xE0262624),
    onGlass: AppColors.charcoalInk,
    badgeErrorFill: Color(0xFF4A1F1F),
    badgeErrorText: Color(0xFFF0A5A5),
  );

  /// A kind's pastel: its surface wherever the kind shows as a colour.
  Color kindWash(DestinationCategory category) => switch (category) {
    DestinationCategory.nature => mint,
    DestinationCategory.museum || DestinationCategory.landmark => sky,
    DestinationCategory.church || DestinationCategory.heritage => butter,
    DestinationCategory.food => blush,
    DestinationCategory.unknown => mint,
  };

  /// A kind's deep tone (`role.kind`), for Keep or skip only: a photo-less
  /// card, its stage and its Keep and Skip buttons. The same in both modes,
  /// since that screen is always dark; white reads on every one.
  Color kindTone(DestinationCategory category) => switch (category) {
    DestinationCategory.nature => AppColors.kindNature,
    DestinationCategory.food => AppColors.kindFood,
    DestinationCategory.church => AppColors.kindChurch,
    DestinationCategory.heritage => AppColors.kindHeritage,
    DestinationCategory.museum => AppColors.kindMuseum,
    DestinationCategory.landmark => AppColors.kindLandmark,
    DestinationCategory.unknown => AppColors.ink700,
  };

  @override
  LakbayanColors copyWith({
    Color? textOnLightGreen,
    Color? tint,
    Color? spatial,
    Color? onSpatial,
    Color? closed,
    Color? save,
    Color? featured,
    Color? onFeatured,
    Color? mint,
    Color? sky,
    Color? butter,
    Color? blush,
    Color? glass,
    Color? onGlass,
    Color? badgeErrorFill,
    Color? badgeErrorText,
  }) => LakbayanColors(
    textOnLightGreen: textOnLightGreen ?? this.textOnLightGreen,
    tint: tint ?? this.tint,
    spatial: spatial ?? this.spatial,
    onSpatial: onSpatial ?? this.onSpatial,
    closed: closed ?? this.closed,
    save: save ?? this.save,
    featured: featured ?? this.featured,
    onFeatured: onFeatured ?? this.onFeatured,
    mint: mint ?? this.mint,
    sky: sky ?? this.sky,
    butter: butter ?? this.butter,
    blush: blush ?? this.blush,
    glass: glass ?? this.glass,
    onGlass: onGlass ?? this.onGlass,
    badgeErrorFill: badgeErrorFill ?? this.badgeErrorFill,
    badgeErrorText: badgeErrorText ?? this.badgeErrorText,
  );

  @override
  LakbayanColors lerp(covariant LakbayanColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return LakbayanColors(
      textOnLightGreen: mix(textOnLightGreen, other.textOnLightGreen),
      tint: mix(tint, other.tint),
      spatial: mix(spatial, other.spatial),
      onSpatial: mix(onSpatial, other.onSpatial),
      closed: mix(closed, other.closed),
      save: mix(save, other.save),
      featured: mix(featured, other.featured),
      onFeatured: mix(onFeatured, other.onFeatured),
      mint: mix(mint, other.mint),
      sky: mix(sky, other.sky),
      butter: mix(butter, other.butter),
      blush: mix(blush, other.blush),
      glass: mix(glass, other.glass),
      onGlass: mix(onGlass, other.onGlass),
      badgeErrorFill: mix(badgeErrorFill, other.badgeErrorFill),
      badgeErrorText: mix(badgeErrorText, other.badgeErrorText),
    );
  }
}

extension LakbayanThemeX on BuildContext {
  /// Brand tokens outside Material's [ColorScheme].
  LakbayanColors get lakbayan => Theme.of(this).extension<LakbayanColors>()!;
}
