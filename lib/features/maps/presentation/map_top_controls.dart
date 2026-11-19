import "dart:async";

import "package:flutter/material.dart";

import "../../destinations/domain/place_kind.dart";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/controls/filter_chip_row.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/presentation/search_surface.dart";
import "../domain/map_route.dart";

/// Over the top of the map: the filters, the way to the grid, and the route
/// being shown, each on its own white surface so nothing needs a scroll edge.
///
/// Search and the view toggle have their own row above the filters.
class MapTopControls extends ConsumerWidget {
  const MapTopControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(browseCategoryProvider);
    final savedOnly = ref.watch(mapShowsSavedProvider);
    final kinds = ref.watch(placeKindsProvider);

    void choose(String? kind, {bool saved = false}) {
      ref.read(browseCategoryProvider.notifier).select(kind);
      ref.read(mapShowsSavedProvider.notifier).set(saved);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: MapSearchBar(),
        ),
        const SizedBox(height: AppSpace.x2),
        FilterChipRow(
          items: [
            FilterChipItem(
              label: "All",
              selected: category == null && !savedOnly,
              onTap: () => choose(null),
            ),
            for (final kind in kinds)
              FilterChipItem(
                label: kind.label,
                selected: category == kind.key && !savedOnly,
                onTap: () => choose(kind.key),
              ),
            FilterChipItem(
              label: "Saved",
              selected: savedOnly,
              onTap: () => choose(null, saved: true),
            ),
          ],
        ),
        const _RouteBanner(),
      ],
    );
  }
}

/// Map and Browse share the query, input and fixed view-toggle geometry.
class MapSearchBar extends ConsumerStatefulWidget {
  const MapSearchBar({super.key});

  static double heightOf(BuildContext context) =>
      (MediaQuery.textScalerOf(context).lineHeightOf(AppTypography.bodyLarge) +
              AppSpace.x4)
          .clamp(AppSize.minTouchTarget, double.infinity);

  @override
  ConsumerState<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends ConsumerState<MapSearchBar> {
  late final _controller = TextEditingController(
    text: ref.read(browseQueryProvider),
  );
  Timer? _debounce;
  final _focus = FocusNode();

  void _change(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.read(browseQueryProvider.notifier).update(value);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(browseQueryProvider, (_, query) {
      if (_controller.text == query) return;
      _debounce?.cancel();
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
      setState(() {});
    });
    final grid = ref.watch(browseShowsGridProvider);
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            shape: StadiumBorder(
              side: BorderSide(
                color: _focus.hasFocus
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: _focus.hasFocus ? AppStroke.bold : AppStroke.hairline,
              ),
            ),
            child: Focus(
              onFocusChange: (_) => setState(() {}),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MapSearchBar.heightOf(context),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: AppSpace.x3),
                    const Icon(AppIcons.search, size: AppSize.glyphMd),
                    const SizedBox(width: AppSpace.x2),
                    Expanded(
                      child: PlacesSearchInput(
                        controller: _controller,
                        focusNode: _focus,
                        onChanged: _change,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: "Clear search",
                        icon: const Icon(AppIcons.close, size: AppSize.glyphMd),
                        onPressed: () {
                          _debounce?.cancel();
                          _controller.clear();
                          ref.read(browseQueryProvider.notifier).update("");
                          setState(() {});
                        },
                      )
                    else
                      const SizedBox(width: AppSpace.x3),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.x2),
        SymbolButton(
          icon: grid ? AppIcons.map : AppIcons.grid,
          tooltip: grid ? "Show on the map" : "Show as photos",
          onGround: true,
          onTap: () {
            _debounce?.cancel();
            ref.read(browseQueryProvider.notifier).update(_controller.text);
            FocusScope.of(context).unfocus();
            ref.read(browseShowsGridProvider.notifier).toggle();
          },
        ),
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
