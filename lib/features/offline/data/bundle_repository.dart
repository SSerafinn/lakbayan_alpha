import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

import "../domain/offline_bundle.dart";

/// Reads `offlineBundles`.
///
/// World-readable by design — wireframe 1b keeps discovery open to guests, and
/// choosing a town to download is discovery. So unlike `destinations` there is
/// no status filter to remember here.
class BundleRepository {
  const BundleRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection("offlineBundles");

  /// Every town with a bundle, by name.
  Stream<List<OfflineBundle>> watchAll() =>
      _col.orderBy("name").snapshots().map((snap) {
        final out = <OfflineBundle>[];
        for (final doc in snap.docs) {
          try {
            out.add(OfflineBundle.fromJson({...doc.data(), "townId": doc.id}));
          } catch (e) {
            // One malformed manifest must not empty the downloads screen —
            // the same reasoning as DestinationRepository._decodeAll.
            debugPrint("Skipping malformed bundle '${doc.id}': $e");
          }
        }
        return out;
      });

  Stream<OfflineBundle?> watchById(String townId) =>
      _col.doc(townId).snapshots().map((snap) {
        if (!snap.exists) return null;
        try {
          return OfflineBundle.fromJson({...?snap.data(), "townId": snap.id});
        } catch (e) {
          debugPrint("Skipping malformed bundle '${snap.id}': $e");
          return null;
        }
      });
}
