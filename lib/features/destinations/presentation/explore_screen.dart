import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/lakbayan_list_row.dart";
import "../../../core/widgets/storage_image.dart";
import "../domain/destination_providers.dart";

/// Wireframe 1c, screen 3 — Explore (tab 1).
///
/// Order is fixed by the wireframe: the build-a-tour hero first and never
/// dismissible, then Popular as a horizontal carousel, then Nearby as vertical
/// rows.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularDestinationsProvider);
    final featured = ref.watch(featuredDestinationsProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.x8),
      children: [
        const _BuildATourCard(),

        _SectionHeader(
          title: "Popular Places",
          onMore: () => context.go("/browse"),
        ),
        _HorizontalRail(state: popular),

        _SectionHeader(title: "Featured", onMore: () => context.go("/browse")),
        // Featured stands in for the wireframe's "Nearby Places" until location
        // permission and distance sorting land with the maps work in Phase 3.
        // Same vertical-row treatment, editorially chosen rather than by
        // distance, so the section is useful rather than empty.
        _VerticalRows(state: featured),
      ],
    );
  }
}

class _BuildATourCard extends StatelessWidget {
  const _BuildATourCard();

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpace.x4,
        AppSpace.x4,
        AppSpace.x4,
        AppSpace.x2,
      ),
      padding: const EdgeInsets.all(AppSpace.x3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.line),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 88,
                height: 70,
                child: ImagePlaceholder(borderRadius: AppRadius.smAll),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Create your own tour", style: AppTypography.title),
                    const SizedBox(height: AppSpace.x1),
                    Text(
                      "Pick the stops you want and we'll route them for you.",
                      style: AppTypography.body.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x3),
          const FilledButton(
            // Itineraries are Phase 3; the hero stays visible because the
            // wireframe says it is never dismissible.
            onPressed: null,
            child: Text("Create"),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onMore});

  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.x4,
      AppSpace.x5,
      AppSpace.x2,
      AppSpace.x2,
    ),
    child: Row(
      children: [
        Text(title, style: AppTypography.h3),
        const Spacer(),
        if (onMore != null)
          TextButton(onPressed: onMore, child: const Text("More")),
      ],
    ),
  );
}

class _HorizontalRail extends StatelessWidget {
  const _HorizontalRail({required this.state});

  final AsyncValue<List<Destination>> state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorNote(error: e),
        data: (items) => items.isEmpty
            ? const _EmptyNote("Nothing here yet.")
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x3),
                itemBuilder: (context, i) => SizedBox(
                  width: 168,
                  child: _RailCard(destination: items[i]),
                ),
              ),
      ),
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({required this.destination});

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
                SizedBox(
                  height: 110,
                  width: double.infinity,
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
            Padding(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.town,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalRows extends StatelessWidget {
  const _VerticalRows({required this.state});

  final AsyncValue<List<Destination>> state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
    child: state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorNote(error: e),
      data: (items) => items.isEmpty
          ? const _EmptyNote("Nothing featured yet.")
          : Column(
              children: [
                for (final d in items)
                  LakbayanListRow(
                    title: d.name,
                    subtitle: "${d.town} · ${d.category.label}",
                    leading: d.coverImage == null
                        ? null
                        : StorageImage(
                            path: d.coverImage!,
                            borderRadius: AppRadius.mdAll,
                          ),
                    trailing: d.featured
                        ? const LakbayanBadge.featured()
                        : null,
                    showDivider: d != items.last,
                    onTap: () => context.push("/destination/${d.id}"),
                  ),
              ],
            ),
    ),
  );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpace.x4),
    child: Text(
      message,
      style: AppTypography.body.copyWith(color: context.lakbayan.textSecondary),
    ),
  );
}

/// Surfaces the actual error rather than a generic message: a permission-denied
/// here almost always means a query lost its `status == published` filter, and
/// hiding that costs an hour.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Container(
      margin: const EdgeInsets.all(AppSpace.x4),
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: c.badgeErrorFill,
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        "Couldn't load destinations.\n$error",
        style: AppTypography.body.copyWith(color: c.badgeErrorText),
      ),
    );
  }
}
