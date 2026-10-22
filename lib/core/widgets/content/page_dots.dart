import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../motion/motion.dart";

/// Says a row of pages can be swiped, and where in it you are: a dot per
/// page, the current one stretched into a short capsule on the chrome
/// spring. Explore's featured cards and the Map's place cards use it, so a
/// swipeable row looks the same everywhere.
///
/// Past [maxDots] only a window of dots shows. The window stays put while
/// the current dot walks across it, and moves on only when the dot reaches
/// its edge, so every swipe visibly moves something; a dot at an edge with
/// more pages beyond it is drawn smaller, so the row still reads as "more
/// this way". Decorative for a screen reader: the pages carry the content.
class PageDots extends StatefulWidget {
  const PageDots({
    required this.count,
    required this.current,
    this.onPhoto = false,
    super.key,
  });

  final int count;
  final int current;

  /// White on a photo (Place detail's stage), rather than the page's ink.
  final bool onPhoto;

  static const maxDots = 7;

  @override
  State<PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<PageDots> {
  /// The first page the window shows.
  int _first = 0;

  int get _shown =>
      widget.count < PageDots.maxDots ? widget.count : PageDots.maxDots;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(PageDots old) {
    super.didUpdateWidget(old);
    _follow();
  }

  /// Keeps the current dot inside the window, one dot in from either edge
  /// where there is more beyond it; otherwise the window does not move.
  void _follow() {
    final last = widget.count - _shown;
    final current = widget.current;
    if (current < _first + 1) _first = current - 1;
    if (current > _first + _shown - 2) _first = current - _shown + 2;
    _first = _first.clamp(0, last < 0 ? 0 : last);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count < 2) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final on = widget.onPhoto ? Colors.white : scheme.onSurface;
    final off = widget.onPhoto
        ? Colors.white.withValues(alpha: 0.6)
        : scheme.outlineVariant;
    final shown = _shown;
    final first = _first;
    return ExcludeSemantics(
      child: SizedBox(
        height: AppSize.pageDot,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = first; i < first + shown; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.x1 / 2,
                ),
                child: AppMotionBuilder(
                  end: i == widget.current ? 1 : 0,
                  builder: (context, t, _) {
                    final beyond =
                        (i == first && first > 0) ||
                        (i == first + shown - 1 && i < widget.count - 1);
                    final dot = beyond
                        ? AppSize.pageDot * 0.6
                        : AppSize.pageDot;
                    return SizedBox(
                      width: lerpDouble(dot, AppSpace.x4, t),
                      height: dot,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Color.lerp(off, on, t.clamp(0.0, 1.0)),
                          shape: capsule,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
