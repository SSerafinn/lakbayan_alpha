import "package:flutter/foundation.dart" show listEquals;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/presentation/browse_screen.dart";
import "../../destinations/presentation/place_photo.dart";
import "../../explore/domain/home_chrome.dart";
import "../../explore/domain/home_tab.dart";
import "map_top_controls.dart";
import "map_view.dart";

/// The Map tab. **Job:** find places by where they are. **Emotion:**
/// orientation.
///
/// A real map under the filters, grid toggle and route ([MapTopControls]).
/// At its foot a panel, no scrim: the area's name and a row of photo cards
/// that is one selection with the pins, each with how far from the chosen
/// one (D-19). Browse is every result as photos, one toggle away.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  final _controlsKey = GlobalKey();
  final _panelKey = GlobalKey();
  final _viewportChanges = ValueNotifier<int>(0);
  bool _viewportPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() => _viewportChanged();

  /// Read layout only on camera events, never poll it or resize the map on
  /// each sheet tick. The bounds include cutouts and the measured controls.
  Rect? _visibleMapBounds() {
    final box = context.findRenderObject() as RenderBox?;
    final controls =
        _controlsKey.currentContext?.findRenderObject() as RenderBox?;
    final panel = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null ||
        !box.hasSize ||
        controls == null ||
        !controls.hasSize ||
        panel == null ||
        !panel.hasSize) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero);
    final safe = MediaQuery.viewPaddingOf(context);
    final top = controls.localToGlobal(Offset(0, controls.size.height)).dy;
    final bottom = panel.localToGlobal(Offset.zero).dy;
    return Rect.fromLTRB(
      origin.dx + safe.left,
      top,
      origin.dx + box.size.width - safe.right,
      bottom,
    );
  }

  void _viewportChanged() {
    if (_viewportPending) return;
    _viewportPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportPending = false;
      if (mounted) _viewportChanges.value++;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewportChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(browseShowsGridProvider, (_, _) {
      // A fresh view can be too short to produce reverse scroll travel.
      // Keep navigation reachable after either view toggle.
      if (ref.read(selectedHomeTabProvider) == HomeTab.map) {
        ref.read(homeChromeProvider.notifier).expand();
      }
    });
    final showsGrid = ref.watch(browseShowsGridProvider);
    if (showsGrid) {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical &&
              notification is ScrollUpdateNotification &&
              ref.read(selectedHomeTabProvider) == HomeTab.map) {
            final chrome = ref.read(homeChromeProvider.notifier);
            if (notification.metrics.pixels <=
                notification.metrics.minScrollExtent) {
              chrome.expand();
            } else {
              chrome.onMapTravel(notification.scrollDelta ?? 0);
            }
          }
          return true;
        },
        child: const BrowseScreen(),
      );
    }

    final results = ref.watch(mapResultsProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: results.whenLocalFirst(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            // The map takes the results whether or not there are any; a blank
            // where a map should be would read as a failure to load.
            data: (items) => MapView(
              destinations: items,
              visibleBounds: _visibleMapBounds,
              viewportChanges: _viewportChanges,
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.x2),
              child: NotificationListener<ScrollNotification>(
                // The panel handles direction itself; do not also collapse
                // navigation through the shell's ordinary-feed listener.
                onNotification: (_) => true,
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: SingleChildScrollView(
                            child: Column(
                              key: _controlsKey,
                              children: const [
                                MapTopControls(),
                                SizedBox(height: AppSpace.x2),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: results.whenLocalFirst(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => QuietNote(
                            errorCopy("Couldn't load destinations.", error),
                            onRetry: () => ref.invalidate(
                              browseSource(ref.read(browseCategoryProvider)),
                            ),
                          ),
                          data: (items) => _PlacesSheet(
                            items: items,
                            surfaceKey: _panelKey,
                            onViewportChanged: _viewportChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact photos at rest; pull up or press Expand for the province's grid.
/// No scrim: the map remains usable above this parallel task.
class _PlacesSheet extends ConsumerStatefulWidget {
  const _PlacesSheet({
    required this.items,
    required this.surfaceKey,
    required this.onViewportChanged,
  });

  final List<Destination> items;
  final GlobalKey surfaceKey;
  final VoidCallback onViewportChanged;

  @override
  ConsumerState<_PlacesSheet> createState() => _PlacesSheetState();
}

class _PlacesSheetState extends ConsumerState<_PlacesSheet> {
  final _sheet = DraggableScrollableController();
  double? _lastExtent;
  bool _extentChanged = false;

  void _settled() {
    if (!mounted || !_extentChanged) return;
    _extentChanged = false;
    widget.onViewportChanged();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return true;
    if (notification is ScrollUpdateNotification &&
        ref.read(selectedHomeTabProvider) == HomeTab.map) {
      ref
          .read(homeChromeProvider.notifier)
          .onMapTravel(notification.scrollDelta ?? 0);
    } else if (notification is ScrollEndNotification) {
      _settled();
    }
    return true;
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.items;
    final selectedId = ref.watch(mapSelectedIdProvider);
    final query = ref.watch(browseQueryProvider).trim();
    final selected = items.where((d) => d.id == selectedId).firstOrNull;
    final photos = ref.watch(mapPhotoSectionsProvider);
    final title = selected?.town ?? (query.isEmpty ? "Cagayan" : query);
    final headerHeight = AppSheetHeader.heightOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight <= 0) return const SizedBox.shrink();
        final rest =
            ((headerHeight +
                        _PlacePeekRail.heightOf(
                          constraints.maxWidth -
                              MediaQuery.paddingOf(context).horizontal,
                        ) +
                        AppSpace.x3 +
                        FloatingTabBar.clearance(context)) /
                    constraints.maxHeight)
                .clamp(0.0, 1.0);
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            final previous = _lastExtent ?? rest;
            _lastExtent = notification.extent;
            _extentChanged = true;
            if (ref.read(selectedHomeTabProvider) == HomeTab.map) {
              final chrome = ref.read(homeChromeProvider.notifier);
              chrome.onMapTravel(
                (notification.extent - previous) * constraints.maxHeight,
              );
              if (notification.extent <= notification.minExtent) {
                chrome.expand();
              }
            }
            return true;
          },
          child: DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: rest,
            minChildSize: rest,
            maxChildSize: 1,
            builder: (context, scrollController) => Material(
              key: widget.surfaceKey,
              color: scheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadii.sheetTop,
              ),
              clipBehavior: Clip.antiAlias,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: AppSheetHeader(
                          title: title,
                          onToggle: () {
                            final target = _sheet.size > rest + 0.02
                                ? rest
                                : 1.0;
                            if (MediaQuery.disableAnimationsOf(context)) {
                              _sheet.jumpTo(target);
                              _settled();
                            } else {
                              _sheet
                                  .animateTo(
                                    target,
                                    duration: AppMotion.span,
                                    curve: SpringCurve(
                                      AppMotion.chrome,
                                      AppMotion.span,
                                    ),
                                  )
                                  .whenComplete(_settled);
                            }
                          },
                        ),
                      ),
                      if (items.isEmpty)
                        const SliverToBoxAdapter(
                          child: QuietNote("Nothing matches those filters."),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: _PlacePeekRail(
                            items: photos.rail,
                            from: selected,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.all(AppSpace.gutter),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: AppSpace.near,
                                  crossAxisSpacing: AppSpace.near,
                                  childAspectRatio: 7 / 8,
                                ),
                            itemCount: photos.grid.length,
                            itemBuilder: (context, index) => PlacePhoto(
                              key: ValueKey(photos.grid[index].id),
                              place: photos.grid[index],
                              from: HeroSource.browse,
                              aspectRatio: 7 / 8,
                              tags: false,
                              onOpen: () => ref
                                  .read(mapSelectedIdProvider.notifier)
                                  .select(photos.grid[index].id),
                            ),
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              FloatingTabBar.clearance(context) +
                              AppSpace.section,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The places on the map as a row of cards on the sheet's resting face, one
/// card a page with the dots under it saying there are more ([PageDots]).
/// It and the pins are one selection:
/// swiping a card to the middle selects its pin, and the camera glides
/// there; tapping a pin brings its card to the middle.
///
/// A card is the place's photo, 16:10, its name on it and how far from the
/// chosen pin; the next card and a slice of the one after peek in at the
/// trailing edge (D-19), so the panel leaves most of the screen to the map.
class _PlacePeekRail extends ConsumerStatefulWidget {
  const _PlacePeekRail({required this.items, required this.from});

  final List<Destination> items;
  final Destination? from;

  /// How much of the row one card takes, so the next shows.
  static const _fraction = 0.6;

  /// A card's width over its height.
  static const aspectRatio = 16 / 10;

  /// A card's height at this screen's width, and the dots under it. The
  /// caption is on the photo, so text size does not change it.
  static double heightOf(double width) =>
      _cardHeight(width) + _dotsGap + AppSize.pageDot;

  static double _cardHeight(double width) =>
      (width - AppSpace.gutter) * _fraction / aspectRatio;

  static const _dotsGap = AppSpace.x2;

  @override
  ConsumerState<_PlacePeekRail> createState() => _PlacePeekRailState();
}

class _PlacePeekRailState extends ConsumerState<_PlacePeekRail> {
  late int _page = widget.items
      .indexWhere((place) => place.id == widget.from?.id)
      .clamp(0, widget.items.length - 1);
  late final _pages = PageController(
    viewportFraction: _PlacePeekRail._fraction,
    initialPage: _page,
  );

  static const _turn = Duration(milliseconds: 450);

  /// True while the rail turns to a pin's card, so the pages it passes on
  /// the way do not each select their own pin.
  bool _following = false;
  int _followRevision = 0;

  @override
  void didUpdateWidget(_PlacePeekRail old) {
    super.didUpdateWidget(old);
    if (listEquals(
      old.items.map((place) => place.id).toList(),
      widget.items.map((place) => place.id).toList(),
    )) {
      return;
    }
    final revision = ++_followRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients || revision != _followRevision) return;
      final index = widget.items.indexWhere(
        (place) => place.id == widget.from?.id,
      );
      _following = true;
      _pages.jumpToPage(index < 0 ? 0 : index);
      setState(() => _page = index < 0 ? 0 : index);
      _following = false;
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// A pin chosen on the map turns the rail to its card, on the spring.
  void _follow(String? previous, String? next) {
    final index = widget.items.indexWhere((place) => place.id == next);
    if (index < 0 || !_pages.hasClients) return;
    if ((_pages.page ?? 0).round() == index && !_following) return;
    final revision = ++_followRevision;
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
          .whenComplete(() {
            if (mounted && revision == _followRevision) _following = false;
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(mapSelectedIdProvider, _follow);
    final items = widget.items;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: _PlacePeekRail.heightOf(constraints.maxWidth),
        child: Column(
          children: [
            Expanded(
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) {
                    _followRevision++;
                    _following = false;
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pages,
                  padEnds: false,
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
                    padding: EdgeInsets.only(
                      left: index == 0 ? AppSpace.gutter : AppSpace.x1,
                      right: AppSpace.x1,
                    ),
                    child: _Card(
                      key: ValueKey(items[index].id),
                      place: items[index],
                      from: widget.from,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _PlacePeekRail._dotsGap),
            PageDots(count: items.length, current: _page),
          ],
        ),
      ),
    );
  }
}

/// The place as its photo, its name on the scrim and how far it is from the
/// chosen pin on glass (the scan glyph instead for the chosen one, when it
/// has exhibits): the map's card is the place itself, not a row about it.
class _Card extends StatelessWidget {
  const _Card({required this.place, required this.from, super.key});

  final Destination place;
  final Destination? from;

  @override
  Widget build(BuildContext context) {
    final origin = from;
    final measured = origin != null && origin.id != place.id;
    return PlacePhoto(
      place: place,
      from: HeroSource.mapCard,
      aspectRatio: _PlacePeekRail.aspectRatio,
      radius: AppRadii.md,
      tags: false,
      pill: measured
          ? PhotoPill(distanceLabel(distanceBetween(origin, place)))
          : place.hasAR
          ? const PhotoPill.scan()
          : null,
    );
  }
}
