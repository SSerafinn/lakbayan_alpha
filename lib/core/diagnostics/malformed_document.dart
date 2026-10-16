import "package:flutter/foundation.dart";

import "error_reporter.dart";

/// Decodes one Firestore document, or reports why it could not and returns
/// null.
///
/// The one place a malformed document becomes a missing one. Every repository
/// makes that trade — one bad document must not blank a screen — and each of
/// them used to make it with a `debugPrint` that nobody in the field reads.
/// Content that silently vanishes is its own kind of bug; this is what gets it
/// in front of somebody, as a non-fatal report.
///
/// [what] names the document for whoever reads the report, e.g.
/// `destination 'palaui'`: a label and an id, not the path, because an
/// itinerary's path carries its owner's uid. It must pick out one document on
/// its own, since it is also what the once-only rule below keys on, so a
/// subcollection's id comes with its parent's:
/// `destination 'palaui' segment 'stop-01'`.
///
/// **Each distinct failure is reported once per [reporter].** A snapshot
/// stream decodes again on every change, and one destination can sit in
/// Explore's popular, featured and browse queries at once, so a single bad
/// document would otherwise be reported over and over. Crashlytics keeps only
/// the last eight non-fatal reports of a session; repeats would push out the
/// one that was different. Per reporter rather than global, so each test's
/// fake starts clean.
T? decodeOrSkip<T extends Object>(
  T Function() decode, {
  required String what,
  required ErrorReporter reporter,
}) {
  try {
    return decode();
  } catch (e, st) {
    debugPrint(
      "Skipping malformed $what: $e\n"
      "The document is missing a required field or has an unexpected type. "
      "Check it against docs/DATA_MODEL.md.",
    );
    final reported = _reported[reporter] ??= <String>{};
    if (reported.add("$what: $e")) {
      reporter.recordError(e, st, reason: "while decoding $what");
    }
    return null;
  }
}

final _reported = Expando<Set<String>>("malformed documents reported");
