import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

// Placeholder router. Phase 1: add auth-gated routes and the feature routes.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const _HomePlaceholder(),
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
      body: const Center(
        child: Text("Lakbayan — start with PLAN.md, Phase 1."),
      ),
    );
  }
}
