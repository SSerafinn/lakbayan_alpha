import "dart:ui" show ImageFilter;

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "../theme/app_dimens.dart";
import "../theme/app_motion.dart";

/// How strongly the boundary between a pinned control and the content
/// scrolling under it is drawn (design doc 05).
enum ScrollEdgeStyle {
  /// A tall, gentle falloff. The default, and the right choice under
  /// controls that sit on their own surface (a capsule search field, a bar
  /// group).
  soft,

  /// A short falloff approaching a solid edge. For interactive text or
  /// controls that have no background of their own.
  hard,
}

/// The scroll edge treatment: a progressive blur, no wash and no tint, that
/// marks where the interface ends and content begins, only while content is
/// under a pinned control. The top band is always drawn; [bottom] is the
/// height of the region the tab bar covers ([homeBarHeight]), or null.
class ScrollEdge extends StatefulWidget {
  const ScrollEdge({
    required this.child,
    this.bottom,
    this.style = ScrollEdgeStyle.soft,
    super.key,
  });

  /// The scrolling content.
  final Widget child;
  final double? bottom;

  final ScrollEdgeStyle style;

  /// The region the floating tab bar covers at the bottom of a home tab:
  /// its height, its margin and the gesture inset under it.
  static double homeBarHeight(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom +
      AppSize.bottomNav +
      AppSpace.x3;

  @override
  State<ScrollEdge> createState() => _ScrollEdgeState();
}

class _ScrollEdgeState extends State<ScrollEdge> {
  bool _topScrolled = false;
  bool _bottomScrolled = false;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    final top = metrics.pixels > metrics.minScrollExtent;
    final bottom = metrics.pixels < metrics.maxScrollExtent;
    if (top == _topScrolled && bottom == _bottomScrolled) return false;

    void apply() {
      if (!mounted) return;
      setState(() {
        _topScrolled = top;
        _bottomScrolled = bottom;
      });
    }

    // Mid-layout (keyboard resize, ballistic correction) a setState is a
    // build in the wrong scope; wait for the frame to end.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final extent = switch (widget.style) {
      ScrollEdgeStyle.soft => AppSpace.x12 + AppSpace.x2,
      ScrollEdgeStyle.hard => AppSpace.x4,
    };
    final bottom = widget.bottom;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: extent,
          child: _ProgressiveBlur(
            visible: _topScrolled,
            falloff: extent,
            fromTop: true,
          ),
        ),
        if (bottom != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: bottom + extent,
            child: _ProgressiveBlur(
              visible: _bottomScrolled,
              falloff: extent,
              fromTop: false,
            ),
          ),
      ],
    );
  }
}

/// Blur ramping from nothing at the end of the falloff to full at the edge.
/// Flutter has no variable-radius blur, so three `BackdropFilter`s of rising
/// sigma are each masked to a shorter reach and compound. Three `saveLayer`s
/// per edge while scrolled (over design doc 08's budget): profile it.
class _ProgressiveBlur extends StatelessWidget {
  const _ProgressiveBlur({
    required this.visible,
    required this.falloff,
    required this.fromTop,
  });

  final bool visible;
  final double falloff;
  final bool fromTop;

  static const _sigmas = [2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    final edge = fromTop ? Alignment.topCenter : Alignment.bottomCenter;
    final inner = fromTop ? Alignment.bottomCenter : Alignment.topCenter;

    final band = visible
        ? LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final solidUntil = height.isFinite && height > 0
                  ? ((height - falloff) / height).clamp(0.0, 1.0)
                  : 0.0;
              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var layer = 0; layer < _sigmas.length; layer++)
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => LinearGradient(
                          begin: edge,
                          end: inner,
                          colors: const [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          // Each stronger layer reaches a third less far.
                          stops: [
                            0,
                            solidUntil,
                            solidUntil +
                                (1 - solidUntil) * (1 - layer / _sigmas.length),
                          ],
                        ).createShader(bounds),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: _sigmas[layer],
                            sigmaY: _sigmas[layer],
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              );
            },
          )
        : const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.edge,
        curve: Curves.easeOut,
        child: band,
      ),
    );
  }
}
