import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../auth/domain/auth_providers.dart";

/// The four-tab shell from wireframe 1a: *Explore · Map · Itineraries · Profile*,
/// present on every screen except Splash, Auth, Player and AR View.
///
/// Phase 1 stops at an empty shell — the tabs are placeholders until their
/// features land in Phases 2 and 3.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ["Explore", "Map", "Itineraries", "Profile"];

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(guestModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
      body: _index == 3
          ? _ProfileTab(isGuest: isGuest)
          : _EmptyTab(title: _titles[_index]),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTypography.h2),
            const SizedBox(height: AppSpace.x2),
            Text(
              "Nothing here yet — this lands in a later phase.",
              style: AppTypography.body.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
        if (isGuest)
          FilledButton(
            onPressed: () => ref.read(guestModeProvider.notifier).disable(),
            child: const Text("Sign in"),
          )
        else
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
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
