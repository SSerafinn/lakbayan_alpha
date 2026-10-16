import "dart:async" show TimeoutException;
import "dart:io" show HttpException, SocketException;

import "package:firebase_core/firebase_core.dart" show FirebaseException;
import "package:flutter/foundation.dart" show debugPrint;

/// Firebase codes that mean the network was out of reach rather than that
/// anything was wrong with the request: Firestore's `unavailable` and
/// `deadline-exceeded`, Auth's `network-request-failed`, and Storage's
/// `retry-limit-exceeded`, which is what it says once it gives up on a dead
/// connection.
const _offlineCodes = {
  "unavailable",
  "deadline-exceeded",
  "network-request-failed",
  "retry-limit-exceeded",
};

/// Whether [error] is the phone being offline, or on a connection too poor
/// to finish, rather than something being broken.
bool isOfflineError(Object error) => switch (error) {
  FirebaseException(:final code) => _offlineCodes.contains(code),
  SocketException() || HttpException() || TimeoutException() => true,
  _ => false,
};

/// What [errorCopy] says after its lead when the phone is offline.
const offlineErrorHint =
    "You seem to be offline. Anything you've opened before still works.";

/// What [errorCopy] says after its lead for every other failure.
const genericErrorHint = "Something went wrong. Try again in a moment.";

/// The words for something that failed to load: [lead], what did not happen
/// ("Couldn't load destinations."), then what to do about it. [offline]
/// replaces the offline hint where the screen knows better what still works.
///
/// Never the exception's own text. That is written for a developer, and can
/// carry a path, a code or the project's id; it goes to the debug log here
/// instead, so not showing it loses nothing.
String errorCopy(
  String lead,
  Object error, {
  String offline = offlineErrorHint,
}) {
  _logOnce(lead, error);
  return "$lead ${isOfflineError(error) ? offline : genericErrorHint}";
}

/// The failures [errorCopy] has logged. Weak, so each is forgotten with the
/// state that held it.
final _logged = Expando<bool>("logged by errorCopy");

/// Logs [error] the first time it is put into words. [errorCopy] runs in
/// `build`, and a failure on screen is built again on every scroll or
/// keystroke; once in the log is enough.
void _logOnce(String lead, Object error) {
  // An Expando cannot hold a string, a number, a boolean or a record. Those
  // are logged each time, and only a plugin's bare message ever is one.
  final remembered = switch (error) {
    String() || num() || bool() || Record() => false,
    _ => true,
  };
  if (remembered) {
    if (_logged[error] ?? false) return;
    _logged[error] = true;
  }
  debugPrint("$lead $error");
}
