import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/auth/domain/auth_providers.dart";
import "../../features/auth/presentation/sign_in_screen.dart";
import "../../features/auth/presentation/splash_screen.dart";
import "../../features/design_system/presentation/design_system_gallery.dart";
import "../../features/destinations/presentation/destination_detail_screen.dart";
import "../../features/destinations/presentation/places_list_screen.dart";
import "../../features/destinations/presentation/swipe_screen.dart";
import "../../features/explore/presentation/home_shell.dart";
import "../../features/landing/presentation/landing_screen.dart";
import "../../features/itineraries/presentation/itinerary_screen.dart";
import "../../features/offline/presentation/downloads_screen.dart";
import "../../features/profile/presentation/help_screen.dart";
import "../../features/profile/presentation/policy_screen.dart";
import "../../features/profile/presentation/settings_screen.dart";
import "../prefs/app_preferences.dart";
import "../widgets/motion/page_transitions.dart";

abstract final class Routes {
  static const splash = "/splash";
  static const landing = "/landing";
  static const signIn = "/sign-in";
  static const home = "/";
  static const designSystem = "/design-system";

  /// Wireframe 1f. Pushed from Profile rather than given a tab: downloading is
  /// something you do once before a trip, not a place you spend time.
  static const downloads = "/downloads";

  /// Swipe mode, full screen. Reached from Home's swipe entry row.
  static const swipe = "/swipe";

  /// Popular places as a list. Home's "See all".
  static const popular = "/popular";

  /// Everything saved with the heart. Reached from Profile.
  static const saved = "/saved";

  /// Appearance and accessibility. Reached from Explore's header and from
  /// Profile.
  static const settings = "/settings";

  /// The emergency lines and the tourism office. Reached from Profile.
  static const help = "/help";

  /// The province's privacy policy and terms of use. Reached from Profile;
  /// the Play Store requires the privacy policy to be reachable in the app.
  static const privacy = "/privacy";
  static const terms = "/terms";

  /// One of the user's own itineraries. Pushed from the Itineraries tab, and
  /// from the add-to-trip confirmation with [added], the stop just put on it,
  /// which the screen scrolls to and lands.
  static String itinerary(String id, {String? added}) => Uri(
    path: "/itinerary/$id",
    queryParameters: added == null ? null : {"added": added},
  ).toString();

  /// Destination Detail. Pushed, not replaced. [from] names the surface the
  /// cover flies from; a deep link has none, and the screen simply appears.
  static String destination(String id, {HeroSource? from}) => Uri(
    path: "/destination/$id",
    queryParameters: from == null ? null : {"from": from.name},
  ).toString();
}

/// The surfaces a place's photo can open it from. A hero tag must be unique
/// on a screen and one place can show twice, so the tag carries its surface;
/// it travels in the URL, so the route stays deep-linkable. Opened with one,
/// a place zooms from that photo (`ZoomPage`); a deep link is pushed.
enum HeroSource {
  featured,
  popular,
  whereToEat,
  browse,
  list,
  stop,
  stopCard,
  map,
  mapCard,
  search,
  swipe,
  around,
}

/// The `Hero` tag for [id]'s cover on [from].
String coverHeroTag(String id, HeroSource from) => "cover:${from.name}:$id";

/// The `Hero` tag for a trip: its row on the Itineraries tab and the route map
/// at the top of the trip, so one grows into the other.
String tripHeroTag(String id) => "trip:$id";

extension PopOrHome on BuildContext {
  /// Back, or Home when there is nothing to go back to (a deep link).
  void popOrHome() => canPop() ? pop() : go(Routes.home);
}

/// The app router, with the auth redirect. Every route arrives on the
/// theme's push, except a place opened from its photo, which zooms.
///
/// **Not** a hard auth gate (wireframe 1b: guests keep discovery): the
/// redirect only forces auth on a cold start; once signed in or a guest,
/// everything is reachable, and saving actions gate themselves.
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

      // No account yet: the landing pages run once per device, then sign-in
      // is the entry. Guest mode is session-only ([GuestMode]), so showing
      // them every launch would bury "Skip for now" behind the carousel each
      // time. Both stay reachable, so back out of sign-in still works.
      if (!mayEnter) {
        final atEntry = here == Routes.landing || here == Routes.signIn;
        if (atEntry) return null;
        // Null preferences (tests, or Hive unavailable) reads as "not seen",
        // which shows the landing page. The safe direction to fail.
        final seenLanding =
            ref.read(appPreferencesProvider)?.hasSeenLanding ?? false;
        return seenLanding ? Routes.signIn : Routes.landing;
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
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeShell(),
      ),
      // Opened from a photo, the photo grows into the page and the page
      // fades in around it; a deep link is pushed.
      GoRoute(
        path: "/destination/:id",
        pageBuilder: (context, state) {
          final from = HeroSource.values
              .asNameMap()[state.uri.queryParameters["from"]];
          final screen = DestinationDetailScreen(
            id: state.pathParameters["id"]!,
            from: from,
          );
          return from == null
              ? MaterialPage<void>(key: state.pageKey, child: screen)
              : ZoomPage<void>(key: state.pageKey, child: screen);
        },
      ),
      GoRoute(
        path: Routes.swipe,
        builder: (context, state) => const SwipeScreen(),
      ),
      GoRoute(
        path: Routes.popular,
        builder: (context, state) =>
            const PlacesListScreen(list: PlacesList.popular),
      ),
      GoRoute(
        path: Routes.saved,
        builder: (context, state) =>
            const PlacesListScreen(list: PlacesList.saved),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.help,
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (context, state) => const PolicyScreen(policy: Policy.privacy),
      ),
      GoRoute(
        path: Routes.terms,
        builder: (context, state) => const PolicyScreen(policy: Policy.terms),
      ),
      GoRoute(
        path: Routes.downloads,
        builder: (context, state) => const DownloadsScreen(),
      ),
      // The trip's row grows into the route map with a `Hero` as the page
      // slides in under it.
      GoRoute(
        path: "/itinerary/:id",
        builder: (context, state) => ItineraryScreen(
          id: state.pathParameters["id"]!,
          added: state.uri.queryParameters["added"],
        ),
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
