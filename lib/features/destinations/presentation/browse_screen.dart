import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_layout.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../domain/destination_providers.dart";
import "save_heart.dart";

/// Browse, the Map tab's second view: the same results as a photo grid.
///
/// **The screen's one job.** Lay the province out in front of you. Browse by
/// looking, filter by category, tap a photo.
///
/// **Emotion.** Abundance. There is more here than one trip can hold.
///
/// **Anatomy, top to bottom.** The header sits on solid surface and does not
/// scroll: the title with the map symbol beside it, the search field, the
/// category chips. Under a hard scroll edge, the grid: featured places span
/// the row at 16:10, the rest sit in columns at 4:5, captions below the
/// photo, no card chrome. The map symbol returns to the map, which is the
/// tab's landing.
///
/// Search is debounced and filters in memory (see `browseResultsProvider`);
/// category chips are single-select. Explore pre-fills the search with a
/// town name when a town row is tapped.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Explore may have pre-filled the query before this tab was shown.
    _controller.text = ref.read(browseQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Debounced because each keystroke re-filters the list and rebuilds the
    // grid; the wireframe calls for it explicitly.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(browseQueryProvider.notifier).update(value);
    });
    // The clear affordance depends on whether there is text.
    setState(() {});
  }

  void _clearQuery() {
    _controller.clear();
    ref.read(browseQueryProvider.notifier).update("");
    // Rebuild to update the clear affordance visibility.
    setState(() {});
  }

  void _clearAll() {
    _clearQuery();
    ref.read(browseCategoryProvider.notifier).select(null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(browseCategoryProvider);
    final results = ref.watch(browseResultsProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    // If the query was set from outside (a town tapped on Explore) after this
    // state was created, mirror it into the field.
    ref.listen(browseQueryProvider, (_, next) {
      if (_controller.text != next) _controller.text = next;
    });

    final columns = switch (context.widthClass) {
      WidthClass.compact => 2,
      WidthClass.medium => 3,
      WidthClass.expanded => 4,
    };

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.gutter,
            topInset + AppSpace.x3,
            AppSpace.x2,
            0,
          ),
          child: Row(
            children: [
              Expanded(child: Text("Browse", style: AppTypography.titleLarge)),
              // A lone symbol action gets its own container; it switches the
              // whole view, so it does not live inside the search field.
              SymbolButton(
                icon: AppIcons.map,
                tooltip: "Show on the map",
                onTap: ref.read(browseShowsGridProvider.notifier).toggle,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.x3,
            AppSpace.gutter,
            AppSpace.x3,
          ),
          child: _SearchField(
            controller: _controller,
            onChanged: _onSearchChanged,
            onClear: _controller.text.isEmpty ? null : _clearQuery,
          ),
        ),
        SizedBox(
          height: AppSize.chip,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            children: [
              _CategoryChip(
                label: "All",
                selected: selected == null,
                onTap: () =>
                    ref.read(browseCategoryProvider.notifier).select(null),
              ),
              for (final category in DestinationCategory.values)
                if (category != DestinationCategory.unknown)
                  _CategoryChip(
                    label: category.label,
                    selected: selected == category,
                    onTap: () => ref
                        .read(browseCategoryProvider.notifier)
                        .select(category),
                  ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.x2),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Text(
                "Couldn't load destinations.\n$error",
                style: AppTypography.bodyMedium.copyWith(color: scheme.error),
              ),
            ),
            data: (items) => items.isEmpty
                ? _NoResults(
                    hasFilters:
                        selected != null ||
                        ref.read(browseQueryProvider).isNotEmpty,
                    onClear: _clearAll,
                  )
                // Returns the `ListView` directly, the same way
                // `ExploreScreen` hands its `CustomScrollView` straight to
                // `ScrollEdge`: the builder must return a real `ScrollView`
                // for `fading_edge_scrollview` to attach to, so this can't be
                // its own wrapper widget the way `_PhotoGrid` used to be.
                : ScrollEdge(
                    // The pinned control is the header above, outside this
                    // widget, so only the short falloff is drawn here.
                    style: ScrollEdgeStyle.hard,
                    bottom: ScrollEdge.homeBarHeight(context),
                    child: _photoGrid(
                      context: context,
                      items: items,
                      columns: columns,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A capsule field. The placeholder is the label; the only trailing thing is
/// the clear glyph, and only while there is something to clear.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: AppSize.primaryButton,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: AppTypography.bodyMedium.copyWith(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: "Search places or towns",
            prefixIcon: const Icon(AppIcons.search, size: 20),
            suffixIcon: onClear == null
                ? null
                : IconButton(
                    icon: const Icon(AppIcons.close, size: 18),
                    tooltip: "Clear",
                    onPressed: onClear,
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
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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

/// Featured places span the full row; the rest fill columns in order. Rows
/// of tiles rather than a staggered grid, so the pattern is predictable and
/// the whole list is one lazy sliver.
///
/// A plain function, not a widget class, and returns the `ListView` itself
/// rather than wrapping it: `ScrollEdge.builder` must get a real `ScrollView`
/// to hand to `fading_edge_scrollview`, the same as `ExploreScreen` handing
/// over its `CustomScrollView` directly. The leaf item is still its own
/// widget class ([_Cell]), which is the actual sub-section STANDARDS.md 1.2
/// is about.
ListView _photoGrid({
  required BuildContext context,
  required List<Destination> items,
  required int columns,
}) {
  final bottomInset =
      MediaQuery.viewPaddingOf(context).bottom + AppSize.bottomNav;

  final rows = <List<Destination>>[];
  var current = <Destination>[];
  for (final item in items) {
    if (item.featured) {
      if (current.isNotEmpty) rows.add(current);
      rows.add([item]);
      current = [];
      continue;
    }
    current.add(item);
    if (current.length == columns) {
      rows.add(current);
      current = [];
    }
  }
  if (current.isNotEmpty) rows.add(current);

  return ListView.separated(
    padding: EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.x2,
      AppSpace.gutter,
      bottomInset + AppSpace.x6,
    ),
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpace.x5),
    itemBuilder: (context, index) {
      final row = rows[index];
      final spansRow = row.length == 1 && row.single.featured;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < (spansRow ? 1 : columns); i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.x3),
            Expanded(
              child: i < row.length
                  ? _Cell(destination: row[i], wide: spansRow)
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      );
    },
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.destination, required this.wide});

  final Destination destination;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cover = destination.coverImage;
    final badge = destination.hasAR
        ? const LakbayanBadge.ar()
        : destination.featured
        ? const LakbayanBadge.featured()
        : null;

    return MediaTile(
      media: CoverImage(cover),
      aspectRatio: wide ? 16 / 10 : 4 / 5,
      title: destination.name,
      subtitle: destination.town,
      badge: badge,
      trailing: SaveHeart(destination.id, style: SaveHeartStyle.tile),
      onTap: () => context.push("/destination/${destination.id}"),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilters ? "No matches" : "No destinations yet",
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              hasFilters
                  ? "Try a different search or category."
                  : "Published destinations will appear here.",
              style: AppTypography.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: AppSpace.x4),
              OutlinedButton(
                onPressed: onClear,
                child: const Text("Clear filters"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
