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
/// Real builds use `lib/firebase_options.dart` from `flutterfire configure`,
/// which is gitignored. See `docs/DOCKER.md`.
const FirebaseOptions demoFirebaseOptions = FirebaseOptions(
  apiKey: "demo-api-key",
  appId: "1:000000000000:android:0000000000000000",
  messagingSenderId: "000000000000",
  projectId: "demo-lakbayan",
  storageBucket: "demo-lakbayan.appspot.com",
);
