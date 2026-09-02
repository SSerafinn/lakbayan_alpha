import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app.dart";
import "core/firebase/firebase_bootstrap.dart";
import "core/firebase/firebase_status_provider.dart";
import "core/prefs/app_preferences.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never throws — see bootstrapFirebase. The app still boots to the
  // placeholder home screen when Firebase is unconfigured.
  // Also turns on Firestore offline persistence — see _enableOfflinePersistence.
  final status = await bootstrapFirebase();

  // Device-local flags. Falls back to an in-memory instance rather than
  // failing to boot: the only thing riding on this today is whether the
  // landing pages have been seen, and showing them again is a far better
  // outcome than a black screen because a Hive box would not open.
  // TODO(phase-3): the same init covers downloaded assets and bundle tracking.
  AppPreferences prefs;
  try {
    prefs = await HivePreferences.open();
  } catch (e) {
    debugPrint("Preferences unavailable, continuing without them: $e");
    prefs = InMemoryPreferences();
  }

  runApp(
    ProviderScope(
      // The status used to be discarded here. Handing it to the tree is what
      // lets the debug strip say which backend is answering — without it, an
      // unreachable emulator and an empty database look identical on screen.
      overrides: [
        firebaseBootstrapStatusProvider.overrideWithValue(status),
        appPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LakbayanApp(),
    ),
  );
}
