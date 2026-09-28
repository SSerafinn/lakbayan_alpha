import "package:flutter/material.dart";

// Shape lives in its own file; re-exported so a screen importing dimens gets
// radii and the capsule from the same place.
export "app_shape.dart";

/// Spacing scale (`space.*` in tokens.json). 4dp base grid.
abstract final class AppSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x7 = 28.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;

  // The compact rhythm. Off the 4dp grid on purpose: a phone screen reads
  // as empty at the desktop-derived 20/28.
  static const gutter = 14.0;
  static const section = 16.0;

  /// Grouped section edge to row edge, and a row's own padding.
  static const groupInset = 4.0;
  static const rowPad = 8.0;
}

/// Fixed sizes (`size.*`). Layout sizes two screens share live here rather
/// than inline so they stay in step.
abstract final class AppSize {
  /// Android accessibility minimum. Every tappable target must meet this.
  static const minTouchTarget = 48.0;
  static const appBarHeight = 56.0;

  /// The floating tab bar at rest: 5 inset, 8 pad, 21 glyph, 2 gap, 13
  /// label, 8 pad, 5 inset. Collapsed it is glyphs only, one touch target.
  static const bottomNav = 60.0;
  static const bottomNavCollapsed = minTouchTarget;

  /// Smaller than Material's 24 so the Cupertino stroke sits light against
  /// the 11pt label under it.
  static const tabGlyph = 21.0;

  /// Taller than the touch minimum so the capsule reads as the one focal
  /// action on a surface (design doc 02, size classes).
  static const primaryButton = 50.0;

  static const chip = 38.0;
  static const badge = 24.0;

  /// A symbol-only control over photography: search, back, close.
  static const symbolButton = 44.0;

  /// The save heart over a hero photo, and at the top-right of a media tile.
  static const heroSave = 48.0;
  static const tileSave = 32.0;

  /// A category glyph circle on Home's strip.
  static const glyphCircle = 56.0;

  /// A recently-viewed thumbnail.
  static const thumbnail = 112.0;

  static const heroHeight = 412.0;
  static const detailHero = 392.0;
  static const routePreview = 196.0;

  /// What the Map's places sheet shows above the tab bar at rest: the
  /// handle, the area's name and two rows.
  static const mapSheetRest = 220.0;

  /// Primary form buttons: a full-width action needs no extra height.
  static const formButton = 48.0;

  /// A large standalone icon, such as the landing page's swipe affordance.
  static const iconLarge = 40.0;

  /// The colour wash behind the shoreline. Taller than the band itself so the
  /// colour has room to clear before it reaches the copy above.
  static const wash = 340.0;

  /// The splash progress bar. Deliberately narrow: it marks time passing, it
  /// does not report progress.
  static const progressBar = 120.0;

  /// The grab bar at the top of the auth sheet.
  static const dragHandleWidth = 36.0;
  static const dragHandleHeight = 4.0;

  /// How far the auth sheet rides up over the illustrated header. Enough to
  /// give the form room without covering the lighthouse behind it.
  static const authCardOverlap = 96.0;

  /// Two lines of [AppTypography.brandDisplay] with headroom, reserved so
  /// copy does not shift while a heading animates in.
  static const brandDisplayBlock = 124.0;

  /// Three lines of [AppTypography.bodyLarge], a floor so centred landing
  /// pages with shorter copy do not sit lower than the rest.
  static const landingBodyBlock = 72.0;
}

/// The shoreline band, `footer.webp`, which is 1440 x 319.
///
/// Laid out three screen-widths wide so a page turn moves it exactly one
/// screen and the pan tracks the finger 1:1 on any device. The height follows
/// from that, so both screens derive it the same way.
const double shorelineAspectRatio = 1440 / 319;
const int shorelinePages = 3;

double shorelineBand(BuildContext context) =>
    MediaQuery.sizeOf(context).width * shorelinePages / shorelineAspectRatio;
