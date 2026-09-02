import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/app.dart";
import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/auth/presentation/sign_in_screen.dart";
import "package:lakbayan/features/auth/presentation/splash_screen.dart";
import "package:lakbayan/features/explore/presentation/home_shell.dart";
import "package:lakbayan/features/landing/presentation/landing_screen.dart";

import "support/fake_auth_repository.dart";

/// The landing page animates forever: the greeting loops and the swipe chevron
/// nudges on a repeating controller. `pumpAndSettle` waits for an idle tree and
/// so never returns on it, which is why these tests advance the clock by hand.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpApp(WidgetTester tester, {FakeAuthRepository? repo}) async {
    // The default 800dp test surface cuts off the bottom of the sign-in screen,
    // and a ListView does not build children outside its viewport — so the
    // guest button would not exist to tap. Give the tests a tall phone.
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo ?? auth)],
        child: const LakbayanApp(),
      ),
    );
    await settle(tester);
  }

  /// The landing page is the signed-out entry point **on a fresh device**, so
  /// any test that needs the sign-in screen travels through it first. There is
  /// no skip control by design: the only way out is to swipe past the last
  /// page, or tap the chevron that does the same thing.
  ///
  /// These tests override no preferences, which reads as "landing not yet
  /// seen". Once it has been, a signed-out launch goes straight to sign-in —
  /// covered in test/features/landing/landing_test.dart.
  Future<void> leaveLanding(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await settle(tester);
    }
  }

  testWidgets("no account yet lands on the landing page", (tester) async {
    await pumpApp(tester);

    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets("the landing page hands off to sign-in", (tester) async {
    await pumpApp(tester);
    await leaveLanding(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(LandingScreen), findsNothing);
  });

  testWidgets("a signed-in user goes straight to the home shell", (
    tester,
  ) async {
    // Wireframe 1b: "Valid session -> straight to Explore, Auth never shown."
    final signedIn = FakeAuthRepository(
      initialUser: const AppUser(uid: "u1", email: "ana@example.com"),
    );
    addTearDown(signedIn.dispose);

    await pumpApp(tester, repo: signedIn);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets("holds on the splash until auth state resolves", (tester) async {
    // Without the loading guard, a signed-in user is bounced to sign-in for a
    // frame while Firebase restores the session.
    final pending = FakeAuthRepository(emitInitial: false);
    addTearDown(pending.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(pending)],
        child: const LakbayanApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets("guest mode opens the app without signing in", (tester) async {
    // Wireframe 1b: "Guest skip keeps discovery open."
    await pumpApp(tester);
    await leaveLanding(tester);
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.tap(find.text("BROWSE AS GUEST"));
    await settle(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(auth.signInCalls, 0, reason: "guest must not create an account");
  });

  testWidgets("the design system gallery is reachable in debug", (
    tester,
  ) async {
    await pumpApp(tester);
    await leaveLanding(tester);
    await tester.tap(find.text("BROWSE AS GUEST"));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.person_outline));
    await settle(tester);

    expect(find.text("Browsing as guest"), findsOneWidget);
  });
}
