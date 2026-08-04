import "package:cloud_firestore/cloud_firestore.dart";

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
        (snap) => snap.exists ? _toDestination(snap) : null,
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
        (snap) => snap.docs
            .map((d) => Segment.fromJson({...d.data(), "id": d.id}))
            .toList(),
      );

  List<Destination> _toList(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(_toDestination).toList();

  Destination _toDestination(DocumentSnapshot<Map<String, dynamic>> snap) =>
      Destination.fromJson({...?snap.data(), "id": snap.id});
}
