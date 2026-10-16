import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/controls/filter_chip_row.dart";
import "../../../core/widgets/motion/motion.dart";
import "../domain/destination_providers.dart";
import "explore_sections.dart";
import "featured_carousel.dart";
import "places_list_screen.dart";
import "province_notice.dart";

/// The Explore tab. Sections ordered by how a visitor decides:
/// Featured → Kinds → Towns → Popular → Where to eat → Tours → Guides.
/// Above them all, only while the province has one, its notice
/// ([ProvinceNotice]).
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredDestinationsProvider);
    final category = ref.watch(homeCategoryProvider);
    final barHeight = FloatingTabBar.clearance(context);
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);
    const gap = SliverToBoxAdapter(child: SizedBox(height: AppSpace.section));

    // One scroll view, slivers all the way down: lazy list of sections,
    // inner lists build only visible rows.
    return EntranceScope(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
            ),
          ),
          const SliverToBoxAdapter(child: ProvinceNotice()),
          SliverToBoxAdapter(
            child: Entrance(
              child: featured.whenLocalFirst(
                loading: () => const _FeaturedPlaceholder(),
                error: (error, _) => Padding(
                  padding: gutter,
                  child: QuietNote(
                    errorCopy("Couldn't load destinations.", error),
                    onRetry: () => ref.invalidate(featuredDestinationsProvider),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : FeaturedCarousel(places: items),
              ),
            ),
          ),
          gap,
          const SliverToBoxAdapter(child: Entrance(order: 1, child: _Kinds())),
          gap,
          // A new scope per choice, so the section under the chips arrives
          // in order each time it changes rather than cutting.
          EntranceScope(
            key: ValueKey(category),
            child: category != null
                ? SliverPadding(
                    padding: gutter,
                    sliver: _Matches(category: category),
                  )
                : _Feed(featured: featured.value ?? const []),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: barHeight + AppSpace.section),
          ),
        ],
      ),
    );
  }
}

class _FeaturedPlaceholder extends StatelessWidget {
  const _FeaturedPlaceholder();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
    child: SizedBox(
      height: AppSize.featuredCard,
      child: ImagePlaceholder(borderRadius: AppRadii.lgAll),
    ),
  );
}

/// The kinds of place, the same single-select chips as the Map's, food
/// among them. Tapping the chosen kind again clears it.
class _Kinds extends ConsumerWidget {
  const _Kinds();

  static const _kinds = [
    DestinationCategory.nature,
    DestinationCategory.food,
    DestinationCategory.church,
    DestinationCategory.heritage,
    DestinationCategory.museum,
    DestinationCategory.landmark,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(homeCategoryProvider);
    return FilterChipRow(
      items: [
        for (final kind in _kinds)
          FilterChipItem(
            label: kind.label,
            selected: chosen == kind,
            onTap: () => ref.read(homeCategoryProvider.notifier).toggle(kind),
          ),
      ],
    );
  }
}

/// The matches for the chosen kind, as a sliver: the heading, then rows
/// built lazily.
class _Matches extends ConsumerWidget {
  const _Matches({required this.category});

  final DestinationCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(homeResultsProvider);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Entrance(
            order: 2,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.x2),
              child: SectionHeading(category.label),
            ),
          ),
        ),
        results.whenLocalFirst(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.x6),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: QuietNote(
              errorCopy("Couldn't load places.", error),
              onRetry: () => ref.invalidate(allDestinationsProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(
                  child: QuietNote("Nothing matches. Try another kind."),
                )
              : SliverPlaceRows(items: items, from: HeroSource.list),
        ),
      ],
    );
  }
}

/// Everything under the chips, each a beat after the one before, as one
/// lazy list: a section is built only as it nears the screen, and each sits
/// behind its own repaint boundary.
class _Feed extends StatelessWidget {
  const _Feed({required this.featured});

  final List<Destination> featured;

  static const _gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);
  static const _gap = SizedBox(height: AppSpace.section);

  @override
  Widget build(BuildContext context) => SliverList.list(
    children: [
      const Entrance(order: 2, child: TownRail()),
      _gap,
      const Padding(
        padding: _gutter,
        child: Entrance(order: 3, child: PopularSection()),
      ),
      // Each of these brings its own gap, so an empty one leaves none.
      const Entrance(order: 4, child: WhereToEat()),
      const Entrance(order: 5, child: ReadyMadeDays()),
      const Entrance(order: 6, child: LocalGuides()),
      if (featured.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.section,
            AppSpace.gutter,
            0,
          ),
          child: Entrance(order: 7, child: SwipeEntry(covers: featured)),
        ),
    ],
  );
}
