import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:motor/motor.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "save_heart.dart";

/// The featured places as a deck (D-19): the front card full size, the next
/// two waiting behind it a step smaller and dimmer, their edges showing at
/// the trailing side, so there is always a hint of more. A swipe deals the
/// front card off to the leading edge and the next comes forward; a fling
/// decides whatever the distance; a tap on the waiting edges deals one.
/// Each card moves by one transform on the chrome spring; nothing is laid
/// out or built again. The front card opens its place, its photo zooming.
class FeaturedDeck extends StatefulWidget {
  const FeaturedDeck({required this.places, super.key});

  final List<Destination> places;

  /// How far the waiting cards' edges show past the front card's.
  static const peek = AppSpace.x10;

  /// The deck's height in [width]: the front card's, 5:6.
  static double heightOf(double width) => (width - peek) * 6 / 5;

  @override
  State<FeaturedDeck> createState() => _FeaturedDeckState();
}

class _FeaturedDeckState extends State<FeaturedDeck>
    with SingleTickerProviderStateMixin {
  /// Which card is in front, as a fraction while one is being dealt.
  late final _position = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
    initialValue: 0,
  );

  /// The card the dots mark, so only the dots rebuild when it changes.
  final _front = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _position.addListener(_settle);
  }

  @override
  void dispose() {
    _position.dispose();
    _front.dispose();
    super.dispose();
  }

  void _settle() {
    _front.value = _position.value.round().clamp(0, widget.places.length - 1);
  }

  /// One card's travel, in pixels: its width.
  double get _step => (context.size?.width ?? 1) - FeaturedDeck.peek;

  void _drag(DragUpdateDetails details) {
    final last = widget.places.length - 1.0;
    var shift = details.delta.dx / _step;
    // Past either end the deck holds back: a third of the finger's travel.
    final next = _position.value - shift;
    if (next < 0 || next > last) shift /= 3;
    _position.value = _position.value - shift;
  }

  void _release(DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    final at = _position.value;
    var target = at.roundToDouble();
    if (speed.abs() > AppMotion.flingSpeed) {
      target = speed < 0 ? at.floorToDouble() + 1 : at.ceilToDouble() - 1;
    }
    _deal(
      target.clamp(0, widget.places.length - 1).toDouble(),
      velocity: -speed / _step,
    );
  }

  /// Deals the next card, and after the last gathers the deck back.
  void _next() {
    final now = _position.value.round();
    _deal(now >= widget.places.length - 1 ? 0 : now + 1.0);
  }

  void _deal(double target, {double velocity = 0}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
    } else {
      _position.animateTo(target, withVelocity: velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.places;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth - FeaturedDeck.peek;
            return SizedBox(
              width: box.maxWidth,
              height: FeaturedDeck.heightOf(box.maxWidth),
              child: GestureDetector(
                onHorizontalDragStart: (_) => _position.stop(),
                onHorizontalDragUpdate: _drag,
                onHorizontalDragEnd: _release,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The last card first, so the front one paints on top.
                    for (var i = places.length - 1; i >= 0; i--)
                      _DeckCard(
                        position: _position,
                        index: i,
                        width: width,
                        child: _Face(place: places[i]),
                      ),
                    if (places.length > 1)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: FeaturedDeck.peek,
                        child: Semantics(
                          button: true,
                          label: "Next featured place",
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _next,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (places.length > 1) ...[
          const SizedBox(height: AppSpace.x2),
          ValueListenableBuilder(
            valueListenable: _front,
            builder: (context, front, _) =>
                PageDots(count: places.length, current: front),
          ),
        ],
      ],
    );
  }
}

/// One card's place in the deck, from how far it is from the front: dealt
/// off to the leading edge, in front, or waiting a step behind. Only the
/// transform and the dimming follow the spring; the card is built once.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.position,
    required this.index,
    required this.width,
    required this.child,
  });

  final Animation<double> position;
  final int index;
  final double width;
  final Widget child;

  /// Each waiting place: how far its trailing edge shows past the front
  /// card's, how small it is and how dim.
  static const _peeks = [0.0, AppSpace.x5, FeaturedDeck.peek];
  static const _scales = [1.0, 0.93, 0.86];
  static const _dims = [0.0, 0.18, 0.34];

  @override
  Widget build(BuildContext context) {
    final card = SizedBox(
      width: width,
      child: RepaintBoundary(child: child),
    );
    return AnimatedBuilder(
      animation: position,
      child: card,
      builder: (context, card) {
        final away = index - position.value;
        var dx = away * (width + AppSpace.x3);
        var scale = 1.0;
        var dim = 0.0;
        if (away > 0) {
          final low = away.floor().clamp(0, 2);
          final high = (low + 1).clamp(0, 2);
          final share = (away - low).clamp(0.0, 1.0);
          dx = lerpDouble(_peeks[low], _peeks[high], share)!;
          scale = lerpDouble(_scales[low], _scales[high], share)!;
          dim = lerpDouble(_dims[low], _dims[high], share)!;
        }
        final front = away.abs() < 0.5;
        return Offstage(
          offstage: away <= -1 || away >= 3,
          child: IgnorePointer(
            ignoring: !front,
            child: ExcludeSemantics(
              excluding: !front,
              child: Transform(
                alignment: Alignment.centerRight,
                transform: Matrix4.translationValues(
                  dx,
                  0,
                  0,
                ).multiplied(Matrix4.diagonal3Values(scale, scale, 1)),
                child: Stack(
                  children: [
                    card!,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: Colors.black.withValues(alpha: dim),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.lgAll,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A featured place: its photo, its name on the scrim, the heart on glass.
class _Face extends StatelessWidget {
  const _Face({required this.place});

  final Destination place;

  @override
  Widget build(BuildContext context) {
    void open() =>
        context.push(Routes.destination(place.id, from: HeroSource.featured));
    return Pressable(
      child: GestureDetector(
        onTap: open,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: AppRadii.lgAll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ParentRadius(
                radius: AppRadii.lg,
                child: PhotoHero(
                  tag: coverHeroTag(place.id, HeroSource.featured),
                  child: CoverImage(place.coverImage),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaScrim(
                  child: Text(
                    place.name,
                    style: AppTypography.display.copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // The CMS's `featured` flag is what puts a place here, so the
              // card says what it is, on a line with the heart.
              Positioned(
                top: AppSpace.x3,
                left: AppSpace.x3,
                right: AppSpace.x3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PhotoPill("Popular This Season"),
                      ),
                    ),
                    SaveHeart(place.id, style: SaveHeartStyle.hero),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
