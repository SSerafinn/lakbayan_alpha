import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:latlong2/latlong.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
// ImagePlaceholder lives here rather than with StorageImage.
import "../../../core/widgets/lakbayan_badge.dart";
import "../../../core/widgets/storage_image.dart";
import "../domain/tile_source.dart";

/// Roughly the middle of Cagayan, used when there is nothing to fit.
///
/// Tuguegarao rather than the province centroid: the centroid falls in the
/// Sierra Madre with nothing on it, and an empty map of forest is a worse first
/// impression than the provincial capital.
const _fallbackCentre = LatLng(17.6132, 121.7270);

/// The ◈ half of wireframe 1c — Browse's destinations as pins instead of cards.
///
/// Reads the same provider the grid does, so the search box and category chips
/// filter both views. Toggling is then a change of representation rather than a
/// change of subject, which is what the toggle implies.
class MapView extends ConsumerStatefulWidget {
  const MapView({required this.destinations, super.key});

  final List<Destination> destinations;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _controller = MapController();
  String? _selectedId;

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

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(tileSourceProvider);
    final bounds = _bounds;

    final selected = _selectedId == null
        ? null
        : widget.destinations.where((d) => d.id == _selectedId).firstOrNull;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            // Fit the pins when there are any. A fixed centre and zoom would
            // open on empty sea for a filter that matches one northern town.
            initialCameraFit: bounds == null
                ? null
                : CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(AppSpace.x8),
                    maxZoom: 14,
                  ),
            initialCenter: _fallbackCentre,
            initialZoom: 9,
            maxZoom: source.maxZoom.toDouble(),
            // Tapping the basemap dismisses the card, the same gesture that
            // dismisses a sheet.
            onTap: (_, _) => setState(() => _selectedId = null),
          ),
          children: [
            _tileLayer(source),
            MarkerLayer(
              markers: [
                for (final d in widget.destinations)
                  Marker(
                    point: LatLng(d.coords.lat, d.coords.lng),
                    width: AppSize.minTouchTarget,
                    height: AppSize.minTouchTarget,
                    // Anchor at the point of the pin, not its centre, or every
                    // marker sits half a pin north of where it belongs.
                    alignment: Alignment.topCenter,
                    child: _Pin(
                      // `Marker` is a data class, not a widget, so it cannot
                      // be found by type. The key is how a test addresses one.
                      key: Key("pin-${d.id}"),
                      destination: d,
                      selected: d.id == _selectedId,
                      onTap: () => setState(() => _selectedId = d.id),
                    ),
                  ),
              ],
            ),
            _Attribution(source: source),
          ],
        ),

        if (widget.destinations.isEmpty)
          const Positioned(
            top: AppSpace.x4,
            left: AppSpace.x4,
            right: AppSpace.x4,
            child: _Banner("Nothing matches those filters."),
          ),

        if (selected != null)
          Positioned(
            left: AppSpace.x3,
            right: AppSpace.x3,
            bottom: AppSpace.x3,
            child: _PinCard(
              destination: selected,
              onOpen: () => context.push(Routes.destination(selected.id)),
              onDismiss: () => setState(() => _selectedId = null),
            ),
          ),
      ],
    );
  }

  Widget _tileLayer(TileSource source) => switch (source) {
    OnlineRasterTiles(:final urlTemplate) => TileLayer(
      urlTemplate: urlTemplate,
      maxNativeZoom: source.maxZoom,
      // Required by the OSM tile policy, and good manners on any source: it is
      // how an operator tells our traffic apart from a scraper's.
      userAgentPackageName: "ph.gov.cagayan.lakbayan",
    ),
    // The pack path reaches the layer once `features/offline` reports a
    // downloaded town. Until then this branch is unreachable, which is why the
    // source provider never returns it.
    OfflinePackTiles() => const SizedBox.shrink(),
  };
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.destination,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Icon(
          selected ? Icons.location_on : Icons.location_on_outlined,
          // Primary, never gold. Gold is reserved for AR and Featured badges —
          // see docs/DESIGN_SYSTEM.md.
          color: scheme.primary,
          size: selected ? 40 : 32,
          shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
        ),
      ),
    );
  }
}

/// The tapped pin's destination, as a card above the map.
class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.destination,
    required this.onOpen,
    required this.onDismiss,
  });

  final Destination destination;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.lgAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: c.line),
          boxShadow: AppShadow.card,
        ),
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Row(
          children: [
            if (destination.coverImage case final path?)
              ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: StorageImage(path: path),
                ),
              )
            else
              const ImagePlaceholder(
                width: 64,
                height: 64,
                borderRadius: AppRadius.mdAll,
              ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    destination.name,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${destination.town} · ${destination.category.label}",
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpace.x2),
                  FilledButton(onPressed: onOpen, child: const Text("Open")),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: "Dismiss",
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
  Widget build(BuildContext context) => RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    attributions: [
      // Text only, with no tap handler. The credit itself is what ODbL
      // requires; the customary link to the copyright page needs a URL
      // launcher this app does not yet depend on, and an `onTap` that does
      // nothing is worse than none — it renders the label as tappable and
      // then ignores the tap. [TileSource.attributionUrl] carries the address
      // for when that dependency arrives.
      TextSourceAttribution(source.attribution),
    ],
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: c.line),
        ),
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Text(text, style: AppTypography.body),
      ),
    );
  }
}
