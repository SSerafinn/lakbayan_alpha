import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:latlong2/latlong.dart" show LatLng;

import "../../../core/models/destination.dart";
import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/app_card.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/media_tile.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../../core/widgets/storage_image.dart";
import "../../../core/widgets/symbol_button.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";
import "../../maps/domain/map_route.dart";
import "../../maps/domain/tile_source.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "stop_picker.dart";

/// Itinerary overview (redesign 2j). Where Create lands.
///
/// **The screen's one job.** See the shape of the trip and start it.
///
/// **Emotion.** A plan taking form.
///
/// **Anatomy.** A route preview with the name over its scrim, back and an
/// overflow menu on it. One grouped section of stops under the trip's date,
/// with Reorder in the heading turning the chevrons into move up and down,
/// and an "Add a stop" row at the end. An offline card with a blue Download.
/// Pinned under a scroll edge: Open on the map, the one primary action.
///
/// The order **is** the route, so reordering is the point of the screen;
/// buttons rather than a drag handle because a handful of stops on a phone
/// is easier to nudge than to drag, and buttons reach a screen reader.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itineraries = ref.watch(myItinerariesProvider);

    return itineraries.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => MessageScreen("Couldn't load this itinerary.\n$e"),
      data: (items) {
        final itinerary = items.where((i) => i.id == id).firstOrNull;
        if (itinerary == null) {
          return const MessageScreen("This itinerary is no longer here.");
        }
        return _Overview(itinerary: itinerary);
      },
    );
  }
}

class _Overview extends ConsumerStatefulWidget {
  const _Overview({required this.itinerary});

  final Itinerary itinerary;

  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  bool _reordering = false;

  Itinerary get itinerary => widget.itinerary;

  Future<void> _setStops(List<String> next) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref
        .read(itineraryRepositoryProvider)
        .setStops(uid, itinerary.id, next);
  }

  Future<void> _move(int from, int to) {
    final next = [...itinerary.destinationIds];
    next.insert(to, next.removeAt(from));
    return _setStops(next);
  }

  Future<void> _addStops() async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddStopsSheet(already: itinerary.destinationIds),
    );
    if (picked == null || picked.isEmpty) return;
    await _setStops([...itinerary.destinationIds, ...picked]);
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
        .show(itinerary.name, itinerary.destinationIds);
    ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final actionHeight =
        AppSize.primaryButton + AppSpace.gutter * 2 + bottomInset;
    final stops = itinerary.destinationIds;
    final start = itinerary.startDate;
    final heading = start == null ? "Stops" : weekday(start);

    return Scaffold(
      body: Stack(
        children: [
          ScrollEdge(
            style: ScrollEdgeStyle.hard,
            bottom: actionHeight,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _RoutePreview(itinerary: itinerary)),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.section,
                    AppSpace.gutter,
                    actionHeight + AppSpace.section,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              heading,
                              style: AppTypography.groupHeading,
                            ),
                          ),
                          if (stops.length > 1)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _reordering = !_reordering),
                              child: Text(_reordering ? "Done" : "Reorder"),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.x2),
                      GroupedSection(
                        children: [
                          for (final (index, stopId) in stops.indexed)
                            _StopRow(
                              key: ValueKey(stopId),
                              index: index,
                              total: stops.length,
                              destinationId: stopId,
                              reordering: _reordering,
                              onUp: index == 0
                                  ? null
                                  : () => _move(index, index - 1),
                              onDown: index == stops.length - 1
                                  ? null
                                  : () => _move(index, index + 1),
                              onRemove: () =>
                                  _setStops([...stops]..removeAt(index)),
                            ),
                          _AddStopRow(heading: heading, onTap: _addStops),
                        ],
                      ),
                      const SizedBox(height: AppSpace.section),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpace.x4),
                        onTap: () => context.push(Routes.downloads),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Take this trip offline",
                                    style: AppTypography.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpace.x1),
                                  Text(
                                    "Guide, map and audio for its towns",
                                    style: AppTypography.secondLine.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.x2),
                            Text(
                              "Download",
                              style: AppTypography.labelLarge.copyWith(
                                color: brand.spatial,
                              ),
                            ),
                          ],
                        ),
                      ),
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
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(AppSpace.gutter),
              child: FilledButton(
                onPressed: stops.isEmpty ? null : _openOnMap,
                child: const Text("Open on the map"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stops as pins joined in order: a preview of the sequence, not a road
/// route (D-11). The trip's name and dates over a scrim; back and the
/// overflow menu on their own circles.
class _RoutePreview extends ConsumerWidget {
  const _RoutePreview({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final source = ref.watch(tileSourceProvider);
    final all = ref.watch(allDestinationsProvider).value ?? const [];
    final byId = {for (final d in all) d.id: d};
    final points = [
      for (final id in itinerary.destinationIds)
        if (byId[id] case final d?) LatLng(d.coords.lat, d.coords.lng),
    ];
    // The dates, when set. The stops are the list under the preview, so a
    // count here would be a number with nothing to do.
    final line = datePhrase(itinerary);

    return SizedBox(
      height: AppSize.routePreview + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (points.isEmpty)
            const ImagePlaceholder(borderRadius: BorderRadius.zero)
          else
            FlutterMap(
              options: MapOptions(
                initialCameraFit: points.length == 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        maxZoom: 13,
                        padding: const EdgeInsets.all(AppSpace.x8),
                      )
                    : CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.x8,
                          AppSpace.x12 * 2,
                          AppSpace.x8,
                          AppSpace.x12 * 2,
                        ),
                      ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: source.urlTemplate,
                  maxNativeZoom: source.maxZoom,
                  userAgentPackageName: "ph.gov.cagayan.lakbayan",
                ),
                if (points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: brand.spatial,
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final point in points)
                      Marker(
                        point: point,
                        width: AppSpace.x4,
                        height: AppSpace.x4,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: brand.spatial,
                            shape: CircleBorder(
                              side: BorderSide(color: scheme.surface, width: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: MediaScrim(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x12,
                  AppSpace.gutter,
                  AppSpace.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      itinerary.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (line != null) ...[
                      const SizedBox(height: AppSpace.x1),
                      Text(
                        line,
                        style: AppTypography.secondLine.copyWith(
                          color: Colors.white,
                        ),
                      ),
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
            right: AppSpace.x2,
            child: _MoreMenu(itinerary: itinerary),
          ),
        ],
      ),
    );
  }
}

/// Rename and Delete, anchored to the more symbol. Delete is last, red, and
/// confirmed.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.lakbayan;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => _rename(context, ref),
          child: const Text("Rename"),
        ),
        MenuItemButton(
          leadingIcon: Icon(AppIcons.delete, color: brand.closed),
          onPressed: () => _confirmDelete(context, ref),
          child: Text(
            "Delete",
            style: AppTypography.bodyMedium.copyWith(color: brand.closed),
          ),
        ),
      ],
      builder: (context, controller, _) => SymbolButton(
        icon: AppIcons.more,
        tooltip: "More",
        onTap: controller.isOpen ? controller.close : controller.open,
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: itinerary.name),
    );
    if (name == null || name.trim().isEmpty) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref
        .read(itineraryRepositoryProvider)
        .rename(uid, itinerary.id, name.trim());
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
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
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(itineraryRepositoryProvider).delete(uid, itinerary.id);
    if (context.mounted) context.pop();
  }
}

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

/// One stop. At rest the row opens the place; while reordering the trailing
/// accessory becomes move up, move down and remove, each its own 48 target.
class _StopRow extends ConsumerWidget {
  const _StopRow({
    required this.index,
    required this.total,
    required this.destinationId,
    required this.reordering,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
    super.key,
  });

  final int index;
  final int total;
  final String destinationId;
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

    final Widget? trailing = reordering
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(AppIcons.chevronUp, size: 18),
                tooltip: "Move earlier",
                onPressed: onUp,
              ),
              IconButton(
                icon: const Icon(AppIcons.chevronDown, size: 18),
                tooltip: "Move later",
                onPressed: onDown,
              ),
              IconButton(
                icon: const Icon(AppIcons.close, size: 18),
                tooltip: "Remove this stop",
                onPressed: onRemove,
              ),
            ],
          )
        : missing
        ? IconButton(
            icon: const Icon(AppIcons.close, size: 18),
            tooltip: "Remove this stop",
            onPressed: onRemove,
          )
        : null;

    return Semantics(
      label: "Stop ${index + 1} of $total",
      child: GroupedRow(
        title: place?.name ?? _fallbackTitle(destination),
        subtitle: place?.town,
        leading: CoverImage(place?.coverImage),
        trailing: trailing,
        onTap: reordering || place == null
            ? null
            : () => context.push(Routes.destination(place.id)),
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

/// The last row of the section: a dashed square plus in green text.
class _AddStopRow extends StatelessWidget {
  const _AddStopRow({required this.heading, required this.onTap});

  final String heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    return GroupedRow(
      title: heading == "Stops" ? "Add a stop" : "Add a stop to $heading",
      leading: CustomPaint(
        painter: _DashedBorderPainter(color: brand.textOnLightGreen),
        child: Icon(AppIcons.add, color: brand.textOnLightGreen),
      ),
      trailing: GroupedRow.noAccessory,
      onTap: onTap,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Pick more stops. Multi-select; Add confirms.
class _AddStopsSheet extends ConsumerStatefulWidget {
  const _AddStopsSheet({required this.already});

  final List<String> already;

  @override
  ConsumerState<_AddStopsSheet> createState() => _AddStopsSheetState();
}

class _AddStopsSheetState extends ConsumerState<_AddStopsSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allDestinationsProvider).value ?? const [];
    final choices = [
      for (final place in all)
        if (!widget.already.contains(place.id)) place,
    ];

    return FractionallySizedBox(
      heightFactor: 0.62,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.x2,
              AppSpace.x2,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text("Add a stop", style: AppTypography.titleMedium),
                ),
                SymbolButton(
                  icon: AppIcons.close,
                  tooltip: "Close",
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x2,
                AppSpace.gutter,
                AppSpace.x3,
              ),
              children: [
                if (choices.isEmpty)
                  Text(
                    "Every place is already on this trip.",
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  StopPicker(
                    items: choices,
                    selected: _picked,
                    onToggle: (place) => setState(() {
                      _picked.contains(place.id)
                          ? _picked.remove(place.id)
                          : _picked.add(place.id);
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.x2,
              AppSpace.gutter,
              AppSpace.gutter,
            ),
            child: FilledButton(
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
          ),
        ],
      ),
    );
  }
}
