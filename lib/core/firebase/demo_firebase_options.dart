import "package:firebase_core/firebase_core.dart";

/// Placeholder Firebase options for **emulator-only** development.
///
/// These are not secrets and not credentials — they are deliberately fake. The
/// Emulator Suite treats any project whose ID starts with `demo-` as a local
/// sandbox: no real Firebase project is contacted, and any attempt to reach a
/// non-emulated service fails loudly rather than silently hitting production.
///
/// The project ID must match the `--project` flag the emulators run with; see
/// the `emulators` service command in `docker-compose.yml`.
///
/// A real project (`project-lakbayan`) now exists in
/// `lib/firebase_options.dart`, so why keep these?
///
/// **Safety.** `bootstrapFirebase` swallows emulator connection failures so the
/// app still boots. If emulator mode initialized with the *real* project
/// options and the emulator connection then failed, the app would silently fall
/// through to the production backend while the developer believed they were on
/// localhost — writing test data into the real Firestore.
///
/// A `demo-` project has no backend at all. Firebase refuses to contact one, so
/// that failure mode is impossible by construction rather than by care.
///
/// **That only holds if these options are the ones in force**, and on Android
/// they were not. `FirebaseInitProvider` built the default app from
/// `google-services.json` before `main()` ran, a default app cannot be
/// replaced, and emulator mode carried on with the real project's options —
/// the exact arrangement this file exists to rule out. The debug manifest now
/// removes that provider, and `bootstrapFirebase` reports
/// `emulatorsWrongProject` if the app ever comes up as anything else.
/// The id must match the `--project` flag on the `emulators` service in
/// `docker-compose.yml`.
const FirebaseOptions demoFirebaseOptions = FirebaseOptions(
  apiKey: "demo-api-key",
  appId: "1:000000000000:android:0000000000000000",
  messagingSenderId: "000000000000",
  projectId: "demo-lakbayan",
  storageBucket: "demo-lakbayan.appspot.com",
);
