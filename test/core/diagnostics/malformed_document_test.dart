import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/diagnostics/malformed_document.dart";
import "package:lakbayan/core/models/destination.dart";

import "../../support/recording_error_reporter.dart";

/// What every repository does with a document it cannot read: drop it, and
/// say so to the reporter. The repositories themselves need a Firestore to
/// run; this is the part that decides what gets reported.
void main() {
  late DebugPrintCallback savedDebugPrint;

  setUp(() {
    savedDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
  });
  tearDown(() => debugPrint = savedDebugPrint);

  // Written by a seeding script that only set the fields it cared about.
  Destination? decodeHalfSeeded(RecordingErrorReporter reporter) =>
      decodeOrSkip(
        () => Destination.fromJson({"id": "palaui", "name": "Palaui Island"}),
        what: "destination 'palaui'",
        reporter: reporter,
      );

  test("a document that decodes is returned and nothing is reported", () {
    final reporter = RecordingErrorReporter();

    final value = decodeOrSkip(
      () => "decoded",
      what: "destination 'palaui'",
      reporter: reporter,
    );

    expect(value, "decoded");
    expect(reporter.errors, isEmpty);
  });

  test("a malformed document is dropped and reported as non-fatal", () {
    final reporter = RecordingErrorReporter();

    expect(decodeHalfSeeded(reporter), isNull);

    expect(reporter.errors, hasLength(1));
    final report = reporter.errors.single;
    expect(report.fatal, isFalse);
    expect(report.stack, isNotNull);
    expect(report.reason, contains("destination 'palaui'"));
    expect(reporter.flutterErrors, isEmpty);
  });

  test("the same failure is reported once, however often it is decoded", () {
    // A snapshot stream decodes again on every change, and Crashlytics keeps
    // only eight non-fatals a session.
    final reporter = RecordingErrorReporter();

    for (var i = 0; i < 5; i++) {
      decodeHalfSeeded(reporter);
    }
    decodeOrSkip<String>(
      () => throw const FormatException("bad coords"),
      what: "destination 'callao-cave'",
      reporter: reporter,
    );

    expect(reporter.errors, hasLength(2));
    expect(reporter.errors.last.reason, contains("callao-cave"));
  });

  test("the same failure in two documents is reported for each", () {
    // Every imported destination's first stop is `stop-01`, so a segment's
    // name has to carry its destination's, or the second report is lost.
    final reporter = RecordingErrorReporter();

    for (final destination in ["palaui", "callao-cave"]) {
      decodeOrSkip<String>(
        () => throw const FormatException("title missing"),
        what: "destination '$destination' segment 'stop-01'",
        reporter: reporter,
      );
    }

    expect(reporter.errors.map((e) => e.reason), [
      contains("palaui"),
      contains("callao-cave"),
    ]);
  });

  test("a fresh reporter hears about it again", () {
    decodeHalfSeeded(RecordingErrorReporter());
    final second = RecordingErrorReporter();

    decodeHalfSeeded(second);

    expect(second.errors, hasLength(1));
  });
}
