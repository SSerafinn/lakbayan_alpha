import "package:flutter/foundation.dart";
import "package:lakbayan/core/diagnostics/error_reporter.dart";

/// One [ErrorReporter.recordError] call.
typedef RecordedError = ({
  Object error,
  StackTrace? stack,
  bool fatal,
  String? reason,
});

/// An [ErrorReporter] that keeps what it is told, for a test to look at.
class RecordingErrorReporter implements ErrorReporter {
  final errors = <RecordedError>[];
  final flutterErrors = <({FlutterErrorDetails details, bool fatal})>[];

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) => errors.add((error: error, stack: stack, fatal: fatal, reason: reason));

  @override
  void recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) =>
      flutterErrors.add((details: details, fatal: fatal));
}
