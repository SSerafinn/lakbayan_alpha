import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../../core/widgets/section_heading.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../../audio/presentation/audio_guide_section.dart";
import "../../explore/domain/home_tab.dart";
import "../../itineraries/presentation/add_to_itinerary_sheet.dart";
import "../../maps/domain/directions.dart";
import "../domain/destination_providers.dart";
import "../domain/recently_viewed.dart";
import "save_heart.dart";

/// Place detail. **One job:** decide whether to go, then add it to a trip.
/// **Emotion:** being there already.
///
/// Top to bottom: the hero with town and name on its scrim; a row of
/// read-only badges (featured, AR, category, tags); the description, the
/// history folded to four lines; the audio guide inline, stops and player;
/// Plan your visit, one grouped section ending in the map row; Nearby as
/// two tiles with the distance in blue; More in the town; and, pinned, the
/// one primary action, Add to itinerary.
class DestinationDetailScreen extends ConsumerStatefulWidget {
  const DestinationDetailScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState
    extends ConsumerState<DestinationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Opening a place is what "recently viewed" means. Once, not per build,
    // and after the first frame: a provider must not change mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentlyViewedProvider.notifier).markViewed(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(destinationByIdProvider(widget.id));

    return destination.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => MessageScreen("Couldn't load this destination.\n$e"),
      data: (d) => d == null
          ? const MessageScreen("This destination is no longer available.")
          : Scaffold(body: _Content(destination: d)),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // The pinned action's region: button, its padding, the gesture inset.
    final actionHeight =
        AppSize.primaryButton + AppSpace.gutter * 2 + bottomInset;

    return Stack(
      children: [
        ScrollEdge(
          style: ScrollEdgeStyle.hard,
          bottom: actionHeight,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(destination: destination)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.gutter,
                  AppSpace.gutter,
                  actionHeight + AppSpace.section,
                ),
                sliver: SliverList.list(
                  children: [
                    _Badges(destination: destination),
                    _Prose(destination: destination),
                    _AudioGuide(id: destination.id),
                    const SizedBox(height: AppSpace.section),
                    _PlanYourVisit(destination: destination),
                    _Nearby(id: destination.id),
                    _MoreInTown(destination: destination),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _PinnedAction(destination: destination),
        ),
      ],
    );
  }
}

/// The photos, pageable when there are several, under a scrim carrying the
/// town and the name. Back, share and the save heart sit on their own
/// circles.
class _Hero extends StatefulWidget {
  const _Hero({required this.destination});

  final Destination destination;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final destination = widget.destination;
    final images = destination.images;

    return SizedBox(
      height: AppSize.detailHero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            const ImagePlaceholder(borderRadius: BorderRadius.zero)
          else
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: images.length,
              // Only the cover page carries the tag: it is the one image the
              // "Popular this week" tile can share a continuity flight with.
              itemBuilder: (context, i) => i == 0
                  ? Hero(
                      tag: destination.popularHeroTag,
                      child: StorageImage(path: images[i]),
                    )
                  : StorageImage(path: images[i]),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: MediaScrim(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x12 * 2,
                  AppSpace.gutter,
                  AppSpace.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      destination.town,
                      style: AppTypography.labelMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      destination.name,
                      style: AppTypography.hero.copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (images.length > 1) ...[
                      const SizedBox(height: AppSpace.x2),
                      _PageDots(count: images.length, current: _page),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + AppSpace.x2,
            left: AppSpace.x2,
            child: SymbolButton(
              icon: AppIcons.back,
              tooltip: "Back",
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(Routes.home),
            ),
          ),
          Positioned(
            top: topInset + AppSpace.x2,
            right: AppSpace.x2 + AppSize.heroSave + AppSpace.x2,
            child: SymbolButton(
              icon: AppIcons.share,
              tooltip: "Share",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Sharing will be available in a future update.",
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: topInset + AppSpace.x2,
            right: AppSpace.x2,
            child: SaveHeart(destination.id, style: SaveHeartStyle.hero),
          ),
        ],
      ),
    );
  }
}

/// Which photo is showing. Small white capsules, the current one longer.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.only(right: AppSpace.x1),
          child: AnimatedContainer(
            duration: AppMotion.edge,
            width: i == current ? AppSpace.x4 : AppSpace.x1 + 2,
            height: AppSpace.x1 + 2,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: i == current ? 1 : 0.5),
              shape: const StadiumBorder(),
            ),
          ),
        ),
    ],
  );
}

/// Read-only: featured, AR, the category, the tags. Nothing computed:
/// `openHours` is free text, so there is no OPEN NOW.
class _Badges extends StatelessWidget {
  const _Badges({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x4),
    child: Wrap(
      spacing: AppSpace.x2,
      runSpacing: AppSpace.x2,
      children: [
        if (destination.featured) const LakbayanBadge.featured(),
        if (destination.hasAR) const LakbayanBadge.ar(),
        LakbayanBadge(destination.category.label, kind: BadgeKind.info),
        for (final tag in destination.tags)
          LakbayanBadge(tag, kind: BadgeKind.info),
      ],
    ),
  );
}

/// The description in full; the history folded to four lines behind "More".
class _Prose extends StatefulWidget {
  const _Prose({required this.destination});

  final Destination destination;

  @override
  State<_Prose> createState() => _ProseState();
}

class _ProseState extends State<_Prose> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = widget.destination.history?.trim() ?? "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.destination.description, style: AppTypography.bodyLarge),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpace.x3),
          Text(
            history,
            style: AppTypography.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(_expanded ? "Less" : "More"),
          ),
        ],
      ],
    );
  }
}

/// The stops and the player, inline: the guide is content, not a setting.
/// Absent entirely when the place has no stops.
class _AudioGuide extends ConsumerWidget {
  const _AudioGuide({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(destinationSegmentsProvider(id)).value ?? const [];
    if (stops.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading("Audio guide"),
          const SizedBox(height: AppSpace.x2),
          AudioGuideSection(destinationId: id, segments: stops),
        ],
      ),
    );
  }
}

/// The practical facts as rows, each only when set, ending in the map row in
/// blue. Rendered as written: `openHours` cannot be computed against.
class _PlanYourVisit extends ConsumerWidget {
  const _PlanYourVisit({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.lakbayan;
    final practical = destination.practical;
    final facts = <(String, String?)>[
      ("Hours", practical?.openHours),
      ("Entry", practical?.entryFee),
      ("Best time to go", practical?.bestSeason),
      ("Getting around", practical?.accessibility),
    ];

    return GroupedSection(
      heading: "Plan your visit",
      children: [
        for (final (label, value) in facts)
          if (value != null && value.trim().isNotEmpty)
            GroupedRow(title: label, subtitle: value.trim()),
        GroupedRow(
          title: "See it on the map",
          subtitle: destination.town,
          subtitleColor: brand.spatial,
          leadingGlyph: AppIcons.directions,
          glyphColor: brand.spatial,
          onTap: () {
            ref.read(mapSelectedIdProvider.notifier).select(destination.id);
            ref.read(browseShowsGridProvider.notifier).set(false);
            ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
            context.go(Routes.home);
          },
        ),
        GroupedRow(
          title: "Take me there",
          subtitle: "Opens your map app",
          leadingGlyph: AppIcons.drive,
          glyphColor: brand.spatial,
          onTap: () async {
            // Resolved before the await: this is a ConsumerWidget, so there
            // is no `mounted` to check afterwards.
            final messenger = ScaffoldMessenger.of(context);
            final opened = await openDirections(
              lat: destination.coords.lat,
              lng: destination.coords.lng,
              label: destination.name,
            );
            if (opened) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text("Couldn't open a map app for directions."),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The two closest places, distance in blue under each.
class _Nearby extends ConsumerWidget {
  const _Nearby({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyProvider(id));
    final origin = ref.watch(destinationByIdProvider(id)).value;
    if (nearby.isEmpty || origin == null) return const SizedBox.shrink();
    final brand = context.lakbayan;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading("Nearby"),
          const SizedBox(height: AppSpace.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, place) in nearby.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: MediaTile(
                    media: place.coverImage == null
                        ? const ImagePlaceholder(
                            borderRadius: BorderRadius.zero,
                          )
                        : StorageImage(path: place.coverImage!),
                    aspectRatio: 4 / 3,
                    title: place.name,
                    subtitle:
                        "${distanceLabel(distanceBetween(origin, place))} away",
                    subtitleColor: brand.spatial,
                    onTap: () => context.push(Routes.destination(place.id)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The rest of the town, so the screen leads somewhere. Skips this place
/// and the two already shown as Nearby.
class _MoreInTown extends ConsumerWidget {
  const _MoreInTown({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = {
      destination.id,
      for (final place in ref.watch(nearbyProvider(destination.id))) place.id,
    };
    final town = ref
        .watch(townsProvider)
        .where((t) => t.name == destination.town)
        .firstOrNull;
    final others = [
      for (final place in town?.places ?? const <Destination>[])
        if (!shown.contains(place.id)) place,
    ].take(3).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: GroupedSection(
        heading: "More in ${destination.town}",
        children: [
          for (final place in others)
            GroupedRow(
              title: place.name,
              subtitle: place.category.label,
              leading: CoverImage(place.coverImage),
              onTap: () => context.push(Routes.destination(place.id)),
            ),
        ],
      ),
    );
  }
}

/// The one primary action, pinned. Takes its own SafeArea so the surface
/// reaches the edge and the button does not.
class _PinnedAction extends StatelessWidget {
  const _PinnedAction({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.all(AppSpace.gutter),
    child: FilledButton(
      onPressed: () => showAddToItinerary(
        context,
        destinationId: destination.id,
        destinationName: destination.name,
      ),
      child: const Text("Add to itinerary"),
    ),
  );
}
