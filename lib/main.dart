import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app.dart";
import "core/firebase/firebase_bootstrap.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never throws — see bootstrapFirebase. The app still boots to the
  // placeholder home screen when Firebase is unconfigured.
  await bootstrapFirebase();
  // TODO(phase-1): init Hive and enable Firestore offline persistence.
  runApp(const ProviderScope(child: LakbayanApp()));
}
