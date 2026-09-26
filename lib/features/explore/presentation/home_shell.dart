import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_motion.dart";
import "../../destinations/presentation/explore_screen.dart";
import "../../itineraries/presentation/itineraries_tab.dart";
import "../../maps/presentation/map_screen.dart";
import "../../profile/presentation/profile_tab.dart";
import "../domain/home_chrome.dart";
import "../domain/home_tab.dart";
import "home_chrome_layer.dart";

/// Four-tab shell. Each tab is built once and kept offstage, so a switch
/// rebuilds nothing and keeps scroll and camera. A switch is a 200ms
/// cross-fade: the chosen tab, on its own ground, over the one it replaces,
/// with no white between them.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: AppMotion.edge,
    value: 1,
  );

  /// Eased out, so the chosen tab is mostly there within the first frames.
  late final _fadeIn = _fade.drive(CurveTween(curve: Curves.easeOut));

  /// Tabs chosen at least once this session, so built and kept.
  late final _built = <HomeTab>{ref.read(selectedHomeTabProvider)};

  /// The tab fading out, while the switch runs.
  HomeTab? _outgoing;

  @override
  void initState() {
    super.initState();
    _fade.addStatusListener((status) {
      if (status.isCompleted && _outgoing != null) {
        setState(() => _outgoing = null);
      }
    });
    // Every switch resets the chrome bar, even from screens that programmatically
    // switch tabs (a kept tab's dispose no longer fires on switch).
    ref.listenManual(selectedHomeTabProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.read(homeChromeProvider.notifier).reset();
      setState(() {
        _built.add(next);
        _outgoing = previous;
      });
      _fade.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(selectedHomeTabProvider);
    final fill = Theme.of(context).colorScheme.surface;
    final outgoing = _outgoing;

    // Keyed, so a tab keeps its element (and all its state) as the order
    // changes. The chosen tab goes last, on top, so it fades in over the
    // outgoing one.
    final order = [
      for (final built in HomeTab.values)
        if (_built.contains(built) && built != tab) built,
      tab,
    ];

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: ref.read(homeChromeProvider.notifier).onScroll,
        child: HomeChromeLayer(
          tab: tab,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final each in order)
                _TabLayer(
                  key: ValueKey(each),
                  shown: each == tab || each == outgoing,
                  opacity: each == tab ? _fadeIn : kAlwaysCompleteAnimation,
                  ground: fill,
                  child: _screenFor(each),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _screenFor(HomeTab tab) => switch (tab) {
    HomeTab.explore => const ExploreScreen(),
    HomeTab.map => const MapScreen(),
    HomeTab.itineraries => const ItinerariesTab(),
    HomeTab.profile => const ProfileTab(),
  };
}

/// One kept tab. The same widgets whether shown or not, so nothing under it
/// is rebuilt or loses state when it hides; hidden, it is offstage, its
/// tickers muted, and its heroes out of any flight.
class _TabLayer extends StatelessWidget {
  const _TabLayer({
    required this.shown,
    required this.opacity,
    required this.ground,
    required this.child,
    super.key,
  });

  final bool shown;

  /// The switch's fade for the chosen tab; complete for every other.
  final Animation<double> opacity;

  /// Opaque under the tab, so a tab fading in covers the one beneath rather
  /// than showing it through its gaps.
  final Color ground;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !shown,
    child: TickerMode(
      enabled: shown,
      child: HeroMode(
        enabled: shown,
        // Settled at 1, the fade is the identity: the same tree, no rebuild.
        child: FadeTransition(
          opacity: opacity,
          child: ColoredBox(color: ground, child: child),
        ),
      ),
    ),
  );
}
