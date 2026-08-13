import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/app.dart";
import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/auth/presentation/sign_in_screen.dart";
import "package:lakbayan/features/auth/presentation/splash_screen.dart";
import "package:lakbayan/features/explore/presentation/home_shell.dart";

import "support/fake_auth_repository.dart";

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
    await tester.pumpAndSettle();
  }

  testWidgets("signed out lands on the sign-in screen", (tester) async {
    await pumpApp(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
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
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.tap(find.text("Skip for now — browse as guest"));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(auth.signInCalls, 0, reason: "guest must not create an account");
  });

  testWidgets("the design system gallery is reachable in debug", (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text("Skip for now — browse as guest"));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text("Browsing as guest"), findsOneWidget);
  });
}
