import "dart:async";

import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../firebase/firebase_bootstrap.dart";

part "error_reporter.g.dart";

/// Where errors go that nobody is in the room to read.
///
/// A seam rather than calls to `FirebaseCrashlytics.instance` wherever
/// something fails, for two reasons. Touching that instance needs a real
/// Firebase app: tests have none, and emulator runs have a demo project
/// Crashlytics has never heard of. And the repositories that drop malformed
/// documents are constructed in tests that should not have to care.
///
/// **Reports only, and never throws.** Printing stays with the caller, so the
/// console reads the same whichever reporter is installed. Both methods are
/// fire-and-forget: they are called from `FlutterError.onError` and from
/// inside stream transforms, neither of which can await anything.
abstract interface class ErrorReporter {
  /// An error caught outside the framework — an uncaught async error, or one
  /// a repository chose to survive. [reason] says what was being attempted.
  void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  /// An error the framework caught: a build, layout or paint failure.
  void recordFlutterError(FlutterErrorDetails details, {bool fatal = false});
}

/// Reports nothing. The default, so tests, emulator runs and debug builds never
/// reach Crashlytics; `main()` swaps in [CrashlyticsErrorReporter] for a live
/// profile or release build.
class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) {}

  @override
  void recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) {}
}

/// Sends reports to Firebase Crashlytics. Only ever built for a
/// [FirebaseBootstrapStatus.live] launch outside debug — see
/// [startErrorReporting].
class CrashlyticsErrorReporter implements ErrorReporter {
  const CrashlyticsErrorReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) => _send(
    _crashlytics.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
      printDetails: false,
    ),
  );

  /// Not `FirebaseCrashlytics.recordFlutterError`, which also calls
  /// `FlutterError.presentError`. [installErrorReporting] already has, so
  /// every framework error would print twice. This is the same report
  /// without the second print.
  @override
  void recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) =>
      _send(
        _crashlytics.recordError(
          details.exceptionAsString(),
          details.stack,
          reason: details.context
              ?.toStringDeep(minLevel: DiagnosticLevel.info)
              .trim(),
          information: details.informationCollector?.call() ?? const [],
          fatal: fatal,
          printDetails: false,
        ),
      );

  /// A report that cannot be sent is logged and dropped. Left uncaught it
  /// would reach `PlatformDispatcher.onError`, which would try to report it,
  /// and fail the same way.
  void _send(Future<void> report) {
    unawaited(
      report.catchError((Object e) {
        debugPrint("Crash report not sent: $e");
      }),
    );
  }
}

/// The reporter for this launch. Overridden in `main()`; anything else gets
/// [NoopErrorReporter], so a widget test never needs to know this exists.
@Riverpod(keepAlive: true)
ErrorReporter errorReporter(Ref ref) => const NoopErrorReporter();

/// Picks the reporter for this launch, and installs it when it is a real one.
///
/// **Crashlytics is not touched unless [status] is
/// [FirebaseBootstrapStatus.live].** Emulator builds point at a demo project
/// Crashlytics has never heard of, and an unavailable Firebase has no app for
/// `FirebaseCrashlytics.instance` to find.
///
/// **A debug build reports nothing**, live or not. A developer's hot-reload
/// mistakes are not field crashes, and the console already shows them.
/// Collection off is not enough on its own: Crashlytics keeps on the device
/// whatever it is given meanwhile, and uploads it once a release build
/// installed over this one turns collection back on. So debug also installs
/// no hooks, and deletes what is already waiting — the native SDK records a
/// native crash whether or not the hooks are in.
///
/// Never throws, for the same reason as [bootstrapFirebase]: `main()` awaits
/// this before `runApp`. A Crashlytics that will not start means a launch
/// without crash reports, not a black screen.
///
/// [crashlytics] and [debug] are for tests, which have no Firebase to get the
/// real instance from and always run in debug.
Future<ErrorReporter> startErrorReporting(
  FirebaseBootstrapStatus status, {
  @visibleForTesting FirebaseCrashlytics Function()? crashlytics,
  @visibleForTesting bool debug = kDebugMode,
}) async {
  if (status != FirebaseBootstrapStatus.live) return const NoopErrorReporter();
  try {
    final instance = (crashlytics ?? () => FirebaseCrashlytics.instance)();
    await instance.setCrashlyticsCollectionEnabled(!debug);
    if (debug) {
      await instance.deleteUnsentReports();
      return const NoopErrorReporter();
    }
    final reporter = CrashlyticsErrorReporter(instance);
    installErrorReporting(reporter);
    return reporter;
  } catch (e, st) {
    debugPrint("Crashlytics unavailable, continuing without it: $e");
    debugPrintStack(stackTrace: st);
    return const NoopErrorReporter();
  }
}

/// Sends every error nothing else caught to [reporter], as fatal.
///
/// Two hooks, because Flutter has two places an error can end up:
/// `FlutterError.onError` for what the framework caught while building,
/// laying out or painting, and `PlatformDispatcher.onError` for everything
/// else — an uncaught error in a `Future`, a stream, a platform callback.
///
/// The console keeps what it showed before. `FlutterError.presentError` is the
/// framework's own default handler; the platform hook prints for itself,
/// because returning `true` tells the engine the error is handled and it no
/// longer prints anything.
void installErrorReporting(ErrorReporter reporter) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.recordFlutterError(details, fatal: true);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrintStack(stackTrace: stack, label: "Uncaught error: $error");
    reporter.recordError(error, stack, fatal: true);
    return true;
  };
}
