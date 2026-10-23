import "dart:ui" show lerpDouble;

import "package:animations/animations.dart";
import "package:flutter/gestures.dart" show kTouchSlop;
import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_motion.dart";

// Every shared motion widget. All ride the `AppMotion` springs, honour
// reduced motion, and settle on identity values in the same tree (opacity
// 1, no offset, scale 1, no clip): swapping the bare child in at rest would
// rebuild it from nothing (STANDARDS 10.13). A motion used once stays inline.

/// Morphs `t` toward [end] on `AppMotion.chrome`; reduced motion fades the
/// end state in. Pass the stable part as [child], built once. Lazy: the
/// spring is made the first time `t` moves, so a list of these mounts with
/// no controllers (STANDARDS 10.11).
class AppMotionBuilder extends StatefulWidget {
  const AppMotionBuilder({
    required this.end,
    required this.builder,
    this.motion = AppMotion.chrome,
    this.from,
    this.onEnd,
    this.child,
    super.key,
  });

  final double end;
  final ValueWidgetBuilder<double> builder;
  final Motion motion;

  /// Where `t` starts on first build. Null mounts at rest on [end].
  final double? from;

  final Widget? child;

  /// Fires once [end] is reached, under reduced motion too; not on first build.
  final VoidCallback? onEnd;

  @override
  State<AppMotionBuilder> createState() => _AppMotionBuilderState();
}

class _AppMotionBuilderState extends State<AppMotionBuilder>
    with TickerProviderStateMixin {
  /// Made the first time `t` moves; null while it rests on [end].
  SingleMotionController? _spring;

  /// Reduced motion fades one copy of the subtree in (a cross-fade's two
  /// copies would duplicate any `GlobalKey`).
  AnimationController? _fade;

  bool _mounted = false;

  /// What a resting builder listens to: never changes, never ticks.
  static const _rest = AlwaysStoppedAnimation<double>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mounted) return;
    _mounted = true;
    final from = widget.from;
    if (from == null || from == widget.end) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fadeIn();
    } else {
      _springAt(from).animateTo(widget.end);
    }
  }

  @override
  void didUpdateWidget(AppMotionBuilder old) {
    super.didUpdateWidget(old);
    final spring = _spring;
    if (spring != null && widget.motion != old.motion) {
      spring.motion = widget.motion;
    }
    if (widget.end == old.end) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      spring?.value = widget.end;
      _fadeIn();
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onEnd?.call());
    } else {
      _springAt(old.end).animateTo(widget.end);
    }
  }

  SingleMotionController _springAt(double value) =>
      _spring ??= SingleMotionController(
        motion: widget.motion,
        vsync: this,
        initialValue: value,
      )..addStatusListener(_onStatus);

  /// motor reports a return to the start as `dismissed`; both are the end.
  void _onStatus(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) widget.onEnd?.call();
  }

  void _fadeIn() => (_fade ??= AnimationController(
    vsync: this,
    duration: AppMotion.edge,
  )).forward(from: 0);

  @override
  void dispose() {
    _spring?.dispose();
    _fade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final spring = reduced ? null : _spring;
    // The same two widgets in every state, so starting a spring never
    // rebuilds the subtree.
    return FadeTransition(
      opacity: _fade ?? kAlwaysCompleteAnimation,
      child: ListenableBuilder(
        listenable: spring ?? _rest,
        builder: (context, child) =>
            widget.builder(context, spring?.value ?? widget.end, child),
        child: widget.child,
      ),
    );
  }
}

/// Press feedback: control sinks under the finger and springs back on release.
/// For cards, photo tiles, buttons. Rows use the flat highlight instead.
/// Spring controller is created on first touch, not on mount.
class Pressable extends StatefulWidget {
  const Pressable({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

/// Pointer events one [Pressable] has already answered. Events reach every
/// listener from the innermost out, so a heart inside a tile claims the press
/// and the tile around it stays still.
final _claimed = Expando<bool>("Pressable");

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  Offset _origin = Offset.zero;

  /// Null until the first press.
  SingleMotionController? _scale;

  void _press(PointerDownEvent event) {
    if (_claimed[event] ?? false) return;
    _claimed[event] = true;
    _origin = event.position;
    _down = true;
    final scale = _scale;
    if (scale == null) {
      // The one rebuild a press costs: the transform starts listening.
      setState(() {
        _scale = SingleMotionController(
          motion: AppMotion.chrome,
          vsync: this,
          initialValue: 1,
        )..animateTo(AppMotion.pressScale);
      });
    } else {
      scale.animateTo(AppMotion.pressScale);
    }
  }

  void _release([PointerEvent? _]) {
    if (!_down) return;
    _down = false;
    _scale?.animateTo(1);
  }

  void _move(PointerMoveEvent event) {
    if ((event.position - _origin).distance > kTouchSlop) _release();
  }

  @override
  void dispose() {
    _scale?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return Listener(
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: ScaleTransition(
        scale: _scale ?? kAlwaysCompleteAnimation,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// One glyph turning into another (play into pause, the heart filling): the
/// new one fades in from [growFrom] of its size on [motion]. Fades by colour
/// alpha, so no `saveLayer`; mounts as a plain glyph, and only a change
/// animates.
class SymbolSwap extends StatefulWidget {
  const SymbolSwap(
    this.icon, {
    this.size,
    this.color,
    this.growFrom = 0.6,
    this.motion = AppMotion.chrome,
    super.key,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final double growFrom;

  /// One of the two `AppMotion` springs.
  final Motion motion;

  @override
  State<SymbolSwap> createState() => _SymbolSwapState();
}

class _SymbolSwapState extends State<SymbolSwap> {
  IconData? _previous;
  Color? _previousColor;

  @override
  void didUpdateWidget(SymbolSwap old) {
    super.didUpdateWidget(old);
    if (old.icon != widget.icon) {
      _previous = old.icon;
      _previousColor = old.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    // No previous icon: render bare, no spring needed.
    if (previous == null) {
      return Icon(widget.icon, size: widget.size, color: widget.color);
    }
    final fallback = IconTheme.of(context).color ?? Colors.black;
    final color = widget.color ?? fallback;
    final previousColor = _previousColor ?? fallback;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return SingleMotionBuilder(
      key: ValueKey(widget.icon),
      motion: widget.motion,
      from: 0,
      value: 1,
      builder: (context, t, _) {
        final fade = t.clamp(0.0, 1.0);
        final scale = reduced ? 1.0 : lerpDouble(widget.growFrom, 1, t)!;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (fade < 1)
              Icon(
                previous,
                size: widget.size,
                color: previousColor.withValues(
                  alpha: previousColor.a * (1 - fade),
                ),
              ),
            Transform.scale(
              scale: scale,
              child: Icon(
                widget.icon,
                size: widget.size,
                color: color.withValues(alpha: color.a * fade),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Grows out of nothing along its height, or folds back into it. Folded,
/// the child is not built; moving, it is clipped hard-edged and faded.
class Fold extends StatelessWidget {
  const Fold({
    required this.open,
    required this.child,
    this.from,
    this.motion = AppMotion.chrome,
    this.onFolded,
    super.key,
  });

  final bool open;
  final Widget child;
  final double? from;
  final Motion motion;

  /// Fires once folded shut.
  final VoidCallback? onFolded;

  @override
  Widget build(BuildContext context) => AppMotionBuilder(
    end: open ? 1 : 0,
    from: from,
    motion: motion,
    onEnd: open ? null : onFolded,
    child: child,
    builder: (context, t, child) {
      final size = t.clamp(0.0, 1.0);
      if (size == 0) return const SizedBox.shrink();
      return ClipRect(
        clipBehavior: size < 1 ? Clip.hardEdge : Clip.none,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: size,
          child: Opacity(opacity: size, child: child),
        ),
      );
    },
  );
}

/// One thing cross-fading into the next in place: a label changing, a
/// spinner giving way to a button. [id] says when it is a different thing.
class FadeSwap extends StatelessWidget {
  const FadeSwap({
    required this.id,
    required this.child,
    this.alignment = Alignment.center,
    super.key,
  });

  final Object? id;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.edge,
    layoutBuilder: (current, previous) =>
        Stack(alignment: alignment, children: [...previous, ?current]),
    child: KeyedSubtree(key: ValueKey(id), child: child),
  );
}

/// Something landing with weight: scales up from nothing on
/// `AppMotion.arrive`. Only a first build with [animate] moves.
class PopIn extends StatelessWidget {
  const PopIn({
    required this.child,
    this.animate = true,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;
  final bool animate;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => AppMotionBuilder(
    end: 1,
    from: animate ? 0 : null,
    motion: AppMotion.arrive,
    child: child,
    builder: (context, t, child) =>
        Transform.scale(scale: t, alignment: alignment, child: child),
  );
}

/// Marks where a screen begins, so its [Entrance]s know whether it is
/// arriving. A scope first built while its route is still animating in sits
/// still: a pushed screen arrives whole on its transition. A tab's first
/// visit and in-place changes still arrive in order.
class EntranceScope extends StatefulWidget {
  const EntranceScope({required this.child, super.key});

  final Widget child;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  /// Null when the screen arrived on a push: nothing here animates.
  Stopwatch? _clock;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final route = ModalRoute.of(context)?.animation;
    if (route == null || route.isCompleted) _clock = Stopwatch()..start();
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceClock(clock: _clock, child: widget.child);
}

class _EntranceClock extends InheritedWidget {
  const _EntranceClock({required this.clock, required super.child});

  final Stopwatch? clock;

  @override
  bool updateShouldNotify(_EntranceClock old) => false;
}

/// A screen's content arriving in order: each part rises and fades in a beat
/// after the one before ([order]), only while its [EntranceScope] is new, so
/// scrolling never replays it. No timers: later parts start below zero on
/// the same spring.
class Entrance extends StatelessWidget {
  const Entrance({required this.child, this.order = 0, super.key});

  final Widget child;
  final int order;

  /// How long after a screen opens its content still arrives.
  static const _window = Duration(milliseconds: 500);

  /// How far below zero each later part starts, and the most parts staggered.
  static const _step = 0.15;
  static const _maxStagger = 6;

  @override
  Widget build(BuildContext context) {
    final clock = context
        .getInheritedWidgetOfExactType<_EntranceClock>()
        ?.clock;
    final arriving =
        clock != null &&
        clock.elapsed < _window &&
        !MediaQuery.disableAnimationsOf(context);
    final stagger = order < _maxStagger ? order : _maxStagger;

    return AppMotionBuilder(
      end: 1,
      from: arriving ? -_step * stagger : null,
      child: child,
      builder: (context, t, child) {
        final shown = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, (1 - shown) * AppSpace.x3),
            child: child,
          ),
        );
      },
    );
  }
}

/// A spring as a [Curve], for built-ins that take only a curve and a
/// duration: the spring's own position over [span], snapping to 1. It
/// overshoots, so never feed it to an `Opacity`.
class SpringCurve extends Curve {
  SpringCurve(Motion motion, this.span)
    : _simulation = motion.createSimulation();

  /// How long the route runs; long enough for the spring to settle.
  final Duration span;
  final Simulation _simulation;

  @override
  double transform(double t) => t >= 1
      ? 1
      : _simulation.x(t * span.inMicroseconds / Duration.microsecondsPerSecond);
}

/// The selection travelling to the chosen item (a page's parts): a shape
/// painted wherever [at] puts it as [moves] ticks, so the row never rebuilds
/// per frame (D-19). A capsule, or a rounded rectangle at [radius] inside a
/// rounded container (concentric with it). Nothing while [at] is null.
class TravellingPill extends CustomPainter {
  TravellingPill({
    required this.moves,
    required this.at,
    required this.color,
    this.radius,
  }) : super(repaint: moves);

  final Listenable moves;
  final Rect? Function(Size size) at;
  final Color color;
  final double? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = at(size);
    if (rect == null) return;
    final paint = Paint()..color = color;
    final radius = this.radius;
    if (radius == null) {
      canvas.drawPath(capsule.getOuterPath(rect), paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TravellingPill old) =>
      old.color != color ||
      old.moves != moves ||
      old.at != at ||
      old.radius != radius;
}

/// Shows a dialog that settles in from a beat larger while fading up, and
/// leaves by fading alone. Every dialog in the app opens this way.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModal<T>(
  context: context,
  configuration: _AlertConfiguration(
    barrierColor: Theme.of(context).colorScheme.scrim,
  ),
  builder: builder,
);

class _AlertConfiguration extends ModalConfiguration {
  _AlertConfiguration({required super.barrierColor})
    : super(
        barrierDismissible: true,
        barrierLabel: "Dismiss",
        transitionDuration: _in,
        reverseTransitionDuration: AppMotion.edge,
      );

  static const _in = AppMotion.span;

  /// How much larger the dialog starts than where it settles.
  static const _startScale = 1.08;

  final _spring = SpringCurve(AppMotion.chrome, _in);

  @override
  Widget transitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
      child: child,
    );
    if (MediaQuery.disableAnimationsOf(context)) return fade;
    return AnimatedBuilder(
      animation: animation,
      child: fade,
      builder: (context, child) {
        // Only arriving settles in; leaving is the fade alone.
        final arriving = animation.status == AnimationStatus.forward;
        final settled = arriving ? _spring.transform(animation.value) : 1.0;
        return Transform.scale(
          scale: lerpDouble(_startScale, 1, settled),
          child: child,
        );
      },
    );
  }
}
