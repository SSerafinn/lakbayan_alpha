import "dart:math" show pi;
import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:flutter/semantics.dart" show CustomSemanticsAction;
import "package:flutter/services.dart" show HapticFeedback;
import "package:motor/motor.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/motion/motion.dart";

/// The swipe deck: the front card follows the finger 1:1 and tilts around
/// where it was grabbed; a flick or a long enough drag decides, and the next
/// card rises in step. The uncovered strip shows what letting go will do
/// (the heart or the cross, solid past the line, with a haptic tick). A
/// decided card is gone as soon as it is off the deck, so the next is live
/// at once. One `MotionController<Offset>` drives it; tiles are built once.
/// Keep and Skip are also semantic actions, and [controller] lets buttons
/// outside answer.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    required this.cards,
    required this.tileFor,
    required this.onDecided,
    this.controller,
    super.key,
  });

  /// The remaining cards, front first. Only the first two are drawn.
  final List<Destination> cards;

  /// The cached photo tile for a place.
  final Widget Function(Destination place) tileFor;

  final void Function(Destination place, {required bool keep}) onDecided;

  /// Follows the front card and answers for it from outside the deck.
  final SwipeDeckController? controller;

  /// Room under the front card for the one behind it to show.
  static const backOffset = AppSpace.x4;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

/// Lets what sits around a [SwipeDeck] follow its front card and answer for
/// it: the stage behind it, the Keep and Skip buttons under it. Both values
/// are the deck's own drag read another way, never a second copy of it.
class SwipeDeckController {
  final _lean = ProxyAnimation(kAlwaysDismissedAnimation);
  final _rise = ProxyAnimation(kAlwaysDismissedAnimation);
  _SwipeDeckState? _deck;

  /// How far the front card leans, from -1 (skip) to 1 (keep).
  Animation<double> get lean => _lean;

  /// How far the next card has risen into place, from 0 to 1: where the
  /// stage and the buttons are between this card and the next.
  Animation<double> get rise => _rise;

  void keep() => _deck?._answer(keep: true);
  void skip() => _deck?._answer(keep: false);
}

/// One of the deck's drag readings, as an animation: listeners go straight
/// to the drag itself.
class _DragRatio extends Animation<double>
    with AnimationWithParentMixin<Offset> {
  _DragRatio(this.parent, this.of);

  @override
  final Animation<Offset> parent;
  final double Function(Offset drag) of;

  @override
  double get value => of(parent.value);
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  // Gesture tuning, local to this deck (PREFERENCES: a motion or constant
  // only one screen needs is declared where it is used).

  /// How far across, as a share of the card's width, a slow drag must go.
  static const _commitShare = 0.3;

  /// A release faster than this decides whatever the distance.
  static const _flingSpeed = AppMotion.flingSpeed;

  /// Where a leaving card is sent, as a share of the width past the edge.
  static const _exitShare = 1.4;

  /// Past this share of the width a leaving card is out of sight, and the
  /// decision is made there rather than when its spring settles.
  static const _goneShare = 1.15;

  /// The most the card turns at a full commit, in radians (twelve degrees).
  static const _maxTilt = 12 * pi / 180;

  /// The back card's scale at rest.
  static const _backScale = 0.95;

  /// A programmatic decision (a screen reader's Keep or Skip) throws the
  /// card at this speed, in px/s.
  static const _actionSpeed = 1600.0;

  late final _drag = MotionController<Offset>(
    motion: AppMotion.arrive,
    vsync: this,
    converter: MotionConverter.offset,
    initialValue: Offset.zero,
  );

  /// Grabbed above the middle: swing from the bottom edge.
  bool _grabbedHigh = true;

  /// A decision is flying; the finger has no say until it lands.
  bool _leaving = false;

  /// How far across the card was when it was let go; the symbol fades out
  /// from there. Null while a finger holds it.
  double? _releasedAt;

  /// Past the line on the last frame, so crossing it ticks once.
  bool _armed = false;

  double _width = 1;

  /// The front card's lean, -1 to 1.
  late final _lean = _DragRatio(
    _drag,
    (drag) => (drag.dx / _width).clamp(-1.0, 1.0),
  );

  /// How far the next card has risen, 0 to 1: all the way by the line.
  late final _rise = _DragRatio(
    _drag,
    (drag) => (drag.dx.abs() / (_width * _commitShare)).clamp(0.0, 1.0),
  );

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(SwipeDeck old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _detach(old.controller);
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _drag.dispose();
    super.dispose();
  }

  void _attach(SwipeDeckController? controller) {
    if (controller == null) return;
    controller
      .._deck = this
      .._lean.parent = _lean
      .._rise.parent = _rise;
  }

  void _detach(SwipeDeckController? controller) {
    if (controller == null || controller._deck != this) return;
    controller
      .._deck = null
      .._lean.parent = kAlwaysDismissedAnimation
      .._rise.parent = kAlwaysDismissedAnimation;
  }

  /// A button or a screen reader decides: the card is thrown that way.
  void _answer({required bool keep}) {
    if (_leaving || widget.cards.isEmpty) return;
    _leave(
      keep: keep,
      velocity: Offset(keep ? _actionSpeed : -_actionSpeed, 0),
    );
  }

  void _start(DragStartDetails details, double height) {
    if (_leaving) return;
    _grabbedHigh = details.localPosition.dy < height / 2;
    _drag.stop();
  }

  void _update(DragUpdateDetails details) {
    if (_leaving) return;
    _drag.value = _drag.value + details.delta;
    final armed = _drag.value.dx.abs() > _width * _commitShare;
    if (armed != _armed) {
      _armed = armed;
      HapticFeedback.selectionClick();
    }
  }

  void _end(DragEndDetails details) {
    if (_leaving) return;
    final velocity = details.velocity.pixelsPerSecond;
    final dx = _drag.value.dx;
    final bool? keep = velocity.dx.abs() > _flingSpeed
        ? velocity.dx > 0
        : dx.abs() > _width * _commitShare
        ? dx > 0
        : null;
    _armed = false;
    if (keep == null) {
      _drag.motion = _motion(AppMotion.arrive);
      _drag.animateTo(Offset.zero, withVelocity: velocity);
      return;
    }
    _leave(keep: keep, velocity: velocity);
  }

  void _leave({required bool keep, required Offset velocity}) {
    final place = widget.cards.first;
    // A keep lands with a little more weight than a skip.
    keep ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    final exit = Offset(
      (keep ? 1 : -1) * _width * _exitShare,
      _drag.value.dy + velocity.dy * 0.1,
    );
    setState(() {
      _leaving = true;
      _releasedAt = _drag.value.dx.abs();
    });
    var decided = false;
    void gone() {
      if (decided || !mounted) return;
      decided = true;
      _drag.stop(canceled: true);
      // Home before the parent swaps cards, in the same frame, so the card
      // that was behind is simply the front one now.
      _drag.value = Offset.zero;
      setState(() {
        _leaving = false;
        _releasedAt = null;
      });
      widget.onDecided(place, keep: keep);
    }

    void outOfSight() {
      if (_drag.value.dx.abs() < _width * _goneShare) return;
      _drag.removeListener(outOfSight);
      gone();
    }

    _drag
      ..motion = _motion(AppMotion.chrome)
      ..addListener(outOfSight);
    _drag.animateTo(exit, withVelocity: velocity).then((_) {
      _drag.removeListener(outOfSight);
      gone();
    });
  }

  /// Under reduced motion the card still moves (it follows a finger), but
  /// settles on a short, bounceless curve rather than a spring.
  Motion _motion(Motion spring) => MediaQuery.disableAnimationsOf(context)
      ? const Motion.curved(AppMotion.edge, Curves.easeOut)
      : spring;

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final front = cards.first;
    final back = cards.length > 1 ? cards[1] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final height = constraints.maxHeight - SwipeDeck.backOffset;
        final commit = _width * _commitShare;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (back != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height,
                child: AnimatedBuilder(
                  animation: _rise,
                  child: RepaintBoundary(
                    key: ValueKey(back.id),
                    child: widget.tileFor(back),
                  ),
                  builder: (context, tile) {
                    final rise = _rise.value;
                    return Transform.translate(
                      offset: Offset(0, SwipeDeck.backOffset * (1 - rise)),
                      child: Transform.scale(
                        scale: lerpDouble(_backScale, 1, rise),
                        child: tile,
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: height,
              child: _Reveal(
                drag: _drag,
                commit: commit,
                releasedAt: _releasedAt,
                width: _width,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: height,
              child: Semantics(
                customSemanticsActions: {
                  const CustomSemanticsAction(label: "Keep"): () =>
                      _answer(keep: true),
                  const CustomSemanticsAction(label: "Skip"): () =>
                      _answer(keep: false),
                },
                child: GestureDetector(
                  onPanStart: (details) => _start(details, height),
                  onPanUpdate: _update,
                  onPanEnd: _end,
                  child: AnimatedBuilder(
                    animation: _drag,
                    child: RepaintBoundary(
                      key: ValueKey(front.id),
                      child: widget.tileFor(front),
                    ),
                    builder: (context, tile) {
                      final offset = _drag.value;
                      final lean = (offset.dx / _width).clamp(-1.0, 1.0);
                      return Transform.translate(
                        offset: offset,
                        child: Transform.rotate(
                          angle: lean * _maxTilt * (_grabbedHigh ? 1 : -1),
                          alignment: _grabbedHigh
                              ? Alignment.bottomCenter
                              : Alignment.topCenter,
                          child: tile,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// What letting go will do, in the strip the front card has uncovered: the
/// heart on the left while it goes right, the cross on the right while it
/// goes left, on its own white circle so it never sits on raw photo.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.drag,
    required this.commit,
    required this.releasedAt,
    required this.width,
  });

  final MotionController<Offset> drag;
  final double commit;

  /// Where the card was let go, once it is leaving.
  final double? releasedAt;
  final double width;

  /// How far the leaving card travels, as a share of the width, while the
  /// symbol fades out.
  static const _fadeShare = 0.35;

  static const _size = AppSize.heroSave;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: drag,
      builder: (context, _) {
        final dx = drag.value.dx;
        final released = releasedAt;
        // Leaving, it holds where it was let go and fades as the card flies.
        final travel = released ?? dx.abs();
        final fade = released == null
            ? 1.0
            : 1 -
                  ((dx.abs() - released) / (width * _fadeShare)).clamp(
                    0.0,
                    1.0,
                  );
        final shown = (travel / commit).clamp(0.0, 1.0) * fade;
        if (shown == 0) return const SizedBox.shrink();
        final keep = dx > 0;
        final armed = travel >= commit;
        // Centred in the uncovered strip, never past the card's own middle.
        final strip = travel.clamp(_size + AppSpace.x4, double.infinity);
        final centre = strip / 2;

        return Align(
          alignment: keep ? Alignment.centerLeft : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              left: keep ? centre - _size / 2 : 0,
              right: keep ? 0 : centre - _size / 2,
            ),
            child: Opacity(
              opacity: shown,
              child: Transform.scale(
                scale: lerpDouble(0.5, 1, (travel / commit).clamp(0.0, 1.0)),
                child: _Symbol(keep: keep, armed: armed),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Symbol extends StatelessWidget {
  const _Symbol({required this.keep, required this.armed});

  final bool keep;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    return SizedBox.square(
      dimension: _Reveal._size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerLowest,
          shape: const CircleBorder(),
        ),
        // Past the line the heart fills red and lands with a bump; the
        // cross darkens. The same swap the save heart uses elsewhere.
        child: SymbolSwap(
          keep
              ? (armed ? AppIcons.favoriteFilled : AppIcons.favorite)
              : AppIcons.close,
          size: AppSize.glyphLg,
          color: keep
              ? (armed ? brand.save : scheme.onSurfaceVariant)
              : (armed ? scheme.onSurface : scheme.onSurfaceVariant),
          growFrom: armed ? 1.35 : 0.85,
          motion: AppMotion.arrive,
        ),
      ),
    );
  }
}
