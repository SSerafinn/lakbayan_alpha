import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/router/app_router.dart";
import "core/theme/app_theme.dart";
import "core/theme/app_theme_mode.dart";
import "core/widgets/chrome/dev_status_banner.dart";
import "core/widgets/chrome/system_bars.dart";

class LakbayanApp extends ConsumerWidget {
  const LakbayanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: "Lakbayan",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppDarkTheme(),
      themeMode: ref.watch(appThemeModeProvider),
      routerConfig: router,
      // Wrapping here rather than in each screen puts the strip and the
      // system bar style under every route, including the ones that do not
      // exist yet. A photo header overrides the bars' icons locally.
      builder: (context, child) => _CalmerMotion(
        child: SystemBars(
          child: DevStatusBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Settings' Reduce motion, added to the phone's: either one turns motion
/// down, and neither can turn the other's back up.
class _CalmerMotion extends ConsumerWidget {
  const _CalmerMotion({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(reduceMotionProvider);
    if (!chosen) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    );
  }
}
