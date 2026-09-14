import "package:animated_text_kit/animated_text_kit.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/app.dart";
import "package:lakbayan/core/prefs/app_preferences.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/auth/presentation/sign_in_screen.dart";
import "package:lakbayan/features/landing/presentation/landing_screen.dart";
import "package:lakbayan/features/landing/presentation/landing_widgets.dart";

import "../../support/fake_auth_repository.dart";

/// The landing pages animate forever, so `pumpAndSettle` never returns on
/// them. Advance the clock by hand instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpApp(WidgetTester tester, AppPreferences prefs) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const LakbayanApp(),
      ),
    );
    await settle(tester);
  }

  group("the landing pages run once per device", () {
    testWidgets("first launch shows them", (tester) async {
      await pumpApp(tester, InMemoryPreferences());

      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets("having seen them, a signed-out launch opens sign-in", (
      tester,
    ) async {
      // The point of the whole change. Guest mode is session-only by design,
      // so a guest is signed out again on the next launch — and before this,
      // reaching "Skip for now" meant swiping through the introduction every
      // single time.
      await pumpApp(tester, InMemoryPreferences(hasSeenLanding: true));

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(LandingScreen), findsNothing);
    });

    testWidgets("they are marked seen on the way out, not on first paint", (
      tester,
    ) async {
      final prefs = InMemoryPreferences();
      await pumpApp(tester, prefs);

      // Still on page one: someone who kills the app here has not read it.
      expect(prefs.hasSeenLanding, isFalse);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(AppIcons.chevron));
        await settle(tester);
      }

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(prefs.hasSeenLanding, isTrue);
    });
  });

  group("reduced motion", () {
    Future<void> pumpGreeting(
      WidgetTester tester, {
      required bool reduce,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: const Scaffold(
              body: LandingPageContent(
                page: LandingPage(
                  wash: Color(0xFFEEEEEE),
                  greeting: "MADDULO\nKAMU",
                  body: "Body copy.",
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("the greeting types itself out normally", (tester) async {
      await pumpGreeting(tester, reduce: false);

      expect(find.byType(AnimatedTextKit), findsOneWidget);
    });

    testWidgets("under reduced motion it is just the finished words", (
      tester,
    ) async {
      await pumpGreeting(tester, reduce: true);

      expect(find.byType(AnimatedTextKit), findsNothing);
      expect(find.text("MADDULO\nKAMU"), findsOneWidget);

      // No perpetual animation left running, so the tree can reach idle. That
      // it settles at all is the assertion.
      await tester.pumpAndSettle();
    });

    testWidgets("the swipe chevron holds still under reduced motion", (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: SwipeHint(atEnd: true, onTap: () {})),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<SwipeHintState>(find.byType(SwipeHint));
      expect(state.isNudging, isFalse);

      await tester.pumpAndSettle();
    });
  });
}
