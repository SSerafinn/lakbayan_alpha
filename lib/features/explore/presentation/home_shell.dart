import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/presentation/browse_screen.dart";
import "../../destinations/presentation/explore_screen.dart";
import "../../itineraries/presentation/itineraries_tab.dart";
import "../domain/home_tab.dart";

/// The four-tab shell from wireframe 1a: *Explore · Map · Itineraries · Profile*,
/// present on every screen except Splash, Auth, Player and AR View.
///
/// The selected tab lives in a provider rather than in this widget, so a screen
/// inside one tab can send somebody to another — see [SelectedHomeTab].
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _titles = ["Explore", "Map", "Itineraries", "Profile"];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider);
    final tab = ref.watch(selectedHomeTabProvider);
    final index = tab.index;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[index])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref
            .read(selectedHomeTabProvider.notifier)
            .select(HomeTab.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: "Explore",
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: "Map",
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: "Itineraries",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
      body: switch (tab) {
        HomeTab.explore => const ExploreScreen(),
        // Browse is the Map tab's landing; its ◈ toggle swaps in the map.
        HomeTab.map => const BrowseScreen(),
        HomeTab.itineraries => const ItinerariesTab(),
        HomeTab.profile => _ProfileTab(isGuest: isGuest),
      },
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final user = ref.watch(authStateProvider).value;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.x4),
      children: [
        Text(
          isGuest ? "Browsing as guest" : (user?.label ?? "Signed in"),
          style: AppTypography.h2,
        ),
        const SizedBox(height: AppSpace.x2),
        Text(
          isGuest
              ? "Sign in to save tours and download towns for offline use."
              : (user?.email ?? ""),
          style: AppTypography.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.x6),
        // Above the auth actions, and offered to guests too: wireframe 1b keeps
        // discovery open without an account, and taking a town with you is
        // discovery. Nothing here writes to a user document.
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.downloads),
          icon: const Icon(Icons.download_outlined),
          label: const Text("Download a town"),
        ),
        const SizedBox(height: AppSpace.x3),
        if (isGuest)
          FilledButton(
            onPressed: () => ref.read(guestModeProvider.notifier).disable(),
            child: const Text("Sign in"),
          )
        else
          OutlinedButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text("Sign out"),
          ),
        if (kDebugMode) ...[
          const SizedBox(height: AppSpace.x3),
          TextButton(
            onPressed: () => context.push("/design-system"),
            child: const Text("Design system"),
          ),
        ],
      ],
    );
  }
}
