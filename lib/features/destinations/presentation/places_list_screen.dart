import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/chrome/page_title.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../domain/destination_providers.dart";
import "../domain/saved_destinations.dart";
import "save_heart.dart";

/// Which list this screen shows.
enum PlacesList { popular, saved }

/// A plain list of places under a large title: Explore's Popular and
/// Profile's Saved, each from its See All. One grouped card, the whole row
/// opens the place, the heart trailing.
class PlacesListScreen extends ConsumerWidget {
  const PlacesListScreen({required this.list, super.key});

  final PlacesList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String title, AsyncValue<List<Destination>> places) = switch (list) {
      PlacesList.popular => (
        "Popular Destinations",
        ref.watch(popularDestinationsProvider),
      ),
      PlacesList.saved => ("Saved", ref.watch(savedPlacesProvider)),
    };

    return EntranceScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x2,
                  AppSpace.gutter,
                  AppSpace.section,
                ),
                sliver: SliverToBoxAdapter(child: PageTitle(title)),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  MediaQuery.viewPaddingOf(context).bottom + AppSpace.section,
                ),
                sliver: places.whenLocalFirst(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: QuietNote(
                      errorCopy("Couldn't load places.", error),
                      // Saved places are derived from every place.
                      onRetry: () => ref.invalidate(switch (list) {
                        PlacesList.popular => popularDestinationsProvider,
                        PlacesList.saved => allDestinationsProvider,
                      }),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? SliverToBoxAdapter(
                          child: QuietNote(
                            list == PlacesList.saved
                                ? "Nothing saved yet. The heart on any place keeps it here."
                                : "Nothing here yet.",
                          ),
                        )
                      : SliverPlaceRows(items: items, from: HeroSource.list),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Places as rows on one surface: thumbnail, name, town, save heart. A
/// sliver, so a long list builds only the rows on screen.
class SliverPlaceRows extends StatelessWidget {
  const SliverPlaceRows({required this.items, required this.from, super.key});

  final List<Destination> items;

  /// Which surface the rows are on, for the cover's flight to detail.
  final HeroSource from;

  @override
  Widget build(BuildContext context) => SliverGroupedSection(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final place = items[index];
      return Entrance(
        order: index,
        child: GroupedRow(
          title: place.name,
          subtitle: place.town,
          leading: PhotoHero(
            tag: coverHeroTag(place.id, from),
            child: CoverImage(place.coverImage),
          ),
          trailing: SaveHeart(place.id, style: SaveHeartStyle.row),
          onTap: () => context.push(Routes.destination(place.id, from: from)),
        ),
      );
    },
  );
}
