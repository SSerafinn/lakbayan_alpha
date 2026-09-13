import "dart:math" show pi;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../../core/widgets/section_heading.dart";
import "../../../core/widgets/storage_image.dart";
import "../../explore/domain/home_tab.dart";
import "../domain/destination_providers.dart";
import "../domain/recently_viewed.dart";
import "category_strip.dart";
import "home_hero.dart";
import "places_list_screen.dart";
import "save_heart.dart";

/// Home (redesign 2a). **One job:** put a place in front of you that you
/// could go to today. **Emotion:** quiet anticipation, the night before a trip.
///
/// Top to bottom: the featured hero, edge to edge; the category strip; the
/// way into swipe mode, a fan of covers; Popular this week, two tiles;
/// Recently viewed; Pick a town. No greeting, no eyebrows. Search is the shell's circle pinned over
/// the hero (`HomeChromeLayer`), not a row here.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredDestinationsProvider);
    final category = ref.watch(homeCategoryProvider);

    final hero = featured.when(
      loading: () => const SizedBox(
        height: AppSize.heroHeight,
        child: ImagePlaceholder(borderRadius: BorderRadius.zero),
      ),
      error: (error, _) => _ErrorNote(error: error),
      data: (items) {
        final destination = items.firstOrNull;
        return destination == null
            ? const _NoHero()
            : HomeHero(destination: destination);
      },
    );

    return Scaffold(
      extendBody: true,
      body: ScrollEdge(
        bottom: ScrollEdge.homeBarHeight(context),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: hero),
            const SliverPadding(
              padding: EdgeInsets.only(top: AppSpace.section),
              sliver: SliverToBoxAdapter(child: CategoryStrip()),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.section,
                AppSpace.gutter,
                ScrollEdge.homeBarHeight(context) + AppSpace.section,
              ),
              sliver: SliverToBoxAdapter(
                child: category != null
                    ? _Matches(category: category)
                    : _Feed(featured: featured.value ?? const []),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing is featured yet: just the title.
class _NoHero extends StatelessWidget {
  const _NoHero();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
    child: Text("Explore", style: AppTypography.titleLarge),
  );
}

/// One grouped section of matches for the active category.
class _Matches extends ConsumerWidget {
  const _Matches({required this.category});

  final DestinationCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(homeResultsProvider);
    final loading = ref.watch(allDestinationsProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(category.label),
        const SizedBox(height: AppSpace.x3),
        if (results.isNotEmpty)
          PlaceRows(items: results)
        else if (!loading)
          const QuietNote("Nothing matches. Try another word or category."),
      ],
    );
  }
}

/// The full feed under the strip.
class _Feed extends StatelessWidget {
  const _Feed({required this.featured});

  final List<Destination> featured;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (featured.isNotEmpty) ...[
        _SwipeEntry(covers: featured),
        const SizedBox(height: AppSpace.section),
      ],
      const _Popular(),
      const _RecentlyViewed(),
      const SizedBox(height: AppSpace.section),
      const SectionHeading("Pick a town"),
      const SizedBox(height: AppSpace.x3),
      const _Towns(),
    ],
  );
}

/// The way into swipe mode: a fan of three covers, tilted the way the deck
/// is, so the row looks like the thing it opens. A tap opens it; so does a
/// sideways swipe, the gesture the screen behind it is built on.
class _SwipeEntry extends StatelessWidget {
  const _SwipeEntry({required this.covers});

  final List<Destination> covers;

  static const _fanHeight = 64.0;
  static const _fanWidth = 96.0;
  static const _cardWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void open() => context.push(Routes.swipe);
    final fanned = covers.take(3).toList();

    return GestureDetector(
      onHorizontalDragEnd: (_) => open(),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x3,
              AppSpace.x3,
              AppSpace.rowPad,
              AppSpace.x3,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _fanWidth,
                  height: _fanHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final (index, place) in fanned.indexed)
                        Positioned(
                          left: index * (_fanWidth - _cardWidth) / 2,
                          top: 0,
                          bottom: 0,
                          width: _cardWidth,
                          child: Transform.rotate(
                            angle: (index - 1) * 8 * pi / 180,
                            child: ClipRRect(
                              borderRadius: AppRadii.xsAll,
                              child: CoverImage(place.coverImage),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
                const SizedBox(width: AppSpace.x2),
                SizedBox(
                  width: AppSize.minTouchTarget,
                  height: AppSize.minTouchTarget,
                  child: Icon(
                    AppIcons.chevron,
                    size: 18,
                    color: scheme.onSurfaceVariant,
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

/// Two tiles side by side. The heading is the way to the rest.
class _Popular extends ConsumerWidget {
  const _Popular();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularDestinationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          "Popular this week",
          onSeeAll: () => context.push(Routes.popular),
        ),
        const SizedBox(height: AppSpace.x2),
        popular.when(
          loading: () => const Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ImagePlaceholder(borderRadius: AppRadii.tileAll),
                ),
              ),
              SizedBox(width: AppSpace.x3),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ImagePlaceholder(borderRadius: AppRadii.tileAll),
                ),
              ),
            ],
          ),
          error: (error, _) => _ErrorNote(error: error),
          data: (items) => items.isEmpty
              ? const QuietNote("Nothing here yet.")
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, place) in items.take(2).indexed) ...[
                      if (index > 0) const SizedBox(width: AppSpace.x3),
                      Expanded(child: _PopularTile(place)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PopularTile extends StatelessWidget {
  const _PopularTile(this.place);

  final Destination place;

  @override
  Widget build(BuildContext context) => MediaTile(
    media: Hero(tag: place.popularHeroTag, child: CoverImage(place.coverImage)),
    aspectRatio: 4 / 3,
    title: place.name,
    subtitle: place.town,
    badge: place.hasAR ? const LakbayanBadge.ar() : null,
    trailing: SaveHeart(place.id, style: SaveHeartStyle.tile),
    onTap: () => context.push(Routes.destination(place.id)),
  );
}

/// Small square thumbnails, name and town under each. A history, so the
/// section simply is not there until there is one.
class _RecentlyViewed extends ConsumerWidget {
  const _RecentlyViewed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedDestinationsProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    final title = AppTypography.titleSmall;
    final line = AppTypography.secondLine;
    final captionHeight = MediaQuery.textScalerOf(context).scale(
      title.fontSize! * title.height! +
          line.fontSize! * line.height! +
          AppSpace.x2,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading("Recently viewed"),
          const SizedBox(height: AppSpace.x2),
          SizedBox(
            height: AppSize.thumbnail + captionHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x3),
              itemBuilder: (context, index) {
                final place = recent[index];
                return SizedBox(
                  width: AppSize.thumbnail,
                  child: MediaTile(
                    media: CoverImage(place.coverImage),
                    aspectRatio: 1,
                    title: place.name,
                    subtitle: place.town,
                    radius: AppRadii.sm,
                    onTap: () => context.push(Routes.destination(place.id)),
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

/// One row per municipality. The second line names the places, so the row
/// says what is there rather than how many.
class _Towns extends ConsumerWidget {
  const _Towns();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final towns = ref.watch(townsProvider);
    final loading = ref.watch(allDestinationsProvider).isLoading;

    if (towns.isEmpty) {
      return loading
          ? const SizedBox.shrink()
          : const QuietNote("No towns published yet.");
    }

    return GroupedSection(
      children: [
        for (final town in towns)
          GroupedRow(
            title: town.name,
            subtitle: town.places.take(3).map((p) => p.name).join(", "),
            leading: CoverImage(town.cover),
            onTap: () {
              // Browse lives in the Map tab, so a town is a tab switch with
              // its name pre-filled.
              ref.read(browseQueryProvider.notifier).update(town.name);
              ref.read(browseCategoryProvider.notifier).select(null);
              ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
            },
          ),
      ],
    );
  }
}

/// Surfaces the actual error rather than a generic message: a permission-denied
/// here almost always means a query lost its `status == published` filter, and
/// hiding that costs an hour.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.gutter),
      child: Text(
        "Couldn't load destinations.\n$error",
        style: AppTypography.bodyMedium.copyWith(color: scheme.error),
      ),
    );
  }
}
