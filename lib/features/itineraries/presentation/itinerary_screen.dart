import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart" show listEquals;
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:motor/motor.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/app_menu.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/bar_item_group.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";
import "../../maps/domain/map_route.dart";
import "../domain/itinerary_actions.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "route_map.dart";
import "stop_picker.dart";
import "stop_strip.dart";
import "trip_dates.dart";

/// Trip detail screen. Route map header (expandable into full-screen with stop
/// strip), stop timeline below, reorder/add/remove actions. List is shown
/// optimistically and snaps to stored order on write failure.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({required this.id, this.added, super.key});

  final String id;

  /// A stop just put on this trip, to scroll to and land.
  final String? added;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(itineraryByIdProvider(id))
      .whenLocalFirst(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        // The trip is derived from the list of them, so the list is what is
        // tried again.
        error: (e, _) => MessageScreen(
          errorCopy("Couldn't load this itinerary.", e),
          onRetry: () => ref.invalidate(myItinerariesProvider),
        ),
        data: (itinerary) => itinerary == null
            ? const MessageScreen("This itinerary is no longer here.")
            : _Overview(itinerary: itinerary, added: added),
      );
}

class _Overview extends ConsumerStatefulWidget {
  const _Overview({required this.itinerary, required this.added});

  final Itinerary itinerary;
  final String? added;

  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  bool _reordering = false;

  /// The route map grown into the screen, with the strip of stops over it.
  bool _expanded = false;

  /// The stop the strip is showing and the map is flown to; null frames them
  /// all, which is where the expanded map starts.
  int? _focused;

  /// A page turn the screen started (a pin tap), so the pages it passes do
  /// not each fly the map.
  bool _turning = false;

  final _scroll = ScrollController();
  final _strip = PageController(
    viewportFraction: StopStrip.viewportFraction,
    keepPage: false,
  );

  /// The order on screen while a write is in flight; null once the stored
  /// order has caught up.
  List<String>? _optimistic;

  /// Stops that grow in when they first build.
  late final Set<String> _arriving = {?widget.added};

  /// Stops folding away before their removal is written.
  final _leaving = <String>{};

  /// Rows that just moved, and how many rows they came from. Keyed with
  /// [_moveGeneration] so each move starts its slide afresh.
  Map<String, int> _shifts = const {};
  int _moveGeneration = 0;

  /// The row for [widget.added], to scroll it into view once.
  final _addedKey = GlobalKey();

  Itinerary get itinerary => widget.itinerary;
  List<String> get _stops => _optimistic ?? itinerary.destinationIds;

  @override
  void initState() {
    super.initState();
    if (widget.added != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final target = _addedKey.currentContext;
        if (target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Durations.medium2,
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _strip.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Overview old) {
    super.didUpdateWidget(old);
    final pending = _optimistic;
    if (pending != null && listEquals(pending, itinerary.destinationIds)) {
      _optimistic = null;
    }
  }

  Future<void> _write(List<String> next) async {
    setState(() => _optimistic = next);
    final landed = await ref
        .read(itineraryActionsProvider)
        .setStops(itinerary.id, next);
    if (!mounted || landed) return;
    setState(() => _optimistic = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't save that change. Try again.")),
    );
  }

  void _move(int from, int to) {
    final next = [..._stops];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() {
      _moveGeneration++;
      // Each row starts where it was and slides to where it is now.
      _shifts = {moved: from - to, _stops[to]: to - from};
    });
    _write(next);
  }

  void _remove(String stop) {
    // Under reduced motion there is no fold to wait for.
    if (MediaQuery.disableAnimationsOf(context)) return _removed(stop);
    setState(() => _leaving.add(stop));
  }

  void _removed(String stop) {
    _leaving.remove(stop);
    _write([..._stops]..remove(stop));
  }

  Future<void> _addStops() async {
    final picked = await showAppSheet<Set<String>>(
      context,
      builder: (_) => _AddStopsSheet(itineraryId: itinerary.id),
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    _arriving.addAll(picked);
    await _write([..._stops, ...picked]);
  }

  void _openOnMap() {
    ref.read(browseQueryProvider.notifier).update("");
    ref.read(browseCategoryProvider.notifier).select(null);
    ref.read(mapShowsSavedProvider.notifier).set(false);
    ref.read(browseShowsGridProvider.notifier).set(false);
    // Deliberately no selected pin. The route frames the whole trip; selecting
    // a stop would move the camera to that one pin in the same frame, and
    // whichever listener ran last would decide what you saw.
    ref.read(mapSelectedIdProvider.notifier).select(null);
    ref
        .read(activeMapRouteProvider.notifier)
        // The order on screen, so a reorder still being written is the
        // route that is drawn.
        .show(itinerary.name, _stops);
    ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
    context.go(Routes.home);
  }

  /// The header grows into the whole screen, framing every stop, with the
  /// strip of stops rising under it. A scrolled list scrolls home as it goes,
  /// so the map grows from where the header is.
  void _expand() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: _flightDuration,
        curve: SpringCurve(AppMotion.chrome, _flightDuration),
      );
    }
    setState(() {
      _expanded = true;
      _focused = null;
    });
  }

  void _collapse() => setState(() {
    _expanded = false;
    _focused = null;
  });

  /// A card the strip settled on, by a swipe.
  void _onStripPage(int index) {
    if (_turning) return;
    setState(() => _focused = index);
  }

  /// A pin tapped on the map: the strip turns to its card.
  Future<void> _onPinTap(int index) async {
    setState(() => _focused = index);
    if (!_strip.hasClients) return;
    _turning = true;
    await _strip.animateToPage(
      index,
      duration: _flightDuration,
      curve: SpringCurve(AppMotion.chrome, _flightDuration),
    );
    _turning = false;
  }

  /// How long a scroll or a page turn that has to take a duration runs; the
  /// chrome spring settles inside it.
  static const _flightDuration = AppMotion.span;

  @override
  Widget build(BuildContext context) {
    // No floating action on this page: the map is the way into the map, and
    // the expanded map carries its own hand-off.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final stripBottom = bottomInset + AppSpace.x3;
    final stops = _stops;
    final start = itinerary.startDate;
    final heading = start == null ? "Stops" : weekday(start);
    final screen = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final restHeight = AppSize.routePreview + topInset;
    final stripHeight = StopStrip.heightOf(context);
    final surface = Theme.of(context).colorScheme.surface;

    // The stops that can be drawn, in the order on screen, each keeping its
    // number in the trip so the pin, the row and the card agree.
    final byId = ref.watch(placesByIdProvider);
    final drawn = <RouteStop>[
      for (final (index, id) in stops.indexed)
        if (byId[id] case final place?) (number: index + 1, place: place),
    ];
    final focused = _focused == null || _focused! >= drawn.length
        ? null
        : _focused;

    final map = RepaintBoundary(
      child: Hero(
        tag: tripHeroTag(itinerary.id),
        flightShuttleBuilder: (_, animation, _, _, _) => _TripFlight(
          animation: animation,
          cover: drawn.firstOrNull?.place.coverImage,
        ),
        child: drawn.isEmpty
            ? const ImagePlaceholder(borderRadius: BorderRadius.zero)
            : RouteMap(
                stops: drawn,
                expanded: _expanded,
                focused: focused,
                onStopTap: _onPinTap,
                // The page's rounded top covers the map's foot at rest; the
                // credit sits above it rather than under it.
                restCreditInset: _pageEdge,
                frame: Size(
                  screen.width,
                  _expanded ? screen.height : restHeight,
                ),
                restPadding: EdgeInsets.fromLTRB(
                  AppSpace.x8,
                  topInset + AppSpace.x12,
                  AppSpace.x8,
                  AppSpace.x12 * 2,
                ),
                expandedPadding: EdgeInsets.fromLTRB(
                  AppSpace.x8,
                  topInset + AppSize.symbolButton + AppSpace.x8,
                  AppSpace.x8,
                  stripBottom + stripHeight + AppSpace.x8,
                ),
              ),
      ),
    );

    // Built here, once per build, not inside the map layer's builder: that
    // runs on every scroll frame, and an unchanged instance is skipped there
    // instead of rebuilt (STANDARDS 10.10).
    final controls = _HeaderControls(
      itinerary: itinerary,
      expanded: _expanded,
      onClose: _collapse,
      onOpenInMap: stops.isEmpty ? null : _openOnMap,
    );

    return PopScope(
      // Back closes the expanded map first; the next back leaves.
      canPop: !_expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _collapse();
      },
      child: Scaffold(
        body: EntranceScope(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  // The map is drawn by the layer above, which scrolls with
                  // this space at rest; the space takes the tap that grows
                  // it, and lets a drag that starts on it scroll the list.
                  SliverToBoxAdapter(
                    child: Semantics(
                      button: drawn.isNotEmpty,
                      label: drawn.isEmpty
                          ? null
                          : "Show every stop on the map",
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Nothing to show until a stop has a place.
                        onTap: drawn.isEmpty ? null : _expand,
                        child: SizedBox(height: restHeight),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      0,
                      AppSpace.gutter,
                      bottomInset + AppSpace.section,
                    ),
                    sliver: SliverList.list(
                      children: [
                        // The trip's name on the page rising over the map,
                        // the way a place's name sits on Place detail.
                        Entrance(child: _TripTitle(itinerary: itinerary)),
                        const SizedBox(height: AppSpace.x6),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.x1,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  heading,
                                  style: AppTypography.groupHeading,
                                ),
                              ),
                              if (stops.length > 1)
                                TextButton(
                                  onPressed: () => setState(
                                    () => _reordering = !_reordering,
                                  ),
                                  child: FadeSwap(
                                    id: _reordering,
                                    child: Text(
                                      _reordering ? "Done" : "Reorder",
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // A trip is a handful of stops, built together so
                        // moves can slide between neighbours.
                        Entrance(
                          order: 1,
                          child: _Timeline(
                            children: [
                              for (final (index, stop) in stops.indexed)
                                _StopMotion(
                                  key: ValueKey(stop),
                                  arriving: _arriving.contains(stop),
                                  leaving: _leaving.contains(stop),
                                  shift: _shifts[stop] ?? 0,
                                  generation: _moveGeneration,
                                  onLeft: () => _removed(stop),
                                  child: _StopRow(
                                    key: stop == widget.added
                                        ? _addedKey
                                        : null,
                                    index: index,
                                    total: stops.length,
                                    destinationId: stop,
                                    previousId: index == 0
                                        ? null
                                        : stops[index - 1],
                                    reordering: _reordering,
                                    onUp: index == 0
                                        ? null
                                        : () => _move(index, index - 1),
                                    onDown: index == stops.length - 1
                                        ? null
                                        : () => _move(index, index + 1),
                                    onRemove: () => _remove(stop),
                                  ),
                                ),
                              _AddStopRow(heading: heading, onTap: _addStops),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.section),
                        const Entrance(order: 2, child: _OfflineRow()),
                      ],
                    ),
                  ),
                ],
              ),
              // The map, the title over it and its controls: one `t` grows
              // them from the header into the screen and back.
              Positioned.fill(
                child: AppMotionBuilder(
                  end: _expanded ? 1 : 0,
                  child: map,
                  builder: (context, t, map) => ListenableBuilder(
                    listenable: _scroll,
                    builder: (context, _) {
                      final scrolled = _scroll.hasClients
                          ? _scroll.offset.clamp(0.0, restHeight)
                          : 0.0;
                      final shown = t.clamp(0.0, 1.0);
                      final top = -scrolled * (1 - shown);
                      return Stack(
                        children: [
                          Positioned(
                            top: top,
                            left: 0,
                            right: 0,
                            height: lerpDouble(restHeight, screen.height, t),
                            child: IgnorePointer(
                              ignoring: !_expanded,
                              child: map!,
                            ),
                          ),
                          if (shown < 1) ...[
                            // The page's rounded edge over the map's foot,
                            // the curve Place detail rises on; the page
                            // under it is the list's own white. It fades
                            // by its colour as the map grows.
                            Positioned(
                              top: top + restHeight - _pageEdge,
                              left: 0,
                              right: 0,
                              height: _pageEdge,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: surface.withValues(alpha: 1 - shown),
                                    borderRadius: AppRadii.sheetTop,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Positioned(
                            top: top + topInset + AppSpace.x2,
                            left: AppSpace.x2,
                            right: AppSpace.x2,
                            child: controls,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (drawn.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: stripBottom,
                  child: AppMotionBuilder(
                    end: _expanded ? 1 : 0,
                    child: StopStrip(
                      stops: drawn,
                      controller: _strip,
                      onFocused: _onStripPage,
                    ),
                    // Rises from the bottom edge as the map grows, and
                    // sinks back as it shrinks; not built while folded.
                    // Arrived, it keeps the same tree at identity values,
                    // so the strip is not rebuilt as it lands.
                    builder: (context, t, strip) {
                      final shown = t.clamp(0.0, 1.0);
                      if (shown == 0) return const SizedBox.shrink();
                      return IgnorePointer(
                        ignoring: !_expanded,
                        child: Opacity(
                          opacity: shown,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              (1 - t) * (stripHeight + stripBottom),
                            ),
                            child: strip,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // The route map keeps the status bar at rest; the page's
              // white closes in under it as the trip's name arrives there.
              StatusBarGround.below(scroll: _scroll, contentTop: restHeight),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stop's row in motion: growing in when it arrives, folding away when it
/// leaves, sliding from its old place after a move. At rest it is just the
/// row: no clip, no fade, no transform.
class _StopMotion extends StatelessWidget {
  const _StopMotion({
    required this.arriving,
    required this.leaving,
    required this.shift,
    required this.generation,
    required this.onLeft,
    required this.child,
    super.key,
  });

  final bool arriving;
  final bool leaving;

  /// Rows away from where it was, before this move.
  final int shift;
  final int generation;
  final VoidCallback onLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget row = child;

    if (shift != 0 && !MediaQuery.disableAnimationsOf(context)) {
      row = SingleMotionBuilder(
        key: ValueKey(generation),
        motion: AppMotion.chrome,
        from: shift.toDouble(),
        value: 0,
        // At rest the offset is zero in the same tree, so the row is not
        // rebuilt as it lands (STANDARDS 10.13).
        builder: (context, rows, child) =>
            FractionalTranslation(translation: Offset(0, rows), child: child),
        child: row,
      );
    }

    if (!arriving && !leaving) return row;

    return Fold(
      open: !leaving,
      // A row that starts leaving mounts here at full height, so the fold
      // has somewhere to fold from.
      from: arriving ? 0 : 1,
      motion: leaving ? AppMotion.chrome : AppMotion.arrive,
      onFolded: onLeft,
      child: row,
    );
  }
}

/// Taking the trip offline, as a plain row on the white ground like the
/// stops above it: the download glyph in blue, what it keeps, and a chevron
/// to the downloads. No coloured tile.
class _OfflineRow extends StatelessWidget {
  const _OfflineRow();

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      GroupedRow(
        leadingGlyph: AppIcons.download,
        glyphColor: context.lakbayan.spatial,
        title: "Take this trip offline",
        subtitle: "Map, photos and audio",
        onTap: () => context.push(Routes.downloads),
      ),
    ],
  );
}

/// The stops as a route: a blue line runs down through their numbers, from
/// the first to "Add a stop", so the list reads as one journey rather than
/// a pile of rows. The line is drawn behind the rows, under the numerals'
/// centres; the rows themselves are unchanged.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final side = StopNumeral.sideOf(context);
    return Stack(
      children: [
        Positioned(
          left: AppSpace.x1 + side / 2 - AppStroke.bold / 2,
          top: AppSpace.x6,
          bottom: AppSpace.x6,
          width: AppStroke.bold,
          child: ColoredBox(color: context.lakbayan.spatial),
        ),
        GroupedSection(children: children),
      ],
    );
  }
}

/// The page's rounded edge over the foot of the route map.
const _pageEdge = AppSpace.x6;

/// The trip's name, large, at the top of the page, and its dates as one
/// quiet line under it; tapping the dates changes them. With no dates yet,
/// a link to add them. The map stays a clean map above.
class _TripTitle extends StatelessWidget {
  const _TripTitle({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The dates, when set. The stops are the list below, so a count here
    // would be a number with nothing to do.
    final line = datePhrase(itinerary);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(itinerary.name, style: AppTypography.hero),
          ),
          if (line != null)
            Semantics(
              button: true,
              hint: "Change the dates",
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showTripDates(context, itinerary),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.x1),
                  child: Text(
                    line,
                    style: AppTypography.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => showTripDates(context, itinerary),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text("Add dates"),
            ),
        ],
      ),
    );
  }
}

/// "Open in Map" on a white capsule over the expanded route map: the trip,
/// handed to the Map tab with its route drawn. A text label, since a map
/// glyph over a map says nothing. A Material button, so the 48dp target is
/// padded around the 44 capsule that matches the close circle beside it.
class _OpenInMap extends StatelessWidget {
  const _OpenInMap({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, AppSize.symbolButton),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
          shape: const StadiumBorder(),
        ),
        child: const Text("Open in Map"),
      ),
    );
  }
}

/// The controls over the route map. At rest: back on its circle, and share
/// and more grouped on one capsule (doc 04). Expanded: "Open in Map" and one
/// close circle, the map's own way out; back and the group give way to them
/// rather than cut.
class _HeaderControls extends StatelessWidget {
  const _HeaderControls({
    required this.itinerary,
    required this.expanded,
    required this.onClose,
    required this.onOpenInMap,
  });

  final Itinerary itinerary;
  final bool expanded;
  final VoidCallback onClose;

  /// Null while the trip has no stops to show.
  final VoidCallback? onOpenInMap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FadeSwap(
        id: expanded,
        alignment: Alignment.centerLeft,
        child: expanded
            ? const SizedBox.shrink()
            : SymbolButton(
                icon: AppIcons.back,
                tooltip: "Back",
                onTap: context.popOrHome,
              ),
      ),
      const Spacer(),
      FadeSwap(
        id: expanded,
        alignment: Alignment.centerRight,
        child: expanded
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onOpenInMap case final open?) ...[
                    _OpenInMap(onTap: open),
                    const SizedBox(width: AppSpace.x2),
                  ],
                  SymbolButton(
                    icon: AppIcons.close,
                    tooltip: "Close the map",
                    onTap: onClose,
                  ),
                ],
              )
            : _TripActions(itinerary: itinerary),
      ),
    ],
  );
}

/// Share and more on one capsule. Share is a placeholder until sharing a trip
/// with somebody else is built; more opens the trip's menu from its glyph:
/// change dates and rename, then delete on its own, red and confirmed.
class _TripActions extends ConsumerWidget {
  const _TripActions({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BarItemGroup.overMedia(
    items: [
      BarItem(
        icon: AppIcons.share,
        tooltip: "Share",
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sharing will be available in a future update."),
          ),
        ),
      ),
      BarItem(
        icon: AppIcons.more,
        tooltip: "More",
        menu: [
          [
            AppMenuItem(
              label: "Change dates",
              icon: AppIcons.calendar,
              onSelected: () => showTripDates(context, itinerary),
            ),
            AppMenuItem(
              label: "Rename",
              icon: AppIcons.rename,
              onSelected: () => _rename(context, ref),
            ),
          ],
          [
            AppMenuItem(
              label: "Delete",
              icon: AppIcons.delete,
              destructive: true,
              onSelected: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
    ],
  );

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(itineraryActionsProvider);
    final name = await showAppDialog<String>(
      context,
      builder: (context) => _RenameDialog(initial: itinerary.name),
    );
    if (name == null || name.trim().isEmpty) return;
    final landed = await actions.rename(itinerary.id, name.trim());
    if (!landed && context.mounted) _couldNot(context, "rename it");
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(itineraryActionsProvider);
    final confirmed = await showAppDialog<bool>(
      context,
      builder: (context) => AlertDialog(
        title: Text("Delete ${itinerary.name}?"),
        content: const Text("The stops go with it. This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Keep it"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final landed = await actions.delete(itinerary.id);
    if (!context.mounted) return;
    landed ? context.popOrHome() : _couldNot(context, "delete it");
  }
}

/// What flies between the trip's row on the Itineraries tab and this screen's
/// route map: the first stop's photo growing into the header and fading to
/// the map's ground as it lands, the same path shrinking back. The live map
/// never flies; it is there when the flight ends.
class _TripFlight extends StatelessWidget {
  const _TripFlight({required this.animation, required this.cover});

  final Animation<double> animation;
  final String? cover;

  /// The row's photo radius, which the flight unrounds to the header's edge.
  static final _rowRadius = concentricRadius(
    parentRadius: concentricRadius(
      parentRadius: AppRadii.md,
      padding: AppSpace.groupInset,
      fallback: AppRadii.sm,
    ),
    padding: AppSpace.rowPad,
    fallback: AppRadii.xs,
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: CoverImage(cover),
    builder: (context, photo) {
      final t = animation.value;
      final photoShown =
          1 - Curves.easeIn.transform(const Interval(0.55, 1).transform(t));
      return ClipRRect(
        borderRadius: BorderRadius.circular(lerpDouble(_rowRadius, 0, t)!),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Opacity(opacity: photoShown, child: photo),
        ),
      );
    },
  );
}

void _couldNot(BuildContext context, String what) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Couldn't $what. Try again.")));

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text("Rename"),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: "Name"),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("Cancel"),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text("Save"),
      ),
    ],
  );
}

/// Change a trip's dates in a sheet: the same pair of fields and inline
/// calendar the new-itinerary sheet uses, and Save.
Future<void> showTripDates(BuildContext context, Itinerary itinerary) =>
    showAppSheet<void>(context, builder: (_) => _DatesSheet(itinerary));

class _DatesSheet extends ConsumerStatefulWidget {
  const _DatesSheet(this.itinerary);

  final Itinerary itinerary;

  @override
  ConsumerState<_DatesSheet> createState() => _DatesSheetState();
}

class _DatesSheetState extends ConsumerState<_DatesSheet> {
  late DateTime? _start = widget.itinerary.startDate;
  late DateTime? _end = widget.itinerary.endDate;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final landed = await ref
        .read(itineraryActionsProvider)
        .setDates(widget.itinerary.id, _start, _end);
    if (!mounted) return;
    if (landed) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      _couldNot(context, "save the dates");
    }
  }

  @override
  Widget build(BuildContext context) => AppSheet(
    title: "Dates",
    fill: true,
    action: FilledButton(
      onPressed: _saving ? null : _save,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.primaryButton),
      ),
      child: const Text("Save"),
    ),
    slivers: [
      SliverPadding(
        padding: appSheetBodyPadding,
        sliver: SliverToBoxAdapter(
          child: TripDates(
            start: _start,
            end: _end,
            onChanged: (start, end) => setState(() {
              _start = start;
              _end = end;
            }),
          ),
        ),
      ),
    ],
  );
}

/// One stop: the row opens the place; reordering swaps in move up, move
/// down and remove. The second line is the town for the first stop and the
/// straight-line distance from the one before for the rest, in blue, never
/// a drive time the app cannot know.
class _StopRow extends ConsumerWidget {
  const _StopRow({
    required this.index,
    required this.total,
    required this.destinationId,
    required this.previousId,
    required this.reordering,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
    super.key,
  });

  final int index;
  final int total;
  final String destinationId;

  /// The stop before this one; null for the first.
  final String? previousId;
  final bool reordering;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(destinationByIdProvider(destinationId));
    final place = destination.value;
    // A destination can be unpublished after somebody added it. Saying so
    // beats a blank row, and leaves them able to remove it.
    final missing = destination.hasValue && place == null;
    final previousId = this.previousId;
    final previous = previousId == null
        ? null
        : ref.watch(destinationByIdProvider(previousId)).value;
    final leg = place == null || previous == null
        ? null
        : "${distanceLabel(distanceBetween(previous, place))} "
              "from ${previous.name}";

    final remove = IconButton(
      icon: const Icon(AppIcons.close, size: AppSize.glyphMd),
      tooltip: "Remove this stop",
      onPressed: onRemove,
    );
    final Widget? controls = reordering
        ? Row(
            key: const ValueKey("reorder"),
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(AppIcons.chevronUp, size: AppSize.glyphMd),
                tooltip: "Move earlier",
                onPressed: onUp,
              ),
              IconButton(
                icon: const Icon(AppIcons.chevronDown, size: AppSize.glyphMd),
                tooltip: "Move later",
                onPressed: onDown,
              ),
              remove,
            ],
          )
        : missing
        ? remove
        : null;

    return Semantics(
      label: "Stop ${index + 1} of $total",
      child: GroupedRow(
        mark: StopNumeral(index + 1),
        title: place?.name ?? _fallbackTitle(destination),
        subtitle: leg ?? place?.town,
        subtitleColor: leg == null ? null : context.lakbayan.spatial,
        leading: PhotoHero(
          tag: coverHeroTag(destinationId, HeroSource.stop),
          child: CoverImage(place?.coverImage),
        ),
        trailing: controls == null && !reordering
            ? null
            : FadeSwap(
                id: reordering,
                child: controls ?? const SizedBox.shrink(),
              ),
        onTap: reordering || place == null
            ? null
            : () => context.push(
                Routes.destination(place.id, from: HeroSource.stop),
              ),
      ),
    );
  }

  static String _fallbackTitle(AsyncValue<Destination?> destination) =>
      destination.hasError
      ? "This stop could not be loaded"
      : destination.isLoading
      ? "Loading"
      : "No longer available";
}

/// The last row of the list: a dashed square where the next photo will be,
/// under the stops' photos, with no number yet.
class _AddStopRow extends StatelessWidget {
  const _AddStopRow({required this.heading, required this.onTap});

  final String heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    return GroupedRow(
      // No number yet, but the slot holds its width so the square lines up
      // under the stops' photos.
      mark: SizedBox(width: StopNumeral.sideOf(context)),
      title: heading == "Stops" ? "Add a stop" : "Add a stop to $heading",
      // The row gives its photo slot a derived radius; the dashes follow
      // it, so the square sits concentric with the row like a photo would.
      leading: Builder(
        builder: (context) => CustomPaint(
          painter: _DashedBorderPainter(
            color: brand.textOnLightGreen,
            radius: ParentRadius.maybeOf(context) ?? AppRadii.xs,
          ),
          child: Icon(AppIcons.add, color: brand.textOnLightGreen),
        ),
      ),
      trailing: GroupedRow.noAccessory,
      onTap: onTap,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  // Drawing constants for the dashes, not layout: a short dash, a gap of the
  // base grid step.
  static const _dash = AppSpace.x1 + AppStroke.hairline;
  static const _gap = AppSpace.x1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular;
    // Inset by the hairline so the stroke is not cut at the edge.
    final rect = (Offset.zero & size).deflate(AppStroke.hairline);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(radius - AppStroke.hairline),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Pick more stops. Multi-select; Add confirms.
class _AddStopsSheet extends ConsumerStatefulWidget {
  const _AddStopsSheet({required this.itineraryId});

  final String itineraryId;

  @override
  ConsumerState<_AddStopsSheet> createState() => _AddStopsSheetState();
}

class _AddStopsSheetState extends ConsumerState<_AddStopsSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(addableStopsProvider(widget.itineraryId));

    return AppSheet(
      title: "Add a stop",
      fill: true,
      action: FilledButton(
        onPressed: _picked.isEmpty
            ? null
            : () => Navigator.of(context).pop(_picked),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSize.primaryButton),
        ),
        child: Text(
          _picked.isEmpty ? "Add" : "Add ${stopsPhrase(_picked.length)}",
        ),
      ),
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: choices.whenLocalFirst(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.x6),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: QuietNote(
                errorCopy("Couldn't load places to add.", error),
                onRetry: () => ref.invalidate(allDestinationsProvider),
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverToBoxAdapter(
                    child: QuietNote("Every place is already on this trip."),
                  )
                : SliverStopPicker(
                    items: items,
                    selected: _picked,
                    onToggle: (place) => setState(() {
                      _picked.contains(place.id)
                          ? _picked.remove(place.id)
                          : _picked.add(place.id);
                    }),
                  ),
          ),
        ),
      ],
    );
  }
}
