import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/domain/saved_destinations.dart";
import "../../destinations/presentation/browse_screen.dart";
import "../../destinations/presentation/save_heart.dart";
import "../../explore/domain/home_chrome.dart";
import "map_view.dart";

/// The Map tab (redesign 2c).
///
/// **The screen's one job.** Find places by where they are.
///
/// **Emotion.** Orientation: knowing where you stand.
///
/// **Anatomy.** A real map, edge to edge. Above it a white capsule search
/// field with the grid toggle beside it, then the chip row (categories and
/// Saved). Below, a **parallel** sheet, no scrim, naming the area and listing
/// the places on it with their distance from the tapped pin in blue. The
/// nav bar floats over the sheet.
///
/// The Browse grid is the same results as photos, one toggle away.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsGrid = ref.watch(browseShowsGridProvider);
    if (showsGrid) return const BrowseScreen();

    final results = ref.watch(mapResultsProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                QuietNote("Couldn't load destinations.\n$error"),
            // The map takes the results whether or not there are any; a blank
            // where a map should be would read as a failure to load.
            data: (items) => MapView(destinations: items),
          ),
        ),
        Positioned(
          top: topInset + AppSpace.x2,
          left: 0,
          right: 0,
          child: const _TopControls(),
        ),
        if (results case AsyncData(:final value)) _PlacesSheet(items: value),
      ],
    );
  }
}

/// The search capsule with the grid toggle, then the chips. Each sits on its
/// own white surface, so nothing here needs a scroll edge.
class _TopControls extends ConsumerStatefulWidget {
  const _TopControls();

  @override
  ConsumerState<_TopControls> createState() => _TopControlsState();
}

class _TopControlsState extends ConsumerState<_TopControls> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(browseQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(browseQueryProvider.notifier).update(value);
    });
    // Rebuild to update the clear affordance visibility.
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    ref.read(browseQueryProvider.notifier).update("");
    // Rebuild to update the clear affordance visibility.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = ref.watch(browseCategoryProvider);
    final savedOnly = ref.watch(mapShowsSavedProvider);

    // A town tapped on Home pre-fills the query after this state exists.
    ref.listen(browseQueryProvider, (_, next) {
      if (_controller.text != next) _controller.text = next;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: scheme.surface,
                  shape: StadiumBorder(
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: AppSize.primaryButton,
                    child: TextField(
                      controller: _controller,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTypography.bodyMedium.copyWith(
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search places or towns",
                        prefixIcon: const Icon(AppIcons.search, size: 20),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(AppIcons.close, size: 18),
                                tooltip: "Clear",
                                onPressed: _clear,
                              ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.x4,
                          vertical: AppSpace.x4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.x2),
              SymbolButton(
                icon: AppIcons.grid,
                tooltip: "Show as a grid",
                onTap: ref.read(browseShowsGridProvider.notifier).toggle,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.x2),
        SizedBox(
          height: AppSize.chip,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            children: [
              _Chip(
                label: "All",
                selected: category == null && !savedOnly,
                onTap: () {
                  ref.read(browseCategoryProvider.notifier).select(null);
                  ref.read(mapShowsSavedProvider.notifier).set(false);
                },
              ),
              for (final kind in DestinationCategory.values)
                if (kind != DestinationCategory.unknown)
                  _Chip(
                    label: kind.label,
                    selected: category == kind && !savedOnly,
                    onTap: () {
                      ref.read(browseCategoryProvider.notifier).select(kind);
                      ref.read(mapShowsSavedProvider.notifier).set(false);
                    },
                  ),
              _Chip(
                label: "Saved",
                selected: savedOnly,
                onTap: () {
                  ref.read(browseCategoryProvider.notifier).select(null);
                  ref.read(mapShowsSavedProvider.notifier).set(true);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpace.x2),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

/// The parallel sheet: the area's name, then the places on it. No scrim,
/// because the map stays usable while it is up (design doc 04).
///
/// At rest it shows the title and two rows above the floating tab bar.
/// Dragged above that, the bar slides away so the sheet has the whole
/// bottom of the screen; dropped back, the bar returns.
class _PlacesSheet extends ConsumerStatefulWidget {
  const _PlacesSheet({required this.items});

  final List<Destination> items;

  static const _maxSize = 0.72;

  @override
  ConsumerState<_PlacesSheet> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends ConsumerState<_PlacesSheet> {
  /// Read once: `ref` is gone by [dispose], and the bar must not stay hidden
  /// when the grid toggle swaps this sheet out mid-drag.
  late final HomeChrome _chrome = ref.read(homeChromeProvider.notifier);

  /// Whether this sheet is the reason the bar is hidden.
  bool _hidBar = false;

  void _raise(bool raised) {
    if (raised == _hidBar) return;
    _hidBar = raised;
    raised ? _chrome.hide() : _chrome.expand();
  }

  @override
  void dispose() {
    // After the frame: a provider cannot change while the tree is torn down.
    if (_hidBar) {
      final chrome = _chrome;
      WidgetsBinding.instance.addPostFrameCallback((_) => chrome.expand());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final selectedId = ref.watch(mapSelectedIdProvider);
    final query = ref.watch(browseQueryProvider).trim();
    final selected = items.where((d) => d.id == selectedId).firstOrNull;
    final title = selected?.town ?? (query.isEmpty ? "Cagayan" : query);
    final barHeight = ScrollEdge.homeBarHeight(context);
    final barHidden = ref.watch(homeChromeProvider) == HomeChromeState.hidden;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final restSize =
            ((barHeight + AppSize.mapSheetRest) / constraints.maxHeight).clamp(
              0.0,
              _PlacesSheet._maxSize,
            );

        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            _raise(notification.extent > restSize + 0.02);
            return false;
          },
          child: DraggableScrollableSheet(
            initialChildSize: restSize,
            minChildSize: restSize,
            maxChildSize: _PlacesSheet._maxSize,
            builder: (context, scrollController) => Material(
              color: scheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.sheetTop,
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x2,
                  AppSpace.gutter,
                  (barHidden ? bottomInset : barHeight) + AppSpace.section,
                ),
                children: [
                  Center(
                    child: Container(
                      width: AppSize.dragHandleWidth,
                      height: AppSize.dragHandleHeight,
                      decoration: ShapeDecoration(
                        color: scheme.outlineVariant,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.x3),
                  Text(title, style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpace.x3),
                  if (items.isEmpty)
                    const QuietNote("Nothing matches those filters.")
                  else
                    GroupedSection(
                      children: [
                        for (final place in items)
                          _PlaceRow(
                            place: place,
                            from: selected,
                            distanceColor: brand.spatial,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One place on the sheet. The second line is the distance from the tapped
/// pin, in blue, or the town when nothing is tapped. Saved places carry the
/// heart; the rest a chevron.
class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({
    required this.place,
    required this.from,
    required this.distanceColor,
  });

  final Destination place;
  final Destination? from;
  final Color distanceColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      savedDestinationsProvider.select((ids) => ids.contains(place.id)),
    );
    final origin = from;
    final measured = origin != null && origin.id != place.id;
    final subtitle = measured
        ? "${distanceLabel(distanceBetween(origin, place))} from the pin"
        : place.town;

    return GroupedRow(
      title: place.name,
      subtitle: subtitle,
      subtitleColor: measured ? distanceColor : null,
      leading: CoverImage(place.coverImage),
      trailing: saved ? SaveHeart(place.id, style: SaveHeartStyle.row) : null,
      onTap: () => context.push(Routes.destination(place.id)),
    );
  }
}
