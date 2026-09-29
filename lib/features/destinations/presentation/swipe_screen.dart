import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:motor/motor.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_theme.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../domain/destination_providers.dart";
import "../domain/saved_destinations.dart";
import "swipe_deck.dart";

/// Keep or skip. **Job:** decide on one place at a time. **Emotion:** play,
/// the place filling the room.
///
/// The stage is the front card's photo, soft and dark, with the next card's
/// fading in over it in step with the drag. The card carries town, name and
/// a two-line lede, and opens the place. Skip and Keep take the card's
/// colour and grow toward the lean; the last skipped place waits as a photo
/// disc. Always dark, in either appearance (the deliberate exception to
/// white first); photo-less cards take their kind's tone (`role.kind`).
class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredDestinationsProvider);

    return Theme(
      data: _stageTheme,
      child: SystemBars(
        child: Scaffold(
          body: featured.when(
            loading: () => const _Plain(child: CircularProgressIndicator()),
            error: (error, _) => _Plain(
              child: QuietNote("Couldn't load places.\n$error", centered: true),
            ),
            data: (items) => items.isEmpty
                ? const _Plain(
                    child: QuietNote(
                      "Nothing to swipe through yet.",
                      centered: true,
                    ),
                  )
                : _Deck(items: items),
          ),
        ),
      ),
    );
  }
}

/// The app's dark theme, built once, for everything on the stage.
final _stageTheme = buildAppDarkTheme();

/// A place's kind as its deep tone (`role.kind`).
Color _toneOf(BuildContext context, Destination place) =>
    context.lakbayan.kindTone(place.category);

/// Close and the title, over the stage.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpace.x2,
      MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
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
        Expanded(child: Text("Keep or skip", style: AppTypography.titleMedium)),
      ],
    ),
  );
}

/// The header over a state with no cards: loading, an error, nothing yet.
class _Plain extends StatelessWidget {
  const _Plain({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _Header(),
      Expanded(child: Center(child: child)),
    ],
  );
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

  /// Only a skip (an arrival) pops the disc in, not a bring-back.
  bool _skipAdded = false;
  bool _done = false;

  final _controller = SwipeDeckController();

  /// Photo tiles are built once per place and only repositioned.
  final _tiles = <String, Widget>{};

  Widget _tileFor(Destination place) =>
      _tiles.putIfAbsent(place.id, () => _DeckTile(destination: place));

  /// Cards on their way back from the disc to the deck. Each tap starts its
  /// own flight, so spamming the disc never waits on the last one.
  final _flights = <_Flight>[];

  /// Where a flight starts and ends, measured in the Stack's own space.
  final _stackKey = GlobalKey();
  final _deckKey = GlobalKey();
  final _discKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _deck = List.of(widget.items);
  }

  void _decided(Destination place, {required bool keep}) => setState(() {
    _index++;
    _done = _index >= _deck.length;
    if (keep) {
      ref.read(savedDestinationsProvider.notifier).save(place.id);
    } else {
      _skipped.add(place);
      _skipAdded = true;
    }
  });

  /// Tapping the disc, or flicking it up: the last skipped place flies back
  /// to the deck, leaving at the flick's own speed.
  void _bringBack(Offset velocity) {
    if (_skipped.isEmpty) return;
    final place = _skipped.removeLast();
    _skipAdded = false;
    final path = _flightPath();
    if (path == null || MediaQuery.disableAnimationsOf(context)) {
      setState(() => _insert(place));
      return;
    }
    setState(() => _flights.add((place, path.$1, path.$2, velocity)));
  }

  /// From the disc to the deck's front slot, both in the enclosing Stack's
  /// coordinates. Null before the first layout.
  (Rect, Rect)? _flightPath() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final from = _discKey.currentContext?.findRenderObject() as RenderBox?;
    final to = _deckKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || from == null || to == null) return null;
    if (!stack.hasSize || !from.hasSize || !to.hasSize) return null;
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    // The deck keeps [SwipeDeck.backOffset] under the front card for the one
    // behind it, so the slot is that much shorter than the deck's box.
    final slot = rectOf(to);
    return (
      rectOf(from),
      Rect.fromLTRB(
        slot.left,
        slot.top,
        slot.right,
        slot.bottom - SwipeDeck.backOffset,
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
  }

  void _startOver() => setState(() {
    _deck = List.of(widget.items);
    _index = 0;
    _skipped.clear();
    _done = false;
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final finished = _done || _index >= _deck.length;
    final front = finished ? null : _deck[_index];
    final next = !finished && _index + 1 < _deck.length
        ? _deck[_index + 1]
        : null;
    // The answers' row: the disc sits centred on it at its leading edge.
    const row = AppSize.playerButton;
    final rowBottom = bottomInset + AppSpace.x4;

    return Stack(
      key: _stackKey,
      children: [
        Positioned.fill(
          child: _Stage(front: front, next: next, rise: _controller.rise),
        ),
        Column(
          children: [
            const _Header(),
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
                    // The last card leaving gives way to the end note with a
                    // fade, not a cut.
                    child: FadeSwap(
                      id: finished,
                      child: finished
                          ? _DeckDone(onStartOver: _startOver)
                          : SwipeDeck(
                              cards: _deck.sublist(_index),
                              tileFor: _tileFor,
                              onDecided: _decided,
                              controller: _controller,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.x4),
            _Answers(front: front, next: next, controller: _controller),
            SizedBox(height: rowBottom),
          ],
        ),
        if (_skipped.isNotEmpty)
          Positioned(
            left: AppSpace.gutter,
            bottom: rowBottom + (row - _BringBack.size) / 2,
            child: _BringBack(
              place: _skipped.last,
              discKey: _discKey,
              animate: _skipAdded,
              onBringBack: _bringBack,
            ),
          ),
        for (final flight in _flights)
          _FlightCard(
            key: ValueKey(flight.$1.id),
            flight: flight,
            tile: _tileFor(flight.$1),
            onLanded: () => _land(flight),
          ),
      ],
    );
  }
}

/// The front card's photo behind the deck, the next card's over it at
/// [rise]. Layers are keyed by place, so the next one moves to the front
/// already shown: nothing rebuilds or cuts.
class _Stage extends StatelessWidget {
  const _Stage({required this.front, required this.next, required this.rise});

  final Destination? front;
  final Destination? next;
  final Animation<double> rise;

  /// How dark the stage sits under white type and the answers.
  static const _shade = 0.4;

  @override
  Widget build(BuildContext context) {
    final front = this.front;
    final next = this.next;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (front != null)
          _Backdrop(
            key: ValueKey(front.id),
            place: front,
            opacity: kAlwaysCompleteAnimation,
          ),
        if (next != null)
          _Backdrop(key: ValueKey(next.id), place: next, opacity: rise),
        ColoredBox(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: _shade),
        ),
      ],
    );
  }
}

/// One place on the stage: its photo decoded tiny and stretched (a blur with
/// no filter), or its kind's tone. Fades in once, when first mounted.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.place, required this.opacity, super.key});

  final Destination place;
  final Animation<double> opacity;

  /// The photo's decoded width, in pixels.
  static const _decodeWidth = 32;

  @override
  Widget build(BuildContext context) {
    final cover = place.coverImage;
    return FadeTransition(
      opacity: opacity,
      child: AppMotionBuilder(
        end: 1,
        from: 0,
        child: cover == null
            ? ColoredBox(color: _toneOf(context, place))
            : StorageImage(path: cover, decodeWidth: _decodeWidth),
        builder: (context, t, layer) =>
            Opacity(opacity: t.clamp(0.0, 1.0), child: layer),
      ),
    );
  }
}

/// Skip and Keep in the card's colour, blending to the next card's as it
/// rises; the side the card leans to grows. A tap throws the card.
class _Answers extends StatelessWidget {
  const _Answers({
    required this.front,
    required this.next,
    required this.controller,
  });

  final Destination? front;
  final Destination? next;
  final SwipeDeckController controller;

  @override
  Widget build(BuildContext context) {
    final front = this.front;
    final next = this.next;
    final from = front == null ? null : _toneOf(context, front);
    final to = next == null ? from : _toneOf(context, next);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Answer(
          icon: AppIcons.close,
          label: "Skip",
          side: -1,
          from: from,
          to: to,
          controller: controller,
          onTap: controller.skip,
        ),
        const SizedBox(width: AppSpace.x6),
        _Answer(
          icon: AppIcons.favoriteFilled,
          label: "Keep",
          side: 1,
          from: from,
          to: to,
          controller: controller,
          onTap: controller.keep,
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.icon,
    required this.label,
    required this.side,
    required this.from,
    required this.to,
    required this.controller,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Which way the card leans for this answer: -1 skip, 1 keep.
  final double side;

  /// The front card's tone and the next card's; null with no card left.
  final Color? from;
  final Color? to;
  final SwipeDeckController controller;
  final VoidCallback onTap;

  /// How much it grows as the card leans its way, shrinks as it leans the
  /// other, and dims then.
  static const _grow = 0.15;
  static const _shrink = 0.1;
  static const _dimBy = 0.4;

  @override
  Widget build(BuildContext context) {
    final from = this.from;
    final glyph = Theme.of(context).colorScheme.onSurface;
    final enabled = from != null;

    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          enabled: enabled,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            // A frame of the drag rescales and recolours; the glyph is
            // built once.
            child: AnimatedBuilder(
              animation: controller.lean,
              child: SizedBox.square(
                dimension: AppSize.playerButton,
                child: Icon(icon, color: glyph, size: AppSize.glyphLg),
              ),
              builder: (context, face) {
                final lean = controller.lean.value * side;
                final rise = controller.rise.value;
                final mine = lean > 0 ? rise : 0.0;
                final other = lean < 0 ? rise : 0.0;
                final fill = from == null
                    ? Colors.transparent
                    : Color.lerp(from, to ?? from, rise)!;
                return Transform.scale(
                  scale: 1 + _grow * mine - _shrink * other,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill.withValues(
                        alpha: fill.a * (1 - _dimBy * other),
                      ),
                      shape: const CircleBorder(),
                    ),
                    child: face,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A place in flight from the disc to the deck, and the speed it was
/// flicked at (zero for a tap).
typedef _Flight = (Destination, Rect, Rect, Offset);

/// One card flying back, on its own controller so it can start at the
/// flick's speed (a motion builder cannot be given a velocity). Lands on
/// `AppMotion.arrive`; corners go from the disc's round to the deck's as it
/// grows.
class _FlightCard extends StatefulWidget {
  const _FlightCard({
    required this.flight,
    required this.tile,
    required this.onLanded,
    super.key,
  });

  final _Flight flight;
  final Widget tile;
  final VoidCallback onLanded;

  @override
  State<_FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<_FlightCard>
    with SingleTickerProviderStateMixin {
  late final Rect _from = widget.flight.$2;
  late final Rect _to = widget.flight.$3;

  late final _rect = MotionController<Rect>(
    motion: AppMotion.arrive,
    vsync: this,
    converter: MotionConverter.rect,
    initialValue: _from,
  );

  @override
  void initState() {
    super.initState();
    final v = widget.flight.$4;
    // The whole card moves at the flick's speed: every edge shares it.
    _rect
        .animateTo(_to, withVelocity: Rect.fromLTRB(v.dx, v.dy, v.dx, v.dy))
        .then((_) {
          if (mounted) widget.onLanded();
        });
  }

  @override
  void dispose() {
    _rect.dispose();
    super.dispose();
  }

  /// Corners go from the disc's round to the deck's as the card grows, read
  /// off its own width so the two never drift apart.
  double _radiusAt(Rect rect) {
    final total = _to.width - _from.width;
    final t = total == 0
        ? 1.0
        : ((rect.width - _from.width) / total).clamp(0.0, 1.0);
    return lerpDouble(_BringBack.size / 2, AppRadii.lg, t)!;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _rect,
    child: widget.tile,
    builder: (context, tile) {
      final rect = _rect.value;
      return Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radiusAt(rect)),
            child: tile,
          ),
        ),
      );
    },
  );
}

/// The card: the photo (its kind's tone until there is one), and on its
/// scrim the town, the name and a two-line lede. Built once per place. A
/// tap opens the place, the photo growing into its page.
class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final place = destination;
    final cover = place.coverImage;
    const white = Colors.white;
    return Pressable(
      child: ClipRRect(
        borderRadius: AppRadii.lgAll,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ParentRadius(
              radius: AppRadii.lg,
              child: PhotoHero(
                tag: coverHeroTag(place.id, HeroSource.swipe),
                child: cover == null
                    ? ColoredBox(color: _toneOf(context, place))
                    : CoverImage(cover),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MediaScrim(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x4,
                  AppSpace.x12,
                  AppSpace.x4,
                  AppSpace.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.town,
                      style: AppTypography.labelMedium.copyWith(color: white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      place.name,
                      style: AppTypography.titleLarge.copyWith(color: white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpace.x1),
                    Text(
                      place.description,
                      style: AppTypography.bodyMedium.copyWith(color: white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => context.push(
                  Routes.destination(place.id, from: HeroSource.swipe),
                ),
              ),
            ),
            if (place.hasAR)
              const Positioned(
                top: AppSpace.x3,
                left: AppSpace.x3,
                child: LakbayanBadge.ar(),
              ),
          ],
        ),
      ),
    );
  }
}

/// The last skipped place as a photo disc at the answers' leading edge
/// (its kind's tone until there is a photo). Tap it, or flick it up, and it
/// flies back onto the deck. Symbol-only, so the tooltip and semantics say
/// what the tap does.
class _BringBack extends StatelessWidget {
  const _BringBack({
    required this.place,
    required this.discKey,
    required this.animate,
    required this.onBringBack,
  });

  final Destination place;

  /// On the disc itself, so the flight back can start from it.
  final GlobalKey discKey;
  final bool animate;
  final ValueChanged<Offset> onBringBack;

  static const size = AppSize.minTouchTarget;

  /// An upward flick faster than this pulls it back, in px/s.
  static const _pullSpeed = 400.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = place.coverImage;
    return Tooltip(
      message: "Bring back ${place.name}",
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: "Bring back ${place.name}",
        child: GestureDetector(
          onTap: () => onBringBack(Offset.zero),
          onVerticalDragEnd: (details) {
            final velocity = details.velocity.pixelsPerSecond;
            if (velocity.dy < -_pullSpeed) onBringBack(velocity);
          },
          behavior: HitTestBehavior.opaque,
          child: PopIn(
            key: ValueKey(place.id),
            animate: animate,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: scheme.onSurface,
                    width: AppStroke.regular,
                  ),
                ),
              ),
              child: ClipOval(
                child: SizedBox.square(
                  key: discKey,
                  dimension: size,
                  child: cover == null
                      ? ColoredBox(color: _toneOf(context, place))
                      : CoverImage(cover),
                ),
              ),
            ),
          ),
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
