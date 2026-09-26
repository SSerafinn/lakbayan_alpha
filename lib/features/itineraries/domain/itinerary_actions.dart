import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/itinerary.dart";
import "../../auth/domain/auth_providers.dart";
import "../data/itinerary_repository.dart";
import "itinerary_providers.dart";

part "itinerary_actions.g.dart";

/// The writes a screen makes to the signed-in user's itineraries, in one
/// place: who is signed in, the repository call, and what a failure does.
///
/// Every method returns whether it landed (a `create` returns the new id, or
/// null). A failure is logged and handed back rather than thrown, so a screen
/// shows it on the control that caused it and never leaves an
/// unhandled error behind a fire-and-forget tap. A guest has no uid, and
/// every write is then a quiet no-op that reports false.
///
/// The repository calls, and so the documents written, are exactly the ones
/// the screens made before; this only gathers them.
@riverpod
ItineraryActions itineraryActions(Ref ref) => ItineraryActions(
  ref.watch(itineraryRepositoryProvider),
  ref.watch(authStateProvider.select((auth) => auth.value?.uid)),
);

class ItineraryActions {
  const ItineraryActions(this._repository, this._uid);

  final ItineraryRepository _repository;
  final String? _uid;

  Future<String?> create({
    required String name,
    List<String> stops = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) => _run(
    "create",
    (uid) => _repository.create(
      uid,
      name: name,
      destinationIds: stops,
      startDate: startDate,
      endDate: endDate,
    ),
  );

  /// Appends [destinationId] as the trip's last stop.
  Future<bool> addStop(Itinerary itinerary, String destinationId) =>
      setStops(itinerary.id, [...itinerary.destinationIds, destinationId]);

  Future<bool> setStops(String id, List<String> stops) =>
      _done("set stops", (uid) => _repository.setStops(uid, id, stops));

  Future<bool> setDates(String id, DateTime? start, DateTime? end) => _done(
    "set dates",
    (uid) => _repository.setDates(uid, id, startDate: start, endDate: end),
  );

  Future<bool> rename(String id, String name) =>
      _done("rename", (uid) => _repository.rename(uid, id, name));

  Future<bool> delete(String id) =>
      _done("delete", (uid) => _repository.delete(uid, id));

  Future<bool> _done(String what, Future<void> Function(String uid) write) =>
      _run(what, (uid) async {
        await write(uid);
        return true;
      }).then((landed) => landed ?? false);

  Future<T?> _run<T>(String what, Future<T> Function(String uid) write) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      return await write(uid);
    } catch (error) {
      debugPrint("Itinerary $what failed: $error");
      return null;
    }
  }
}
