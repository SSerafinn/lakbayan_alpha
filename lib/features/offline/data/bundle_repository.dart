import "package:cloud_firestore/cloud_firestore.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/diagnostics/malformed_document.dart";
import "../domain/offline_bundle.dart";

/// Reads `offlineBundles`.
///
/// World-readable by design — wireframe 1b keeps discovery open to guests, and
/// choosing a town to download is discovery. So unlike `destinations` there is
/// no status filter to remember here.
class BundleRepository {
  const BundleRepository(
    this._firestore, {
    this._reporter = const NoopErrorReporter(),
  });

  final FirebaseFirestore _firestore;

  /// Told about every manifest this drops. See [decodeOrSkip].
  final ErrorReporter _reporter;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection("offlineBundles");

  /// Every town with a bundle, by name.
  Stream<List<OfflineBundle>> watchAll() => _col
      .orderBy("name")
      .snapshots()
      .map(
        // One malformed manifest must not empty the downloads screen — the
        // same reasoning as DestinationRepository._decodeAll.
        (snap) => snap.docs
            .map(
              (doc) => decodeOrSkip(
                () => OfflineBundle.fromJson({...doc.data(), "townId": doc.id}),
                what: "bundle '${doc.id}'",
                reporter: _reporter,
              ),
            )
            .nonNulls
            .toList(),
      );

  Stream<OfflineBundle?> watchById(String townId) =>
      _col.doc(townId).snapshots().map((snap) {
        if (!snap.exists) return null;
        return decodeOrSkip(
          () => OfflineBundle.fromJson({...?snap.data(), "townId": snap.id}),
          what: "bundle '${snap.id}'",
          reporter: _reporter,
        );
      });
}
