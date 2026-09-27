import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/domain/saved_destinations.dart";
import "../../destinations/presentation/browse_screen.dart";
import "../../destinations/presentation/save_heart.dart";
import "../../explore/domain/home_chrome.dart";
import "map_top_controls.dart";
import "map_view.dart";

/// The Map tab. **Job:** find places by where they are. **Emotion:**
/// orientation.
///
/// A real map under the filters, grid toggle and route ([MapTopControls]).
/// At its foot a parallel sheet, no scrim: at rest the area's name and a row
/// of place cards that is one selection with the pins; pulled up, the full
/// list with each place's distance from the chosen pin. Browse is the same
/// results as photos, one toggle away.
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
            // Under the controls, not behind them.
            error: (error, _) => Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                topInset + AppSpace.x2 + MapTopControls.extent(context),
                AppSpace.gutter,
                0,
              ),
              child: QuietNote("Couldn't load destinations.\n$error"),
            ),
            // The map takes the results whether or not there are any; a blank
            // where a map should be would read as a failure to load.
            data: (items) => MapView(destinations: items),
          ),
        ),
        Positioned(
          top: topInset + AppSpace.x2,
          left: 0,
          right: 0,
          child: const MapTopControls(),
        ),
        if (results case AsyncData(:final value)) _PlacesSheet(items: value),
      ],
    );
  }
}

/// The parallel sheet: the grip and the area's name pinned at its top, the
/// rail at rest, the full list above it. No scrim, because the map stays usable while it is up (design
/// doc 04). Dragged above rest, the bar slides away so the sheet has the
/// bottom of the screen; dropped back, the bar returns.
class _PlacesSheet extends ConsumerStatefulWidget {
  const _PlacesSheet({required this.items});

  final List<Destination> items;

  static const _maxSize = AppSheetSize.mapMax;

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

  /// The resting face: the header, then the rail and its dots, measured at
  /// the person's text size rather than a fixed number.
  double _restHeight(BuildContext context) =>
      _SheetHeader.heightOf(context) +
      (widget.items.isEmpty
          ? AppSize.minTouchTarget
          : _PlacePeekRail.heightOf(context)) +
      AppSpace.x3;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final scheme = Theme.of(context).colorScheme;
    final selectedId = ref.watch(mapSelectedIdProvider);
    final query = ref.watch(browseQueryProvider).trim();
    final selected = items.where((d) => d.id == selectedId).firstOrNull;
    // Nearest first from the chosen pin, in the list only: the rail keeps
    // the map's order so its cards stay where they were swiped.
    final rows = selected == null
        ? items
        : ([...items]..sort(
            (a, b) => distanceBetween(
              selected,
              a,
            ).compareTo(distanceBetween(selected, b)),
          ));
    final title = selected?.town ?? (query.isEmpty ? "Cagayan" : query);
    final barHeight = FloatingTabBar.clearance(context);
    final barHidden = ref.watch(homeChromeProvider) == HomeChromeState.hidden;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    return LayoutBuilder(
      builder: (context, constraints) {
        final restSize =
            ((barHeight + _restHeight(context)) / constraints.maxHeight).clamp(
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
              // Slivers so a full province's results builds only visible rows.
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SheetHeader(
                      title: title,
                      extent: _SheetHeader.heightOf(context),
                      color: scheme.surface,
                      grip: scheme.outlineVariant,
                    ),
                  ),
                  if (items.isEmpty)
                    const SliverPadding(
                      padding: gutter,
                      sliver: SliverToBoxAdapter(
                        child: QuietNote("Nothing matches those filters."),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _PlacePeekRail(items: items)),
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        AppSpace.section,
                        AppSpace.gutter,
                        AppSpace.x1,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: SectionHeading("Everything on the map"),
                      ),
                    ),
                    SliverPadding(
                      padding: gutter,
                      sliver: SliverGroupedSection(
                        itemCount: rows.length,
                        itemBuilder: (context, index) => _PlaceRow(
                          place: rows[index],
                          from: selected,
                          distanceColor: context.lakbayan.spatial,
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          (barHidden ? bottomInset : barHeight) +
                          AppSpace.section,
                    ),
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

/// One place in the full list. The second line is the distance from the
/// chosen pin, in blue, or the town when nothing is chosen. Saved places
/// carry the heart; the rest a chevron.
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
      leading: PhotoHero(
        tag: coverHeroTag(place.id, HeroSource.map),
        child: CoverImage(place.coverImage),
      ),
      trailing: saved ? SaveHeart(place.id, style: SaveHeartStyle.row) : null,
      onTap: () =>
          context.push(Routes.destination(place.id, from: HeroSource.map)),
    );
  }
}

/// The sheet's grip: the handle and the area's name, pinned at the top of
/// the sheet's scroll so they stay while the list moves under them.
class _SheetHeader extends SliverPersistentHeaderDelegate {
  const _SheetHeader({
    required this.title,
    required this.extent,
    required this.color,
    required this.grip,
  });

  final String title;
  final double extent;
  final Color color;
  final Color grip;

  /// Rounded up, line by line: the laid-out text can land a fraction above
  /// its nominal line height, and a pinned header has no room to give.
  static double heightOf(BuildContext context) {
    final title = MediaQuery.textScalerOf(context)
        .lineHeightOf(AppTypography.titleMedium)
        .ceilToDouble();
    return AppSpace.x2 +
        AppSize.dragHandleHeight +
        AppSpace.x2 +
        title +
        AppSpace.x2 +
        1;
  }

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      ColoredBox(
        color: color,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.x2,
            AppSpace.gutter,
            AppSpace.x2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: AppSize.dragHandleWidth,
                  height: AppSize.dragHandleHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: grip,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.x2),
              Text(
                title,
                style: AppTypography.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );

  @override
  bool shouldRebuild(_SheetHeader old) =>
      old.title != title ||
      old.extent != extent ||
      old.color != color ||
      old.grip != grip;
}

/// The places on the map as a row of cards on the sheet's resting face, one
/// card a page with the dots under it saying there are more ([PageDots]).
/// It and the pins are one selection:
/// swiping a card to the middle selects its pin, and the camera glides
/// there; tapping a pin brings its card to the middle.
///
/// A card is the place's photo, wide, with its name and town on it.
class _PlacePeekRail extends ConsumerStatefulWidget {
  const _PlacePeekRail({required this.items});

  final List<Destination> items;

  /// A wide photo card and the dots under it. Fixed: the caption is on the
  /// photo, so text size does not change the card's height.
  static double heightOf(BuildContext context) =>
      AppSize.mapCard + _dotsGap + AppSize.pageDot;

  static const _dotsGap = AppSpace.x2;

  @override
  ConsumerState<_PlacePeekRail> createState() => _PlacePeekRailState();
}

class _PlacePeekRailState extends ConsumerState<_PlacePeekRail> {
  final _pages = PageController();
  int _page = 0;

  static const _turn = Duration(milliseconds: 450);

  /// True while the rail turns to a pin's card, so the pages it passes on
  /// the way do not each select their own pin.
  bool _following = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// A pin chosen on the map turns the rail to its card, on the spring.
  void _follow(String? previous, String? next) {
    final index = widget.items.indexWhere((place) => place.id == next);
    if (index < 0 || !_pages.hasClients) return;
    if ((_pages.page ?? 0).round() == index) return;
    _following = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
      _following = false;
    } else {
      _pages
          .animateToPage(
            index,
            duration: _turn,
            curve: SpringCurve(AppMotion.chrome, _turn),
          )
          .whenComplete(() => _following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(mapSelectedIdProvider, _follow);
    final items = widget.items;
    return SizedBox(
      height: _PlacePeekRail.heightOf(context),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: items.length,
              // A card settling on the page is a choice, the same as its pin.
              onPageChanged: (index) {
                setState(() => _page = index);
                if (_following) return;
                ref
                    .read(mapSelectedIdProvider.notifier)
                    .select(items[index].id);
              },
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter,
                ),
                child: Center(
                  child: SizedBox(
                    height: AppSize.mapCard,
                    child: _Card(place: items[index]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _PlacePeekRail._dotsGap),
          PageDots(count: items.length, current: _page),
        ],
      ),
    );
  }
}

/// The place as a wide photo, its name and town on the photo's scrim, the
/// heart on its corner: the map's card is the place itself, not a row about
/// it.
class _Card extends StatelessWidget {
  const _Card({required this.place});

  final Destination place;

  @override
  Widget build(BuildContext context) => MediaTile(
    media: PhotoHero(
      tag: coverHeroTag(place.id, HeroSource.mapCard),
      child: CoverImage(place.coverImage),
    ),
    aspectRatio: 2.4,
    overlay: true,
    dense: true,
    title: place.name,
    subtitle: place.town,
    badge: place.hasAR ? const LakbayanBadge.ar() : null,
    trailing: SaveHeart(place.id, style: SaveHeartStyle.tile),
    onTap: () =>
        context.push(Routes.destination(place.id, from: HeroSource.mapCard)),
  );
}
