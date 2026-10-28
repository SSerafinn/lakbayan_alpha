import "dart:async";
import "dart:math" show pi;

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
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../explore/domain/home_tab.dart";
import "../../guides/domain/guide_providers.dart";
import "../../itineraries/domain/itinerary_providers.dart";
import "../../itineraries/presentation/tour_tile.dart";
import "../domain/destination_providers.dart";
import "save_heart.dart";

// Explore's feed under the featured cards, one widget per section, in the
// order the screen shows them (see `ExploreScreen`). Every photo carries its
// caption on its own scrim, so no section spends a line of white under a
// picture.

/// Popular this week as a bento: the most visited place a tall tile, the
/// next two stacked beside it, one block of photos with no gaps to read
/// across (doc 01: give the top item real size). The heading is the way to
/// the rest.
class PopularSection extends ConsumerWidget {
  const PopularSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularDestinationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          "Popular this week",
          onSeeAll: () => context.push(Routes.popular),
        ),
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
            child: SectionHeading("Ready-made days"),
          ),
          const SizedBox(height: AppSpace.x2),
          TourRail(tours: tours),
        ],
      ),
    );
  }
}

/// The people who know the place (`guides`, from the CMS): the app
/// complements local guides, and this is where it hands you to one. Each is
/// a grey card, the name, the town and what they lead, VERIFIED
/// when the province accredits them; a tap calls or emails them. Signed-in
/// only, as the rules require, so the section is not there for a guest.
class LocalGuides extends ConsumerWidget {
  const LocalGuides({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike, as Ready-made
    // days are: extras, from the guides.
    final guides = ref.watch(guidesProvider).value ?? const [];
    if (guides.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    // The first line holds the name and the VERIFIED badge side by side, so
    // it is whichever of the two is taller.
    final title = scaler.lineHeightOf(AppTypography.titleSmall);
    final first = title > AppSize.badge ? title : AppSize.badge;
    final lines = first + 2 * scaler.lineHeightOf(AppTypography.secondLine);
    final height = (lines + 2 * AppSpace.x3).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading("Local guides"),
          ),
          const SizedBox(height: AppSpace.x2),
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
    final uri = contactUri(guide.contact);
    final leads = guide.specialties.isEmpty
        ? guide.contact
        : "Leads ${guide.specialties.join(", ")}";
    final second = AppTypography.secondLine.copyWith(
      color: scheme.onSurfaceVariant,
    );

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        guide.name,
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (guide.verified)
                      const LakbayanBadge("Verified", kind: BadgeKind.neutral),
                  ],
                ),
                Text(guide.town, style: second, maxLines: 1),
                Text(
                  leads,
                  style: second,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// For the undecided: a fan of three covers, tilted the way the deck is, so
/// the row looks like the thing it opens. A tap opens swipe mode; so does a
/// sideways swipe, the gesture the screen behind it is built on. The fan
/// deals itself out once as the screen opens, on `AppMotion.arrive`.
class SwipeEntry extends StatelessWidget {
  const SwipeEntry({required this.covers, super.key});

  final List<Destination> covers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void open() => context.push(Routes.swipe);

    return Pressable(
      child: GestureDetector(
        onHorizontalDragEnd: (_) => open(),
        child: Material(
          color: scheme.surfaceContainerLowest,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.x3,
                AppSpace.x2,
                AppSpace.x1,
                AppSpace.x2,
              ),
              child: Row(
                children: [
                  _Fan(covers: covers.take(3).toList()),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Not sure where to go?",
                          style: AppTypography.titleSmall,
                        ),
                        Text(
                          "Flip through places one at a time",
                          style: AppTypography.secondLine.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.chevron,
                    size: AppSize.glyphMd,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpace.x2),
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
                width: AppSize.guideCard,
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

/// Every town as a wide photo card, the name and the places in it on the
/// photo: a row of destinations to pick from, not a directory to read. A
/// town is a tab switch to the map with its name as the filter.
class TownRail extends ConsumerWidget {
  const TownRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike. Its places
    // are every place, a listener apart from Popular's: if only that read
    // fails, the rail goes without a word, and Popular says nothing of it.
    final towns = ref.watch(townsProvider);
    if (towns.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: SectionHeading("Towns"),
        ),
        const SizedBox(height: AppSpace.x2),
        SizedBox(
          height: AppSize.townCard * 10 / 16,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            itemCount: towns.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
            itemBuilder: (context, index) {
              final town = towns[index];
              return SizedBox(
                width: AppSize.townCard,
                child: MediaTile(
                  media: CoverImage(town.cover),
                  aspectRatio: 16 / 10,
                  overlay: true,
                  dense: true,
                  title: town.name,
                  subtitle: town.placesLine,
                  onTap: () {
                    ref.read(browseQueryProvider.notifier).update(town.name);
                    ref.read(browseCategoryProvider.notifier).select(null);
                    ref
                        .read(selectedHomeTabProvider.notifier)
                        .select(HomeTab.map);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
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
              "Where to eat",
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
