import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/itinerary.dart";
import "../../auth/domain/auth_providers.dart";
import "../data/itinerary_repository.dart";

part "itinerary_providers.g.dart";

@Riverpod(keepAlive: true)
TourRepository tourRepository(Ref ref) =>
    TourRepository(FirebaseFirestore.instance);

@Riverpod(keepAlive: true)
ItineraryRepository itineraryRepository(Ref ref) =>
    ItineraryRepository(FirebaseFirestore.instance);

@riverpod
Stream<List<Tour>> tours(Ref ref) =>
    ref.watch(tourRepositoryProvider).watchAll();

@riverpod
Stream<Tour?> tourById(Ref ref, String id) =>
    ref.watch(tourRepositoryProvider).watchById(id);

/// The signed-in user's own itineraries.
///
/// Empty for a guest rather than an error. Wireframe 1b lets somebody browse
/// without an account, and the tab should explain what signing in would give
/// them rather than fail at them.
@riverpod
Stream<List<Itinerary>> myItineraries(Ref ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(itineraryRepositoryProvider).watchAll(uid);
}

/// The province's tours this user has saved, in the catalog's order.
@riverpod
Stream<List<Tour>> savedTours(Ref ref) {
  final saved = ref.watch(userProfileProvider).value?.savedTourIds ?? const [];
  if (saved.isEmpty) return Stream.value(const []);
  return ref
      .watch(tourRepositoryProvider)
      .watchAll()
      .map((all) => all.where((t) => saved.contains(t.id)).toList());
}
