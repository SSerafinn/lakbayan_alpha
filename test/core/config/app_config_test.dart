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
    test("never throws, whatever the environment", () async {
      // The property that matters: main() awaits this before runApp, so
      // anything escaping means no Flutter view is mounted and the app is a
      // blank window with nothing on screen to explain why.
      //
      // The suite runs without emulator defines and without platform channels,
      // so live init genuinely fails here — `unavailable` is the correct
      // outcome. Asserting on completion rather than a specific status keeps
      // this test about not-throwing rather than about which backend is up.
      await expectLater(bootstrapFirebase(), completes);
    });
  });
}
