import "package:flutter/foundation.dart";

/// Compile-time configuration, supplied via `--dart-define` or, more usually,
/// `--dart-define-from-file=config/dev.json`.
///
/// Every value here is `const`, which is the point: a release build compiled
/// without the emulator defines has the emulator branch tree-shaken out
/// entirely. There is no runtime switch that could point a shipped app at
/// somebody's laptop.
abstract final class AppConfig {
  /// Whether to route Auth/Firestore/Storage at the local Emulator Suite.
  static const bool useFirebaseEmulators = bool.fromEnvironment(
    "USE_FIREBASE_EMULATORS",
  );

  static const String _emulatorHostOverride = String.fromEnvironment(
    "FIREBASE_EMULATOR_HOST",
  );

  static const int authEmulatorPort = int.fromEnvironment(
    "FIREBASE_AUTH_EMULATOR_PORT",
    defaultValue: 9099,
  );

  static const int firestoreEmulatorPort = int.fromEnvironment(
    "FIREBASE_FIRESTORE_EMULATOR_PORT",
    defaultValue: 8080,
  );

  static const int storageEmulatorPort = int.fromEnvironment(
    "FIREBASE_STORAGE_EMULATOR_PORT",
    defaultValue: 9199,
  );

  /// OAuth web client ID for Google Sign-In.
  ///
  /// Web only. On Android the client ID comes out of `google-services.json`,
  /// but there is no equivalent on web, so `google_sign_in_web` asserts unless
  /// it is passed explicitly. Not a secret — it is public by design and appears
  /// in the page source of every site using Google Sign-In.
  ///
  /// Find it in the Firebase console under
  /// Authentication → Sign-in method → Google → Web SDK configuration.
  static const String googleWebClientId = String.fromEnvironment(
    "GOOGLE_WEB_CLIENT_ID",
  );

  /// Where the Emulator Suite is reachable from *this* device.
  ///
  /// An Android emulator cannot see the host's `localhost` — 10.0.2.2 is its
  /// alias for the host loopback. A physical device needs the host's LAN IP,
  /// which the app has no way to discover, so it must be passed explicitly:
  ///
  ///   flutter run --dart-define-from-file=config/dev.json \
  ///               --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.42
  static String get emulatorHost {
    if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return "10.0.2.2";
    }
    return "localhost";
  }
}
