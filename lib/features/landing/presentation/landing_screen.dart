import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/brand_wash.dart";
import "landing_widgets.dart";

/// The landing page, shown while there is no account yet.
///
/// Keep the pages **outside** the [AnimatedBuilder]s. Rebuilding them on every
/// scroll frame restarts their text animation mid-drag.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
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
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => SwipeHint(
                      atEnd: _settled == lastIndex,
                      onTap: () => _forward(lastIndex),
                    ),
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
    final colors = context.lakbayan;

    return [
      LandingPage(
        wash: colors.blueTint,
        greeting: "MADDULO\nKAMU",
        body:
            "The welcome that met every traveller at the old provincial arch. "
            "Rivers, mountains and coast, and the stories that come with them.",
      ),
      LandingPage(
        wash: colors.greenTint,
        greeting: "YENA TAM\nNGAMIN",
        body:
            "Mother of us all. At Piat, the pilgrimage centre of the valley, "
            "faith and heritage have always shared the same road.",
      ),
      LandingPage(
        wash: colors.goldContainer,
        greeting: "TULOY PO\nKAYO",
        body:
            "Come in. Download a town before you set out and the province "
            "travels with you, signal or none.",
      ),
    ];
  }
}
