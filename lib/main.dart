import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app.dart";
import "core/firebase/firebase_bootstrap.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never throws — see bootstrapFirebase. The app still boots to the
  // placeholder home screen when Firebase is unconfigured.
  // Also turns on Firestore offline persistence — see _enableOfflinePersistence.
  await bootstrapFirebase();
  // TODO(phase-3): init Hive for downloaded assets and offline bundle tracking.
  runApp(const ProviderScope(child: LakbayanApp()));
}
