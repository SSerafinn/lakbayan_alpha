import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";

import "../config/app_config.dart";
import "demo_firebase_options.dart";

/// Outcome of [bootstrapFirebase], so callers can report it rather than guess.
enum FirebaseBootstrapStatus {
  /// Firebase is up and every SDK points at the local Emulator Suite.
  emulators,

  /// Firebase is up and pointing at a real project.
  live,

  /// Firebase was skipped: no emulator defines and no generated options.
  notConfigured,
}

/// Initializes Firebase and, in emulator mode, repoints the SDKs at the local
/// Emulator Suite.
///
/// Deliberately never throws. Until someone runs `flutterfire configure` there
/// are no real options to initialize with, and a hard failure there would stop
/// the app booting to its placeholder home screen for everyone not running the
/// emulators. Returns [FirebaseBootstrapStatus.notConfigured] instead.
Future<FirebaseBootstrapStatus> bootstrapFirebase() async {
  if (!AppConfig.useFirebaseEmulators) {
    // TODO(phase-1): after `flutterfire configure`, import the generated
    // lib/firebase_options.dart and initialize with
    // DefaultFirebaseOptions.currentPlatform, returning `live`.
    debugPrint(
      "Firebase not initialized: no emulator defines and no generated "
      "firebase_options.dart. Run with "
      "--dart-define-from-file=config/dev.json, or run `flutterfire "
      "configure`. See docs/DOCKER.md.",
    );
    return FirebaseBootstrapStatus.notConfigured;
  }

  await _initializeApp(demoFirebaseOptions);
  await _connectEmulators();
  return FirebaseBootstrapStatus.emulators;
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
