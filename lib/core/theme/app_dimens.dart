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

  /// Between things that belong together: a heading and its content, chips
  /// in a row, photos in a grid, a row's own padding, the tab bar's inset
  /// (D-19).
  static const near = 6.0;

  /// The screen's side margin.
  static const gutter = 12.0;

  /// Between sections and between cards: a clear step, kept short so the
  /// page stays close (D-19).
  static const section = 16.0;

  /// A grouped card's edge to its rows' edge.
  static const groupInset = 4.0;

  /// Between the grouped surfaces of one menu.
  static const menuGroupGap = 8.0;
}

/// Fixed sizes (`size.*`). Layout sizes two screens share live here rather
/// than inline so they stay in step.
abstract final class AppSize {
  /// Android accessibility minimum. Every tappable target must meet this.
  static const minTouchTarget = 48.0;
  static const appBarHeight = 56.0;

  /// The floating tab bar at rest: the four sections and search in one
  /// capsule, the chosen one carrying its name (D-19).
  static const bottomNav = 60.0;

  /// The same bar shrunk on a scroll down, one touch target tall, so every
  /// cell still meets the minimum.
  static const bottomNavCollapsed = minTouchTarget;

  /// A drawn tab glyph (`TabGlyph`). Full size now there is no label under
  /// it to keep light against.
  static const tabGlyph = 24.0;

  /// Taller than the touch minimum so the capsule reads as the focal action.
  static const primaryButton = 50.0;

  static const chip = 38.0;

  static const badge = 24.0;

  /// A symbol-only control over photography: search, back, close.
  static const symbolButton = 44.0;

  /// The save heart over a hero photo, and at the top-right of a media tile.
  static const heroSave = 48.0;
  static const tileSave = 32.0;

  /// The audio player sheet's play button, the sheet's one focal control.
  static const playerButton = 64.0;

  /// A tour's tile on a rail: 3:4, so the rail reads as a row of posters.
  static const tourTile = 124.0;

  /// A photo tile on a rail with its caption on the photo, 4:5: Where to
  /// eat, Around here.
  static const railTile = 136.0;

  /// A local guide's card on Explore's rail.
  static const guideCard = 232.0;

  /// A place's card on the Map's sheet, a wide photo.
  static const mapCard = 136.0;

  /// The itinerary's route map at rest; it grows in place to the screen.
  static const routePreview = 248.0;

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
  static const progressBarHeight = 3.0;

  /// A carousel page dot; the current one stretches to [AppSpace.x4].
  static const pageDot = 6.0;

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

  // Glyph sizes. Material's icon default is 24; the Cupertino strokes read
  // heavier, so most in-row glyphs step down. One ladder, no inline sizes.

  /// A glyph inside a selection circle.
  static const glyphSm = 16.0;

  /// A trailing glyph in a grouped row, or a row's reorder controls.
  static const glyphMd = 18.0;

  /// A symbol button's glyph, and a field's leading glyph.
  static const glyph = 20.0;

  /// A FAB or a leading glyph in a grouped row.
  static const glyphLg = 22.0;

  /// Material's default; the navigation bar and rail.
  static const glyphXl = 24.0;

  /// A grouped row's leading photo, and its leading glyph circle.
  static const rowMedia = 48.0;
  static const rowGlyphCircle = 40.0;

  /// A dense row's leading photo or glyph circle.
  static const rowMediaDense = 40.0;

  /// The numbered circle that ties a stop in a list to its pin on a map.
  static const stopNumeral = 24.0;

  /// An anchored menu's width: long enough for "Change dates" and a glyph.
  static const menuWidth = 240.0;

  /// Profile's avatar, half over the cover photo.
  static const avatar = 80.0;

  /// The check circle beside a pickable row.
  static const selectionCircle = 26.0;

  /// A small inline spinner, the size of a [glyph].
  static const spinner = 20.0;
}

/// Stroke widths. A hairline bounds; the heavier strokes mark focus, a
/// selection ring or a drawn route.
abstract final class AppStroke {
  static const hairline = 1.0;
  static const regular = 1.5;
  static const bold = 2.0;
  static const route = 3.0;

  /// A route on the full map: a step heavier than the preview's, so it
  /// holds its own over the basemap's roads.
  static const mapRoute = 4.0;
}

/// Modal sheet heights as a fraction of the screen. A sheet is sized by
/// [AppSheetSize.form] at most and shrinks with the keyboard, never the other
/// way round.
abstract final class AppSheetSize {
  /// A form or picker sheet: enough to show a header, a few rows and the
  /// pinned action without covering the context behind it.
  static const form = 0.62;

  /// The Map's places sheet fully raised.
  static const mapMax = 0.72;
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
