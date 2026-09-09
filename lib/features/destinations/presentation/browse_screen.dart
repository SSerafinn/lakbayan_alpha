import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/storage_image.dart";
import "../../maps/presentation/map_view.dart";
import "../domain/destination_providers.dart";

/// Wireframe 1c, screen 4 — Search / Browse, the Map tab's landing screen.
///
/// Search is debounced and filters the results in place; category chips are
/// single-select. The ◈ toggle swaps the grid for a map of the same results —
/// it stays inside the tab rather than pushing a route, because wireframe 1a
/// keeps the bottom navigation on every screen but Splash, Auth, Player and AR.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

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
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final selected = ref.watch(browseCategoryProvider);
    final results = ref.watch(browseResultsProvider);
    final showsMap = ref.watch(browseShowsMapProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x4,
            AppSpace.x4,
            AppSpace.x4,
            AppSpace.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: "Search your destination",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              ref.read(browseQueryProvider.notifier).update("");
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.x2),
              // Outside the field rather than as a suffix icon: it switches the
              // whole view, and a control that lives inside the search box
              // reads as something that acts on the search.
              IconButton.filledTonal(
                onPressed: ref.read(browseShowsMapProvider.notifier).toggle,
                icon: Icon(showsMap ? Icons.grid_view : Icons.map_outlined),
                tooltip: showsMap ? "Show as a list" : "Show on the map",
              ),
            ],
          ),
        ),

        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
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

        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpace.x4),
              child: Text(
                "Couldn't load destinations.\n$e",
                style: AppTypography.body.copyWith(color: c.badgeErrorText),
              ),
            ),
            // The map draws its own empty state over the basemap, so it takes
            // the results whether or not there are any. A blank screen where a
            // map should be would read as a failure to load.
            data: (items) => showsMap
                ? MapView(destinations: items)
                : items.isEmpty
                ? _NoResults(
                    hasFilters:
                        selected != null ||
                        ref.read(browseQueryProvider).isNotEmpty,
                    onClear: () {
                      _controller.clear();
                      ref.read(browseQueryProvider.notifier).update("");
                      ref.read(browseCategoryProvider.notifier).select(null);
                      setState(() {});
                    },
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(AppSpace.x4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpace.x3,
                          mainAxisSpacing: AppSpace.x3,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _GridCard(items[i]),
                  ),
          ),
        ),
      ],
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
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      side: BorderSide(
        color: selected ? AppColors.green500 : context.lakbayan.line,
      ),
    ),
  );
}

class _GridCard extends StatelessWidget {
  const _GridCard(this.destination);

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final cover = destination.coverImage;

    return InkWell(
      onTap: () => context.push("/destination/${destination.id}"),
      borderRadius: AppRadius.lgAll,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: c.line),
          boxShadow: AppShadow.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: cover == null
                      ? const ImagePlaceholder(borderRadius: BorderRadius.zero)
                      : StorageImage(path: cover),
                ),
                if (destination.hasAR)
                  const Positioned(
                    top: AppSpace.x2,
                    left: AppSpace.x2,
                    child: LakbayanBadge.ar(),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: AppTypography.title.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      destination.town,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilters ? "No matches" : "No destinations yet",
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              hasFilters
                  ? "Try a different search or category."
                  : "Published destinations will appear here.",
              style: AppTypography.body.copyWith(color: c.textSecondary),
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
