import "package:flutter_riverpod/flutter_riverpod.dart";

import "firebase_bootstrap.dart";

/// What [bootstrapFirebase] reported, made visible to the widget tree.
///
/// The status used to be computed and thrown away — `main()` awaited the
/// bootstrap and discarded the result, so the app knew it could not reach
/// Firebase and had no way of saying so. That is the whole reason an
/// unreachable emulator looked identical to an empty database.
///
/// **Defaults to null, and that is deliberate.** Widget tests pump
/// [LakbayanApp] inside their own `ProviderScope` and override only the auth
/// repository; a provider that threw unless overridden would make every one of
/// them fail, and force each new test to know about a diagnostic it does not
/// care about. Null means "nobody reported", and the banner renders nothing.
final firebaseBootstrapStatusProvider = Provider<FirebaseBootstrapStatus?>(
  (ref) => null,
);
