import "dart:ui" show ErrorCallback;

import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/diagnostics/error_reporter.dart";
import "package:lakbayan/core/firebase/firebase_bootstrap.dart";

import "../../support/recording_error_reporter.dart";

/// The parts of a [FirebaseCrashlytics] the reporter calls. Anything else
/// throws, which is the point: nothing else should be called.
class _FakeCrashlytics extends Fake implements FirebaseCrashlytics {
  final collectionEnabled = <bool>[];
  final reports = <({Object? exception, bool fatal, bool? printDetails})>[];
  var unsentDeleted = 0;

  /// Set to make every report fail, as a broken platform channel would.
  Object? reportError;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async =>
      collectionEnabled.add(enabled);

  @override
  Future<void> deleteUnsentReports() async => unsentDeleted++;

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) async {
    if (reportError case final error?) throw error;
    reports.add((
      exception: exception,
      fatal: fatal,
      printDetails: printDetails,
    ));
  }
}

/// Where uncaught errors go, and when Crashlytics is allowed anywhere near
/// them. Both global hooks are put back after every test.
void main() {
  late FlutterExceptionHandler? savedOnError;
  late FlutterExceptionHandler savedPresentError;
  late ErrorCallback? savedPlatformOnError;
  late DebugPrintCallback savedDebugPrint;
  late List<String?> printed;
  late List<FlutterErrorDetails> presented;

  setUp(() {
    savedOnError = FlutterError.onError;
    savedPresentError = FlutterError.presentError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    savedDebugPrint = debugPrint;

    printed = [];
    presented = [];
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    FlutterError.presentError = presented.add;
  });

  tearDown(() {
    FlutterError.onError = savedOnError;
    FlutterError.presentError = savedPresentError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    debugPrint = savedDebugPrint;
  });

  FlutterErrorDetails frameworkError() => FlutterErrorDetails(
    exception: StateError("RenderFlex overflowed"),
    stack: StackTrace.current,
  );

  group("installErrorReporting", () {
    test("a framework error still prints, and is reported as fatal", () {
      final reporter = RecordingErrorReporter();
      installErrorReporting(reporter);

      final details = frameworkError();
      FlutterError.onError!(details);

      expect(presented, [same(details)]);
      expect(reporter.flutterErrors, hasLength(1));
      expect(reporter.flutterErrors.single.details, same(details));
      expect(reporter.flutterErrors.single.fatal, isTrue);
      expect(reporter.errors, isEmpty);
    });

    test("an uncaught error elsewhere still prints, is reported as fatal, "
        "and is marked handled", () {
      final reporter = RecordingErrorReporter();
      installErrorReporting(reporter);

      final error = StateError("Future nobody awaited");
      final stack = StackTrace.current;
      final handled = PlatformDispatcher.instance.onError!(error, stack);

      // False would hand it back to the engine, which reports it its own way
      // as well.
      expect(handled, isTrue);
      expect(printed.join("\n"), contains("Future nobody awaited"));
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.error, same(error));
      expect(reporter.errors.single.stack, same(stack));
      expect(reporter.errors.single.fatal, isTrue);
      expect(reporter.flutterErrors, isEmpty);
    });
  });

  group("startErrorReporting", () {
    test("anything but a live launch never touches Crashlytics", () async {
      for (final status in FirebaseBootstrapStatus.values) {
        if (status == FirebaseBootstrapStatus.live) continue;
        var touched = false;

        final reporter = await startErrorReporting(
          status,
          crashlytics: () {
            touched = true;
            return _FakeCrashlytics();
          },
        );

        expect(touched, isFalse, reason: "$status reached Crashlytics");
        expect(reporter, isA<NoopErrorReporter>(), reason: "$status");
        expect(FlutterError.onError, same(savedOnError), reason: "$status");
        expect(
          PlatformDispatcher.instance.onError,
          same(savedPlatformOnError),
          reason: "$status",
        );
      }
    });

    test("a live release launch installs Crashlytics, collecting", () async {
      final crashlytics = _FakeCrashlytics();

      final reporter = await startErrorReporting(
        FirebaseBootstrapStatus.live,
        crashlytics: () => crashlytics,
        debug: false,
      );

      expect(reporter, isA<CrashlyticsErrorReporter>());
      expect(crashlytics.collectionEnabled, [true]);
      expect(crashlytics.unsentDeleted, 0);

      FlutterError.onError!(frameworkError());
      await pumpEventQueue();

      expect(crashlytics.reports, hasLength(1));
      expect(crashlytics.reports.single.fatal, isTrue);
      // installErrorReporting already printed it; Crashlytics must not again.
      expect(crashlytics.reports.single.printDetails, isFalse);
      expect(presented, hasLength(1));
    });

    test("a live debug launch turns collection off, deletes what is waiting, "
        "and installs nothing", () async {
      // Kept with collection off, a report would still be uploaded once a
      // release build installed over this one turned collection back on.
      final crashlytics = _FakeCrashlytics();

      final reporter = await startErrorReporting(
        FirebaseBootstrapStatus.live,
        crashlytics: () => crashlytics,
      );

      expect(reporter, isA<NoopErrorReporter>());
      expect(crashlytics.collectionEnabled, [false]);
      expect(crashlytics.unsentDeleted, 1);
      expect(FlutterError.onError, same(savedOnError));
      expect(PlatformDispatcher.instance.onError, same(savedPlatformOnError));
    });

    test("a Crashlytics that will not start leaves the app without reports, "
        "not without a launch", () async {
      final reporter = await startErrorReporting(
        FirebaseBootstrapStatus.live,
        crashlytics: () => throw StateError("no default app"),
      );

      expect(reporter, isA<NoopErrorReporter>());
      expect(FlutterError.onError, same(savedOnError));
    });
  });

  test("a report that cannot be sent is logged, not thrown", () async {
    // Left uncaught it would come back through PlatformDispatcher.onError and
    // fail the same way. An uncaught async error fails this test.
    final crashlytics = _FakeCrashlytics()
      ..reportError = StateError("channel closed");
    CrashlyticsErrorReporter(crashlytics).recordError(StateError("boom"), null);
    await pumpEventQueue();

    expect(printed.join("\n"), contains("Crash report not sent"));
  });
}
