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
  static const IconData offline = CupertinoIcons.wifi_slash;
  static const IconData clock = CupertinoIcons.clock;
  static const IconData grid = CupertinoIcons.square_grid_2x2;
  static const IconData delete = CupertinoIcons.trash;
  static const IconData settings = CupertinoIcons.gear;
  static const IconData chevronUp = CupertinoIcons.chevron_up;
  static const IconData chevronDown = CupertinoIcons.chevron_down;
  static const IconData arrowForward = CupertinoIcons.arrow_right;
  static const IconData account = CupertinoIcons.person_crop_circle;
  static const IconData visibility = CupertinoIcons.eye;
  static const IconData visibilityOff = CupertinoIcons.eye_slash;
  static const IconData cloud = CupertinoIcons.cloud;
  static const IconData developer = CupertinoIcons.hammer;
  static const IconData calendar = CupertinoIcons.calendar;

  /// A place's facts in Plan your visit, each beside its name and value:
  /// the best time, the entry fee, the access notes.
  static const IconData season = CupertinoIcons.sun_max;
  static const IconData entry = CupertinoIcons.tickets;
  static const IconData info = CupertinoIcons.info_circle;

  /// Rename. Always beside its label: a pencil alone reads as draw.
  static const IconData rename = CupertinoIcons.pencil;

  static const IconData directions = CupertinoIcons.arrow_turn_up_right;

  /// Reaching the province: Help's lines and office, and Profile's row to
  /// them. Always beside the number or address itself.
  static const IconData phone = CupertinoIcons.phone;
  static const IconData mail = CupertinoIcons.mail;
  static const IconData place = CupertinoIcons.location;

  /// Profile's rows to the privacy policy and the terms of use.
  static const IconData privacy = CupertinoIcons.lock_shield;
  static const IconData document = CupertinoIcons.doc_text;
}
