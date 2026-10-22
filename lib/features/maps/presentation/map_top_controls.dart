import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/controls/filter_chip_row.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/map_route.dart";

/// Over the top of the map: the filters, the way to the grid, and the route
/// being shown, each on its own white surface so nothing needs a scroll edge.
///
/// No search field: search is the bar's last cell (D-16). A town picked
/// on Explore or in search arrives as the row's first chip, chosen, with the
/// close glyph that clears it.
class MapTopControls extends ConsumerWidget {
  const MapTopControls({super.key});

  /// The chip row and the gap under it, at the person's text size.
  static double extent(BuildContext context) {
    final label = AppTypography.labelMedium;
    final grows =
        MediaQuery.textScalerOf(context).lineHeightOf(label) -
        label.fontSize! * label.height!;
    return AppSize.chip + (grows > 0 ? grows : 0) + AppSpace.x2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(browseCategoryProvider);
    final savedOnly = ref.watch(mapShowsSavedProvider);
    final town = ref.watch(browseQueryProvider).trim();

    void choose(DestinationCategory? kind, {bool saved = false}) {
      ref.read(browseCategoryProvider.notifier).select(kind);
      ref.read(mapShowsSavedProvider.notifier).set(saved);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilterChipRow(
                items: [
                  if (town.isNotEmpty)
                    FilterChipItem(
                      label: town,
                      selected: true,
                      onTap: () {},
                      onRemove: () =>
                          ref.read(browseQueryProvider.notifier).update(""),
                    ),
                  FilterChipItem(
                    label: "All",
                    selected: category == null && !savedOnly,
                    onTap: () => choose(null),
                  ),
                  for (final kind in DestinationCategory.values)
                    if (kind != DestinationCategory.unknown)
                      FilterChipItem(
                        label: kind.label,
                        selected: category == kind && !savedOnly,
                        onTap: () => choose(kind),
                      ),
                  FilterChipItem(
                    label: "Saved",
                    selected: savedOnly,
                    onTap: () => choose(null, saved: true),
                  ),
                ],
              ),
            ),
            SymbolButton(
              icon: AppIcons.grid,
              tooltip: "Show as photos",
              onTap: ref.read(browseShowsGridProvider.notifier).toggle,
            ),
            const SizedBox(width: AppSpace.gutter),
          ],
        ),
        const _RouteBanner(),
      ],
    );
  }
}

/// Names the route on the map, and is the only way to dismiss it.
///
/// A route survives the filters and a tap on the basemap — both are things
/// you do *while* reading a route, and losing the trip to either would be
/// its own small betrayal. So dismissal is explicit and lives here.
class _RouteBanner extends ConsumerWidget {
  const _RouteBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(activeMapRouteProvider);
    return route == null ? const SizedBox.shrink() : _Banner(route: route);
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.route});

  final MapRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.x2,
        AppSpace.gutter,
        0,
      ),
      child: Material(
        color: context.lakbayan.glass,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpace.x4),
          child: Row(
            children: [
              Icon(
                AppIcons.directions,
                size: AppSize.glyphMd,
                color: context.lakbayan.spatial,
              ),
              const SizedBox(width: AppSpace.x2),
              // The route's name alone: its numbered pins say the rest.
              Expanded(
                child: Text(
                  route.label,
                  style: AppTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.close, size: AppSize.glyphMd),
                tooltip: "Stop showing this route",
                onPressed: ref.read(activeMapRouteProvider.notifier).clear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
