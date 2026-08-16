import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/app.dart";
import "package:lakbayan/core/firebase/firebase_bootstrap.dart";
import "package:lakbayan/core/firebase/firebase_status_provider.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";

import "../support/fake_auth_repository.dart";

/// The strip exists to make a misconfigured backend visible, so the case that
/// matters most is [FirebaseBootstrapStatus.emulatorsUnreachable] — the state
/// that previously looked exactly like an empty database.
void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pump(
    WidgetTester tester,
    FirebaseBootstrapStatus? status,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          if (status != null)
            firebaseBootstrapStatusProvider.overrideWithValue(status),
        ],
        child: const LakbayanApp(),
      ),
    );
    // Not pumpAndSettle: signed out, the app opens on the landing page, whose
    // greeting and swipe chevron animate on repeating controllers. An idle
    // tree never arrives, so advance the clock by hand instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets("says nothing when no status was reported", (tester) async {
    // The default every widget test gets. A diagnostic that made unrelated
    // tests assert around it would not survive contact with the next screen.
    await pump(tester, null);

    expect(find.textContaining("Emulators"), findsNothing);
    expect(find.textContaining("No emulator"), findsNothing);
  });

  testWidgets("names the host when the emulators answered", (tester) async {
    await pump(tester, FirebaseBootstrapStatus.emulators);

    expect(find.textContaining("Emulators ·"), findsOneWidget);
  });

  testWidgets("warns that lists will look empty when nothing answered", (
    tester,
  ) async {
    await pump(tester, FirebaseBootstrapStatus.emulatorsUnreachable);

    // The wording is the point: without it, the reasonable conclusion from a
    // blank Explore tab is that no content has been added yet.
    expect(find.textContaining("lists will look empty"), findsOneWidget);
  });

  testWidgets("stays out of the way on a live build", (tester) async {
    await pump(tester, FirebaseBootstrapStatus.live);

    expect(find.textContaining("Live project"), findsNothing);
  });
}
