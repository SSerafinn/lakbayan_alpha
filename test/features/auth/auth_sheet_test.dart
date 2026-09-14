import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/app.dart";
import "package:lakbayan/core/prefs/app_preferences.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/auth/presentation/auth_chrome.dart";
import "package:lakbayan/features/auth/presentation/sign_in_screen.dart";
import "package:lakbayan/features/landing/presentation/landing_screen.dart";

import "../../support/fake_auth_repository.dart";

/// A real handset, not the tall viewport the other suites use. The bug this
/// file covers only shows where the sheet fills the screen — which is every
/// phone, and no test that runs 1400dp tall.
const _phone = Size(411, 869);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// The sheet's own drag handle. A plain `byType(GestureDetector)` also catches
/// the six the form's fields and buttons bring with them, so match on the
/// callback that makes this one the handle.
final _handle = find.byWidgetPredicate(
  (w) => w is GestureDetector && w.onVerticalDragUpdate != null,
  description: "the auth sheet's drag handle",
);

Offset _sheetOffset(WidgetTester tester) => tester
    .widget<AnimatedSlide>(
      find
          .descendant(
            of: find.byType(AuthSheet),
            matching: find.byType(AnimatedSlide),
          )
          .first,
    )
    .offset;

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpApp(WidgetTester tester, {required bool seenLanding}) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appPreferencesProvider.overrideWithValue(
            InMemoryPreferences(hasSeenLanding: seenLanding),
          ),
        ],
        child: const LakbayanApp(),
      ),
    );
    await settle(tester);
  }

  group("a swipe down on the auth sheet goes back to the landing pages", () {
    testWidgets("reached as the root route, where there is nothing to pop", (
      tester,
    ) async {
      // The returning-visitor path: the introduction has run, so the router
      // opens straight on sign-in and it is the only route on the stack.
      await pumpApp(tester, seenLanding: true);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(LandingScreen), findsNothing);

      final handle = find.descendant(
        of: find.byType(AuthSheet),
        matching: _handle,
      );
      expect(
        handle,
        findsOneWidget,
        reason: "the grab bar is drawn, so it must take the drag",
      );

      await tester.drag(handle, const Offset(0, 120));
      // Not pumpAndSettle: the landing pages animate forever, so it would
      // never come back. Advance the clock by hand, as the landing suite does.
      await settle(tester);
      await settle(tester);

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets("pushed over the landing pages, where popping is enough", (
      tester,
    ) async {
      await pumpApp(tester, seenLanding: false);
      expect(find.byType(LandingScreen), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(AppIcons.chevron));
        await settle(tester);
      }
      expect(find.byType(SignInScreen), findsOneWidget);

      await tester.drag(
        find.descendant(of: find.byType(AuthSheet), matching: _handle),
        const Offset(0, 120),
      );
      await settle(tester);
      await settle(tester);

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets("a drag too small to dismiss snaps the sheet back", (
      tester,
    ) async {
      await pumpApp(tester, seenLanding: true);

      // Under half of _maxNudge, and slow enough not to read as a fling.
      await tester.timedDrag(
        find.descendant(of: find.byType(AuthSheet), matching: _handle),
        const Offset(0, 8),
        const Duration(milliseconds: 600),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SignInScreen), findsOneWidget);
      // Parked off-centre is the bug that stranded the foot of the form below
      // the screen edge, on a sheet whose maxScrollExtent is 0.
      expect(_sheetOffset(tester), Offset.zero);
    });
  });
}
