import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:motor/motor.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../maps/domain/tile_source.dart";
import "../../maps/presentation/map_view.dart"
    show Basemap, CameraFlying, MapAttribution;

/// A stop that can be drawn: its place in the trip and the place itself.
/// Unpublished stops have no coordinates and are left off the map, so the
/// number is carried rather than recounted.
typedef RouteStop = ({int number, Destination place});

/// A trip's stops on one map, which is both the header at rest and the map
/// the header grows into (itinerary redesign, 2026-09-23).
///
/// One `FlutterMap` for both, so expanding never swaps maps and there is
/// only ever one on screen.
class RouteMap extends ConsumerStatefulWidget {
  const RouteMap({
    required this.stops,
    required this.expanded,
    required this.frame,
    required this.restPadding,
    required this.expandedPadding,
    this.focused,
    this.onStopTap,
    this.restCreditInset = 0,
    super.key,
  });

  final List<RouteStop> stops;
  final bool expanded;

  /// How much of the map's foot something else covers at rest — the page's
  /// rounded top on the trip screen — so the credit sits above it.
  final double restCreditInset;

  /// The size this map ends at for the current state.
  final Size frame;

  /// What the camera keeps clear at rest (the title) and expanded (the
  /// controls and the strip).
  final EdgeInsets restPadding;
  final EdgeInsets expandedPadding;

  /// The index into [stops] the strip is showing, while expanded.
  final int? focused;
  final ValueChanged<int>? onStopTap;

  /// One stop alone is shown at town scale, not zoomed to the street.
  static const _stopZoom = 13.0;
  static const _maxFitZoom = 14.0;

  @override
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<RouteMap>
    with SingleTickerProviderStateMixin, CameraFlying {
  bool _ready = false;

  List<LatLng> get _points => [
    for (final stop in widget.stops)
      LatLng(stop.place.coords.lat, stop.place.coords.lng),
  ];

  EdgeInsets get _padding =>
      widget.expanded ? widget.expandedPadding : widget.restPadding;

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (!_ready || widget.stops.isEmpty) return;
    final focused = widget.expanded ? widget.focused : null;
    final wasFocused = old.expanded ? old.focused : null;
    if (widget.expanded != old.expanded ||
        focused != wasFocused ||
        widget.stops.length != old.stops.length) {
      _flyTo(
        focused == null || focused >= widget.stops.length
            ? _points
            : [_points[focused]],
      );
    }
  }

  /// Flies to frame [points] in [RouteMap.frame], the Map tab's flight.
  void _flyTo(List<LatLng> points) {
    final to = CameraFit.coordinates(
      coordinates: points,
      padding: _padding,
      maxZoom: points.length == 1 ? RouteMap._stopZoom : RouteMap._maxFitZoom,
    ).fit(camera.camera.withNonRotatedSize(widget.frame));
    flyCamera(to.center, to.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spatial = context.lakbayan.spatial;
    final source = ref.watch(tileSourceProvider);
    final points = _points;
    final focused = widget.expanded ? widget.focused : null;

    return FlutterMap(
      mapController: camera,
      options: MapOptions(
        initialCameraFit: points.isEmpty
            ? null
            : CameraFit.coordinates(
                coordinates: points,
                padding: _padding,
                maxZoom: points.length == 1
                    ? RouteMap._stopZoom
                    : RouteMap._maxFitZoom,
              ),
        maxZoom: source.maxZoom.toDouble(),
        onMapReady: () => _ready = true,
        interactionOptions: InteractionOptions(
          flags: widget.expanded
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        // A town taken offline draws from disk, as on the Map tab, so the
        // trip still has a map where there is no signal.
        Basemap(source: source),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: spatial,
                strokeWidth: widget.expanded
                    ? AppStroke.mapRoute
                    : AppStroke.route,
                borderColor: scheme.surface,
                borderStrokeWidth: AppStroke.regular,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final (index, stop) in widget.stops.indexed)
              Marker(
                point: points[index],
                width: AppSize.minTouchTarget,
                height: AppSize.minTouchTarget,
                child: Semantics(
                  button: widget.expanded,
                  label: "Stop ${stop.number}, ${stop.place.name}",
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.expanded
                        ? () => widget.onStopTap?.call(index)
                        : null,
                    child: Center(
                      child: SingleMotionBuilder(
                        motion: AppMotion.chrome,
                        value: focused == index ? _focusScale : 1,
                        child: StopNumeral(
                          stop.number,
                          ring: AppStroke.bold + AppStroke.hairline,
                        ),
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // ODbL wants credit wherever the tiles appear (`tile_source.dart`),
        // and the header at rest is where they appear most. The full control
        // is kept for the map somebody can actually use.
        if (widget.expanded)
          MapAttribution(source: source)
        else
          _RestCredit(source: source, inset: widget.restCreditInset),
      ],
    );
  }

  /// How much larger the stop on the strip's current card draws.
  static const _focusScale = 1.25;
}

/// The credit on the map at rest, as plain text in the corner.
///
/// Not [MapAttribution]: that is a control, an info button that opens a
/// panel with the copyright link, and at rest the header ignores every touch
/// because a tap expands it. A control there would be dead. The credit
/// itself is what the licence asks for; the expanded map still carries the
/// full control with its link.
class _RestCredit extends StatelessWidget {
  const _RestCredit({required this.source, required this.inset});

  final TileSource source;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: AppSpace.x2,
          bottom: inset + AppSpace.x1,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.surface,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.x2,
              vertical: AppSpace.x1,
            ),
            child: Text(
              source.attribution,
              style: AppTypography.labelSmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
