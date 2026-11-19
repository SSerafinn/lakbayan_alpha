import "package:flutter/widgets.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/app_settings.dart";
import "../../../core/models/destination.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/category_glyphs.dart";
import "../../profile/domain/settings_providers.dart";

part "place_kind.g.dart";

/// A kind of place: one of the six built in, or one the province added in
/// the CMS (`settings/taxonomy`).
///
/// The six carry their own glyph and colours. An added one brings an icon
/// from [CategoryGlyphs] and borrows the colours of one of the six ([look]),
/// so it needs no release. Chips, rails and grouping work by [key], which is
/// what a destination's `category` holds ([Destination.kindKey]).
@immutable
class PlaceKind {
  const PlaceKind.builtIn(DestinationCategory this.builtIn) : custom = null;
  const PlaceKind.added(CustomCategory this.custom) : builtIn = null;

  /// A category this phone cannot place: removed, or not loaded yet.
  static const other = PlaceKind.builtIn(DestinationCategory.unknown);

  /// The six, in the category's own order (Browse's and the Map's chips).
  static final builtIns = [
    for (final c in DestinationCategory.values)
      if (c != DestinationCategory.unknown) PlaceKind.builtIn(c),
  ];

  final DestinationCategory? builtIn;
  final CustomCategory? custom;

  String get key => builtIn?.name ?? custom!.id;

  bool get isOther => builtIn == DestinationCategory.unknown;

  /// On chips and section headings: "Museums", "Resorts".
  String get label => builtIn?.label ?? custom!.plural;

  /// One place of the kind: "Museum", "Resort". Empty for [other].
  String get name => switch (builtIn) {
    DestinationCategory.church => "Church",
    DestinationCategory.nature => "Nature",
    DestinationCategory.heritage => "Heritage",
    DestinationCategory.museum => "Museum",
    DestinationCategory.food => "Food",
    DestinationCategory.landmark => "Landmark",
    DestinationCategory.unknown => "",
    null => custom!.name,
  };

  /// Whose colours it is drawn in (`kindWash`, `kindTone`).
  DestinationCategory get look => builtIn ?? custom!.look;

  /// Its picture, the outline at rest and filled while chosen. An added
  /// kind with an icon this build does not know draws as [other] does.
  IconData glyph({bool filled = false}) {
    final kind = builtIn;
    if (kind != null) return AppIcons.kind(kind, filled: filled);
    return CategoryGlyphs.of(custom!.glyph, filled: filled) ??
        AppIcons.kind(DestinationCategory.unknown, filled: filled);
  }

  @override
  bool operator ==(Object other) => other is PlaceKind && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => "PlaceKind($key)";
}

/// The kind with this [key] among [added], or [PlaceKind.other].
PlaceKind kindForKey(String key, List<CustomCategory> added) {
  for (final kind in PlaceKind.builtIns) {
    if (kind.key == key) return kind;
  }
  for (final c in added) {
    if (c.id == key) return PlaceKind.added(c);
  }
  return PlaceKind.other;
}

/// The categories the province added, or none until they load (and on a
/// phone that has never read them offline).
@Riverpod(keepAlive: true)
List<CustomCategory> addedCategories(Ref ref) =>
    ref.watch(taxonomySettingsProvider).value?.categories ?? const [];

/// Every kind a chip row offers: the six, then the province's own.
@riverpod
List<PlaceKind> placeKinds(Ref ref) => [
  ...PlaceKind.builtIns,
  for (final c in ref.watch(addedCategoriesProvider)) PlaceKind.added(c),
];

/// The kind for a stored key ([Destination.kindKey], a chip's choice).
@riverpod
PlaceKind placeKind(Ref ref, String key) =>
    kindForKey(key, ref.watch(addedCategoriesProvider));
