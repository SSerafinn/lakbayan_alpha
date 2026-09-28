import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "destination_providers.dart";

part "saved_destinations.g.dart";

/// Places saved with the heart, in save order. In memory until
/// `users/{uid}.savedDestinationIds` exists; see
/// `my-docs/backend-requests/saved-destinations.md`.
@Riverpod(keepAlive: true)
class SavedDestinations extends _$SavedDestinations {
  @override
  Set<String> build() => const {};

  void save(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);

  bool contains(String id) => state.contains(id);
}

/// The saved places that are still published, newest save first. Async so
/// the screen can tell "still loading the catalogue" from "nothing saved".
@riverpod
AsyncValue<List<Destination>> savedPlaces(Ref ref) {
  final ids = ref.watch(savedDestinationsProvider);
  return ref.watch(allDestinationsProvider).whenData((all) {
    final byId = {for (final destination in all) destination.id: destination};
    return [for (final id in ids.toList().reversed) ?byId[id]];
  });
}
