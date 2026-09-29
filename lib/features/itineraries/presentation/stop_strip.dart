import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../maps/presentation/map_view.dart" show showDirections;
import "route_map.dart";

/// The trip's stops over its expanded map, one per page, each the list's own
/// row on a white card. The strip and the map follow each other through
/// [controller], owned by the screen. A card opens the place (its photo
/// zooms in); its turn arrow hands the stop to the phone's map app.
class StopStrip extends StatelessWidget {
  const StopStrip({
    required this.stops,
    required this.controller,
    required this.onFocused,
    super.key,
  });

  final List<RouteStop> stops;
  final PageController controller;
  final ValueChanged<int> onFocused;

  /// How much of the next card shows, so the row reads as more to swipe.
  static const viewportFraction = 0.86;

  /// The strip's height at the user's text size: a row's photo, or its two
  /// lines if those are taller, inside the row's padding and the plate's.
  static double heightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Each style on its own: Android scales large text less than small.
    final lines =
        scaler.lineHeightOf(AppTypography.titleSmall) +
        scaler.lineHeightOf(AppTypography.secondLine);
    final content = lines > AppSize.rowMedia ? lines : AppSize.rowMedia;
    return content + (AppSpace.rowPad + AppSpace.groupInset) * 2;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: heightOf(context),
    child: PageView.builder(
      controller: controller,
      itemCount: stops.length,
      onPageChanged: onFocused,
      padEnds: false,
      itemBuilder: (context, index) {
        final (:number, :place) = stops[index];
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? AppSpace.gutter : AppSpace.x1,
            right: index == stops.length - 1 ? AppSpace.gutter : AppSpace.x1,
          ),
          child: Semantics(
            label: "Stop $number",
            // The list's own row on a white card, so it reads over the map.
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
              clipBehavior: Clip.antiAlias,
              child: GroupedSection(
                children: [
                  GroupedRow(
                    mark: StopNumeral(number),
                    title: place.name,
                    subtitle: place.town,
                    leading: PhotoHero(
                      tag: coverHeroTag(place.id, HeroSource.stopCard),
                      child: CoverImage(place.coverImage),
                    ),
                    // Going there is what a stop card on the map is for;
                    // the turn arrow is the maps' own shorthand for it.
                    trailing: IconButton(
                      icon: const Icon(
                        AppIcons.directions,
                        size: AppSize.glyphMd,
                      ),
                      tooltip: "Directions to ${place.name}",
                      onPressed: () => showDirections(context, place),
                    ),
                    onTap: () => context.push(
                      Routes.destination(place.id, from: HeroSource.stopCard),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
