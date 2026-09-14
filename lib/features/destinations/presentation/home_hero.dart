import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/storage_image.dart";
import "../../itineraries/presentation/add_to_itinerary_sheet.dart";
import "save_heart.dart";

/// Home's featured place, edge to edge, the largest thing on the screen.
///
/// **Anatomy.** Photo under a scrim; FEATURED and AR top-left; over the
/// scrim the town, the name in the hero step, one sentence, then the
/// screen's one primary action, **Add to a tour**, beside the save heart.
///
/// The search control is not this widget's — it lives in its own row above
/// the hero (`_SearchBar`, `explore_screen.dart`), not layered on the
/// photo. That is also why this hero does not itself reach for the device's
/// top inset: the bar above it already clears the status bar.
class HomeHero extends StatelessWidget {
  const HomeHero({required this.destination, super.key});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSize.heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(destination.coverImage),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => context.push(Routes.destination(destination.id)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MediaScrim(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x12 * 2,
                AppSpace.gutter,
                AppSpace.gutter,
              ),
              child: _HeroCopy(destination: destination),
            ),
          ),
          Positioned(
            top: AppSpace.gutter,
            left: AppSpace.gutter,
            child: Wrap(
              spacing: AppSpace.x2,
              children: [
                if (destination.featured) const LakbayanBadge.featured(),
                if (destination.hasAR) const LakbayanBadge.ar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Town, name, one sentence, close together: the line boxes carry
        // the gaps, so the three read as one caption over the photo.
        Text(
          destination.town,
          style: AppTypography.labelMedium.copyWith(color: white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          destination.name,
          style: AppTypography.hero.copyWith(color: white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpace.x1),
        Text(
          destination.description,
          style: AppTypography.bodyMedium.copyWith(color: white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpace.x3),
        Row(
          children: [
            FilledButton(
              onPressed: () => showAddToItinerary(
                context,
                destinationId: destination.id,
                destinationName: destination.name,
              ),
              child: const Text("Add to a tour"),
            ),
            const SizedBox(width: AppSpace.x3),
            SaveHeart(destination.id, style: SaveHeartStyle.hero),
          ],
        ),
      ],
    );
  }
}
