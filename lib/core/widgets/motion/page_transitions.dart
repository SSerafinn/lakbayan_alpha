import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:flutter/services.dart" show PredictiveBackEvent;

import "../../theme/app_dimens.dart";
import "../../theme/app_motion.dart";
import "motion.dart";

/// Every pushed screen, the iOS way: it slides in from the trailing edge,
/// opaque, while the one beneath drifts a third back and dims a touch (the
/// edge reads without a shadow). Back is the same path, driven by Android's
/// back gesture. Translation and one translucent fill only: no fade, no
/// scale, no `saveLayer`.
class PushPageTransitionsBuilder extends PageTransitionsBuilder {
  const PushPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.span;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _BackGesture(
    route: route,
    child: _Transition(
      arrival: _Arrival.slide,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      // Linear under the finger; the route rebuilds this when a gesture
      // starts or ends.
      linear: route.popGestureInProgress,
      child: child,
    ),
  );
}

/// A screen opened from a photo: the photo ([PhotoHero]) grows into the
/// screen's own while the screen fades in around it, and the screen beneath
/// stays still. Back shrinks it home. A deep link is pushed instead.
class ZoomPage<T> extends Page<T> {
  const ZoomPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _ZoomRoute<T>(this);
}

class _ZoomRoute<T> extends PageRoute<T> {
  _ZoomRoute(ZoomPage<T> page) : super(settings: page);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => AppMotion.span;

  /// Only a pushed page drifts this one back, Material's own test. Drifting
  /// under a sheet or a dialog slid the page aside and showed black.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is MaterialRouteTransitionMixin && !nextRoute.fullscreenDialog;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => (settings as ZoomPage<T>).child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _BackGesture(
    route: this,
    child: _Transition(
      arrival: _Arrival.reveal,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      linear: popGestureInProgress,
      child: child,
    ),
  );
}

enum _Arrival { slide, reveal }

class _Transition extends StatefulWidget {
  const _Transition({
    required this.arrival,
    required this.animation,
    required this.secondaryAnimation,
    required this.linear,
    required this.child,
  });

  final _Arrival arrival;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final bool linear;
  final Widget child;

  @override
  State<_Transition> createState() => _TransitionState();
}

class _TransitionState extends State<_Transition> {
  /// The chrome spring in; flipped out, so a pop leaves at speed.
  static final _in = SpringCurve(AppMotion.chrome, AppMotion.span);
  static final _out = _in.flipped;

  /// A revealed screen is in within the photo's first stretch and holds
  /// until it is nearly home on the way out. Reduced motion fades so too.
  static const _fadeIn = Interval(0, 0.6, curve: Curves.easeOut);
  static const _fadeOut = Interval(0, 0.6, curve: Curves.easeIn);

  static const _drift = 1 / 3;
  static const _dim = 0.1;

  static final _arrive = Tween(begin: const Offset(1, 0), end: Offset.zero);
  static final _recede = Tween(
    begin: Offset.zero,
    end: const Offset(-_drift, 0),
  );

  late CurvedAnimation _primary;
  late CurvedAnimation _secondary;
  late CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _curve();
  }

  @override
  void didUpdateWidget(_Transition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation ||
        old.secondaryAnimation != widget.secondaryAnimation ||
        old.linear != widget.linear) {
      _release();
      _curve();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _curve() {
    final curve = widget.linear ? Curves.linear : _in;
    final reverse = widget.linear ? Curves.linear : _out;
    _primary = CurvedAnimation(
      parent: widget.animation,
      curve: curve,
      reverseCurve: reverse,
    );
    _secondary = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: curve,
      reverseCurve: reverse,
    );
    _fade = CurvedAnimation(
      parent: widget.animation,
      curve: _fadeIn,
      reverseCurve: _fadeOut,
    );
  }

  void _release() {
    _primary.dispose();
    _secondary.dispose();
    _fade.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: every screen fades, nothing slides or flies.
    if (MediaQuery.disableAnimationsOf(context)) {
      return HeroMode(
        enabled: false,
        child: FadeTransition(opacity: _fade, child: widget.child),
      );
    }
    final direction = Directionality.of(context);
    final scrim = Theme.of(context).colorScheme.scrim;
    // The same tree at every value; at rest each is the identity.
    return SlideTransition(
      position: _secondary.drive(_recede),
      textDirection: direction,
      child: DecoratedBoxTransition(
        position: DecorationPosition.foreground,
        decoration: _secondary.drive(
          DecorationTween(
            begin: BoxDecoration(color: scrim.withValues(alpha: 0)),
            end: BoxDecoration(color: scrim.withValues(alpha: _dim)),
          ),
        ),
        child: switch (widget.arrival) {
          _Arrival.slide => SlideTransition(
            position: _primary.drive(_arrive),
            textDirection: direction,
            child: widget.child,
          ),
          _Arrival.reveal => FadeTransition(
            opacity: _fade,
            child: widget.child,
          ),
        },
      ),
    );
  }
}

/// Hands Android's back gesture to the route so its own animation follows
/// the finger, as Flutter's predictive back builder does but without a
/// rebuild per move. Only the current route with a pop to make takes it;
/// otherwise the system back is the ordinary pop.
class _BackGesture extends StatefulWidget {
  const _BackGesture({required this.route, required this.child});

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackGesture> createState() => _BackGestureState();
}

class _BackGestureState extends State<_BackGesture>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The rest of a gesture goes only to observers that took its start.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final route = widget.route;
    final takes =
        !backEvent.isButtonEvent && route.isCurrent && route.popGestureEnabled;
    if (takes) route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return takes;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) => widget
      .route
      .handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A place photo that flies between screens (every one that opens a page;
/// never a bare `Hero`). The photo in flight is the one on screen, laid out
/// once and scaled, so nothing is laid out or decoded per frame; the far
/// end's photo fades in as it lands (STANDARDS 10.14). Corners unround from
/// the tile's `ParentRadius`, in a straight line, and back gestures drive it.
class PhotoHero extends StatelessWidget {
  const PhotoHero({required this.tag, required this.child, super.key});

  final Object tag;
  final Widget child;

  /// How far along the flight the far end's photo starts to show.
  static const _handOver = Interval(0.4, 1);

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder: _flight,
    transitionOnUserGestures: true,
    child: child,
  );

  static Widget _flight(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final from = fromContext.widget as Hero;
    final to = toContext.widget as Hero;
    // 0 is the tile's end and 1 the page's, forward on a push, back on a pop.
    final push = direction == HeroFlightDirection.push;
    final tileRadius = _radiusOf(push ? fromContext : toContext);
    final pageRadius = _radiusOf(push ? toContext : fromContext);
    final progress = push ? animation : ReverseAnimation(animation);

    return AnimatedBuilder(
      animation: animation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Scaled(size: _sizeOf(fromContext), child: from.child),
          FadeTransition(
            opacity: progress.drive(CurveTween(curve: _handOver)),
            child: _Scaled(size: _sizeOf(toContext), child: to.child),
          ),
        ],
      ),
      builder: (context, photos) => ClipRRect(
        borderRadius: BorderRadius.circular(
          lerpDouble(tileRadius, pageRadius, animation.value)!,
        ),
        child: photos,
      ),
    );
  }

  static Size? _sizeOf(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  static double _radiusOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ParentRadius>()?.radius ?? 0;
}

/// A photo laid out at [size] and scaled to cover its box: a transform per
/// frame, never a new layout or decode.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.size, required this.child});

  final Size? size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = this.size;
    if (size == null || size.isEmpty) return child;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox.fromSize(size: size, child: child),
    );
  }
}
