import "package:flutter/material.dart";

/// Raw colour values from `design/tokens.json`.
///
/// Green is a signature — only on the primary action, selection, and links.
/// Prefer `Theme.of(context).colorScheme` and [LakbayanColors] in widgets;
/// reach for these only when building the theme (a hex here bypasses dark mode).
abstract final class AppColors {
  // Signature: Cagayan Green. One shade for actions and selection, one
  // darker shade for text on white, one deep shade for pressed states.
  static const green900 = Color(0xFF0B3D1F);
  static const green700 = Color(0xFF0F6431); // green text on white, 7.4:1
  static const green500 = Color(
    0xFF168240,
  ); // BASE: primary fill, selection. White on it 4.9:1
  static const green300 = Color(0xFF5FBF82); // primary on dark surfaces
  static const green100 = Color(
    0xFFCFEFDB,
  ); // primary container, dark ink on it

  // Spatial: River Blue. Map pins, distances, getting there, AR, offline and
  // download, inline "See all". Never a button fill.
  static const blue700 = Color(0xFF0B4F8A);
  static const blue500 = Color(0xFF0B6BCB); // BASE, 5.3:1 on white
  static const blue300 = Color(0xFF5E9BD6);
  static const blue100 = Color(0xFFD5E6F6);

  // Accent: Cagayan Gold. The FEATURED badge and nothing else.
  static const gold700 = Color(0xFF9A6300); // FEATURED fill, white on it 4.6:1
  static const gold500 = Color(0xFFE9A21A); // BASE tint; never white on it
  static const gold300 = Color(0xFFF4C765);
  static const gold100 = Color(0xFFFBEFD2);

  // Red: the CLOSED badge, Sign out, and the saved heart.
  static const red500 = Color(0xFFE5322A);

  // Earth: the Heritage category glyph on Home. A glyph colour, never a fill.
  static const earth700 = Color(0xFFA4620D);

  // Neutrals. A warm near-grey ramp: the chrome is quiet so the signature
  // reads as a signature.
  static const ink = Color(0xFF121212); // onSurface, badge ink
  static const ink700 = Color(0xFF2B2B29);
  static const grey600 = Color(0xFF6D6D6A); // onSurfaceVariant, 5.0:1 on white
  static const grey400 = Color(0xFF9E9E9A); // placeholders, disabled, outline
  static const grey200 = Color(0xFFE1E1DE); // outlineVariant, the hairline
  static const grey100 = Color(0xFFEAE9E4); // surfaceContainerHigh
  static const grey50 = Color(0xFFF6F6F4); // surfaceContainerLow

  /// The light surface ladder. White is the ground; each step up is a barely
  /// visible grey. Elevation is the step you pick, not a shadow you add.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDim = Color(0xFFE5E4DF);
  static const surfaceBright = surface;
  static const surfaceContainerLowest = surface;
  static const surfaceContainerLow = grey50;
  static const surfaceContainer = Color(0xFFEFEFEC);
  static const surfaceContainerHigh = grey100;
  static const surfaceContainerHighest = Color(0xFFE5E4DF);

  /// The hairline. On a white system a 1dp line at this value is the honest
  /// way to bound a chip, an outlined badge or a field; it is still not an
  /// emphasis mechanism and never a divider between rows.
  static const outlineVariant = grey200;
  static const outline = grey400;

  // Semantic.
  static const warning = gold500;
  static const error = Color(0xFFC42B1B);
  static const errorContainer = Color(0xFFFCE8E6);
  static const onErrorContainer = Color(0xFF9E2419);
  static const info = blue500;

  /// Green text on white must be /700 or darker to clear WCAG AA. Don't
  /// substitute [green500] here (4.9:1 is fine for a button label, tight for body).
  static const textOnLightGreen = green700;

  // Dark surface ladder.
  static const darkSurface = Color(0xFF0F1113);
  static const darkSurfaceDim = Color(0xFF0A0B0D);
  static const darkSurfaceBright = Color(0xFF34383D);
  static const darkSurfaceContainerLowest = Color(0xFF0A0B0D);
  static const darkSurfaceContainerLow = Color(0xFF17191C);
  static const darkSurfaceContainer = Color(0xFF1C1F23);
  static const darkSurfaceContainerHigh = Color(0xFF25292E);
  static const darkSurfaceContainerHighest = Color(0xFF2F343A);
  static const darkOnSurface = Color(0xFFF1F2F4);
  static const darkOnSurfaceVariant = Color(0xFFA9B0B8);
  static const darkOutline = Color(0xFF5C636B);
  static const darkOutlineVariant = Color(0xFF2F353C);

  /// Each kind of place as a deep tone (`role.kind`), for Keep or skip only:
  /// a card's stage and its Keep and Skip buttons, until real photos carry
  /// their own colour. White reads on every one, in light and dark alike.
  static const kindNature = Color(0xFF1F5B3A);
  static const kindFood = Color(0xFF8A3B1E);
  static const kindChurch = Color(0xFF3C3F7A);
  static const kindHeritage = Color(0xFF6F4512);
  static const kindMuseum = Color(0xFF1E5A63);
  static const kindLandmark = Color(0xFF1D4E89);
}
