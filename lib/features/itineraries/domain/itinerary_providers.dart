import "package:cloud_firestore/cloud_firestore.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/models/itinerary.dart";
import "../../../core/models/destination.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../data/itinerary_repository.dart";

part "itinerary_providers.g.dart";

@Riverpod(keepAlive: true)
TourRepository tourRepository(Ref ref) => TourRepository(
  FirebaseFirestore.instance,
  reporter: ref.watch(errorReporterProvider),
);

@Riverpod(keepAlive: true)
ItineraryRepository itineraryRepository(Ref ref) => ItineraryRepository(
  FirebaseFirestore.instance,
  reporter: ref.watch(errorReporterProvider),
);

@riverpod
Stream<List<Tour>> tours(Ref ref) =>
    ref.watch(tourRepositoryProvider).watchAll();

/// Explore's rail of ready-made days: featured tours first, at most ten.
@riverpod
AsyncValue<List<Tour>> tourRail(Ref ref) =>
    ref.watch(toursProvider).whenData((all) {
      final routed = [
        for (final tour in all)
          if (tour.stops.isNotEmpty) tour,
      ];
      return [
        for (final tour in routed)
          if (tour.featured) tour,
        for (final tour in routed)
          if (!tour.featured) tour,
      ].take(10).toList();
    });

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

/// The Itineraries tab's order: the trip that comes next, given real size,
/// and the rest.
typedef TripShelf = ({Itinerary? next, List<Itinerary> others});

/// Derived here so the tab does not sort in `build()`.
@riverpod
AsyncValue<TripShelf> tripShelf(Ref ref) =>
    ref.watch(myItinerariesProvider).whenData((all) {
      if (all.isEmpty) return (next: null, others: const <Itinerary>[]);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool ahead(Itinerary trip) {
        final last = trip.endDate ?? trip.startDate;
        return last != null && !last.isBefore(today);
      }

      final upcoming =
          [
            for (final trip in all)
              if (ahead(trip)) trip,
          ]..sort(
            (a, b) => (a.startDate ?? a.endDate!).compareTo(
              b.startDate ?? b.endDate!,
            ),
          );
      final recent = [...all]
        ..sort((a, b) {
          final at = a.updatedAt ?? a.createdAt;
          final bt = b.updatedAt ?? b.createdAt;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at);
        });
      final next = upcoming.firstOrNull ?? recent.first;
      return (
        next: next,
        others: [
          for (final trip in all)
            if (trip.id != next.id) trip,
        ],
      );
    });

/// One of the user's itineraries, or null while loading or once it is gone.
///
/// Derived from [myItineraries], so it opens no query of its own and a
/// screen does not search the whole list on every build.
@riverpod
AsyncValue<Itinerary?> itineraryById(Ref ref, String id) => ref
    .watch(myItinerariesProvider)
    .whenData(
      (all) => all.where((itinerary) => itinerary.id == id).firstOrNull,
    );

/// Every published place by id, derived once per change to the list so the
/// itinerary screen does not index every place on each build (its map and
/// strip resolve the stops in the order on screen, which may be a reorder
/// still being written).
@riverpod
Map<String, Destination> placesById(Ref ref) => {
  for (final place in ref.watch(allDestinationsProvider).value ?? const [])
    place.id: place,
};

/// Every published place not already on [id]: what Add a stop offers.
@riverpod
List<Destination> addableStops(Ref ref, String id) {
  final stops =
      ref.watch(itineraryByIdProvider(id)).value?.destinationIds ?? const [];
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  return [
    for (final place in all)
      if (!stops.contains(place.id)) place,
  ];
}

/// The places offered as a new itinerary's first stop: the first few
/// published, so the sheet stays a short choice rather than a catalogue.
@riverpod
List<Destination> firstStopChoices(Ref ref) =>
    (ref.watch(allDestinationsProvider).value ?? const []).take(8).toList();

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
