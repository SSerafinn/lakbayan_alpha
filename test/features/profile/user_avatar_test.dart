import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/profile/presentation/user_avatar.dart";

import "../../support/fake_auth_repository.dart";

/// Me as a circle (D-19): a guest's account glyph, else the first letter of
/// the name the app knows me by.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    AppUser? user,
    bool guest = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: user),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (guest) container.read(guestModeProvider.notifier).enable();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: Center(child: UserAvatar(size: 40))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("a guest is the account glyph", (tester) async {
    await pump(tester, guest: true);

    expect(find.byIcon(AppIcons.account), findsOneWidget);
  });

  testWidgets("signed in, the first letter of the name", (tester) async {
    await pump(
      tester,
      user: const AppUser(uid: "u1", displayName: "maria Santos"),
    );

    expect(find.text("M"), findsOneWidget);
    expect(find.byIcon(AppIcons.account), findsNothing);
  });

  testWidgets("with no name, the first letter of the email", (tester) async {
    await pump(
      tester,
      user: const AppUser(uid: "u1", email: "juan@example.com"),
    );

    expect(find.text("J"), findsOneWidget);
  });
}
