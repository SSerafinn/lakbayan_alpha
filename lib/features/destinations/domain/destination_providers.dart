import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart" show kReleaseMode;
import "package:latlong2/latlong.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../data/destination_repository.dart";
import "../data/fake_destination_repository.dart";
import "../data/sample_destinations.dart";
import "saved_destinations.dart";

part "destination_providers.g.dart";

/// Overridden in tests; in debug/profile builds [SampleData] swaps in sample data.
/// Profile is included so perf is measured on the same preview as production.
@Riverpod(keepAlive: true)
DestinationRepository destinationRepository(Ref ref) =>
    !kReleaseMode && ref.watch(sampleDataProvider)
    ? FakeDestinationRepository(sampleDestinations, segments: sampleSegments)
    : DestinationRepository(
        FirebaseFirestore.instance,
        reporter: ref.watch(errorReporterProvider),
      );

/// The debug preview switch, toggled from the Profile tab.
@Riverpod(keepAlive: true)
class SampleData extends _$SampleData {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

// keepAlive: tab switches unmount Explore; auto-dispose would re-open these on every return.

@Riverpod(keepAlive: true)
Stream<List<Destination>> popularDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchPopular();

@Riverpod(keepAlive: true)
Stream<List<Destination>> featuredDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchFeatured();

/// Every published destination, for the parts of Explore that are derived
/// rather than editorial: the towns list groups this by `town`.
@Riverpod(keepAlive: true)
Stream<List<Destination>> allDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchAll();

/// A photo for each kind of place, Explore's kind pills: its first place
/// with one.
@riverpod
Map<DestinationCategory, String> kindCovers(Ref ref) {
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  final covers = <DestinationCategory, String>{};
  for (final place in all) {
    final cover = place.coverImage;
    if (cover != null) covers.putIfAbsent(place.category, () => cover);
  }
  return covers;
}

/// Grouped by town. Derived here so the screen does not group on every build.
@riverpod
List<Town> towns(Ref ref) {
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  final byTown = <String, List<Destination>>{};
  for (final destination in all) {
    byTown.putIfAbsent(destination.town, () => []).add(destination);
  }
  final towns = [
    for (final entry in byTown.entries)
      Town(name: entry.key, places: entry.value),
  ]..sort((a, b) => b.places.length.compareTo(a.places.length));
  return towns;
}

/// A municipality and the published places in it.
class Town {
  Town({required this.name, required this.places}) : byKind = _group(places);

  final String name;
  final List<Destination> places;

  /// Its places by kind, in the order the kinds first show: the town page's
  /// chips and what each one shows. Grouped once here, not on every build.
  final Map<DestinationCategory, List<Destination>> byKind;

  static Map<DestinationCategory, List<Destination>> _group(
    List<Destination> places,
  ) {
    final byKind = <DestinationCategory, List<Destination>>{};
    for (final place in places) {
      byKind.putIfAbsent(place.category, () => []).add(place);
    }
    return byKind;
  }

  /// The photo that stands for the town: its first place with one.
  String? get cover {
    for (final place in places) {
      final image = place.coverImage;
      if (image != null) return image;
    }
    return null;
  }
}

@riverpod
Stream<Destination?> destinationById(Ref ref, String id) =>
    ref.watch(destinationRepositoryProvider).watchById(id);

@riverpod
Stream<List<Segment>> destinationSegments(Ref ref, String id) =>
    ref.watch(destinationRepositoryProvider).watchSegments(id);

/// Selected category chip on Browse. `null` is "All".
///
/// The wireframe specifies single-select, so this is one value rather than a set.
@riverpod
class BrowseCategory extends _$BrowseCategory {
  @override
  DestinationCategory? build() => null;

  void select(DestinationCategory? category) {
    state = category;
    // A subcategory belongs to one category; under another it means nothing.
    ref.read(browseSubcategoryProvider.notifier).select(null);
  }
}

/// Selected subcategory chip on Browse, under the chosen category. `null` is
/// the whole category. Cleared whenever the category changes.
@riverpod
class BrowseSubcategory extends _$BrowseSubcategory {
  @override
  String? build() => null;

  void select(String? value) => state = value;
}

/// Search box on Browse.
@riverpod
class BrowseQuery extends _$BrowseQuery {
  @override
  String build() => "";

  void update(String value) => state = value;
}

/// The Map tab lands on the map; this flips it to the Browse grid, the same
/// results as photos. A provider rather than widget state so the choice
/// survives a tab switch.
@riverpod
class BrowseShowsGrid extends _$BrowseShowsGrid {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool value) => state = value;
}

/// Only saved places on the map. The "Saved" chip; exclusive with a category.
@riverpod
class MapShowsSaved extends _$MapShowsSaved {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The pin tapped on the map, or null. Set from outside too: Place detail's
/// "Getting there" lands here.
@riverpod
class MapSelectedId extends _$MapSelectedId {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// The places the map shows: Browse's results, narrowed to saved when the
/// Saved chip is on. Not reordered by the selection: the rail's cards are
/// this list, and a card must not change place under a swipe.
@riverpod
AsyncValue<List<Destination>> mapResults(Ref ref) {
  final savedOnly = ref.watch(mapShowsSavedProvider);
  final saved = ref.watch(savedDestinationsProvider);
  return ref
      .watch(browseResultsProvider)
      .deriveKeepingValue(
        (all) => [
          for (final destination in all)
            if (!savedOnly || saved.contains(destination.id)) destination,
        ],
      );
}

const _distance = Distance();

/// Metres between two places.
double distanceBetween(Destination from, Destination to) => _distance.distance(
  LatLng(from.coords.lat, from.coords.lng),
  LatLng(to.coords.lat, to.coords.lng),
);

/// "900 m" or "2.4 km".
String distanceLabel(double metres) => metres < 1000
    ? "${metres.round()} m"
    : "${(metres / 1000).toStringAsFixed(1)} km";

/// The two closest published places to [id] that may appear as Nearby.
@riverpod
List<Destination> nearby(Ref ref, String id) {
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  final origin = all.where((d) => d.id == id).firstOrNull;
  if (origin == null) return const [];
  final others =
      [
        for (final destination in all)
          if (destination.id != id && destination.nearbyEligible) destination,
      ]..sort(
        (a, b) =>
            distanceBetween(origin, a).compareTo(distanceBetween(origin, b)),
      );
  return others.take(2).toList();
}

/// The category query from Firestore. "All" is the same query as
/// [allDestinations], so it reuses that listener instead of opening a second.
/// Public only so Browse and the Map can invalidate it to try again after a
/// failure ([browseSource]); read [browseResults] instead.
@riverpod
Stream<List<Destination>> browseCategoryStream(Ref ref) {
  final category = ref.watch(browseCategoryProvider);
  return ref.watch(destinationRepositoryProvider).watchAll(category: category);
}

/// Browse results: the category's places, then the search text applied in
/// memory.
///
/// Firestore cannot do substring matching, and one province's published set is
/// small enough that filtering locally beats standing up a search service. It
/// also keeps search working offline, which a search service would not.
///
/// The text filter is derived here rather than folded into the stream, so a
/// keystroke re-filters what is loaded instead of re-subscribing to Firestore.
@riverpod
AsyncValue<List<Destination>> browseResults(Ref ref) {
  final category = ref.watch(browseCategoryProvider);
  final subcategory = ref.watch(browseSubcategoryProvider);
  final query = ref.watch(browseQueryProvider).trim().toLowerCase();
  final source = category == null
      ? ref.watch(allDestinationsProvider)
      : ref.watch(browseCategoryStreamProvider);
  if (query.isEmpty && subcategory == null) return source;
  return source.deriveKeepingValue(
    (all) => [
      for (final destination in all)
        if ((subcategory == null || destination.subcategory == subcategory) &&
            (query.isEmpty ||
                destination.name.toLowerCase().contains(query) ||
                destination.town.toLowerCase().contains(query) ||
                (destination.subcategory?.toLowerCase().contains(query) ??
                    false)))
          destination,
    ],
  );
}

/// The listener [browseResults] reads under [category]: every place for
/// "All", else that category's query. What Browse and the Map invalidate to
/// try again after a failed load.
ProviderOrFamily browseSource(DestinationCategory? category) =>
    category == null ? allDestinationsProvider : browseCategoryStreamProvider;

/// The subcategories among the chosen category's places, for Browse's second
/// chip row. Empty with no category chosen, or none in use, and the row then
/// does not show.
///
/// Taken from the places rather than from the CMS's list, so a chip never
/// leads to an empty grid — a subcategory the province has named but not yet
/// used has nothing to show.
@riverpod
List<String> browseSubcategories(Ref ref) {
  final category = ref.watch(browseCategoryProvider);
  if (category == null) return const [];
  final places = ref.watch(browseCategoryStreamProvider).value ?? const [];
  final names = <String>{
    for (final d in places)
      if (d.subcategory?.trim().isNotEmpty ?? false) d.subcategory!,
  };
  return names.toList()..sort();
}

/// Browse's results cut into grid rows of [columns]. Derived here, not on every build.
@riverpod
AsyncValue<List<List<Destination>>> browseGridRows(Ref ref, int columns) =>
    ref.watch(browseResultsProvider).deriveKeepingValue((items) {
      final rows = <List<Destination>>[];
      var current = <Destination>[];
      for (final item in items) {
        if (item.featured) {
          if (current.isNotEmpty) rows.add(current);
          rows.add([item]);
          current = [];
          continue;
        }
        current.add(item);
        if (current.length == columns) {
          rows.add(current);
          current = [];
        }
      }
      if (current.isNotEmpty) rows.add(current);
      return rows;
    });

/// Up to three more places in [id]'s town, skipping [id] and the two shown
/// as Nearby, so Place detail ends somewhere to go.
@riverpod
List<Destination> moreInTown(Ref ref, String id) {
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  final origin = all.where((d) => d.id == id).firstOrNull;
  if (origin == null) return const [];
  final shown = {
    id,
    for (final place in ref.watch(nearbyProvider(id))) place.id,
  };
  final town = ref
      .watch(townsProvider)
      .where((t) => t.name == origin.town)
      .firstOrNull;
  return [
    for (final place in town?.places ?? const <Destination>[])
      if (!shown.contains(place.id)) place,
  ].take(3).toList();
}

/// One of Place detail's "Around here": a place and the line under its
/// name.
typedef AroundHerePlace = ({Destination place, String line});

/// Place detail's "Around here": nearest places with distance, then more from the same town.
@riverpod
List<AroundHerePlace> aroundHere(Ref ref, String id) {
  final origin = ref.watch(destinationByIdProvider(id)).value;
  if (origin == null) return const [];
  return [
    for (final place in ref.watch(nearbyProvider(id)))
      (
        place: place,
        line: "${distanceLabel(distanceBetween(origin, place))} away",
      ),
    for (final place in ref.watch(moreInTownProvider(id)))
      (place: place, line: place.town),
  ];
}

/// Food places for Explore's "Where to eat", photo-first, at most ten.
@riverpod
List<Destination> foodPlaces(Ref ref) {
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  return [
    for (final place in all)
      if (place.category == DestinationCategory.food) place,
  ].take(10).toList();
}

/// The kind chosen on Explore's chips. `null` is the full feed.
@riverpod
class HomeCategory extends _$HomeCategory {
  @override
  DestinationCategory? build() => null;

  /// Tapping the chosen category again clears it.
  void toggle(DestinationCategory category) =>
      state = state == category ? null : category;
}

/// The text in the search surface's field (the bar's search cell).
@riverpod
class HomeQuery extends _$HomeQuery {
  @override
  String build() => "";

  void update(String value) => state = value;
}

/// The kind chosen on the search surface's chips, apart from Home's strip so
/// a search never rearranges the feed behind it.
@riverpod
class SearchCategory extends _$SearchCategory {
  @override
  DestinationCategory? build() => null;

  /// Tapping the chosen kind again clears it.
  void toggle(DestinationCategory category) =>
      state = state == category ? null : category;

  void clear() => state = null;
}

/// Home's matches while its strip has a category chosen. Async, as
/// [savedPlaces] is, so Explore can tell "still loading" and "couldn't
/// load" from "nothing of this kind"; derived keeping the value, so places
/// already on the phone stay when a later read of them fails.
@riverpod
AsyncValue<List<Destination>> homeResults(Ref ref) {
  final category = ref.watch(homeCategoryProvider);
  return ref
      .watch(allDestinationsProvider)
      .deriveKeepingValue(
        (all) => _matching(all, category: category, query: ""),
      );
}

/// The search surface's matches: its own kind and the typed query. Async
/// for the same reason as [homeResults].
@riverpod
AsyncValue<List<Destination>> searchResults(Ref ref) {
  final category = ref.watch(searchCategoryProvider);
  final query = ref.watch(homeQueryProvider);
  return ref
      .watch(allDestinationsProvider)
      .deriveKeepingValue(
        (all) => _matching(all, category: category, query: query),
      );
}

/// Every published place, filtered in memory (the same trade as
/// [browseResults]): by kind when one is chosen, and by name or town.
List<Destination> _matching(
  List<Destination> all, {
  required DestinationCategory? category,
  required String query,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final destination in all)
      if (category == null || destination.category == category)
        if (needle.isEmpty ||
            destination.name.toLowerCase().contains(needle) ||
            destination.town.toLowerCase().contains(needle))
          destination,
  ];
}
