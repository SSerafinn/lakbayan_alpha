import "package:cloud_firestore/cloud_firestore.dart";

import "../../../core/diagnostics/error_reporter.dart";
import "../../../core/diagnostics/malformed_document.dart";
import "../../../core/models/guide.dart";

/// Reads `guides/{id}`. Featured and verified guides first, at most [limit].
/// Firestore's offline persistence serves the last copy with no signal.
class GuideRepository {
  const GuideRepository(
    this._firestore, {
    this._reporter = const NoopErrorReporter(),
  });

  final FirebaseFirestore _firestore;

  /// Told about every document this drops. See [decodeOrSkip].
  final ErrorReporter _reporter;

  static const limit = 10;

  /// Sorted here rather than by the query: two `orderBy`s on booleans would
  /// need a composite index, and ten rows cost nothing to sort.
  Stream<List<Guide>> watchAll() =>
      _firestore.collection("guides").limit(limit).snapshots().map((snap) {
        final guides = snap.docs
            .map(
              (doc) => decodeOrSkip(
                () => Guide.fromJson({...doc.data(), "id": doc.id}),
                what: "guide '${doc.id}'",
                reporter: _reporter,
              ),
            )
            .nonNulls
            .toList();
        int rank(Guide guide) =>
            (guide.featured ? 0 : 2) + (guide.verified ? 0 : 1);
        return guides..sort((a, b) => rank(a).compareTo(rank(b)));
      });
}
