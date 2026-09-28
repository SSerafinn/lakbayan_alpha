import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../theme/app_motion.dart";

/// Morphs a `t` toward [end] (0 or 1) on `AppMotion.chrome`, or cross-fades
/// the two end states under reduced motion so a call site never re-derives
/// that check (`08-flutter-translation.md`, motion and reduced motion).
class AppMotionBuilder extends StatefulWidget {
  const AppMotionBuilder({
    required this.end,
    required this.builder,
    this.onEnd,
    super.key,
  });

  final double end;
  final ValueWidgetBuilder<double> builder;

  /// Fires once [end] is reached, under reduced motion too; not on first build.
  final VoidCallback? onEnd;

  @override
  State<AppMotionBuilder> createState() => _AppMotionBuilderState();
}

class _AppMotionBuilderState extends State<AppMotionBuilder> {
  @override
  void didUpdateWidget(AppMotionBuilder old) {
    super.didUpdateWidget(old);
    if (widget.end != old.end && MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onEnd?.call());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return AnimatedSwitcher(
        duration: AppMotion.edge,
        child: KeyedSubtree(
          key: ValueKey(widget.end),
          child: widget.builder(context, widget.end, null),
        ),
      );
    }
    return SingleMotionBuilder(
      motion: AppMotion.chrome,
      value: widget.end,
      onAnimationStatusChanged: (status) {
        if (status == AnimationStatus.completed) widget.onEnd?.call();
      },
      builder: widget.builder,
    );
  }
}
