import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/config/app_config.dart";
import "package:lakbayan/core/firebase/firebase_bootstrap.dart";

void main() {
  group("AppConfig", () {
    test("emulators are off unless explicitly compiled in", () {
      // The suite runs without --dart-define, which is the same state a
      // release build ships in. If this ever fails, a build could be pointed
      // at a developer's machine.
      expect(AppConfig.useFirebaseEmulators, isFalse);
    });

    test("ports default to the docker-compose published ports", () {
      expect(AppConfig.authEmulatorPort, 9099);
      expect(AppConfig.firestoreEmulatorPort, 8080);
      expect(AppConfig.storageEmulatorPort, 9199);
    });

    group("emulatorHost", () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      test("resolves to 10.0.2.2 on Android", () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        // The Android emulator cannot reach the host's localhost.
        expect(AppConfig.emulatorHost, "10.0.2.2");
      });

      test("resolves to localhost elsewhere", () {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        expect(AppConfig.emulatorHost, "localhost");
      });
    });
  });

  group("bootstrapFirebase", () {
    test("reports notConfigured instead of throwing when unconfigured", () async {
      // Without emulator defines and without a generated firebase_options.dart
      // there is nothing to initialize. Booting to the placeholder home screen
      // must still work, so this path must not throw.
      await expectLater(
        bootstrapFirebase(),
        completion(FirebaseBootstrapStatus.notConfigured),
      );
    });
  });
}
