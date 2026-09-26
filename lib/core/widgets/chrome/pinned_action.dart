import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../motion/motion.dart";

/// A screen's one primary action floating at the bottom trailing corner:
/// a green capsule with a glyph and a label that collapses to glyph-only
/// while scrolling down, and re-opens on scroll up or at the top.
/// Takes its own `SafeArea` so it clears the gesture pill.
class PinnedAction extends StatelessWidget {
  const PinnedAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// The region the action covers: the button, its gutter all round, and
  /// the gesture inset under it.
  static double extentOf(BuildContext context) =>
      AppSize.primaryButton +
      AppSpace.gutter * 2 +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final compact = _Compact.of(context);
    return Positioned(
      right: 0,
      bottom: 0,
      // Own RepaintBoundary so folding repaints only the action.
      child: RepaintBoundary(
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(AppSpace.gutter),
          child: Pressable(
            enabled: onPressed != null,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.square(AppSize.primaryButton),
                  padding: const EdgeInsets.symmetric(
                    horizontal: (AppSize.primaryButton - AppSize.glyph) / 2,
                  ),
                ),
                child: Semantics(
                  label: label,
                  excludeSemantics: true,
                  child: AppMotionBuilder(
                    end: compact ? 0 : 1,
                    builder: (context, t, _) {
                      final open = t.clamp(0.0, 1.0);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: AppSize.glyph),
                          if (open > 0)
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: open,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpace.x2,
                                  ),
                                  child: Opacity(
                                    opacity: open,
                                    child: Text(label, maxLines: 1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a screen whose [PinnedAction] should fold while the person reads:
/// it hears the screen's vertical scroll and says whether the action is
/// compact. Folds after a deliberate scroll down past the first screenful's
/// top, opens on a scroll back up or at the very top, and folds at the
/// bottom rather than reopening over the screen's own last row. The top and
/// bottom cases are each forced, so a wobble at either edge never flips it.
class PinnedActionScope extends StatefulWidget {
  const PinnedActionScope({required this.child, super.key});

  final Widget child;

  @override
  State<PinnedActionScope> createState() => _PinnedActionScopeState();
}

class _PinnedActionScopeState extends State<PinnedActionScope> {
  bool _compact = false;
  double _travel = 0;

  static const _foldAfter = AppSpace.x12;
  static const _openAfter = AppSpace.x6;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical || notification.depth != 0) return false;
    if (notification is! ScrollUpdateNotification) return false;
    final atTop = metrics.pixels <= metrics.minScrollExtent;
    final atBottom = metrics.pixels >= metrics.maxScrollExtent;
    final delta = notification.scrollDelta ?? 0;
    if ((delta > 0) != (_travel > 0)) _travel = 0;
    _travel += delta;
    final compact = atTop
        ? false
        : atBottom
        ? true
        : _travel > _foldAfter
        ? true
        : _travel < -_openAfter
        ? false
        : _compact;
    if (compact != _compact) setState(() => _compact = compact);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _Compact(compact: _compact, child: widget.child),
      );
}

class _Compact extends InheritedWidget {
  const _Compact({required this.compact, required super.child});

  final bool compact;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Compact>()?.compact ?? false;

  @override
  bool updateShouldNotify(_Compact old) => compact != old.compact;
}
