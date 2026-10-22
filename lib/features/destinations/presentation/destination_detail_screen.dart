import "dart:math" show max;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/app_menu.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/bar_item_group.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../ar/presentation/exhibits_section.dart";
import "../../audio/presentation/audio_guide_section.dart";
import "../../explore/domain/home_tab.dart";
import "../../itineraries/presentation/add_to_itinerary_sheet.dart";
import "../../maps/presentation/map_view.dart" show showDirections;
import "../domain/destination_providers.dart";
import "../domain/place_share.dart";
import "../domain/recently_viewed.dart";
import "save_heart.dart";

/// Place detail. **Job:** decide whether to go, then put it on a trip.
/// **Emotion:** being there already.
///
/// A clean photo stage under the status bar; the page rises over its foot on
/// a rounded edge. Back, and share with the heart, stay pinned. On the page:
/// the name with "kind in town", the lede, the audio guide capsule, a
/// museum's exhibits (Scan an exhibit, D-18), the hours
/// with Plan your visit (a sheet of every fact) and Getting there, the story
/// growing open in place, Around here. Floating: Add to trip. Only name,
/// town, description and coordinates are required in the CMS; any other
/// part is simply absent when empty, and free text renders as written.
class DestinationDetailScreen extends ConsumerStatefulWidget {
  const DestinationDetailScreen({required this.id, this.from, super.key});

  final String id;

  /// The surface the cover flew from; null for a deep link.
  final HeroSource? from;

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
    return destination.whenLocalFirst(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => MessageScreen(
        errorCopy("Couldn't load this destination.", e),
        onRetry: () => ref.invalidate(destinationByIdProvider(widget.id)),
      ),
      data: (d) => d == null
          ? const MessageScreen("This destination is no longer available.")
          : Scaffold(
              body: _PinnedActionScope(
                child: EntranceScope(
                  child: _Content(destination: d, from: widget.from),
                ),
              ),
            ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.destination, required this.from});

  final Destination destination;
  final HeroSource? from;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  /// Read by the photo's drift and by the pinned controls' change of
  /// surface; neither rebuilds the page.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final actionHeight = _PinnedAction.extentOf(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final stage = _PhotoStage.heightOf(context);
    final controlsTop = topInset + AppSpace.x2;
    // The page's edge reaches the controls' foot: from here they sit on the
    // white page rather than on the photo.
    final groundAt =
        stage - _PhotoStage.edge - controlsTop - AppSize.minTouchTarget;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: _PhotoStage(
                destination: destination,
                from: widget.from,
                scroll: _scroll,
                height: stage,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                0,
                AppSpace.gutter,
                actionHeight + AppSpace.section,
              ),
              // The page arrives under the photo in reading order. A lazy
              // list: Around here is not built until it is near.
              sliver: SliverList.list(
                children: [
                  Entrance(child: _Title(destination: destination)),
                  Entrance(order: 1, child: _Lede(destination: destination)),
                  Entrance(order: 2, child: _AudioGuide(id: destination.id)),
                  Entrance(
                    order: 3,
                    child: ExhibitsSection(destination: destination),
                  ),
                  Entrance(order: 4, child: _Visit(destination: destination)),
                  Entrance(order: 5, child: _Story(destination: destination)),
                  Entrance(
                    order: 6,
                    child: _AroundHere(destination: destination),
                  ),
                ],
              ),
            ),
          ],
        ),
        // The photo keeps the status bar at rest; the page's white closes
        // in under it as the name arrives there.
        StatusBarGround.below(scroll: _scroll, contentTop: stage),
        Positioned(
          top: controlsTop,
          left: AppSpace.x2,
          right: AppSpace.x2,
          child: _PinnedControls(
            destination: destination,
            scroll: _scroll,
            groundAt: groundAt,
          ),
        ),
        _PinnedAction(
          label: "Add to trip",
          icon: AppIcons.add,
          onPressed: () => showAddToItinerary(
            context,
            destinationId: destination.id,
            destinationName: destination.name,
          ),
        ),
      ],
    );
  }
}

/// The photos, clean and pageable when there are several. The page's rounded
/// edge sits over their foot, carrying the dots, so the page reads as rising
/// over the photo. As the page scrolls up over it, the photo drifts at half
/// speed.
class _PhotoStage extends StatefulWidget {
  const _PhotoStage({
    required this.destination,
    required this.from,
    required this.scroll,
    required this.height,
  });

  final Destination destination;
  final HeroSource? from;
  final ScrollController scroll;
  final double height;

  /// The page's rounded edge over the photo's foot.
  static const edge = AppSpace.x6;

  /// About this much of the screen goes to the photo, leaving the name and
  /// the lede in view under it.
  static const _share = 0.55;

  /// Just over half the screen, and never shorter than the route map's
  /// header, so a small phone still gets a photo rather than a strip.
  static double heightOf(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    final top = MediaQuery.viewPaddingOf(context).top;
    return max(screen * _share, top + AppSize.routePreview).ceilToDouble();
  }

  @override
  State<_PhotoStage> createState() => _PhotoStageState();
}

class _PhotoStageState extends State<_PhotoStage> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final images = destination.images;
    final from = widget.from;
    final scheme = Theme.of(context).colorScheme;

    final Widget photos = images.isEmpty
        ? const ImagePlaceholder(borderRadius: BorderRadius.zero)
        : PageView.builder(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: images.length,
            // Only the cover carries the tag: it is the one image the tile
            // that opened this screen shares a flight with.
            itemBuilder: (context, i) => i == 0 && from != null
                ? PhotoHero(
                    tag: coverHeroTag(destination.id, from),
                    child: StorageImage(path: images[i]),
                  )
                : StorageImage(path: images[i]),
          );

    return SizedBox(
      height: widget.height,
      // The drifting photo stays inside its stage.
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (MediaQuery.disableAnimationsOf(context))
              photos
            else
              _Drift(scroll: widget.scroll, child: photos),
            // Light status bar icons over the photo only: once the page's
            // paper edge is under the status bar, the icons turn dark.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: _PhotoStage.edge,
              child: SystemBars(overPhoto: true, child: SizedBox.expand()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _PhotoStage.edge,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: AppRadii.sheetTop,
                ),
                child: Center(
                  child: PageDots(count: images.length, current: _page),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo drifts at half the page's scroll speed: a translation read from the
/// scroll offset, photo built once so a scroll repaints without rebuilding.
class _Drift extends StatelessWidget {
  const _Drift({required this.scroll, required this.child});

  final ScrollController scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scroll,
    child: child,
    builder: (context, child) {
      final offset = scroll.hasClients && scroll.offset > 0
          ? scroll.offset
          : 0.0;
      return Transform.translate(offset: Offset(0, offset / 2), child: child);
    },
  );
}

/// The space between the page's parts: more than a section gap, so each part
/// stands on its own without a rule or a card to separate it.
const _block = AppSpace.x6;

/// The name first and large, then what and where as one quiet line: "Nature
/// in Peñablanca". No badges: FEATURED is the feed's business, not this
/// page's.
class _Title extends StatelessWidget {
  const _Title({required this.destination});

  final Destination destination;

  /// The kind as a noun, to sit in front of the town. Null for a kind this
  /// build does not know, which leaves the town alone.
  static String? _kindOf(DestinationCategory category) => switch (category) {
    DestinationCategory.church => "Church",
    DestinationCategory.nature => "Nature",
    DestinationCategory.heritage => "Heritage site",
    DestinationCategory.museum => "Museum",
    DestinationCategory.food => "Place to eat",
    DestinationCategory.landmark => "Landmark",
    DestinationCategory.unknown => null,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The finer kind when the province named one: "Waterfall in Peñablanca"
    // says more than "Nature in Peñablanca".
    final sub = destination.subcategory?.trim();
    final kind = (sub?.isNotEmpty ?? false)
        ? sub
        : _kindOf(destination.category);
    final line = kind == null
        ? destination.town
        : "$kind in ${destination.town}";
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(destination.name, style: AppTypography.hero),
          ),
          const SizedBox(height: AppSpace.x1),
          Text(
            line,
            style: AppTypography.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The description, the CMS's one sentence about the place, set as the lede:
/// larger than reading text and lighter than a heading, the page's one
/// emphasised line.
class _Lede extends StatelessWidget {
  const _Lede({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final description = destination.description.trim();
    if (description.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x4),
      child: Text(description, style: AppTypography.lede),
    );
  }
}

/// Back alone on its circle at the leading top; share and the heart on one
/// white capsule at the trailing top (PREFERENCES: symbols over a photo
/// share one capsule, back stays alone). Pinned, so back is always one tap
/// away. Once the page is under them they take the grey step up, as a
/// control on the white page does (`SymbolButton.onGround`): once, on the
/// chrome spring, when the page crosses them, not on every scroll frame.
class _PinnedControls extends ConsumerStatefulWidget {
  const _PinnedControls({
    required this.destination,
    required this.scroll,
    required this.groundAt,
  });

  final Destination destination;
  final ScrollController scroll;

  /// The scroll offset at which the page's edge reaches the controls.
  final double groundAt;

  @override
  ConsumerState<_PinnedControls> createState() => _PinnedControlsState();
}

class _PinnedControlsState extends ConsumerState<_PinnedControls> {
  bool _onGround = false;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_check);
  }

  @override
  void didUpdateWidget(_PinnedControls old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_check);
      widget.scroll.addListener(_check);
    }
    _check();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final scroll = widget.scroll;
    final onGround = scroll.hasClients && scroll.offset > widget.groundAt;
    if (onGround != _onGround) setState(() => _onGround = onGround);
  }

  /// The place as text, to the phone's share sheet (`placeShareText`), and
  /// a word when the sheet will not open. Closing it unshared says nothing.
  Future<void> _share() async {
    // Resolved before the await, which the sheet holds open until it closes.
    final messenger = ScaffoldMessenger.of(context);
    final place = widget.destination;
    try {
      await ref.read(textSharerProvider)(
        placeShareText(place),
        subject: placeShareSubject(place),
      );
    } catch (e) {
      // Logged, because the snackbar reads the same for a bug as for a phone
      // with no share sheet.
      debugPrint("Share failed: $e");
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't open sharing on this device."),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = widget.destination.id;
    return AppMotionBuilder(
      end: _onGround ? 1 : 0,
      builder: (context, t, _) {
        final tone = Color.lerp(
          context.lakbayan.glass,
          scheme.surfaceContainerLowest,
          t.clamp(0.0, 1.0),
        )!;
        return Row(
          children: [
            SymbolButton(
              icon: AppIcons.back,
              tooltip: "Back",
              onTap: context.popOrHome,
              background: tone,
            ),
            const Spacer(),
            BarItemGroup.overMedia(
              background: tone,
              items: [
                BarItem(
                  icon: AppIcons.share,
                  tooltip: "Share",
                  onPressed: _share,
                ),
                BarItem.control(SaveHeart(id, style: SaveHeartStyle.bar)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A CMS free-text fact, trimmed, or null when the editor left it empty.
String? _fact(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Visiting, in as few words as it takes: the hours on one line, the one
/// fact that decides whether to go now; then two quiet buttons. Plan your
/// visit opens a sheet with every practical fact in full and the tags;
/// Getting there opens a menu from itself with On the map and Directions.
class _Visit extends ConsumerWidget {
  const _Visit({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final practical = destination.practical;
    final hours = _fact(practical?.openHours);
    final plan =
        hours != null ||
        _fact(practical?.entryFee) != null ||
        _fact(practical?.bestSeason) != null ||
        _fact(practical?.accessibility) != null ||
        destination.tags.any((tag) => tag.trim().isNotEmpty);

    void onTheMap() {
      ref.read(mapSelectedIdProvider.notifier).select(destination.id);
      ref.read(browseShowsGridProvider.notifier).set(false);
      ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
      context.go(Routes.home);
    }

    return Padding(
      padding: const EdgeInsets.only(top: _block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hours != null) ...[
            Semantics(
              label: "Hours, $hours",
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // Onto the first line's centre.
                    padding: const EdgeInsets.only(top: AppSpace.x1 / 2),
                    child: Icon(
                      AppIcons.clock,
                      size: AppSize.glyph,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(child: Text(hours, style: AppTypography.bodyLarge)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.x3),
          ],
          Row(
            children: [
              if (plan) ...[
                Expanded(
                  child: Pressable(
                    child: OutlinedButton(
                      onPressed: () => showAppSheet<void>(
                        context,
                        builder: (_) => _PlanSheet(destination: destination),
                      ),
                      child: const Text(
                        "Plan your visit",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.x2),
              ],
              Expanded(
                // The menu grows out of the button that opened it (doc 04).
                child: AppMenu(
                  groups: [
                    [
                      AppMenuItem(
                        label: "On the map",
                        icon: AppIcons.map,
                        onSelected: onTheMap,
                      ),
                      AppMenuItem(
                        label: "Directions",
                        icon: AppIcons.directions,
                        onSelected: () => showDirections(context, destination),
                      ),
                    ],
                  ],
                  builder: (context, controller) => Pressable(
                    child: OutlinedButton(
                      onPressed: controller.isOpen
                          ? controller.close
                          : controller.open,
                      child: const Text(
                        "Getting there",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plan your visit: every practical fact the CMS holds, each in full under
/// its name, then what the place is known for, its tags, as capsules.
class _PlanSheet extends StatelessWidget {
  const _PlanSheet({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final practical = destination.practical;
    final facts = [
      if (_fact(practical?.openHours) case final hours?)
        (icon: AppIcons.clock, label: "Hours", value: hours),
      if (_fact(practical?.entryFee) case final fee?)
        (icon: AppIcons.entry, label: "Entry", value: fee),
      if (_fact(practical?.bestSeason) case final season?)
        (icon: AppIcons.season, label: "Best time", value: season),
      if (_fact(practical?.accessibility) case final access?)
        (icon: AppIcons.info, label: "Access", value: access),
    ];
    final tags = [
      for (final tag in destination.tags)
        if (tag.trim().isNotEmpty) tag.trim(),
    ];

    return AppSheet(
      title: "Plan your visit",
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: SliverList.list(
            children: [
              for (final (index, fact) in facts.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpace.x4),
                _PlanFact(
                  icon: fact.icon,
                  label: fact.label,
                  value: fact.value,
                ),
              ],
              if (tags.isNotEmpty) ...[
                if (facts.isNotEmpty) const SizedBox(height: _block),
                Text(
                  "Known for",
                  style: AppTypography.labelMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.x2),
                Wrap(
                  spacing: AppSpace.x2,
                  runSpacing: AppSpace.x2,
                  children: [
                    for (final tag in tags)
                      LakbayanBadge(tag, kind: BadgeKind.info),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One practical fact in the sheet: its glyph, its name small, its value in
/// full at reading size.
class _PlanFact extends StatelessWidget {
  const _PlanFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSize.glyph, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.secondLine.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: AppTypography.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The audio guide as one capsule, right under the lede: listening is what
/// the app is for once you are there. Absent entirely when the place has no
/// stops.
///
/// Unlike the page's optional parts it does not simply vanish while it is
/// not ready: until the stops arrive, a quiet capsule holds its place, and
/// if they cannot be read, it says so and offers another try. Stops already
/// on the phone are shown even when a later read fails.
class _AudioGuide extends ConsumerWidget {
  const _AudioGuide({required this.id});

  final String id;

  /// The capsule's height at rest: its play button inside a ring of `x1`.
  static const _capsule = AppSize.minTouchTarget + 2 * AppSpace.x1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget? guide = ref
        .watch(destinationSegmentsProvider(id))
        .whenLocalFirst(
          loading: () => const ImagePlaceholder(
            height: _capsule,
            borderRadius: capsuleRadius,
          ),
          error: (error, _) => QuietNote(
            errorCopy("Couldn't load the audio guide.", error),
            onRetry: () => ref.invalidate(destinationSegmentsProvider(id)),
          ),
          data: (stops) => stops.isEmpty
              ? null
              // The capsule names itself, so no heading over it.
              : AudioGuideSection(destinationId: id, segments: stops),
        );
    if (guide == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: _block),
      child: guide,
    );
  }
}

/// The history under its own heading, at full reading weight, cut at a
/// deliberate three lines so it stops mid-thought: a hook, not a caption.
/// Continue reading grows it open in place on the chrome spring, and Show
/// less folds it back the same way; under reduced motion the two cross-fade.
class _Story extends StatefulWidget {
  const _Story({required this.destination});

  final Destination destination;

  @override
  State<_Story> createState() => _StoryState();
}

class _StoryState extends State<_Story> {
  bool _expanded = false;

  static const _collapsedLines = 3;

  static const _grow = AppMotion.span;
  static final _spring = SpringCurve(AppMotion.chrome, _grow);

  @override
  Widget build(BuildContext context) {
    final history = widget.destination.history?.trim() ?? "";
    if (history.isEmpty) return const SizedBox.shrink();
    final text = Text(
      history,
      style: AppTypography.bodyLarge,
      maxLines: _expanded ? null : _collapsedLines,
      overflow: _expanded ? null : TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.only(top: _block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading("The story"),
          const SizedBox(height: AppSpace.x2),
          if (MediaQuery.disableAnimationsOf(context))
            FadeSwap(id: _expanded, alignment: Alignment.topLeft, child: text)
          else
            AnimatedSize(
              duration: _grow,
              curve: _spring,
              alignment: Alignment.topCenter,
              child: text,
            ),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: FadeSwap(
              id: _expanded,
              alignment: Alignment.centerLeft,
              child: Text(_expanded ? "Show less" : "Continue reading"),
            ),
          ),
        ],
      ),
    );
  }
}

/// The nearest places, their distance on the photo, then the rest of the
/// town: one rail, so the screen leads somewhere without another list.
class _AroundHere extends ConsumerWidget {
  const _AroundHere({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike: an ending to
    // the page, not its subject, which is already on screen.
    final places = ref.watch(aroundHereProvider(destination.id));
    if (places.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: _block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading("Around here"),
          const SizedBox(height: AppSpace.x1),
          SizedBox(
            height: AppSize.railTile * 5 / 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
              itemBuilder: (context, index) {
                final (:place, :line) = places[index];
                return SizedBox(
                  width: AppSize.railTile,
                  child: MediaTile(
                    // A neighbour's photo opens into its page, as every
                    // place photo does.
                    media: PhotoHero(
                      tag: coverHeroTag(place.id, HeroSource.around),
                      child: CoverImage(place.coverImage),
                    ),
                    aspectRatio: 4 / 5,
                    overlay: true,
                    dense: true,
                    title: place.name,
                    subtitle: line,
                    onTap: () => context.push(
                      Routes.destination(place.id, from: HeroSource.around),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Add to trip, floating at the bottom trailing corner: a green capsule that
/// folds to its glyph while reading. Takes its own `SafeArea`.
class _PinnedAction extends StatelessWidget {
  const _PinnedAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// The button, its gutter all round, and the gesture inset under it.
  static double extentOf(BuildContext context) =>
      AppSize.primaryButton +
      AppSpace.gutter * 2 +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final compact = _Compact.of(context);
    return Positioned(
      right: 0,
      bottom: 0,
      // Own RepaintBoundary so folding repaints only the action.
      child: RepaintBoundary(
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(AppSpace.gutter),
          child: Pressable(
            enabled: onPressed != null,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.square(AppSize.primaryButton),
                  padding: const EdgeInsets.symmetric(
                    horizontal: (AppSize.primaryButton - AppSize.glyph) / 2,
                  ),
                ),
                child: Semantics(
                  label: label,
                  excludeSemantics: true,
                  child: AppMotionBuilder(
                    end: compact ? 0 : 1,
                    builder: (context, t, _) {
                      final open = t.clamp(0.0, 1.0);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: AppSize.glyph),
                          if (open > 0)
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: open,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpace.x2,
                                  ),
                                  child: Opacity(
                                    opacity: open,
                                    child: Text(label, maxLines: 1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Folds [_PinnedAction] after a deliberate scroll down, opens it on a scroll
/// up or at the top, and keeps it folded at the bottom over the last row.
class _PinnedActionScope extends StatefulWidget {
  const _PinnedActionScope({required this.child});

  final Widget child;

  @override
  State<_PinnedActionScope> createState() => _PinnedActionScopeState();
}

class _PinnedActionScopeState extends State<_PinnedActionScope> {
  bool _compact = false;
  double _travel = 0;

  static const _foldAfter = AppSpace.x12;
  static const _openAfter = AppSpace.x6;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical || notification.depth != 0) return false;
    if (notification is! ScrollUpdateNotification) return false;
    final atTop = metrics.pixels <= metrics.minScrollExtent;
    final atBottom = metrics.pixels >= metrics.maxScrollExtent;
    final delta = notification.scrollDelta ?? 0;
    if ((delta > 0) != (_travel > 0)) _travel = 0;
    _travel += delta;
    final compact = atTop
        ? false
        : atBottom
        ? true
        : _travel > _foldAfter
        ? true
        : _travel < -_openAfter
        ? false
        : _compact;
    if (compact != _compact) setState(() => _compact = compact);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _Compact(compact: _compact, child: widget.child),
      );
}

class _Compact extends InheritedWidget {
  const _Compact({required this.compact, required super.child});

  final bool compact;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Compact>()?.compact ?? false;

  @override
  bool updateShouldNotify(_Compact old) => compact != old.compact;
}
