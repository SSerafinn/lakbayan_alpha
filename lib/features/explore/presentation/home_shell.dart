import "package:animations/animations.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../destinations/presentation/explore_screen.dart";
import "../../itineraries/presentation/itineraries_tab.dart";
import "../../maps/presentation/map_screen.dart";
import "../../profile/presentation/profile_tab.dart";
import "../domain/home_chrome.dart";
import "../domain/home_tab.dart";
import "home_chrome_layer.dart";

/// The four-tab shell from wireframe 1a: *Explore · Map · Itineraries · Profile*,
/// present on every screen except Splash, Auth, Player and AR View. The
/// selected tab lives in a provider so a screen inside one tab can send
/// somebody to another ([SelectedHomeTab]). Every tab draws its own title as
/// content, so there is no app bar; every scroll that bubbles up feeds
/// [HomeChrome], and only the bar watches it.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedHomeTabProvider);

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: ref.read(homeChromeProvider.notifier).onScroll,
        child: HomeChromeLayer(
          tab: tab,
          // Fade through: the four tabs have no spatial or navigational
          // relationship, which is what the Material spec reserves it for.
          child: PageTransitionSwitcher(
            transitionBuilder: (child, primary, secondary) =>
                FadeThroughTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  fillColor: Theme.of(context).colorScheme.surface,
                  child: child,
                ),
            child: KeyedSubtree(
              key: ValueKey(tab),
              child: switch (tab) {
                HomeTab.explore => const ExploreScreen(),
                HomeTab.map => const MapScreen(),
                HomeTab.itineraries => const ItinerariesTab(),
                HomeTab.profile => const ProfileTab(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
