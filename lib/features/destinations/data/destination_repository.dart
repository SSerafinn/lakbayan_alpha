import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

import "../../../core/models/destination.dart";

/// Reads published destinations.
///
/// **Every query filters on `status == published`.** That is not an
/// optimisation — `firestore.rules` gates reads on the field, and Firestore
/// denies an unfiltered collection query *wholesale* rather than returning the
/// subset the caller may see. Dropping the filter turns a working screen into
/// a blanket permission-denied, which reads like an auth bug.
///
/// Reads are local-first: Firestore's offline persistence serves the cached
/// copy when there is no connection, which is what makes Explore work on a
/// boat off Palaui.
class DestinationRepository {
  DestinationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection("destinations");

  Query<Map<String, dynamic>> get _published =>
      _col.where("status", isEqualTo: "published");

  /// Explore → "Popular Places" carousel.
  Stream<List<Destination>> watchPopular({int limit = 10}) => _published
      .where("popular", isEqualTo: true)
      .orderBy("name")
      .limit(limit)
      .snapshots()
      .map(_toList);

  /// Explore → the featured rail, and the FEATURED badge in lists.
  Stream<List<Destination>> watchFeatured({int limit = 10}) => _published
      .where("featured", isEqualTo: true)
      .orderBy("name")
      .limit(limit)
      .snapshots()
      .map(_toList);

  /// Browse → everything, or one category.
  ///
  /// Search is applied client-side by the provider rather than here: Firestore
  /// has no substring matching, and the published set for one province is small
  /// enough that filtering in memory beats adding a search service.
  Stream<List<Destination>> watchAll({DestinationCategory? category}) {
    var query = _published;
    if (category != null && category != DestinationCategory.unknown) {
      query = query.where("category", isEqualTo: category.name);
    }
    return query.orderBy("name").snapshots().map(_toList);
  }

  Stream<Destination?> watchById(String id) => _col.doc(id).snapshots().map(
        (snap) => snap.exists ? _tryParse(snap) : null,
      );

  /// Audio guide stops, in player order.
  ///
  /// Readable only when the parent destination is published — the rules resolve
  /// that by looking at the parent, so this needs no status filter of its own.
  Stream<List<Segment>> watchSegments(String destinationId) => _col
      .doc(destinationId)
      .collection("segments")
      .orderBy("order")
      .snapshots()
      .map(
        (snap) => _decodeAll(
          snap.docs,
          (data, id) => Segment.fromJson({...data, "id": id}),
          label: "segment",
        ),
      );

  List<Destination> _toList(QuerySnapshot<Map<String, dynamic>> snap) =>
      _decodeAll(
        snap.docs,
        (data, id) => Destination.fromJson({...data, "id": id}),
        label: "destination",
      );

  /// Decodes what it can and **drops** what it cannot.
  ///
  /// One malformed document must not blank out a whole screen. That is not
  /// hypothetical: a document written by a newer client, a half-finished
  /// migration, or a seeding script that only set the fields it cared about
  /// will all fail to parse, and mapping the snapshot eagerly turns a single
  /// bad row into an empty Explore tab with no explanation.
  ///
  /// Skipping is the lesser evil — the rest of the province still renders.
  /// The failure is logged loudly because silently vanishing content is its own
  /// kind of bug.
  // TODO(phase-5): report these to Crashlytics — in the field nobody reads logs.
  List<T> _decodeAll<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    T Function(Map<String, dynamic> data, String id) decode, {
    required String label,
  }) {
    final out = <T>[];
    for (final doc in docs) {
      try {
        out.add(decode(doc.data(), doc.id));
      } catch (e) {
        debugPrint(
          "Skipping malformed $label '${doc.id}': $e\n"
          "The document is missing a required field or has an unexpected type. "
          "Check it against docs/DATA_MODEL.md.",
        );
      }
    }
    return out;
  }

  /// Single-document variant. A document that cannot be decoded is reported as
  /// absent, so the detail screen shows its "no longer available" state rather
  /// than an exception.
  Destination? _tryParse(DocumentSnapshot<Map<String, dynamic>> snap) {
    try {
      return Destination.fromJson({...?snap.data(), "id": snap.id});
    } catch (e) {
      debugPrint("Skipping malformed destination '${snap.id}': $e");
      return null;
    }
  }
}
