import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";
import "../../maps/domain/map_route.dart";
import "../domain/itinerary_copy.dart";

/// A province tour as a poster: its cover at 3:4, the title and the number
/// of stops on the photo's scrim, so a row of them takes no caption space. Explore's ready-made days and the
/// Itineraries tab's saved tours are the same tile, so a tour looks the same
/// wherever it turns up.
///
/// A tap draws the tour on the map ([showTourOnMap]). [trailing] is the
/// tile's own control at its top corner (the saved tours' menu).
class TourTile extends ConsumerWidget {
  const TourTile({required this.tour, this.trailing, super.key});

  final Tour tour;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: AppSize.tourTile,
    child: MediaTile(
      media: CoverImage(tour.coverImg),
      aspectRatio: 3 / 4,
      overlay: true,
      dense: true,
      title: tour.title,
      subtitle: tour.stops.isEmpty ? null : stopsPhrase(tour.stops.length),
      trailing: trailing,
      // A tour with no stops has no route to draw, so it stays inert rather
      // than sending somebody to an empty map.
      onTap: tour.stops.isEmpty
          ? null
          : () => showTourOnMap(context, ref, tour),
    ),
  );
}

/// Draws the province's [tour] on the map: every filter cleared so no stop is
/// lost to one, the route framed, the Map tab selected.
void showTourOnMap(BuildContext context, WidgetRef ref, Tour tour) {
  ref.read(browseQueryProvider.notifier).update("");
  ref.read(browseCategoryProvider.notifier).select(null);
  ref.read(mapShowsSavedProvider.notifier).set(false);
  ref.read(browseShowsGridProvider.notifier).set(false);
  ref.read(mapSelectedIdProvider.notifier).select(null);
  ref.read(activeMapRouteProvider.notifier).show(tour.title, tour.stops);
  ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
  context.go(Routes.home);
}

/// A horizontal row of [TourTile]s running to the screen edges, exactly a
/// poster tall: the caption is on the photo.
class TourRail extends StatelessWidget {
  const TourRail({required this.tours, this.trailingFor, super.key});

  final List<Tour> tours;

  /// The control for each tile's corner, if the rail's tiles have one.
  final Widget Function(Tour tour)? trailingFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (AppSize.tourTile * 4 / 3).ceilToDouble(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: tours.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x3),
        itemBuilder: (context, index) => TourTile(
          tour: tours[index],
          trailing: trailingFor?.call(tours[index]),
        ),
      ),
    );
  }
}
