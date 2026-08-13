import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/router/app_router.dart";
import "core/theme/app_theme.dart";
import "core/widgets/dev_status_banner.dart";

class LakbayanApp extends ConsumerWidget {
  const LakbayanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: "Lakbayan",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Dark mode is v2 scope in the design system. Wired so the tokens are
      // exercised, but the app stays light until the palette is signed off.
      darkTheme: buildAppDarkTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      // Wrapping here rather than in each screen puts the strip under every
      // route, including the ones that do not exist yet.
      builder: (context, child) =>
          DevStatusBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
