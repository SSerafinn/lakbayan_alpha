import "package:riverpod_annotation/riverpod_annotation.dart";

part "tile_source.g.dart";

/// Where basemap tiles come from.
///
/// Raster, per D-11. The renderer decision is settled; what is not yet built is
/// the pipeline that rasterises a Protomaps pack, so this exists in two shapes
/// and the screen renders either without caring which.
sealed class TileSource {
  const TileSource();

  /// Shown over the map. **Required, not decorative** — OpenStreetMap data is
  /// ODbL, and every source in `docs/research/map-tiles.md` obliges us to
  /// credit it wherever the tiles appear.
  String get attribution;

  /// Credit link, for the sources that ask for one.
  String? get attributionUrl;

  int get maxZoom;
}

/// Tiles fetched over the network, one at a time, as the user pans.
///
/// **Development only.** The OSM tile policy permits ordinary interactive
/// browsing but prohibits bulk downloading — "download city for offline use" is
/// named in it — and the servers are donation-funded. This is here so
/// `features/maps` could be built and reviewed before the pack pipeline exists.
/// A shipped build reads [OfflinePackTiles]; see D-11 and PLAN.md.
class OnlineRasterTiles extends TileSource {
  const OnlineRasterTiles({
    this.urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    this.attribution = "© OpenStreetMap contributors",
    this.attributionUrl = "https://www.openstreetmap.org/copyright",
    this.maxZoom = 19,
  });

  final String urlTemplate;

  @override
  final String attribution;

  @override
  final String? attributionUrl;

  @override
  final int maxZoom;
}

/// A raster PMTiles pack on the device, produced by
/// `scripts/extract-tiles.mjs` and stored at `/tiles/{townId}/` — the Storage
/// path `docs/DATA_MODEL.md` already reserves.
///
/// Not reachable yet: the rasterisation step that turns Protomaps' vector
/// planet into raster tiles is the next tile task in PLAN.md. Declared now so
/// the screen's switch is exhaustive and the shape is agreed before the
/// download manager is written against it.
class OfflinePackTiles extends TileSource {
  const OfflinePackTiles({
    required this.packPath,
    this.attribution = "© OpenStreetMap contributors · Protomaps",
    this.attributionUrl = "https://www.openstreetmap.org/copyright",
    this.maxZoom = 16,
  });

  /// Absolute path to the `.pmtiles` file on this device.
  final String packPath;

  @override
  final String attribution;

  @override
  final String? attributionUrl;

  @override
  final int maxZoom;
}

/// The basemap source for this build.
///
/// One provider so the eventual switch — network while browsing, the town's
/// pack once it is downloaded — happens in a single place rather than at every
/// map in the app. Overridden in tests to keep them off the network.
@Riverpod(keepAlive: true)
TileSource tileSource(Ref ref) {
  // Deliberately not reading a downloaded pack yet. Choosing one requires the
  // download manager (`features/offline`) to say which town is on disk, and
  // silently falling back to the network would defeat the offline guarantee by
  // making a missing pack invisible rather than loud.
  //
  // No assert guards this. An assert is compiled out of release builds, so one
  // here would read as protection while being incapable of firing in the only
  // mode it claims to protect. The real guard is that `features/offline` has
  // to return a pack before a release build has anything to ship, and this
  // returning [OnlineRasterTiles] unconditionally is what makes that obvious
  // in review.
  return const OnlineRasterTiles();
}
