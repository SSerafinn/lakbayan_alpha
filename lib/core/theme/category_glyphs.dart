import "package:flutter/widgets.dart";

/// The icons a category added in the CMS may use, by the name stored on it
/// (`CustomCategory.glyph`).
///
/// Transcribed from `design/category-glyphs.json`, which the CMS offers as
/// its list; `test/core/theme/category_glyphs_test.dart` checks the two agree.
/// Every entry is a constant [IconData], one per weight, so release builds
/// can still tree-shake the Phosphor fonts.
abstract final class CategoryGlyphs {
  static const _regular = "PhosphorRegular";
  static const _fill = "PhosphorFill";

  /// The glyph called [name], or null for a name this build does not know.
  static IconData? of(String name, {bool filled = false}) =>
      filled ? _filled(name) : _outline(name);

  /// Every name, in the file's order.
  static const names = [
    "umbrella",
    "swimming-pool",
    "island",
    "waves",
    "sailboat",
    "boat",
    "fish",
    "tent",
    "campfire",
    "person-simple-hike",
    "tree-evergreen",
    "flower-lotus",
    "plant",
    "barn",
    "horse",
    "sun",
    "binoculars",
    "camera",
    "lighthouse",
    "bridge",
    "bicycle",
    "bed",
    "house-line",
    "buildings",
    "storefront",
    "shopping-bag",
    "coffee",
    "music-notes",
    "confetti",
    "mask-happy",
    "palette",
    "books",
    "ticket",
  ];

  static IconData? _outline(String name) => switch (name) {
    "umbrella" => const IconData(0xe684, fontFamily: _regular),
    "swimming-pool" => const IconData(0xecb6, fontFamily: _regular),
    "island" => const IconData(0xee06, fontFamily: _regular),
    "waves" => const IconData(0xe6de, fontFamily: _regular),
    "sailboat" => const IconData(0xe78a, fontFamily: _regular),
    "boat" => const IconData(0xe786, fontFamily: _regular),
    "fish" => const IconData(0xe728, fontFamily: _regular),
    "tent" => const IconData(0xe8ba, fontFamily: _regular),
    "campfire" => const IconData(0xe9d8, fontFamily: _regular),
    "person-simple-hike" => const IconData(0xed54, fontFamily: _regular),
    "tree-evergreen" => const IconData(0xe6dc, fontFamily: _regular),
    "flower-lotus" => const IconData(0xe6cc, fontFamily: _regular),
    "plant" => const IconData(0xebae, fontFamily: _regular),
    "barn" => const IconData(0xec72, fontFamily: _regular),
    "horse" => const IconData(0xe2b0, fontFamily: _regular),
    "sun" => const IconData(0xe472, fontFamily: _regular),
    "binoculars" => const IconData(0xea64, fontFamily: _regular),
    "camera" => const IconData(0xe10e, fontFamily: _regular),
    "lighthouse" => const IconData(0xe9f6, fontFamily: _regular),
    "bridge" => const IconData(0xea68, fontFamily: _regular),
    "bicycle" => const IconData(0xe0d6, fontFamily: _regular),
    "bed" => const IconData(0xe0cc, fontFamily: _regular),
    "house-line" => const IconData(0xe2c4, fontFamily: _regular),
    "buildings" => const IconData(0xe102, fontFamily: _regular),
    "storefront" => const IconData(0xe470, fontFamily: _regular),
    "shopping-bag" => const IconData(0xe416, fontFamily: _regular),
    "coffee" => const IconData(0xe1c2, fontFamily: _regular),
    "music-notes" => const IconData(0xe340, fontFamily: _regular),
    "confetti" => const IconData(0xe81a, fontFamily: _regular),
    "mask-happy" => const IconData(0xe9f4, fontFamily: _regular),
    "palette" => const IconData(0xe6c8, fontFamily: _regular),
    "books" => const IconData(0xe758, fontFamily: _regular),
    "ticket" => const IconData(0xe490, fontFamily: _regular),
    _ => null,
  };

  static IconData? _filled(String name) => switch (name) {
    "umbrella" => const IconData(0xe684, fontFamily: _fill),
    "swimming-pool" => const IconData(0xecb6, fontFamily: _fill),
    "island" => const IconData(0xee06, fontFamily: _fill),
    "waves" => const IconData(0xe6de, fontFamily: _fill),
    "sailboat" => const IconData(0xe78a, fontFamily: _fill),
    "boat" => const IconData(0xe786, fontFamily: _fill),
    "fish" => const IconData(0xe728, fontFamily: _fill),
    "tent" => const IconData(0xe8ba, fontFamily: _fill),
    "campfire" => const IconData(0xe9d8, fontFamily: _fill),
    "person-simple-hike" => const IconData(0xed54, fontFamily: _fill),
    "tree-evergreen" => const IconData(0xe6dc, fontFamily: _fill),
    "flower-lotus" => const IconData(0xe6cc, fontFamily: _fill),
    "plant" => const IconData(0xebae, fontFamily: _fill),
    "barn" => const IconData(0xec72, fontFamily: _fill),
    "horse" => const IconData(0xe2b0, fontFamily: _fill),
    "sun" => const IconData(0xe472, fontFamily: _fill),
    "binoculars" => const IconData(0xea64, fontFamily: _fill),
    "camera" => const IconData(0xe10e, fontFamily: _fill),
    "lighthouse" => const IconData(0xe9f6, fontFamily: _fill),
    "bridge" => const IconData(0xea68, fontFamily: _fill),
    "bicycle" => const IconData(0xe0d6, fontFamily: _fill),
    "bed" => const IconData(0xe0cc, fontFamily: _fill),
    "house-line" => const IconData(0xe2c4, fontFamily: _fill),
    "buildings" => const IconData(0xe102, fontFamily: _fill),
    "storefront" => const IconData(0xe470, fontFamily: _fill),
    "shopping-bag" => const IconData(0xe416, fontFamily: _fill),
    "coffee" => const IconData(0xe1c2, fontFamily: _fill),
    "music-notes" => const IconData(0xe340, fontFamily: _fill),
    "confetti" => const IconData(0xe81a, fontFamily: _fill),
    "mask-happy" => const IconData(0xe9f4, fontFamily: _fill),
    "palette" => const IconData(0xe6c8, fontFamily: _fill),
    "books" => const IconData(0xe758, fontFamily: _fill),
    "ticket" => const IconData(0xe490, fontFamily: _fill),
    _ => null,
  };
}
