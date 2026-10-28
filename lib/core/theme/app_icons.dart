import "package:flutter/widgets.dart";

import "../models/destination.dart";

/// The single action-to-glyph map (design doc 06).
///
/// Phosphor is the one icon family in this app (D-20), its regular and fill
/// weights bundled as fonts (`assets/fonts/Phosphor/`, MIT), used with
/// Material widgets. Reference only this file: a call site that writes an `IconData` or
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
  static const _regular = "PhosphorRegular";
  static const _fill = "PhosphorFill";

  // The four sections in the tab bar, the outline at rest and the filled
  // one while chosen. `map` is also Browse's way back to the map.
  static const IconData explore = IconData(0xe1c8, fontFamily: _regular);
  static const IconData exploreFilled = IconData(0xe1c8, fontFamily: _fill);
  static const IconData map = IconData(
    0xe31a,
    fontFamily: _regular,
    matchTextDirection: true,
  );
  static const IconData mapFilled = IconData(
    0xe31a,
    fontFamily: _fill,
    matchTextDirection: true,
  );
  static const IconData trips = IconData(0xe5b0, fontFamily: _regular);
  static const IconData tripsFilled = IconData(0xe5b0, fontFamily: _fill);
  static const IconData profile = IconData(0xe4c2, fontFamily: _regular);
  static const IconData profileFilled = IconData(0xe4c2, fontFamily: _fill);

  // Actions with reliable shorthand. May appear symbol-only, with a tooltip.
  static const IconData search = IconData(0xe30c, fontFamily: _regular);
  static const IconData back = IconData(
    0xe138,
    fontFamily: _regular,
    matchTextDirection: true,
  );
  static const IconData close = IconData(0xe4f6, fontFamily: _regular);
  static const IconData share = IconData(0xe406, fontFamily: _regular);
  static const IconData add = IconData(0xe3d4, fontFamily: _regular);
  static const IconData download = IconData(0xe028, fontFamily: _regular);
  static const IconData play = IconData(
    0xe3d0,
    fontFamily: _fill,
    matchTextDirection: true,
  );
  static const IconData pause = IconData(0xe39e, fontFamily: _fill);
  static const IconData stop = IconData(0xe46c, fontFamily: _fill);
  static const IconData skipNext = IconData(
    0xe5a6,
    fontFamily: _fill,
    matchTextDirection: true,
  );
  static const IconData skipPrevious = IconData(
    0xe5a4,
    fontFamily: _fill,
    matchTextDirection: true,
  );
  static const IconData favorite = IconData(0xe2a8, fontFamily: _regular);
  static const IconData favoriteFilled = IconData(0xe2a8, fontFamily: _fill);
  static const IconData more = IconData(0xe1fe, fontFamily: _regular);

  // Accessories and state. Never the only signal (doc 03: no meaning in a
  // glyph alone any more than in a colour alone), so these sit beside text.
  static const IconData chevron = IconData(
    0xe13a,
    fontFamily: _regular,
    matchTextDirection: true,
  );
  static const IconData check = IconData(0xe182, fontFamily: _regular);
  static const IconData warning = IconData(0xe4e2, fontFamily: _regular);
  static const IconData grid = IconData(0xe464, fontFamily: _regular);
  static const IconData delete = IconData(0xe4a6, fontFamily: _regular);
  static const IconData settings = IconData(0xe270, fontFamily: _regular);
  static const IconData chevronUp = IconData(0xe13c, fontFamily: _regular);
  static const IconData chevronDown = IconData(0xe136, fontFamily: _regular);
  static const IconData arrowForward = IconData(
    0xe06c,
    fontFamily: _regular,
    matchTextDirection: true,
  );
  static const IconData account = IconData(0xe4c4, fontFamily: _regular);
  static const IconData visibility = IconData(0xe220, fontFamily: _regular);
  static const IconData visibilityOff = IconData(0xe224, fontFamily: _regular);
  static const IconData calendar = IconData(0xe10a, fontFamily: _regular);
  static const IconData info = IconData(0xe2ce, fontFamily: _regular);

  /// Rename. Always beside its label: a pencil alone reads as draw.
  static const IconData rename = IconData(0xe3b4, fontFamily: _regular);

  static const IconData directions = IconData(
    0xe026,
    fontFamily: _regular,
    matchTextDirection: true,
  );

  /// A row whose value opens a menu of choices (Settings' Theme), and the
  /// three appearances in that menu.
  static const IconData menu = IconData(0xe140, fontFamily: _regular);
  static const IconData themeSystem = IconData(0xe18c, fontFamily: _regular);
  static const IconData themeLight = IconData(0xe474, fontFamily: _regular);
  static const IconData themeDark = IconData(0xe330, fontFamily: _regular);

  /// Change Profile's cover: on the photo it changes, with its tooltip.
  static const IconData cover = IconData(0xe2ca, fontFamily: _regular);

  /// Scan an exhibit (D-18): the camera framing something, not the camera
  /// alone, which would read as taking a photo.
  static const IconData scan = IconData(0xebb6, fontFamily: _regular);

  /// A guide the province accredits: a status as a glyph, not a word (D-19).
  static const IconData verified = IconData(0xe606, fontFamily: _fill);

  /// A place the province marks popular (the CMS `popular` flag): the
  /// featured card's tag, and a pill on a photo outside Popular
  /// Destinations. Never a count or a trend; there is no data for one.
  static const IconData popular = IconData(0xe242, fontFamily: _fill);

  /// A kind of place as a picture of it, the outline at rest and the filled
  /// one while chosen (the kind rail on Explore and Town). Both weights share
  /// one codepoint per kind. Each is a constant `IconData`, which is what
  /// lets a release build shake unused glyphs out of the fonts.
  static IconData kind(DestinationCategory kind, {bool filled = false}) =>
      filled ? _kindFilled(kind) : _kind(kind);

  static IconData _kind(DestinationCategory kind) => switch (kind) {
    DestinationCategory.nature => const IconData(0xe7ae, fontFamily: _regular),
    DestinationCategory.food => const IconData(0xe262, fontFamily: _regular),
    DestinationCategory.church => const IconData(0xecea, fontFamily: _regular),
    DestinationCategory.heritage => const IconData(
      0xe9d0,
      fontFamily: _regular,
    ),
    DestinationCategory.museum => const IconData(0xe0b4, fontFamily: _regular),
    DestinationCategory.landmark => const IconData(
      0xe244,
      fontFamily: _regular,
    ),
    DestinationCategory.unknown => const IconData(0xe316, fontFamily: _regular),
  };

  static IconData _kindFilled(DestinationCategory kind) => switch (kind) {
    DestinationCategory.nature => const IconData(0xe7ae, fontFamily: _fill),
    DestinationCategory.food => const IconData(0xe262, fontFamily: _fill),
    DestinationCategory.church => const IconData(0xecea, fontFamily: _fill),
    DestinationCategory.heritage => const IconData(0xe9d0, fontFamily: _fill),
    DestinationCategory.museum => const IconData(0xe0b4, fontFamily: _fill),
    DestinationCategory.landmark => const IconData(0xe244, fontFamily: _fill),
    DestinationCategory.unknown => const IconData(0xe316, fontFamily: _fill),
  };
}
