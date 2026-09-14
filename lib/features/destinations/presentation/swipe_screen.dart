import "dart:math" show pi;
import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:flutter_card_swiper/flutter_card_swiper.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:motor/motor.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../domain/destination_providers.dart";
import "../domain/saved_destinations.dart";

/// Swipe mode (redesign 2b). **One job:** decide on one place at a time.
/// **Emotion:** play, low stakes.
///
/// Close and a title; the deck (`flutter_card_swiper`, left and right only)
/// with a KEEP or SKIP stamp surfacing under the drag; one line of hint until
/// the first swipe; and, once something has been skipped, a tilted stack of
/// the skipped places bottom-left. Tapping the stack flies the last one back
/// onto the deck, landing with a spring.
class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredDestinationsProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.x2,
              topInset + AppSpace.x2,
              AppSpace.gutter,
              0,
            ),
            child: Row(
              children: [
                SymbolButton(
                  icon: AppIcons.close,
                  tooltip: "Close",
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(
                  child: Text("Keep or skip", style: AppTypography.titleMedium),
                ),
              ],
            ),
          ),
          Expanded(
            child: featured.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  QuietNote("Couldn't load places.\n$error", centered: true),
              data: (items) => items.isEmpty
                  ? const QuietNote(
                      "Nothing to swipe through yet.",
                      centered: true,
                    )
                  : _Deck(items: items),
            ),
          ),
        ],
      ),
    );
  }
}

class _Deck extends ConsumerStatefulWidget {
  const _Deck({required this.items});

  final List<Destination> items;

  @override
  ConsumerState<_Deck> createState() => _DeckState();
}

class _DeckState extends ConsumerState<_Deck> {
  /// The cards in play. Bringing a skipped place back inserts it here.
  late List<Destination> _deck;

  /// The front card's position in [_deck].
  int _index = 0;
  final _skipped = <Destination>[];

  /// Only a skip (an arrival) pops the stack's top in, not a bring-back.
  bool _skipAdded = false;
  bool _swipedOnce = false;
  bool _done = false;

  /// Bumped when [_deck] changes shape so the swiper rebuilds from [_index].
  int _generation = 0;

  /// The package calls `cardBuilder` every drag frame; the photo tile is
  /// built once per place and only the stamp layer changes (STANDARDS 5.6).
  final _tiles = <String, Widget>{};

  Widget _tileFor(Destination place) =>
      _tiles.putIfAbsent(place.id, () => _DeckTile(destination: place));

  /// Cards on their way back from the stack to the deck. Each tap starts its
  /// own flight, so spamming the stack never waits on the last one.
  final _flights = <_Flight>[];

  /// Where a flight starts and ends, measured in the Stack's own space.
  final _stackKey = GlobalKey();
  final _deckKey = GlobalKey();
  final _skippedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _deck = List.of(widget.items);
  }

  bool _onSwipe(int previous, int? current, CardSwiperDirection direction) {
    final place = _deck[previous];
    setState(() {
      _swipedOnce = true;
      _index = current ?? _deck.length;
      if (direction == CardSwiperDirection.right) {
        ref.read(savedDestinationsProvider.notifier).save(place.id);
      } else {
        _skipped.add(place);
        _skipAdded = true;
      }
    });
    return true;
  }

  /// Tapping the stack: the last skipped place flies back to the deck.
  void _bringBack() {
    if (_skipped.isEmpty) return;
    final place = _skipped.removeLast();
    _skipAdded = false;
    final path = _flightPath();
    if (path == null || MediaQuery.disableAnimationsOf(context)) {
      setState(() => _insert(place));
      return;
    }
    setState(() => _flights.add((place, path.$1, path.$2)));
  }

  /// From the top of the skipped stack to the deck's front slot, both in the
  /// enclosing Stack's coordinates. Null before the first layout.
  (Rect, Rect)? _flightPath() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final from = _skippedKey.currentContext?.findRenderObject() as RenderBox?;
    final to = _deckKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || from == null || to == null) return null;
    if (!stack.hasSize || !from.hasSize || !to.hasSize) return null;
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    // The swiper keeps [_deckPadding] under the front card for the one
    // behind it, so the slot is that much shorter than the deck's box.
    final slot = rectOf(to);
    return (
      rectOf(from),
      Rect.fromLTRB(
        slot.left,
        slot.top,
        slot.right,
        slot.bottom - _deckPadding,
      ),
    );
  }

  void _land(_Flight flight) => setState(() {
    _flights.remove(flight);
    _insert(flight.$1);
  });

  void _insert(Destination place) {
    _index = _index.clamp(0, _deck.length);
    _deck.insert(_index, place);
    _done = false;
    _generation++;
  }

  void _startOver() => setState(() {
    _deck = List.of(widget.items);
    _index = 0;
    _skipped.clear();
    _done = false;
    _generation++;
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      key: _stackKey,
      children: [
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x3,
                  AppSpace.gutter,
                  0,
                ),
                child: Center(
                  child: AspectRatio(
                    key: _deckKey,
                    aspectRatio: 3 / 4,
                    child: _done
                        ? _DeckDone(onStartOver: _startOver)
                        : _index >= _deck.length
                        ? _DeckDone(onStartOver: _startOver)
                        : CardSwiper(
                            key: ValueKey(_generation),
                            cardsCount: _deck.length,
                            initialIndex: _index,
                            numberOfCardsDisplayed: _deck.length - _index == 1
                                ? 1
                                : 2,
                            isLoop: false,
                            allowedSwipeDirection:
                                const AllowedSwipeDirection.symmetric(
                                  horizontal: true,
                                ),
                            padding: const EdgeInsets.only(
                              bottom: _deckPadding,
                            ),
                            backCardOffset: const Offset(0, _deckPadding),
                            scale: 0.95,
                            maxAngle: 12,
                            threshold: 60,
                            duration: reduceMotion
                                ? AppMotion.edge
                                : Durations.medium2,
                            onSwipe: _onSwipe,
                            onEnd: () => setState(() => _done = true),
                            cardBuilder: (context, index, horizontal, _) =>
                                _DeckCard(
                                  tile: _tileFor(_deck[index]),
                                  horizontal: horizontal / 100,
                                ),
                          ),
                  ),
                ),
              ),
            ),
            // Reserved after the first swipe so the deck does not jump.
            SizedBox(
              height: AppSize.minTouchTarget,
              child: Center(
                child: _swipedOnce || _done
                    ? null
                    : Text(
                        "Drag right to keep, left to skip",
                        style: AppTypography.secondLine.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            SizedBox(height: _SkippedStack.height + bottomInset + AppSpace.x3),
          ],
        ),
        if (_skipped.isNotEmpty)
          Positioned(
            left: AppSpace.gutter,
            bottom: bottomInset + AppSpace.x3,
            child: _SkippedStack(
              skipped: _skipped,
              topKey: _skippedKey,
              animateTop: _skipAdded,
              onBringBack: _bringBack,
            ),
          ),
        for (final flight in _flights)
          MotionBuilder<Rect>(
            key: ValueKey(flight.$1.id),
            motion: AppMotion.arrive,
            converter: const RectMotionConverter(),
            from: flight.$2,
            value: flight.$3,
            onAnimationStatusChanged: (status) {
              if (status == AnimationStatus.completed) _land(flight);
            },
            child: _tileFor(flight.$1),
            builder: (context, rect, child) => Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    _radiusAlong(flight, rect),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Corners round from the stack's thumbnail radius to the deck's as the
  /// card grows, read off its own width so the two never drift apart.
  static double _radiusAlong(_Flight flight, Rect rect) {
    final grown = rect.width - flight.$2.width;
    final total = flight.$3.width - flight.$2.width;
    final t = total == 0 ? 1.0 : (grown / total).clamp(0.0, 1.0);
    return lerpDouble(AppRadii.sm, AppRadii.lg, t)!;
  }
}

/// A place in flight, where it starts and where it lands.
typedef _Flight = (Destination, Rect, Rect);

/// The swiper's own inset under the front card, and the back card's offset.
const _deckPadding = AppSpace.x4;

/// The photo with the name on a scrim. Built once per place.
class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return MediaTile(
      media: CoverImage(destination.coverImage),
      aspectRatio: 3 / 4,
      title: destination.name,
      subtitle: destination.town,
      overlay: true,
      badge: destination.hasAR ? const LakbayanBadge.ar() : null,
      radius: AppRadii.lg,
      onTap: () => context.push(Routes.destination(destination.id)),
    );
  }
}

/// One card: the cached tile and the stamp that surfaces with the drag.
/// Rebuilt every drag frame by the package, so only the stamp is here.
class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.tile, required this.horizontal});

  final Widget tile;

  /// Drag as a fraction of the threshold; negative is left.
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final amount = horizontal.abs().clamp(0.0, 1.0);
    final keeping = horizontal > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        tile,
        if (amount > 0)
          Positioned(
            top: AppSpace.x6,
            left: keeping ? AppSpace.x5 : null,
            right: keeping ? null : AppSpace.x5,
            child: IgnorePointer(
              child: Opacity(
                opacity: amount,
                child: _Stamp(keep: keeping),
              ),
            ),
          ),
      ],
    );
  }
}

/// KEEP in solid green tilted one way, SKIP in solid red tilted the other.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.keep});

  final bool keep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    return Transform.rotate(
      angle: (keep ? -8 : 8) * pi / 180,
      child: Material(
        color: keep ? scheme.primary : brand.closed,
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x4,
            vertical: AppSpace.x2,
          ),
          child: Text(
            keep ? "KEEP" : "SKIP",
            style: AppTypography.caps.copyWith(
              color: keep ? scheme.onPrimary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The skipped places as a tilted stack of thumbnails; a tap sends the top
/// one back to the deck. Symbol-only, so tooltip and semantics say what the
/// tap does.
class _SkippedStack extends StatelessWidget {
  const _SkippedStack({
    required this.skipped,
    required this.topKey,
    required this.animateTop,
    required this.onBringBack,
  });

  final List<Destination> skipped;

  /// On the top thumbnail, so the flight back can start from it.
  final GlobalKey topKey;
  final bool animateTop;
  final VoidCallback onBringBack;

  static const height = 96.0;
  static const _width = 72.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final top = skipped.last;
    final shown = skipped.reversed.take(3).toList();

    return Tooltip(
      message: "Bring back ${top.name}",
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: "Bring back ${top.name}",
        child: GestureDetector(
          onTap: onBringBack,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: _width + AppSpace.x3,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (index, place) in shown.reversed.indexed)
                  Positioned(
                    left: index * AppSpace.x1,
                    bottom: 0,
                    child: Transform.rotate(
                      angle: (index - (shown.length - 1)) * 6 * pi / 180,
                      child: index == shown.length - 1
                          ? _PopIn(
                              key: ValueKey(place.id),
                              animate: animateTop,
                              reduceMotion: reduceMotion,
                              child: _Thumb(
                                key: topKey,
                                place: place,
                                named: true,
                              ),
                            )
                          : _Thumb(place: place, named: false),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The newest thumbnail scales up from its base with a small overshoot, so it
/// visibly arrives rather than appears. Reduced motion fades it in instead.
class _PopIn extends StatelessWidget {
  const _PopIn({
    required this.animate,
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final bool animate;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    motion: AppMotion.arrive,
    from: animate ? 0 : null,
    value: 1,
    child: child,
    builder: (context, t, child) => reduceMotion
        ? Opacity(opacity: t.clamp(0.0, 1.0), child: child)
        : Transform.scale(
            scale: t,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.place, required this.named, super.key});

  final Destination place;
  final bool named;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox(
        width: _SkippedStack._width,
        height: _SkippedStack.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(place.coverImage),
            if (named)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaScrim(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x2,
                    AppSpace.x6,
                    AppSpace.x2,
                    AppSpace.x2,
                  ),
                  child: Text(
                    place.name,
                    style: AppTypography.glyphLabel.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeckDone extends StatelessWidget {
  const _DeckDone({required this.onStartOver});

  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("That is every place.", style: AppTypography.titleMedium),
            const SizedBox(height: AppSpace.x2),
            Text(
              "The ones you kept are waiting on your profile.",
              style: AppTypography.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.x4),
            TextButton(onPressed: onStartOver, child: const Text("Start over")),
          ],
        ),
      ),
    );
  }
}
