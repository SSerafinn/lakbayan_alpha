import "dart:async";
import "dart:math" show max, min, sin;
import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";
import "package:motor/motor.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../destinations/domain/saved_destinations.dart";
import "../domain/directions.dart";
import "../domain/map_route.dart";
import "../domain/tile_source.dart";

/// Tuguegarao, when there is nothing to fit: the province's centroid falls on
/// empty Sierra Madre forest.
const _fallbackCentre = LatLng(17.6132, 121.7270);

/// [openDirections] to [place], saying so when nothing opened: every
/// directions control calls this, so a failure reads the same everywhere.
Future<void> showDirections(BuildContext context, Destination place) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await openDirections(
    lat: place.coords.lat,
    lng: place.coords.lng,
    label: place.name,
  );
  if (opened) return;
  messenger.showSnackBar(
    const SnackBar(content: Text("Couldn't open a map app for directions.")),
  );
}

/// A camera move the eye can follow, the Apple Maps fly: the centre travels
/// straight, and when the ends are more than a screen apart the zoom pulls
/// back mid-way just far enough to fit both, then settles in. Crossing at
/// the overview zoom also loads a handful of tiles instead of every
/// street-level tile on the way. Both maps fly with it.
class CameraFlight {
  factory CameraFlight({
    required MapCamera from,
    required LatLng to,
    required double toZoom,
  }) {
    final overview = CameraFit.coordinates(
      coordinates: [from.center, to],
      padding: const EdgeInsets.all(AppSpace.x12),
    ).fit(from).zoom;
    return CameraFlight._(
      from.center,
      from.zoom,
      to,
      toZoom,
      max(0, min(from.zoom, toZoom) - overview),
    );
  }

  const CameraFlight._(
    this._from,
    this._fromZoom,
    this._to,
    this._toZoom,
    this._dip,
  );

  /// Its own motion, declared here rather than in `AppMotion` (PREFERENCES):
  /// a camera crossing a map needs longer than chrome's 350ms to follow, and
  /// must not overshoot, which makes people queasy.
  static const motion = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 700),
    snapToEnd: true,
  );

  final LatLng _from;
  final double _fromZoom;
  final LatLng _to;
  final double _toZoom;

  /// How far below the straight zoom line the middle of the flight sits.
  final double _dip;

  /// The camera at [t], 0 (where it was) to 1 (arrived). `pi` is latlong2's.
  ({LatLng center, double zoom}) at(double t) => (
    center: LatLng(
      lerpDouble(_from.latitude, _to.latitude, t)!,
      lerpDouble(_from.longitude, _to.longitude, t)!,
    ),
    zoom: lerpDouble(_fromZoom, _toZoom, t)! - _dip * sin(pi * t),
  );
}

/// Flies [camera] with [CameraFlight] on its own spring (flutter_map has no
/// animated move). A new flight starts from wherever the camera is; reduced
/// motion moves at once. Both maps' states mix this in.
mixin CameraFlying<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  final camera = MapController();
  late final _flight = SingleMotionController(
    motion: CameraFlight.motion,
    vsync: this,
  );
  VoidCallback? _step;

  void flyCamera(LatLng to, double zoom) {
    if (MediaQuery.disableAnimationsOf(context)) {
      camera.move(to, zoom);
      return;
    }
    final flight = CameraFlight(from: camera.camera, to: to, toZoom: zoom);
    void step() {
      if (!mounted) return;
      final at = flight.at(_flight.value);
      camera.move(at.center, at.zoom);
    }

    if (_step case final previous?) _flight.removeListener(previous);
    _step = step;
    _flight
      ..stop()
      ..value = 0
      ..addListener(step)
      ..animateTo(1);
  }

  @override
  void dispose() {
    _flight.dispose();
    camera.dispose();
    super.dispose();
  }
}

/// The basemap with the places as pins, edge to edge; `MapScreen` owns the
/// chrome. Selection lives in [mapSelectedIdProvider] so Place detail can
/// land here on a pin.
class MapView extends ConsumerStatefulWidget {
  const MapView({required this.destinations, super.key});

  final List<Destination> destinations;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView>
    with SingleTickerProviderStateMixin, CameraFlying {
  /// The area the pins occupy, or null when there is nothing to fit.
  LatLngBounds? get _bounds {
    final points = widget.destinations
        .map((d) => LatLng(d.coords.lat, d.coords.lng))
        .toList();
    if (points.isEmpty) return null;
    return LatLngBounds.fromPoints(points);
  }

  /// A chosen pin is brought to the middle: from elsewhere (Place detail's
  /// "Getting there"), from the sheet's rail, or tapped on the map.
  void _onSelected(String? previous, String? next) {
    if (next == null || next == previous) return;
    final place = widget.destinations.where((d) => d.id == next).firstOrNull;
    if (place == null) return;
    final zoom = camera.camera.zoom < 13 ? 13.0 : camera.camera.zoom;
    flyCamera(LatLng(place.coords.lat, place.coords.lng), zoom);
  }

  /// Frames a route just opened. It does not also select a stop: both would
  /// move the camera, and whichever ran last would win.
  void _onRoute(MapRoute? previous, MapRoute? next) {
    if (next == null) return;
    final points = _currentPointsFor(next);
    if (points.length < 2) return;
    camera.fitCamera(
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

  /// A route's stops as coordinates, in order, resolved against every
  /// destination: a filter must never drop a stop from the line.
  static List<LatLng> _pointsFor(
    MapRoute route,
    Map<String, Destination> byId,
  ) => [
    for (final id in route.destinationIds)
      if (byId[id] case final d?) LatLng(d.coords.lat, d.coords.lng),
  ];

  /// The same for the listener: `read` is right in a one-off event, wrong in
  /// a build (the line must appear once the destinations load).
  List<LatLng> _currentPointsFor(MapRoute route) => _pointsFor(route, {
    for (final d in ref.read(allDestinationsProvider).value ?? const [])
      d.id: d,
  });

  @override
  Widget build(BuildContext context) {
    // Selection, saved places and the route are watched by the layers that
    // draw them, so a pin tap rebuilds the pins, not the map.
    final source = ref.watch(tileSourceProvider);
    final bounds = _bounds;
    ref.listen<String?>(mapSelectedIdProvider, _onSelected);
    ref.listen<MapRoute?>(activeMapRouteProvider, _onRoute);

    return FlutterMap(
      mapController: camera,
      options: MapOptions(
        // Fit the pins when there are any, never open on empty sea.
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
        Basemap(source: source),
        // Under the pins: the line joins the stops, the pins are the stops.
        const _RouteLine(),
        _Pins(destinations: widget.destinations),
        MapAttribution(source: source),
      ],
    );
  }
}

/// The tiles every map draws: the network basemap with each downloaded
/// town's pack over it, off disk where it has coverage. Tiles appear
/// without flutter_map's fade-in, an offscreen layer per fading tile.
class Basemap extends ConsumerWidget {
  const Basemap({required this.source, super.key});

  final TileSource source;

  static const _display = TileDisplay.instantaneous();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(openPacksProvider).value ?? const [];
    return Stack(
      fit: StackFit.expand,
      children: [
        TileLayer(
          urlTemplate: source.urlTemplate,
          maxNativeZoom: source.maxZoom,
          // Required by the OSM tile policy, and good manners on any
          // source: it is how an operator tells our traffic apart from a
          // scraper's.
          userAgentPackageName: "ph.gov.cagayan.lakbayan",
          tileDisplay: _display,
        ),
        for (final pack in packs)
          TileLayer(
            key: ValueKey("pack-${pack.townId}"),
            tileProvider: pack.provider,
            tileDimension: packTileDimension,
            maxNativeZoom: packMaxZoom,
            tileDisplay: _display,
          ),
      ],
    );
  }
}

/// The route being shown, as a line through its stops. An authored
/// polyline, not a computed road route (D-11): it draws from the pack with
/// no signal, which a routing engine could not.
class _RouteLine extends ConsumerWidget {
  const _RouteLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(activeMapRouteProvider);
    if (route == null) return const SizedBox.shrink();
    // Watched, not read: the route is usually opened before the destination
    // list has arrived, and the line has to appear when it does.
    final all =
        ref.watch(allDestinationsProvider).value ?? const <Destination>[];
    final points = _MapViewState._pointsFor(route, {
      for (final d in all) d.id: d,
    });
    if (points.length < 2) return const SizedBox.shrink();
    return PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          color: context.lakbayan.spatial,
          strokeWidth: AppStroke.mapRoute,
          borderColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderStrokeWidth: AppStroke.regular,
        ),
      ],
    );
  }
}

/// The places as pins: the only part of the map that a selection, a save or
/// a route's numbering changes.
class _Pins extends ConsumerWidget {
  const _Pins({required this.destinations});

  final List<Destination> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(mapSelectedIdProvider);
    final saved = ref.watch(savedDestinationsProvider);
    final route = ref.watch(activeMapRouteProvider);

    // Where each stop falls in the route, so its pin can carry the number.
    // The order *is* the route (`docs/DATA_MODEL.md`), and a bare line does
    // not say which end you start from.
    final order = <String, int>{
      if (route != null)
        for (final (index, id) in route.destinationIds.indexed) id: index + 1,
    };
    final slot = _Pin.slotOf(context);

    return MarkerLayer(
      markers: [
        for (final d in destinations)
          Marker(
            point: LatLng(d.coords.lat, d.coords.lng),
            width: _Pin.labelWidth,
            height: slot * 2,
            // The dot sits in the lower slot; this puts its centre on
            // the coordinate so a label above never shifts the pin.
            alignment: _Pin.anchor,
            child: _Pin(
              // `Marker` is a data class, not a widget, so it cannot
              // be found by type. The key is how a test addresses one.
              key: Key("pin-${d.id}"),
              destination: d,
              slot: slot,
              selected: d.id == selectedId,
              saved: saved.contains(d.id),
              stopNumber: order[d.id],
              onTap: () =>
                  ref.read(mapSelectedIdProvider.notifier).select(d.id),
            ),
          ),
      ],
    );
  }
}

/// A place on the map. Blue circle with a white ring; green when saved; the
/// selected one grows, gains a centre dot and its name on an ink capsule.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.destination,
    required this.slot,
    required this.selected,
    required this.saved,
    required this.onTap,
    this.stopNumber,
    super.key,
  });

  final Destination destination;

  /// Each half's height, from [slotOf].
  final double slot;
  final bool selected;
  final bool saved;

  /// Its 1-based position when a route is being shown, else null.
  final int? stopNumber;

  final VoidCallback onTap;

  static const _dot = 22.0;
  static const _dotSelected = 28.0;
  static const _ring = 3.0;
  static const labelWidth = 160.0;
  static const anchor = Alignment(0, -0.5);

  /// Each of the pin's two halves (the name above, the dot below): tall
  /// enough for the selected dot, a stop's numeral and the name capsule at
  /// the person's text size, so none of them spills out of the marker's
  /// fixed box (STANDARDS 6.7). Equal halves keep [anchor] on the dot.
  static double slotOf(BuildContext context) {
    final label =
        MediaQuery.textScalerOf(context)
            .lineHeightOf(AppTypography.labelMedium) +
        2 * AppSpace.x1;
    final numeral = StopNumeral.sideOf(
      context,
      size: _dotSelected,
      ring: _ring,
    );
    return max(_dotSelected, max(numeral, label)).ceilToDouble();
  }

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
              height: slot,
              child: selected
                  ? Center(
                      // The name lands on the pin with the pin's own weight.
                      child: PopIn(
                        alignment: Alignment.bottomCenter,
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
                                color: scheme.surfaceContainerLowest,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(
              height: slot,
              child: Center(
                // The number outranks the centre dot: both say "this one
                // matters", and only one of them says where it comes in the
                // trip. The numeral is the itinerary list's too.
                child: number != null
                    ? StopNumeral(
                        number,
                        size: size,
                        ring: _ring,
                        color: saved ? scheme.primary : null,
                      )
                    // Chosen, the dot swells a size on the arrive spring, so
                    // it pops rather than swaps.
                    : AppMotionBuilder(
                        end: selected ? 1 : 0,
                        motion: AppMotion.arrive,
                        builder: (context, t, child) => Transform.scale(
                          scale: 1 + (_dotSelected / _dot - 1) * t,
                          child: child,
                        ),
                        child: Container(
                          width: _dot,
                          height: _dot,
                          decoration: ShapeDecoration(
                            color: saved ? scheme.primary : brand.spatial,
                            shape: CircleBorder(
                              side: BorderSide(
                                color: scheme.surfaceContainerLowest,
                                width: _ring,
                              ),
                            ),
                          ),
                          child: selected
                              ? Center(
                                  child: Container(
                                    width: AppSpace.x2,
                                    height: AppSpace.x2,
                                    decoration: ShapeDecoration(
                                      color: scheme.surfaceContainerLowest,
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ODbL credit. Not optional, and not something to tuck away: on every map
/// a person can explore, the Map tab and a trip's expanded route map.
class MapAttribution extends StatelessWidget {
  const MapAttribution({required this.source, super.key});

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
