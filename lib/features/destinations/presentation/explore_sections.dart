import "dart:async";
import "dart:math" show pi, sin;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:motor/motor.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/guide.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../guides/domain/guide_providers.dart";
import "../../itineraries/domain/itinerary_providers.dart";
import "../../itineraries/presentation/tour_tile.dart";
import "../domain/destination_providers.dart";
import "save_heart.dart";

// Explore's feed under the featured cards, one widget per section, in the
// order the screen shows them (see `ExploreScreen`). Every photo carries its
// caption on its own scrim, so no section spends a line of white under a
// picture.

/// Popular as a bento: the most visited place a tall tile, the next two
/// stacked beside it, one block of photos to read across (doc 01: give the
/// top item real size). See All is the way to the rest.
class PopularSection extends ConsumerWidget {
  const PopularSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularDestinationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading("Popular", onSeeAll: () => context.push(Routes.popular)),
        popular.whenLocalFirst(
          loading: () => const AspectRatio(
            aspectRatio: 1 / _Bento.heightShare,
            child: ImagePlaceholder(borderRadius: AppRadii.tileAll),
          ),
          // Popular's own query. The featured cards above say when theirs
          // fails; the rails below hide on theirs.
          error: (error, _) => QuietNote(
            errorCopy("Couldn't load destinations.", error),
            onRetry: () => ref.invalidate(popularDestinationsProvider),
          ),
          data: (items) => items.isEmpty
              ? const QuietNote("Nothing here yet.")
              : _Bento(items: items.take(3).toList()),
        ),
      ],
    );
  }
}

class _Bento extends StatelessWidget {
  const _Bento({required this.items});

  final List<Destination> items;

  /// The block's height as a share of its width.
  static const heightShare = 0.62;
  static const _bigShare = 0.58;
  static const _gap = AppSpace.x2;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = width * heightShare;
      final rest = items.skip(1).toList();
      final bigWidth = rest.isEmpty ? width : (width - _gap) * _bigShare;
      final sideWidth = width - _gap - bigWidth;
      final sideHeight = rest.length < 2 ? height : (height - _gap) / 2;
      return SizedBox(
        height: height,
        child: Row(
          children: [
            _Tile(place: items.first, width: bigWidth, height: height),
            if (rest.isNotEmpty) ...[
              const SizedBox(width: _gap),
              Column(
                children: [
                  for (final (index, place) in rest.indexed) ...[
                    if (index > 0) const SizedBox(height: _gap),
                    _Tile(place: place, width: sideWidth, height: sideHeight),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.place, required this.width, required this.height});

  final Destination place;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: MediaTile(
      media: PhotoHero(
        tag: coverHeroTag(place.id, HeroSource.popular),
        child: CoverImage(place.coverImage),
      ),
      aspectRatio: width / height,
      overlay: true,
      dense: true,
      title: place.name,
      subtitle: place.town,
      pill: place.hasAR ? const PhotoPill.scan() : null,
      trailing: SaveHeart(place.id, style: SaveHeartStyle.tile),
      onTap: () =>
          context.push(Routes.destination(place.id, from: HeroSource.popular)),
    ),
  );
}

/// The province's own tours, a whole day already planned, as posters running
/// to the screen edges. Not there until there is one.
class ReadyMadeDays extends ConsumerWidget {
  const ReadyMadeDays({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike: a rail of
    // extras, from the tours, so a failure there leaves nothing missing
    // that the screen needs.
    final tours = ref.watch(tourRailProvider).value ?? const [];
    if (tours.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading("Day Tours"),
          ),
          const SizedBox(height: AppSpace.near),
          TourRail(tours: tours),
        ],
      ),
    );
  }
}

/// The people who know the place (`guides`, from the CMS): the app
/// complements local guides, and this is where it hands you to one. Each is
/// a white card, their initial, the name with the seal when the province
/// accredits them, and the town; a tap calls or emails them. Signed-in
/// only, as the rules require, so the section is not there for a guest.
class LocalGuides extends ConsumerWidget {
  const LocalGuides({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike, as Day Tours
    // are: extras, from the guides.
    final guides = ref.watch(guidesProvider).value ?? const [];
    if (guides.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final lines =
        scaler.lineHeightOf(AppTypography.titleSmall) +
        scaler.lineHeightOf(AppTypography.secondLine);
    final content = lines > AppSize.rowMediaDense
        ? lines
        : AppSize.rowMediaDense;
    final height = (content + 2 * AppSpace.x3).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading("Guides"),
          ),
          const SizedBox(height: AppSpace.near),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              itemCount: guides.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
              itemBuilder: (context, index) => SizedBox(
                width: AppSize.guideCard,
                child: _GuideCard(guide: guides[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends ConsumerWidget {
  const _GuideCard({required this.guide});

  final Guide guide;

  /// Call or email them, and say so when the phone cannot.
  ///
  /// The card's second line is what they lead, not how to reach them, so a
  /// failed tap has to hand the contact over itself. A tablet with no dialer,
  /// or a phone with no mail app, is exactly where this used to leave
  /// somebody with a card that did nothing and no number to copy.
  Future<void> _reach(BuildContext context, WidgetRef ref, Uri uri) async {
    // Resolved before the await: a widget like this has no `mounted` to check
    // afterwards.
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(contactLauncherProvider)(uri);
    } catch (_) {
      // No handler for the scheme throws on some platforms rather than
      // answering false. Either way the answer is the same message.
    }
    if (opened) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "No app here can open that. Reach ${guide.name} at ${guide.contact}.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final uri = contactUri(guide.contact);
    final name = guide.name.trim();

    return Pressable(
      enabled: uri != null,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uri == null
              ? null
              : () => unawaited(_reach(context, ref, uri)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x3),
            child: Row(
              children: [
                // Their initial on an emerald wash, as on Profile.
                ExcludeSemantics(
                  child: Container(
                    width: AppSize.rowMediaDense,
                    height: AppSize.rowMediaDense,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: brand.tint,
                      shape: const CircleBorder(),
                    ),
                    child: Text(
                      name.isEmpty ? "" : name.characters.first.toUpperCase(),
                      style: AppTypography.titleMedium.copyWith(
                        color: brand.textOnLightGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTypography.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (guide.verified) ...[
                            const SizedBox(width: AppSpace.x1),
                            Icon(
                              AppIcons.verified,
                              size: AppSize.glyphSm,
                              color: brand.textOnLightGreen,
                              semanticLabel: "Verified",
                            ),
                          ],
                        ],
                      ),
                      Text(
                        guide.town,
                        style: AppTypography.secondLine.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// For the undecided: a fan of three covers, tilted the way the deck is, and
/// the mode's name, on a mint card, so the row looks like the thing it
/// opens. A tap opens Keep or Skip; so does a sideways swipe, the gesture
/// the screen behind it is built on. The fan deals itself out once as the
/// screen opens, on `AppMotion.arrive`.
class SwipeEntry extends StatelessWidget {
  const SwipeEntry({required this.covers, super.key});

  final List<Destination> covers;

  @override
  Widget build(BuildContext context) {
    void open() => context.push(Routes.swipe);

    return Pressable(
      child: GestureDetector(
        onHorizontalDragEnd: (_) => open(),
        child: Material(
          // A brand moment, so a pastel, ink on it (D-19).
          color: context.lakbayan.mint,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.x3,
                vertical: AppSpace.x2,
              ),
              child: Row(
                children: [
                  _Fan(covers: covers.take(3).toList()),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Text(
                      "Keep or Skip",
                      style: AppTypography.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fan extends StatelessWidget {
  const _Fan({required this.covers});

  final List<Destination> covers;

  static const _height = 48.0;
  static const _width = 80.0;
  static const _cardWidth = 36.0;

  /// Eight degrees between neighbours, the deck's own tilt at rest.
  static const _tilt = 8 * pi / 180;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    // Covers are built once and do not depend on the spread.
    final cards = [
      for (final place in covers)
        ClipRRect(
          borderRadius: AppRadii.xsAll,
          child: CoverImage(place.coverImage),
        ),
    ];
    return SizedBox(
      width: _width,
      height: _height,
      child: SingleMotionBuilder(
        motion: AppMotion.arrive,
        from: still ? null : 0,
        value: 1,
        builder: (context, spread, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (index, card) in cards.indexed)
              Positioned(
                left:
                    (_width - _cardWidth) / 2 +
                    (index - 1) * (_width - _cardWidth) / 2 * spread,
                top: 0,
                bottom: 0,
                width: _cardWidth,
                child: Transform.rotate(
                  angle: (index - 1) * _tilt * spread,
                  child: card,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Every town hanging from one river on its own cord: a framed photo with
/// the name on it, each at a small fixed tilt. A still picture, drawn once,
/// nothing swinging (D-19, PERFORMANCE). A town opens its page, the photo
/// zooming.
class TownRail extends ConsumerStatefulWidget {
  const TownRail({super.key});

  @override
  ConsumerState<TownRail> createState() => _TownRailState();
}

class _TownRailState extends ConsumerState<TownRail> {
  /// Read by the river's painter, so the river runs with the towns.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hidden while loading, when empty and on an error alike. Its places
    // are every place, a listener apart from Popular's: if only that read
    // fails, the rail goes without a word, and Popular says nothing of it.
    final towns = ref.watch(townsProvider);
    if (towns.isEmpty) return const SizedBox.shrink();
    final brand = context.lakbayan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: SectionHeading("Towns"),
        ),
        SizedBox(
          height: _Hanging.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _River(scroll: _scroll, color: brand.river),
                  ),
                ),
              ),
              ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter,
                ),
                itemExtent: _Hanging.extent,
                itemCount: towns.length,
                itemBuilder: (context, index) =>
                    _Hanging(town: towns[index], index: index),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The river's height at [x] along the rail's content: one gentle wave,
/// shared by the painter and by each town's dot, so the dots sit on it.
double _riverAt(double x) =>
    _Hanging.riverY + _Hanging.wave * sin(x * 2 * pi / _Hanging.wavelength);

class _River extends CustomPainter {
  _River({required this.scroll, required this.color}) : super(repaint: scroll);

  final ScrollController scroll;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final path = Path()..moveTo(0, _riverAt(offset));
    for (var x = 0.0; x <= size.width; x += AppSpace.x2) {
      path.lineTo(x, _riverAt(x + offset));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _Hanging.river
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_River old) => old.color != color || old.scroll != scroll;
}

/// One town on its cord: a blue dot on the river, the cord, the clip, then
/// the photo in its white frame, turned a little on the clip.
class _Hanging extends StatelessWidget {
  const _Hanging({required this.town, required this.index});

  final Town town;
  final int index;

  /// A rail tile, 5:6 like the deck's cards.
  static const width = AppSize.tourTile;
  static const _photo = width * 6 / 5;
  static const extent = width + AppSpace.x4;

  /// The river: where it runs, how far it bends, one bend per town and a
  /// quarter.
  static const riverY = AppSpace.x4;
  static const wave = AppSpace.near;
  static const wavelength = extent * 1.25;
  static const river = AppStroke.mapRoute;

  static const _dot = AppSpace.x3;
  static const _clip = Size(AppSpace.x4, AppSpace.x2);

  /// The white frame round each photo, like a print's.
  static const _frame = AppSpace.x1;

  /// Each town's own cord and tilt in degrees, in turn, so the row reads
  /// hung by hand.
  static const _cords = [
    AppSpace.x3,
    AppSpace.x6,
    AppSpace.x2,
    AppSpace.x4,
    AppSpace.x5,
  ];
  static const _tilts = [-3.0, 2.5, -1.5, 3.0, -2.0];

  /// The longest cord, its clip and photo, and room for the tilt.
  static const height =
      riverY + wave + AppSpace.x6 + AppSpace.x2 + _photo + AppSpace.x4;

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    final card = Theme.of(context).colorScheme.surfaceContainerLowest;
    final anchor = _riverAt(AppSpace.gutter + index * extent + width / 2);
    final cord = _cords[index % _cords.length];
    final tilt = _tilts[index % _tilts.length] * pi / 180;
    final inner = concentricRadius(
      parentRadius: AppRadii.md,
      padding: _frame,
      fallback: AppRadii.sm,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: width / 2 - AppStroke.regular / 2,
          top: anchor,
          width: AppStroke.regular,
          height: cord,
          child: ColoredBox(color: brand.cord),
        ),
        Positioned(
          left: (width - _dot) / 2,
          top: anchor - _dot / 2,
          width: _dot,
          height: _dot,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: brand.spatial,
              shape: const CircleBorder(),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: anchor + cord,
          width: width,
          child: Transform.rotate(
            angle: tilt,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _clip.width,
                  height: _clip.height,
                  decoration: BoxDecoration(
                    color: brand.cord,
                    borderRadius: AppRadii.xsAll,
                  ),
                ),
                Container(
                  height: _photo,
                  padding: const EdgeInsets.all(_frame),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: AppRadii.mdAll,
                  ),
                  child: TownPhoto(
                    town: town,
                    from: HeroSource.towns,
                    radius: inner,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A town as its photo with its name on it, in the headings' face; a tap
/// opens the town's page, the photo zooming. Explore's hanging towns and
/// search's towns.
class TownPhoto extends StatelessWidget {
  const TownPhoto({
    required this.town,
    required this.from,
    this.radius = AppRadii.tile,
    this.onOpen,
    super.key,
  });

  final Town town;
  final HeroSource from;
  final double radius;

  /// Called just before the page opens: search folds away.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Pressable(
    child: GestureDetector(
      onTap: () {
        onOpen?.call();
        context.push(Routes.town(town.name, from: from));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ParentRadius(
              radius: radius,
              child: PhotoHero(
                tag: townHeroTag(town.name, from),
                child: CoverImage(town.cover),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MediaScrim(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x2,
                  AppSpace.x8,
                  AppSpace.x2,
                  AppSpace.x2,
                ),
                child: Text(
                  town.name,
                  style: AppTypography.titleMedium.copyWith(
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
    ),
  );
}

/// Places to eat, a rail of photos with the name on each: food is part of
/// the trip, so it has its own row rather than hiding in a filter.
class WhereToEat extends ConsumerWidget {
  const WhereToEat({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike, as the towns
    // are, and from the same list of every place.
    final food = ref.watch(foodPlacesProvider);
    if (food.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading(
              "Food",
              onSeeAll: () => ref
                  .read(homeCategoryProvider.notifier)
                  .toggle(DestinationCategory.food),
            ),
          ),
          SizedBox(
            height: AppSize.railTile * 5 / 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              itemCount: food.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
              itemBuilder: (context, index) {
                final place = food[index];
                return SizedBox(
                  width: AppSize.railTile,
                  child: MediaTile(
                    media: PhotoHero(
                      tag: coverHeroTag(place.id, HeroSource.whereToEat),
                      child: CoverImage(place.coverImage),
                    ),
                    aspectRatio: 4 / 5,
                    overlay: true,
                    dense: true,
                    title: place.name,
                    subtitle: place.town,
                    trailing: SaveHeart(place.id, style: SaveHeartStyle.tile),
                    onTap: () => context.push(
                      Routes.destination(place.id, from: HeroSource.whereToEat),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
