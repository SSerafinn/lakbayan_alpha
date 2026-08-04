import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";

import "../../firebase_options.dart";
import "../config/app_config.dart";
import "demo_firebase_options.dart";

/// Outcome of [bootstrapFirebase], so callers can report it rather than guess.
enum FirebaseBootstrapStatus {
  /// Firebase is up and every SDK points at the local Emulator Suite.
  emulators,

  /// Firebase is up and pointing at a real project.
  live,

  /// Initialization was attempted and failed — most often the emulator suite
  /// is not running. The app still boots; anything touching Firebase will fail.
  unavailable,
}

/// Initializes Firebase and, in emulator mode, repoints the SDKs at the local
/// Emulator Suite.
///
/// **Never throws, and that is load-bearing.** `main()` awaits this before
/// `runApp`, so anything escaping here means no Flutter view is ever mounted and
/// the app is a black screen with nothing on screen to explain why. That is
/// exactly what happens when the emulator suite is not running, which is a
/// routine state for a developer who has not started Docker yet.
///
/// Failures are logged and reported as a status; booting to the sign-in screen
/// with broken auth is far more diagnosable than a blank window.
Future<FirebaseBootstrapStatus> bootstrapFirebase() async {
  if (!AppConfig.useFirebaseEmulators) {
    try {
      await _initializeApp(DefaultFirebaseOptions.currentPlatform);
      debugPrint("Firebase: LIVE project — writes hit the real backend.");
      return FirebaseBootstrapStatus.live;
    } catch (e, st) {
      debugPrint("Firebase live init failed: $e");
      debugPrintStack(stackTrace: st);
      return FirebaseBootstrapStatus.unavailable;
    }
  }

  try {
    await _initializeApp(demoFirebaseOptions);
    await _connectEmulators();
    return FirebaseBootstrapStatus.emulators;
  } catch (e, st) {
    debugPrint(
      "Firebase emulator bootstrap FAILED on ${AppConfig.emulatorHost}: $e\n"
      "Is the suite running? `docker compose up emulators`. "
      "The app will start, but anything touching Firebase will fail.",
    );
    debugPrintStack(stackTrace: st);
    return FirebaseBootstrapStatus.unavailable;
  }
}

/// Creates the default [FirebaseApp], tolerating one already existing.
///
/// On Android the `FirebaseInitProvider` content provider can create the
/// `[DEFAULT]` app before `main()` ever runs — Analytics and Crashlytics both
/// drag it in. Calling `initializeApp` again then dies with
/// `IllegalStateException: FirebaseApp name [DEFAULT] already exists!`, which
/// surfaces in Dart as a bare `PlatformException`, not a typed
/// `FirebaseException`. So adopt the existing app rather than matching on an
/// error code.
Future<FirebaseApp> _initializeApp(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) return Firebase.app();
  try {
    return await Firebase.initializeApp(options: options);
  } catch (_) {
    if (Firebase.apps.isNotEmpty) return Firebase.app();
    rethrow;
  }
}

/// Must run before any Firestore/Auth/Storage call — these SDKs latch their
/// endpoint on first use and repointing afterwards throws.
Future<void> _connectEmulators() async {
  final host = AppConfig.emulatorHost;

  await FirebaseAuth.instance.useAuthEmulator(host, AppConfig.authEmulatorPort);
  FirebaseFirestore.instance
      .useFirestoreEmulator(host, AppConfig.firestoreEmulatorPort);
  await FirebaseStorage.instance
      .useStorageEmulator(host, AppConfig.storageEmulatorPort);

  debugPrint(
    "Firebase emulators: auth :${AppConfig.authEmulatorPort}, "
    "firestore :${AppConfig.firestoreEmulatorPort}, "
    "storage :${AppConfig.storageEmulatorPort} on $host",
  );
}
