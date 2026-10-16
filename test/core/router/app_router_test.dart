import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/app.dart";
import "package:lakbayan/core/router/app_router.dart";
import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_providers.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/explore/presentation/home_shell.dart";

import "../../support/fake_auth_repository.dart";
import "../../support/fake_destination_repository.dart";

/// Explore's carousel and the landing page move on their own, so these
/// advance the clock by hand rather than wait for an idle tree.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets("a link to nowhere gets the app's own page and a way home", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeAuthRepository(
      initialUser: const AppUser(uid: "u1", email: "ana@example.com"),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          destinationRepositoryProvider.overrideWithValue(
            FakeDestinationRepository([]),
          ),
        ],
        child: const LakbayanApp(),
      ),
    );
    await settle(tester);
    expect(find.byType(HomeShell), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(HomeShell)))
        .read(appRouterProvider)
        .go("/no-such-page");
    await settle(tester);

    expect(find.textContaining("nothing at this link"), findsOneWidget);
    // Not go_router's own error page, which names the exception.
    expect(find.textContaining("GoException"), findsNothing);

    // Nothing to go back to after a jump, so back is the way home.
    await tester.tap(find.byTooltip("Back"));
    await settle(tester);
    expect(find.byType(HomeShell), findsOneWidget);
  });
}
