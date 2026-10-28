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
import "../../../core/widgets/controls/filter_chip_row.dart";
import "../../../core/widgets/motion/motion.dart";
import "../domain/destination_providers.dart";
import "../../maps/presentation/map_top_controls.dart";
import "place_photo.dart";

/// Browse, the Map tab's second view: the same results as a photo grid.
///
/// **The screen's one job.** Lay the province out in front of you. Browse by
/// looking, filter by category, tap a photo.
///
/// **Emotion.** Abundance. There is more here than one trip can hold.
///
/// **Anatomy, top to bottom.** The header sits on solid surface and does not
/// scroll: the shared map search field and view toggle, then the chips.
/// Under the header, the grid: featured places span
/// the row at 16:10, the rest sit in columns at 4:5, each name on its photo
/// (D-19), no card chrome. The map symbol returns to the map, which is the
/// tab's landing.
///
/// The town filters in memory (see `browseResultsProvider`); category chips
/// are single-select. Explore sets the town when a town row is tapped.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(browseCategoryProvider);
    final subcategory = ref.watch(browseSubcategoryProvider);
    final subcategories = ref.watch(browseSubcategoriesProvider);
    final query = ref.watch(browseQueryProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final columns = switch (_WidthClass.of(context)) {
      _WidthClass.compact => 2,
      _WidthClass.medium => 3,
      _WidthClass.expanded => 4,
    };
    final rows = ref.watch(browseGridRowsProvider(columns));
    final savedOnly = ref.watch(mapShowsSavedProvider);

    void clearAll() {
      ref.read(browseQueryProvider.notifier).update("");
      ref.read(browseCategoryProvider.notifier).select(null);
      ref.read(browseSubcategoryProvider.notifier).select(null);
      ref.read(mapShowsSavedProvider.notifier).set(false);
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.gutter,
            topInset + AppSpace.x2,
            AppSpace.x2,
            0,
          ),
          child: const MapSearchBar(),
        ),
        const SizedBox(height: AppSpace.x2),
        FilterChipRow(
          items: [
            if (query.trim().isNotEmpty)
              FilterChipItem(
                label: query.trim(),
                selected: true,
                onTap: () {},
                onRemove: () =>
                    ref.read(browseQueryProvider.notifier).update(""),
              ),
            FilterChipItem(
              label: "All",
              selected: selected == null && !savedOnly,
              onTap: () {
                ref.read(browseCategoryProvider.notifier).select(null);
                ref.read(mapShowsSavedProvider.notifier).set(false);
              },
            ),
            for (final category in DestinationCategory.values)
              if (category != DestinationCategory.unknown)
                FilterChipItem(
                  label: category.label,
                  selected: selected == category && !savedOnly,
                  onTap: () {
                    ref.read(browseCategoryProvider.notifier).select(category);
                    ref.read(mapShowsSavedProvider.notifier).set(false);
                  },
                ),
            FilterChipItem(
              label: "Saved",
              selected: savedOnly,
              onTap: () {
                ref.read(browseCategoryProvider.notifier).select(null);
                ref.read(mapShowsSavedProvider.notifier).set(true);
              },
            ),
          ],
        ),
        // A chosen category's finer kinds, when its places use any. The same
        // chips one step down: selection is still single and still green.
        if (selected != null && subcategories.isNotEmpty) ...[
          const SizedBox(height: AppSpace.x2),
          FilterChipRow(
            items: [
              FilterChipItem(
                label: "All ${selected.label.toLowerCase()}",
                selected: subcategory == null,
                onTap: () =>
                    ref.read(browseSubcategoryProvider.notifier).select(null),
              ),
              for (final name in subcategories)
                FilterChipItem(
                  label: name,
                  selected: subcategory == name,
                  onTap: () =>
                      ref.read(browseSubcategoryProvider.notifier).select(name),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.x2),
        Expanded(
          child: rows.whenLocalFirst(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: QuietNote(
                errorCopy("Couldn't load destinations.", error),
                onRetry: () => ref.invalidate(browseSource(selected)),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? _NoResults(
                    hasFilters:
                        savedOnly ||
                        selected != null ||
                        subcategory != null ||
                        query.isNotEmpty,
                    onClear: clearAll,
                  )
                : _PhotoGrid(rows: rows, columns: columns),
          ),
        ),
      ],
    );
  }
}

/// Featured places span the full row; the rest fill columns in order. Rows
/// of tiles rather than a staggered grid, so the pattern is predictable and
/// the whole list is one lazy list. The rows are cut in the provider
/// ([browseGridRows]), not here on every build.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.rows, required this.columns});

  final List<List<Destination>> rows;
  final int columns;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.x2,
      AppSpace.gutter,
      FloatingTabBar.clearance(context) + AppSpace.x6,
    ),
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpace.x2),
    itemBuilder: (context, index) {
      final row = rows[index];
      final spansRow = row.length == 1 && row.single.featured;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < (spansRow ? 1 : columns); i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.x2),
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
  Widget build(BuildContext context) => PlacePhoto(
    place: destination,
    from: HeroSource.browse,
    aspectRatio: wide ? 16 / 10 : 4 / 5,
    heart: true,
  );
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
              hasFilters ? "No Matches" : "No Places Yet",
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
              Pressable(
                child: OutlinedButton(
                  onPressed: onClear,
                  child: const Text("Clear Filters"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Material 3 window size classes (design doc 07); no widget holds a raw
/// width. Promote to `lib/core/` when a second screen adapts.
enum _WidthClass {
  compact,
  medium,
  expanded;

  /// `sizeOf`, so only a size change rebuilds.
  static _WidthClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return compact;
    if (width < 840) return medium;
    return expanded;
  }
}
