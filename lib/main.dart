import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path_provider/path_provider.dart";

import "app.dart";
import "core/firebase/firebase_bootstrap.dart";
import "core/firebase/firebase_status_provider.dart";
import "core/prefs/app_preferences.dart";
import "features/offline/data/download_store.dart";
import "features/offline/domain/offline_providers.dart";

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
  AppPreferences prefs;
  try {
    prefs = await HivePreferences.open();
  } catch (e) {
    debugPrint("Preferences unavailable, continuing without them: $e");
    prefs = InMemoryPreferences();
  }

  // Which towns are on this device. Same fallback reasoning: an in-memory
  // store reads as "nothing downloaded", so the app offers a download rather
  // than claiming one it cannot produce. The files would still be on disk, so
  // nothing is lost beyond a repeat download.
  DownloadStore downloads;
  try {
    downloads = await HiveDownloadStore.open();
  } catch (e) {
    debugPrint("Download records unavailable, continuing without them: $e");
    downloads = InMemoryDownloadStore();
  }

  final documents = await getApplicationDocumentsDirectory();

  runApp(
    ProviderScope(
      // The status used to be discarded here. Handing it to the tree is what
      // lets the debug strip say which backend is answering — without it, an
      // unreachable emulator and an empty database look identical on screen.
      overrides: [
        firebaseBootstrapStatusProvider.overrideWithValue(status),
        appPreferencesProvider.overrideWithValue(prefs),
        downloadStoreProvider.overrideWithValue(downloads),
        // Documents, not cache: the OS may empty a cache directory whenever it
        // likes, and a town that vanishes because the phone got low on space
        // is exactly the failure an offline bundle exists to prevent.
        downloadRootProvider.overrideWithValue(documents),
      ],
      child: const LakbayanApp(),
    ),
  );
}
