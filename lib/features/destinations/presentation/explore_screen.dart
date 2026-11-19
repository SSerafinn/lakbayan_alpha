import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/kind_rail.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../explore/domain/home_tab.dart";
import "../../profile/presentation/user_avatar.dart";
import "../domain/destination_providers.dart";
import "../domain/place_kind.dart";
import "explore_sections.dart";
import "featured_deck.dart";
import "places_list_screen.dart";
import "province_notice.dart";

/// The Explore tab. **Job:** pick a place by looking. **Emotion:** the
/// province spread out in photos.
///
/// The title, the province's notice while it has one ([ProvinceNotice]),
/// the kinds as a glyph rail, then the featured deck and the feed in the
/// order a visitor decides: Towns, Popular Destinations, Food, Scan
/// Exhibits, Day Tours, Guides, Keep or Skip for the undecided, and last
/// Recently Viewed (once there is one). Every section that has nothing
/// steps aside. A kind
/// chosen puts its places under the pills in place of the deck and feed.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredDestinationsProvider);
    final category = ref.watch(homeCategoryProvider);
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    // One scroll view, slivers all the way down: lazy list of sections,
    // inner lists build only visible rows.
    return EntranceScope(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.gutter,
              MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
              AppSpace.gutter,
              AppSpace.x3,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text("Explore", style: AppTypography.display),
                    ),
                  ),
                  const _Me(),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: ProvinceNotice()),
          const SliverToBoxAdapter(child: Entrance(child: _Kinds())),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.x6)),
          // A new scope per choice, so the section under the pills arrives
          // in order each time it changes rather than cutting.
          EntranceScope(
            key: ValueKey(category),
            child: category != null
                ? SliverPadding(
                    padding: gutter,
                    sliver: _Matches(category: category),
                  )
                : _Feed(featured: featured),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: FloatingTabBar.clearance(context) + AppSpace.section,
            ),
          ),
        ],
      ),
    );
  }
}

/// Me, at the title's trailing end: my photo or initial, the way to what is
/// mine. It switches to the Profile tab, so the bar's pill moves there too;
/// it is the same place, not a second copy of it.
class _Me extends ConsumerWidget {
  const _Me();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Tooltip(
    message: "Your profile",
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: "Your profile",
      excludeSemantics: true,
      child: Pressable(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref
              .read(selectedHomeTabProvider.notifier)
              .select(HomeTab.profile),
          child: const SizedBox.square(
            dimension: AppSize.minTouchTarget,
            child: Center(child: UserAvatar(size: AppSize.rowMediaDense)),
          ),
        ),
      ),
    ),
  );
}

/// The kinds of place as glyphs over words, food among them. Tapping the
/// chosen kind again clears it.
class _Kinds extends ConsumerWidget {
  const _Kinds();

  /// The six in Explore's order, food among the first.
  static const _builtIns = [
    PlaceKind.builtIn(DestinationCategory.nature),
    PlaceKind.builtIn(DestinationCategory.food),
    PlaceKind.builtIn(DestinationCategory.church),
    PlaceKind.builtIn(DestinationCategory.heritage),
    PlaceKind.builtIn(DestinationCategory.museum),
    PlaceKind.builtIn(DestinationCategory.landmark),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(homeCategoryProvider);
    final kinds = [
      ..._builtIns,
      // Then the province's own, in the order they were added.
      for (final c in ref.watch(addedCategoriesProvider)) PlaceKind.added(c),
    ];
    return KindRail(
      items: [
        for (final kind in kinds)
          KindRailItem(
            label: kind.label,
            glyph: kind.glyph(),
            selectedGlyph: kind.glyph(filled: true),
            selected: chosen == kind.key,
            onTap: () =>
                ref.read(homeCategoryProvider.notifier).toggle(kind.key),
          ),
      ],
    );
  }
}

/// The matches for the chosen kind, as a sliver: the heading, then rows
/// built lazily.
class _Matches extends ConsumerWidget {
  const _Matches({required this.category});

  /// A [PlaceKind.key].
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(homeResultsProvider);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Entrance(
            order: 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.near),
              child: SectionHeading(
                ref.watch(placeKindProvider(category)).label,
              ),
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

/// The deck and everything under it, each a beat after the one before, as
/// one lazy list: a section is built only as it nears the screen, and each
/// sits behind its own repaint boundary.
class _Feed extends ConsumerWidget {
  const _Feed({required this.featured});

  final AsyncValue<List<Destination>> featured;

  static const _gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final covers = featured.value ?? const <Destination>[];
    return SliverList.list(
      children: [
        Padding(
          padding: _gutter,
          child: Entrance(
            order: 1,
            child: featured.whenLocalFirst(
              loading: () => const _DeckPlaceholder(),
              error: (error, _) => QuietNote(
                errorCopy("Couldn't load destinations.", error),
                onRetry: () => ref.invalidate(featuredDestinationsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : FeaturedDeck(places: items),
            ),
          ),
        ),
        // Each of these brings its own gap, so an empty one leaves none.
        const Entrance(order: 2, child: TownRail()),
        const Entrance(order: 3, child: PopularSection()),
        const Entrance(order: 4, child: WhereToEat()),
        const Entrance(order: 5, child: ScanExhibits()),
        const Entrance(order: 6, child: ReadyMadeDays()),
        const Entrance(order: 7, child: LocalGuides()),
        if (covers.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.section,
              AppSpace.gutter,
              0,
            ),
            child: Entrance(order: 8, child: SwipeEntry()),
          ),
        // Last: a way back to what you opened, not a pitch, so it never
        // pushes the province's own places down.
        const Entrance(order: 9, child: RecentlyViewed()),
      ],
    );
  }
}

class _DeckPlaceholder extends StatelessWidget {
  const _DeckPlaceholder();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: const EdgeInsets.only(right: FeaturedDeck.peek),
      child: SizedBox(
        height: FeaturedDeck.heightOf(box.maxWidth),
        child: const ImagePlaceholder(borderRadius: AppRadii.lgAll),
      ),
    ),
  );
}
