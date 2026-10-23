import "package:flutter/material.dart";

/// Raw colour values from `design/tokens.json` (`app.*`, 3.0.0).
///
/// Build the theme from these; widgets read `Theme.of(context).colorScheme`
/// and [LakbayanColors] instead, since a hex here bypasses dark mode.
abstract final class AppColors {
  // Jade emerald: the primary action, selection, links and focus.
  static const emerald = Color(0xFF00755A); // white on it 5.7:1
  static const emeraldText = Color(0xFF005C45); // on paper 6.9:1
  static const emeraldTint = Color(0xFFE2F3EB); // a quiet emerald wash
  static const emeraldDark = Color(0xFF3ECF9E); // primary on charcoal
  static const onEmeraldDark = Color(0xFF06261C);
  static const emeraldTintDark = Color(0xFF1E3A30);

  // Ground and ink. Paper is the page; a card is white on it.
  static const paper = Color(0xFFF3F2EE);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1B19); // on paper 15.5:1
  static const ink700 = Color(0xFF2B2B29);
  static const sub = Color(0xFF6B6A64); // second lines, 4.9:1 on paper
  static const outline = Color(0xFF9E9C95);
  static const line = Color(0xFFE5E3DC); // the hairline

  /// The light surface ladder. A card is one step brighter than the page,
  /// and what sits inside a card takes the page's paper again.
  static const surfaceContainer = Color(0xFFECEBE6);
  static const surfaceContainerHigh = Color(0xFFE5E3DC);
  static const surfaceContainerHighest = Color(0xFFDEDCD4);

  // Warm charcoal, not black.
  static const charcoal = Color(0xFF262624);
  static const charcoalCard = Color(0xFF30302E);
  static const charcoalRaised = Color(0xFF3A3935);
  static const charcoalHigh = Color(0xFF44433F);
  static const charcoalHighest = Color(0xFF4E4D48);
  static const charcoalDim = Color(0xFF1F1E1D);
  static const charcoalInk = Color(0xFFF2F1EC); // 13.4:1
  static const charcoalSub = Color(0xFFABA9A0); // 5.6:1 on a card
  static const charcoalOutline = Color(0xFF7A7870);
  static const charcoalLine = Color(0xFF46453F);

  // Pastels: a kind's surface and the brand's quiet moments. Ink sits on
  // them; they are never a button.
  static const mint = Color(0xFFD7F0E3);
  static const sky = Color(0xFFDCEAF5);
  static const butter = Color(0xFFF8EDCF);
  static const blush = Color(0xFFF7E0D9);
  static const mintDark = Color(0xFF22392F);
  static const skyDark = Color(0xFF1F2F3B);
  static const butterDark = Color(0xFF3A3222);
  static const blushDark = Color(0xFF3B2A25);

  // Red: the saved heart, and destructive words (Sign Out, Delete).
  static const red = Color(0xFFD93A30);
  static const redText = Color(0xFFC8352C); // on paper 4.7:1
  static const redDark = Color(0xFFF2837A);

  // Blue: the route and your own position on a map. Nothing else.
  static const blue = Color(0xFF1F6FD1);
  static const blueDark = Color(0xFF7FB2F0);

  // The rope Explore's towns are clipped to; in dark mode it is [sub].
  static const cord = Color(0xFFB9B7AF);

  // Errors on a field: the border and the warning glyph.
  static const error = Color(0xFFC42B1B);
  static const errorContainer = Color(0xFFFCE8E6);
  static const onErrorContainer = Color(0xFF9E2419);

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
