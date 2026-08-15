import "package:animations/animations.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/auth/domain/auth_providers.dart";
import "../../features/auth/presentation/sign_in_screen.dart";
import "../../features/auth/presentation/splash_screen.dart";
import "../../features/design_system/presentation/design_system_gallery.dart";
import "../../features/destinations/presentation/destination_detail_screen.dart";
import "../../features/explore/presentation/home_shell.dart";
import "../../features/landing/presentation/landing_screen.dart";

abstract final class Routes {
  static const splash = "/splash";
  static const landing = "/landing";
  static const signIn = "/sign-in";
  static const home = "/";
  static const designSystem = "/design-system";

  /// Destination Detail. Pushed, not replaced — wireframe 1d opens it as a
  /// sheet over whatever is beneath.
  static String destination(String id) => "/destination/$id";
}

/// The app router, with the auth redirect.
///
/// Note this is **not** a hard auth gate. Wireframe 1b offers "Skip for now —
/// browse as guest", and notes that guest skip keeps discovery open while
/// saving a tour prompts auth. So the redirect only forces the auth screen for
/// a cold start; once the user is signed in *or* has chosen guest, everything
/// is reachable. Per-action gating belongs on the save actions themselves.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final isGuest = ref.read(guestModeProvider);
      final here = state.matchedLocation;

      // Hold on the splash until the first auth state resolves. Without this,
      // a signed-in user is bounced to the sign-in screen for a frame while
      // Firebase restores the session.
      if (auth.isLoading && !auth.hasValue) {
        return here == Routes.splash ? null : Routes.splash;
      }

      final signedIn = auth.value != null;
      final mayEnter = signedIn || isGuest;
      final atGate =
          here == Routes.splash ||
          here == Routes.landing ||
          here == Routes.signIn;

      // No account yet: open on the landing page, which hands off to sign-in.
      // Both stay reachable while signed out so "Skip" and the back gesture
      // work. Once signed in — or browsing as guest — the branch below sends
      // the user on and the landing page is never shown again.
      if (!mayEnter) {
        final atEntry = here == Routes.landing || here == Routes.signIn;
        return atEntry ? null : Routes.landing;
      }
      if (atGate) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.landing,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        // Shared axis, vertical: Material's own pattern for screens with a
        // navigational relationship, onboarding into auth among them.
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 360),
          child: const SignInScreen(),
          transitionsBuilder: (context, animation, secondary, child) =>
              SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondary,
                transitionType: SharedAxisTransitionType.vertical,
                child: child,
              ),
        ),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: "/destination/:id",
        builder: (context, state) =>
            DestinationDetailScreen(id: state.pathParameters["id"]!),
      ),
      // Debug-only: the living design system specimen. Excluded from release so
      // it cannot be reached in a shipped build.
      if (kDebugMode)
        GoRoute(
          path: Routes.designSystem,
          builder: (context, state) => const DesignSystemGallery(),
        ),
    ],
  );

  // Re-evaluate the redirect when auth or guest state changes. Rebuilding the
  // provider instead would construct a new GoRouter and throw away navigation
  // state, so listen and refresh rather than watch.
  ref
    ..listen(authStateProvider, (_, _) => router.refresh())
    ..listen(guestModeProvider, (_, _) => router.refresh())
    ..onDispose(router.dispose);

  return router;
});
