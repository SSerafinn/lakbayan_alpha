import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart" show kDebugMode;
import "package:latlong2/latlong.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "../data/destination_repository.dart";
import "../data/fake_destination_repository.dart";
import "../data/sample_destinations.dart";
import "saved_destinations.dart";

part "destination_providers.g.dart";

/// Overridden in tests with a fake; in debug, [SampleData] swaps in
/// `sampleDestinations`.
@Riverpod(keepAlive: true)
DestinationRepository destinationRepository(Ref ref) =>
    kDebugMode && ref.watch(sampleDataProvider)
    ? FakeDestinationRepository(sampleDestinations, segments: sampleSegments)
    : DestinationRepository(FirebaseFirestore.instance);

/// The debug preview switch, toggled from the Profile tab.
@Riverpod(keepAlive: true)
class SampleData extends _$SampleData {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

@riverpod
Stream<List<Destination>> popularDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchPopular();

@riverpod
Stream<List<Destination>> featuredDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchFeatured();

/// Every published destination, for the parts of Explore that are derived
/// rather than editorial: the towns list groups this by `town`.
@riverpod
Stream<List<Destination>> allDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchAll();

/// One entry per town, in the order the province's places are named, with
/// the places in it. Derived in the provider so the screen does not group on
/// every build (STANDARDS 5.6).
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
  const Town({required this.name, required this.places});

  final String name;
  final List<Destination> places;

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

  void select(DestinationCategory? category) => state = category;
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
/// Saved chip is on, sorted by distance from the selected pin when there is
/// one (client-side over `coords`, a small set).
@riverpod
AsyncValue<List<Destination>> mapResults(Ref ref) {
  final savedOnly = ref.watch(mapShowsSavedProvider);
  final saved = ref.watch(savedDestinationsProvider);
  final selectedId = ref.watch(mapSelectedIdProvider);
  return ref.watch(browseResultsProvider).whenData((all) {
    final items = [
      for (final destination in all)
        if (!savedOnly || saved.contains(destination.id)) destination,
    ];
    final selected = items.where((d) => d.id == selectedId).firstOrNull;
    if (selected == null) return items;
    final origin = LatLng(selected.coords.lat, selected.coords.lng);
    items.sort(
      (a, b) => _distance
          .distance(origin, LatLng(a.coords.lat, a.coords.lng))
          .compareTo(
            _distance.distance(origin, LatLng(b.coords.lat, b.coords.lng)),
          ),
    );
    return items;
  });
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

/// Browse results: the category query from Firestore, then the search text
/// applied in memory.
///
/// Firestore cannot do substring matching, and one province's published set is
/// small enough that filtering locally beats standing up a search service. It
/// also keeps search working offline, which a search service would not.
@riverpod
Stream<List<Destination>> browseResults(Ref ref) {
  final category = ref.watch(browseCategoryProvider);
  final query = ref.watch(browseQueryProvider).trim().toLowerCase();

  return ref
      .watch(destinationRepositoryProvider)
      .watchAll(category: category)
      .map(
        (all) => query.isEmpty
            ? all
            : all
                  .where(
                    (d) =>
                        d.name.toLowerCase().contains(query) ||
                        d.town.toLowerCase().contains(query),
                  )
                  .toList(),
      );
}

/// The category chosen on Home's strip. `null` is the full feed.
@riverpod
class HomeCategory extends _$HomeCategory {
  @override
  DestinationCategory? build() => null;

  /// Tapping the chosen category again clears it.
  void toggle(DestinationCategory category) =>
      state = state == category ? null : category;
}

/// The text in Home's expanded search field.
@riverpod
class HomeQuery extends _$HomeQuery {
  @override
  String build() => "";

  void update(String value) => state = value;
}

/// Home's matches while a category or a query is active: every published
/// place, filtered in memory (the same trade as [browseResults]).
@riverpod
List<Destination> homeResults(Ref ref) {
  final category = ref.watch(homeCategoryProvider);
  final query = ref.watch(homeQueryProvider).trim().toLowerCase();
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  return [
    for (final destination in all)
      if (category == null || destination.category == category)
        if (query.isEmpty ||
            destination.name.toLowerCase().contains(query) ||
            destination.town.toLowerCase().contains(query))
          destination,
  ];
}
