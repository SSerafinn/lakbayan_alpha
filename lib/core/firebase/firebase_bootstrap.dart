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
  /// Firebase is up, every SDK points at the local Emulator Suite, and the
  /// suite answered.
  emulators,

  /// The SDKs are pointed at an emulator host that did not answer.
  ///
  /// Distinct from [unavailable] because initialization *worked* — the address
  /// is simply wrong or unreachable. Almost always a stale
  /// `FIREBASE_EMULATOR_HOST` after a DHCP change, or Docker not running.
  emulatorsUnreachable,

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
  // Print the *effective* compile-time config on every boot. These are
  // --dart-define values, so they are baked in at build time: a hot reload or
  // hot restart will not pick up an edit to config/dev.json, and running
  // without --dart-define-from-file silently yields defaults. Both failure
  // modes look identical at runtime, hence this line.
  debugPrint(
    "Lakbayan config — emulators: ${AppConfig.useFirebaseEmulators}, "
    "host: ${AppConfig.emulatorHost}, "
    "googleWebClientId: ${AppConfig.googleWebClientId.isEmpty ? "MISSING" : "set"}",
  );

  if (!AppConfig.useFirebaseEmulators) {
    try {
      await _initializeApp(DefaultFirebaseOptions.currentPlatform);
      _enableOfflinePersistence();
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
    _enableOfflinePersistence();

    if (await _emulatorAnswered()) {
      return FirebaseBootstrapStatus.emulators;
    }
    debugPrint(
      "Firebase emulators did NOT answer on ${AppConfig.emulatorHost}.\n"
      "The SDKs are pointed there regardless, so reads will quietly serve an "
      "empty cache and every list will look like it has no content.\n"
      "  - Suite running?  docker compose up -d emulators\n"
      "  - Right address?  on a physical device this must be your PC's current "
      "LAN IP, which changes with the DHCP lease. `node scripts/emulator-host.mjs` "
      "prints it.",
    );
    return FirebaseBootstrapStatus.emulatorsUnreachable;
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

/// Did anything actually answer at [AppConfig.emulatorHost]?
///
/// **`useFirestoreEmulator` performs no I/O and cannot fail.** It records an
/// endpoint and returns, so a wrong host leaves this function's caller
/// reporting a healthy emulator connection while every subsequent read serves
/// an empty cache. On screen that is indistinguishable from "no content has
/// been added yet", with nothing in the logs either way — which is exactly how
/// a stale LAN IP in `config/local.json` cost an afternoon once already.
///
/// `Source.server` is what makes the check mean anything: it refuses the
/// cache, so the call can only succeed by reaching the suite. A
/// permission-denied still counts as reached — the rules were evaluated, which
/// means something on the other end answered.
///
/// Emulator mode only. In a live build this is never called, so no startup
/// round trip is added to a real launch.
Future<bool> _emulatorAnswered() async {
  try {
    await FirebaseFirestore.instance
        .collection("destinations")
        .where("status", isEqualTo: "published")
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 4));
    return true;
  } on FirebaseException catch (e) {
    return e.code == "permission-denied";
  } catch (_) {
    // Timeout, or the platform channel giving up on an address nothing is
    // listening at.
    return false;
  }
}

/// Turns on Firestore's local cache, with no size cap.
///
/// Set explicitly rather than left to the default, because offline-first is a
/// hard guardrail here and the default is not the same everywhere: mobile
/// enables persistence, web does not. This is what lets every read path serve
/// from cache when there is no signal — the whole point of an app used on the
/// road in Cagayan.
///
/// Unbounded because a downloaded town's destinations must not be evicted to
/// make room; Phase 3's offline bundles depend on that.
void _enableOfflinePersistence() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
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
