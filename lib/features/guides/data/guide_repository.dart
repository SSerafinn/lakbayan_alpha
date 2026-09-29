import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

import "../../../core/models/guide.dart";

/// Reads `guides/{id}`. Featured and verified guides first, at most [limit].
/// Firestore's offline persistence serves the last copy with no signal.
class GuideRepository {
  const GuideRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const limit = 10;

  /// Sorted here rather than by the query: two `orderBy`s on booleans would
  /// need a composite index, and ten rows cost nothing to sort.
  Stream<List<Guide>> watchAll() =>
      _firestore.collection("guides").limit(limit).snapshots().map((snap) {
        final guides = <Guide>[];
        for (final doc in snap.docs) {
          try {
            guides.add(Guide.fromJson({...doc.data(), "id": doc.id}));
          } catch (e) {
            debugPrint("Skipping malformed guide '${doc.id}': $e");
          }
        }
        int rank(Guide guide) =>
            (guide.featured ? 0 : 2) + (guide.verified ? 0 : 1);
        return guides..sort((a, b) => rank(a).compareTo(rank(b)));
      });
}
