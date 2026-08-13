import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app.dart";
import "core/firebase/firebase_bootstrap.dart";
import "core/firebase/firebase_status_provider.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never throws — see bootstrapFirebase. The app still boots to the
  // placeholder home screen when Firebase is unconfigured.
  // Also turns on Firestore offline persistence — see _enableOfflinePersistence.
  final status = await bootstrapFirebase();
  // TODO(phase-3): init Hive for downloaded assets and offline bundle tracking.
  runApp(
    ProviderScope(
      // The status used to be discarded here. Handing it to the tree is what
      // lets the debug strip say which backend is answering — without it, an
      // unreachable emulator and an empty database look identical on screen.
      overrides: [firebaseBootstrapStatusProvider.overrideWithValue(status)],
      child: const LakbayanApp(),
    ),
  );
}
