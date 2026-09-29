import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/prefs/app_preferences.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/brand_wash.dart";
import "landing_widgets.dart";

/// The landing page, shown while there is no account yet.
///
/// Keep the pages **outside** the [AnimatedBuilder]s. Rebuilding them on every
/// scroll frame restarts their text animation mid-drag.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final PageController _controller = PageController();

  static const double _handoffPull = 56;

  double _pastEnd = 0;
  bool _leaving = false;

  int _settled = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _page {
    if (!_controller.hasClients) return 0;
    if (!_controller.position.hasContentDimensions) return 0;
    return _controller.page ?? 0;
  }

  void _leave() {
    if (_leaving) return;
    setState(() => _leaving = true);

    // Spend the pull that got us here. It is otherwise only cleared by a
    // ScrollEndNotification, so a hand-off that outlives the gesture would
    // leave the counter primed and bounce the user straight back out of the
    // landing pages on their next pixel of overscroll.
    _pastEnd = 0;

    // Recorded on the way out rather than on first paint: someone who opens
    // the app and kills it on page one has not read the introduction, and
    // should get it again. Reaching sign-in is what counts as having seen it.
    //
    // Not awaited — the navigation should not wait on a disk write, and if the
    // write loses a race with the app being killed the only cost is seeing the
    // pages once more.
    final prefs = ref.read(appPreferencesProvider);
    if (prefs != null) unawaited(prefs.markLandingSeen());

    context.push(Routes.signIn).then((_) {
      if (mounted) setState(() => _leaving = false);
    });
  }

  void _forward(int lastIndex) {
    if (_page >= lastIndex) {
      _leave();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll > 0) {
      _pastEnd += notification.overscroll;
      if (_pastEnd > _handoffPull) _leave();
    } else if (notification is ScrollEndNotification) {
      _pastEnd = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pagesFor(context);
    final lastIndex = pages.length - 1;
    assert(
      pages.length == shorelinePages,
      "shorelinePages is $shorelinePages but the landing page builds "
      "${pages.length}. The scene width is derived from the first, so they "
      "must match.",
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: TickerMode(
        enabled: !_leaving,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: AppSize.wash,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    BrandWash(color: _washAt(_page, pages)),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: pages.length,
                        onPageChanged: (page) =>
                            setState(() => _settled = page),
                        itemBuilder: (context, index) =>
                            LandingPageContent(page: pages[index]),
                      ),
                    ),
                  ),
                  // Depends only on the settled page, which a setState
                  // already carries; not rebuilt on every scroll frame.
                  SwipeHint(
                    atEnd: _settled == lastIndex,
                    onTap: () => _forward(lastIndex),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    child: const ShorelineImage(),
                    builder: (context, child) =>
                        ShorelineBand(page: _page, child: child!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _washAt(double page, List<LandingPage> pages) {
    final lower = page.floor().clamp(0, pages.length - 1);
    final upper = page.ceil().clamp(0, pages.length - 1);
    return Color.lerp(pages[lower].wash, pages[upper].wash, page - lower)!;
  }

  List<LandingPage> _pagesFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return [
      LandingPage(
        wash: scheme.secondaryContainer,
        greeting: "MADDULO\nKAMU",
        body:
            "The welcome that met every traveller at the old provincial arch. "
            "Rivers, mountains and coast, and the stories that come with them.",
      ),
      LandingPage(
        wash: scheme.primaryContainer,
        greeting: "YENA TAM\nNGAMIN",
        body:
            "Mother of us all. At Piat, the pilgrimage centre of the valley, "
            "faith and heritage have always shared the same road.",
      ),
      LandingPage(
        wash: context.lakbayan.goldContainer,
        greeting: "TULOY PO\nKAYO",
        body:
            "Come in. Download a town before you set out and the province "
            "travels with you, signal or none.",
      ),
    ];
  }
}
