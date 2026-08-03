import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/design_system/presentation/design_system_gallery.dart";

// Placeholder router. Phase 1: add auth-gated routes and the feature routes.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const _HomePlaceholder(),
      ),
      // Debug-only: the living design system specimen. Excluded from release
      // so it cannot be reached in a shipped build.
      if (kDebugMode)
        GoRoute(
          path: "/design-system",
          builder: (context, state) => const DesignSystemGallery(),
        ),
    ],
  );
});

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lakbayan")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Lakbayan — start with PLAN.md, Phase 1."),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go("/design-system"),
                child: const Text("Design system"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
