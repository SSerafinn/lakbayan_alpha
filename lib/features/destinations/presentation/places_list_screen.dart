import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../domain/destination_providers.dart";
import "../domain/saved_destinations.dart";
import "save_heart.dart";

/// Which list this screen shows.
enum PlacesList { popular, saved }

/// A plain list of places under a title: Home's "See all" and Profile's
/// Saved places. One grouped section, whole row opens the place, the heart
/// trailing.
class PlacesListScreen extends ConsumerWidget {
  const PlacesListScreen({required this.list, super.key});

  final PlacesList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String title, AsyncValue<List<Destination>> places) = switch (list) {
      PlacesList.popular => (
        "Popular this week",
        ref.watch(popularDestinationsProvider),
      ),
      PlacesList.saved => ("Saved places", ref.watch(savedPlacesProvider)),
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.x2,
            AppSpace.gutter,
            AppSpace.section,
          ),
          children: [
            Row(
              children: [
                SymbolButton(
                  icon: AppIcons.back,
                  tooltip: "Back",
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: AppSpace.x2),
                Expanded(child: Text(title, style: AppTypography.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpace.section),
            places.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => QuietNote("Couldn't load places.\n$error"),
              data: (items) => items.isEmpty
                  ? QuietNote(
                      list == PlacesList.saved
                          ? "Nothing saved yet. The heart on any place keeps it here."
                          : "Nothing here yet.",
                    )
                  : PlaceRows(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

/// Places as rows on one surface: thumbnail, name, town, save heart.
class PlaceRows extends StatelessWidget {
  const PlaceRows({required this.items, super.key});

  final List<Destination> items;

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      for (final place in items)
        GroupedRow(
          title: place.name,
          subtitle: place.town,
          leading: CoverImage(place.coverImage),
          trailing: SaveHeart(place.id, style: SaveHeartStyle.row),
          onTap: () => context.push(Routes.destination(place.id)),
        ),
    ],
  );
}
