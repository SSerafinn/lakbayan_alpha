import "package:flutter/cupertino.dart" show CupertinoIcons;
import "package:flutter/widgets.dart";

import "../models/destination.dart";

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
///
/// One glyph is not in the set: the church cross on Home's strip. SF Symbols
/// has no cross, so `CrossGlyph` (`core/widgets/cross_glyph.dart`) draws one
/// with its stroke matched to the Cupertino set at 25dp. It is the single
/// exception, and [forCategory] returns null for it on purpose.
abstract final class AppIcons {
  // Top level sections. Outline at rest, filled when selected.
  static const IconData explore = CupertinoIcons.compass;
  static const IconData exploreFilled = CupertinoIcons.compass_fill;
  static const IconData map = CupertinoIcons.map;
  static const IconData mapFilled = CupertinoIcons.map_fill;
  static const IconData itineraries = CupertinoIcons.briefcase;
  static const IconData itinerariesFilled = CupertinoIcons.briefcase_fill;
  static const IconData profile = CupertinoIcons.person;
  static const IconData profileFilled = CupertinoIcons.person_fill;

  // Actions with reliable shorthand. May appear symbol-only, with a tooltip.
  static const IconData search = CupertinoIcons.search;
  static const IconData back = CupertinoIcons.chevron_left;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData share = CupertinoIcons.share;
  static const IconData add = CupertinoIcons.plus;
  static const IconData download = CupertinoIcons.arrow_down_circle;
  static const IconData downloaded = CupertinoIcons.arrow_down_circle_fill;
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
  static const IconData location = CupertinoIcons.location;
  static const IconData ar = CupertinoIcons.viewfinder;
  static const IconData check = CupertinoIcons.checkmark;
  static const IconData warning = CupertinoIcons.exclamationmark_circle;
  static const IconData offline = CupertinoIcons.wifi_slash;
  static const IconData audio = CupertinoIcons.headphones;
  static const IconData clock = CupertinoIcons.clock;
  static const IconData listen = CupertinoIcons.speaker_2;
  static const IconData drive = CupertinoIcons.car;
  static const IconData grid = CupertinoIcons.square_grid_2x2;
  static const IconData list = CupertinoIcons.list_bullet;
  static const IconData filter = CupertinoIcons.slider_horizontal_3;
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
  static const IconData directions = CupertinoIcons.arrow_turn_up_right;

  // Category glyphs for Home's strip. Each sits under its label; the glyph is
  // the category's identity, the label carries the meaning. Church is the
  // drawn cross (see the class comment); Food has no glyph, it is not on the
  // strip.
  static const IconData nature = CupertinoIcons.tree;
  static const IconData heritage = CupertinoIcons.book_fill;
  static const IconData museum = CupertinoIcons.photo_fill_on_rectangle_fill;
  static const IconData landmark = CupertinoIcons.flag_fill;

  /// The glyph for a [DestinationCategory]; `null` for church (drawn), food
  /// and [DestinationCategory.unknown].
  static IconData? forCategory(DestinationCategory category) =>
      switch (category) {
        DestinationCategory.nature => nature,
        DestinationCategory.heritage => heritage,
        DestinationCategory.museum => museum,
        DestinationCategory.landmark => landmark,
        DestinationCategory.church ||
        DestinationCategory.food ||
        DestinationCategory.unknown => null,
      };
}
