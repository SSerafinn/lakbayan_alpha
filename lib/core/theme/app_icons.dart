import "package:flutter/cupertino.dart" show CupertinoIcons;
import "package:flutter/widgets.dart";

/// The single action-to-glyph map (design doc 06).
///
/// `CupertinoIcons` is the one icon family in this app (D-12). The glyph set
/// is used with Material widgets; nothing here implies Cupertino widgets.
/// Reference only this file: a call site that writes `CupertinoIcons.x` or
/// `Icons.x` directly is how two glyphs end up meaning the same thing.
///
/// Rules this file exists to hold:
///
/// - A symbol stands alone only when the action has a reliable shorthand:
///   search, share, add, close, back, play and pause, download, favourite.
///   Everything else (select, edit, done, apply, manage) carries a text label.
/// - The same symbol means the same thing everywhere.
/// - A symbol-only control always has a `tooltip` or a `Semantics` label.
/// - A filled variant is the *selected* state of its outline, never a
///   different action.
abstract final class AppIcons {
  // The top-level sections are drawn, not taken from this set: `TabGlyph`
  // animates its own selection (D-16). `map` is Browse's way back to the
  // map.
  static const IconData map = CupertinoIcons.map;

  // Actions with reliable shorthand. May appear symbol-only, with a tooltip.
  static const IconData search = CupertinoIcons.search;
  static const IconData back = CupertinoIcons.chevron_left;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData share = CupertinoIcons.share;
  static const IconData add = CupertinoIcons.plus;
  static const IconData download = CupertinoIcons.arrow_down_circle;
  static const IconData play = CupertinoIcons.play_fill;
  static const IconData pause = CupertinoIcons.pause_fill;
  static const IconData stop = CupertinoIcons.stop_fill;
  static const IconData skipNext = CupertinoIcons.forward_end_fill;
  static const IconData skipPrevious = CupertinoIcons.backward_end_fill;
  static const IconData favorite = CupertinoIcons.heart;
  static const IconData favoriteFilled = CupertinoIcons.heart_fill;
  static const IconData more = CupertinoIcons.ellipsis;

  // Accessories and state. Never the only signal (doc 03: no meaning in a
  // glyph alone any more than in a colour alone), so these sit beside text.
  static const IconData chevron = CupertinoIcons.chevron_right;
  static const IconData check = CupertinoIcons.checkmark;
  static const IconData warning = CupertinoIcons.exclamationmark_circle;
  static const IconData grid = CupertinoIcons.square_grid_2x2;
  static const IconData delete = CupertinoIcons.trash;
  static const IconData settings = CupertinoIcons.gear;
  static const IconData chevronUp = CupertinoIcons.chevron_up;
  static const IconData chevronDown = CupertinoIcons.chevron_down;
  static const IconData arrowForward = CupertinoIcons.arrow_right;
  static const IconData account = CupertinoIcons.person_crop_circle;
  static const IconData visibility = CupertinoIcons.eye;
  static const IconData visibilityOff = CupertinoIcons.eye_slash;
  static const IconData calendar = CupertinoIcons.calendar;
  static const IconData info = CupertinoIcons.info_circle;

  /// Rename. Always beside its label: a pencil alone reads as draw.
  static const IconData rename = CupertinoIcons.pencil;

  static const IconData directions = CupertinoIcons.arrow_turn_up_right;

  /// A row whose value opens a menu of choices (Settings' Theme), and the
  /// three appearances in that menu.
  static const IconData menu = CupertinoIcons.chevron_up_chevron_down;
  static const IconData themeSystem = CupertinoIcons.circle_lefthalf_fill;
  static const IconData themeLight = CupertinoIcons.sun_min;
  static const IconData themeDark = CupertinoIcons.moon;

  /// Change Profile's cover: on the photo it changes, with its tooltip.
  static const IconData cover = CupertinoIcons.photo;

  /// Scan an exhibit (D-18): the camera framing something, not the camera
  /// alone, which would read as taking a photo.
  static const IconData scan = CupertinoIcons.viewfinder;

  /// A guide the province accredits: a status as a glyph, not a word (D-19).
  static const IconData verified = CupertinoIcons.checkmark_seal_fill;
}
