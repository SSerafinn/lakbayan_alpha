import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

import "../../../core/models/itinerary.dart";

/// Reads the province's curated tours — `tours/{id}`.
///
/// World-readable, so unlike destinations there is no status filter to
/// remember. Reads are local-first through Firestore's offline persistence.
class TourRepository {
  const TourRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection("tours");

  Stream<List<Tour>> watchAll() => _col
      .orderBy("title")
      .snapshots()
      .map(
        (snap) => _decode(
          snap.docs,
          (data, id) => Tour.fromJson({...data, "id": id}),
        ),
      );

  Stream<Tour?> watchById(String id) => _col.doc(id).snapshots().map((snap) {
    if (!snap.exists) return null;
    try {
      return Tour.fromJson({...?snap.data(), "id": snap.id});
    } catch (e) {
      debugPrint("Skipping malformed tour '${snap.id}': $e");
      return null;
    }
  });
}

/// Reads and writes `users/{uid}/itineraries` — tours somebody built.
///
/// Owner-only, so every method takes the uid explicitly rather than reaching
/// for the current user. That keeps the repository testable and makes the
/// ownership obvious at every call site.
class ItineraryRepository {
  const ItineraryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection("users").doc(uid).collection("itineraries");

  /// Most recently touched first. Somebody planning a trip is working on the
  /// one they just edited, not the one they made in March.
  Stream<List<Itinerary>> watchAll(String uid) => _col(uid)
      .orderBy("updatedAt", descending: true)
      .snapshots()
      .map(
        (snap) => _decode(
          snap.docs,
          (data, id) => Itinerary.fromJson({...data, "id": id}),
        ),
      );

  Future<String> create(
    String uid, {
    required String name,
    List<String> destinationIds = const [],
  }) async {
    final ref = await _col(uid).add({
      "name": name,
      "destinationIds": destinationIds,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> rename(String uid, String id, String name) =>
      _col(uid)
          .doc(id)
          .update({"name": name, "updatedAt": FieldValue.serverTimestamp()});

  /// Replace the whole ordered list.
  ///
  /// Whole-list rather than arrayUnion: the order *is* the route, and
  /// `arrayUnion` appends without saying where. Reordering is the common edit
  /// here, so the array is written as one value.
  Future<void> setStops(String uid, String id, List<String> destinationIds) =>
      _col(uid).doc(id).update({
        "destinationIds": destinationIds,
        "updatedAt": FieldValue.serverTimestamp(),
      });

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();
}

/// Decode what we can, drop what we cannot.
///
/// One malformed document must not empty a screen — the same reasoning, and
/// the same trade, as `DestinationRepository._decodeAll`.
List<T> _decode<T>(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  T Function(Map<String, dynamic> data, String id) decode,
) {
  final out = <T>[];
  for (final doc in docs) {
    try {
      out.add(decode(doc.data(), doc.id));
    } catch (e) {
      debugPrint("Skipping malformed document '${doc.id}': $e");
    }
  }
  return out;
}
