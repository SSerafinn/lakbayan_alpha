import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "../data/destination_repository.dart";

part "destination_providers.g.dart";

/// Overridden in tests with a fake.
@Riverpod(keepAlive: true)
DestinationRepository destinationRepository(Ref ref) =>
    DestinationRepository(FirebaseFirestore.instance);

@riverpod
Stream<List<Destination>> popularDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchPopular();

@riverpod
Stream<List<Destination>> featuredDestinations(Ref ref) =>
    ref.watch(destinationRepositoryProvider).watchFeatured();

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
