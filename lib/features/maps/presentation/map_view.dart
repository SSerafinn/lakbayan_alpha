import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/domain/saved_destinations.dart";
import "../domain/map_route.dart";
import "../domain/tile_source.dart";

/// Roughly the middle of Cagayan, used when there is nothing to fit.
///
/// Tuguegarao rather than the province centroid: the centroid falls in the
/// Sierra Madre with nothing on it, and an empty map of forest is a worse first
/// impression than the provincial capital.
const _fallbackCentre = LatLng(17.6132, 121.7270);

/// The basemap with the places as pins. Edge to edge; the chrome around it
/// belongs to `MapScreen`.
///
/// Pins are the content (redesign 2c): a spatial-blue circle with a white
/// ring, green when the place is saved, larger with a name label when
/// selected. Selection lives in [mapSelectedIdProvider] so Place detail can
/// land here on a pin.
class MapView extends ConsumerStatefulWidget {
  const MapView({required this.destinations, super.key});

  final List<Destination> destinations;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The area the pins occupy, or null when there is nothing to fit.
  LatLngBounds? get _bounds {
    final points = widget.destinations
        .map((d) => LatLng(d.coords.lat, d.coords.lng))
        .toList();
    if (points.isEmpty) return null;
    return LatLngBounds.fromPoints(points);
  }

  /// A pin chosen from elsewhere (Place detail's "Getting there") is brought
  /// into view; one tapped on the map already is.
  void _onSelected(String? previous, String? next) {
    if (next == null || next == previous) return;
    final place = widget.destinations.where((d) => d.id == next).firstOrNull;
    if (place == null) return;
    final zoom = _controller.camera.zoom < 13 ? 13.0 : _controller.camera.zoom;
    _controller.move(LatLng(place.coords.lat, place.coords.lng), zoom);
  }

  /// Frame a route that has just been opened, so the whole trip is on screen.
  ///
  /// Opening a route deliberately does *not* also select a stop: both would
  /// move the camera, and the last one to run would win by accident.
  void _onRoute(MapRoute? previous, MapRoute? next) {
    if (next == null) return;
    final points = _currentPointsFor(next);
    if (points.length < 2) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x8,
          AppSpace.x12 * 4,
          AppSpace.x8,
          AppSpace.x12 * 5,
        ),
        maxZoom: 14,
      ),
    );
  }

  /// A route's stops as coordinates, in order.
  ///
  /// Resolved against every destination rather than [MapView.destinations]:
  /// the visible list is filtered by the search box and the category chips,
  /// and a line that silently loses a stop to a filter would draw a trip that
  /// nobody planned.
  static List<LatLng> _pointsFor(
    MapRoute route,
    Map<String, Destination> byId,
  ) => [
    for (final id in route.destinationIds)
      if (byId[id] case final d?) LatLng(d.coords.lat, d.coords.lng),
  ];

  /// The same, for the camera listener, which has no build to read from.
  ///
  /// `read` is right *here* and wrong in [build]: a listener fires once, at a
  /// moment the user chose, whereas the line has to appear when the
  /// destinations finish loading — which is a rebuild, not an event.
  List<LatLng> _currentPointsFor(MapRoute route) => _pointsFor(route, {
    for (final d in ref.read(allDestinationsProvider).value ?? const [])
      d.id: d,
  });

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(tileSourceProvider);
    final selectedId = ref.watch(mapSelectedIdProvider);
    final saved = ref.watch(savedDestinationsProvider);
    final route = ref.watch(activeMapRouteProvider);
    final bounds = _bounds;
    ref.listen<String?>(mapSelectedIdProvider, _onSelected);
    ref.listen<MapRoute?>(activeMapRouteProvider, _onRoute);

    // Where each stop falls in the route, so its pin can carry the number.
    // The order *is* the route (`docs/DATA_MODEL.md`), and a bare line does
    // not say which end you start from.
    final order = <String, int>{
      if (route != null)
        for (final (index, id) in route.destinationIds.indexed) id: index + 1,
    };
    // Watched, not read: the route is usually opened before the destination
    // list has arrived, and the line has to appear when it does.
    final all =
        ref.watch(allDestinationsProvider).value ?? const <Destination>[];
    final routePoints = route == null
        ? const <LatLng>[]
        : _pointsFor(route, {for (final d in all) d.id: d});

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        // Fit the pins when there are any. A fixed centre and zoom would
        // open on empty sea for a filter that matches one northern town.
        initialCameraFit: bounds == null
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x8,
                  AppSpace.x12 * 3,
                  AppSpace.x8,
                  AppSpace.x12 * 5,
                ),
                maxZoom: 14,
              ),
        initialCenter: _fallbackCentre,
        initialZoom: 9,
        maxZoom: source.maxZoom.toDouble(),
        // Tapping the basemap clears the selection, the same gesture that
        // dismisses a sheet.
        onTap: (_, _) => ref.read(mapSelectedIdProvider.notifier).select(null),
      ),
      children: [
        TileLayer(
          urlTemplate: source.urlTemplate,
          maxNativeZoom: source.maxZoom,
          // Required by the OSM tile policy, and good manners on any
          // source: it is how an operator tells our traffic apart from a
          // scraper's.
          userAgentPackageName: "ph.gov.cagayan.lakbayan",
        ),
        // Downloaded packs sit **above** the network layer. Where a town
        // has been taken offline its tiles come off disk: instant, free,
        // and unchanged imagery, so the seam is invisible. Everywhere else
        // the network layer below still shows through.
        for (final pack in ref.watch(openPacksProvider).value ?? const [])
          TileLayer(
            key: ValueKey("pack-${pack.townId}"),
            tileProvider: pack.provider,
            tileDimension: packTileDimension,
            maxNativeZoom: packMaxZoom,
          ),
        // Under the pins: the line joins the stops, the pins are the stops.
        // An authored polyline, not a computed road route (D-11) — it draws
        // from the pack with no signal, which a routing engine could not.
        if (routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: context.lakbayan.spatial,
                strokeWidth: 4,
                borderColor: Theme.of(context).colorScheme.surface,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final d in widget.destinations)
              Marker(
                point: LatLng(d.coords.lat, d.coords.lng),
                width: _Pin.labelWidth,
                height: _Pin.height,
                // The dot sits in the lower slot; this puts its centre on
                // the coordinate so a label above never shifts the pin.
                alignment: _Pin.anchor,
                child: _Pin(
                  // `Marker` is a data class, not a widget, so it cannot
                  // be found by type. The key is how a test addresses one.
                  key: Key("pin-${d.id}"),
                  destination: d,
                  selected: d.id == selectedId,
                  saved: saved.contains(d.id),
                  stopNumber: order[d.id],
                  onTap: () =>
                      ref.read(mapSelectedIdProvider.notifier).select(d.id),
                ),
              ),
          ],
        ),
        _Attribution(source: source),
      ],
    );
  }
}

/// A place on the map. Blue circle with a white ring; green when saved; the
/// selected one grows, gains a centre dot and its name on an ink capsule.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.destination,
    required this.selected,
    required this.saved,
    required this.onTap,
    this.stopNumber,
    super.key,
  });

  final Destination destination;
  final bool selected;
  final bool saved;

  /// Its 1-based position when a route is being shown, else null.
  final int? stopNumber;

  final VoidCallback onTap;

  static const _dot = 22.0;
  static const _dotSelected = 28.0;
  static const _ring = 3.0;
  static const _slot = _dotSelected;
  static const labelWidth = 160.0;
  static const height = _slot * 2;
  static const anchor = Alignment(0, -0.5);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final size = selected || stopNumber != null ? _dotSelected : _dot;
    final number = stopNumber;

    return Semantics(
      button: true,
      selected: selected,
      // "Stop 2, Callao Cave" rather than a number a screen reader has to
      // infer from a line it cannot see.
      label: number == null
          ? destination.name
          : "Stop $number, ${destination.name}",
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            SizedBox(
              height: _slot,
              child: selected
                  ? Center(
                      child: Material(
                        color: scheme.onSurface,
                        shape: const StadiumBorder(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.x2,
                            vertical: AppSpace.x1,
                          ),
                          child: Text(
                            destination.name,
                            style: AppTypography.labelMedium.copyWith(
                              color: scheme.surface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(
              height: _slot,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: ShapeDecoration(
                    color: saved ? scheme.primary : brand.spatial,
                    shape: CircleBorder(
                      side: BorderSide(color: scheme.surface, width: _ring),
                    ),
                  ),
                  // The number outranks the centre dot: both say "this one
                  // matters", and only one of them says where it comes in the
                  // trip.
                  child: number != null
                      ? Center(
                          child: Text(
                            "$number",
                            style: AppTypography.labelMedium.copyWith(
                              color: scheme.surface,
                              height: 1,
                            ),
                          ),
                        )
                      : selected
                      ? Center(
                          child: Container(
                            width: AppSpace.x2,
                            height: AppSpace.x2,
                            decoration: ShapeDecoration(
                              color: scheme.surface,
                              shape: const CircleBorder(),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ODbL credit. Not optional, and not something to tuck away.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.source});

  final TileSource source;

  @override
  Widget build(BuildContext context) {
    // The credit is what ODbL requires; the link to the copyright page is the
    // customary courtesy, and now that `url_launcher` is here for the `geo:`
    // hand-off it costs nothing. Still only wired when the source actually
    // carries an address — `attributionUrl` is nullable, and a tap target that
    // does nothing is worse than no tap target.
    final url = source.attributionUrl;

    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      attributions: [
        TextSourceAttribution(
          source.attribution,
          // Failure is swallowed: there is nothing useful to tell somebody
          // whose phone has no browser, and the credit is on screen regardless.
          onTap: url == null
              ? null
              : () => unawaited(
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ).catchError((_) => false),
                ),
        ),
      ],
    );
  }
}
