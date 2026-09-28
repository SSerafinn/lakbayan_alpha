import "package:flutter/foundation.dart";
import "package:flutter_map_pmtiles/flutter_map_pmtiles.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../offline/domain/offline_providers.dart";

part "tile_source.g.dart";

/// Tile size in a pack, matching `tools/tiles/rasterise.mjs`.
///
/// Not flutter_map's default of 256, and getting it wrong does not fail — it
/// draws every tile at twice its proper size, which reads as a map stuck at
/// the wrong zoom. The pack's own metadata records this too; the constant is
/// here because both are written by the same decision.
const packTileDimension = 512;

/// The zoom a town pack is rendered to. `scripts/extract-tiles.mjs --maxzoom`.
const packMaxZoom = 16;

/// The basemap underneath everything.
///
/// Raster, per D-11. Downloaded packs are **not** a variant of this: they are
/// layered over it, several at a time, because each covers only its own town.
/// See [openPacks].
class TileSource {
  const TileSource({
    this.urlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    this.attribution = "© OpenStreetMap contributors",
    this.attributionUrl = "https://www.openstreetmap.org/copyright",
    this.maxZoom = 19,
  });

  final String urlTemplate;

  /// Shown over the map. **Required, not decorative** — OpenStreetMap data is
  /// ODbL, and every source in `docs/research/map-tiles.md` obliges us to
  /// credit it wherever the tiles appear.
  final String attribution;

  /// Credit link, for the sources that ask for one.
  final String? attributionUrl;

  final int maxZoom;
}

/// The network basemap for this build.
///
/// **Development only as a *sole* source.** The OSM tile policy permits
/// ordinary interactive browsing but prohibits bulk downloading, and the
/// servers are donation-funded. What a shipped build relies on offline is the
/// packs in [openPacks]; this layer fills in the rest of the province while
/// there is a connection.
@Riverpod(keepAlive: true)
TileSource tileSource(Ref ref) => const TileSource();

/// One downloaded town's map pack, opened and ready to draw.
@immutable
class OpenPack {
  const OpenPack({required this.townId, required this.provider});

  final String townId;
  final PmTilesTileProvider provider;
}

/// Every pack on this device that is current for its town.
///
/// **All of them, layered together, rather than picking one.** A pack covers
/// only its own town, so drawing them all means each renders where it has
/// coverage and nothing elsewhere. That sidesteps a question with no good
/// answer — which town is the user "in" when the map spans the province — and
/// it degrades the right way: with no signal, the downloaded towns appear and
/// the rest is blank, which is the truth.
///
/// Stale packs are excluded by [currentPackFor]. Drawing last month's map
/// because it happens to be on disk is how an offline feature starts lying.
@riverpod
Future<List<OpenPack>> openPacks(Ref ref) async {
  final store = ref.watch(downloadStoreProvider);
  final bundles = ref.watch(offlineBundlesProvider).value ?? const [];

  final packs = <OpenPack>[];
  for (final bundle in bundles) {
    final file = currentPackFor(store, bundle);
    if (file == null) continue;
    try {
      packs.add(
        OpenPack(
          townId: bundle.townId,
          provider: await PmTilesTileProvider.fromSource(file.path),
        ),
      );
    } catch (e) {
      // A corrupt or truncated pack must not take the whole map down — the
      // other towns, and the network layer, are still perfectly good.
      debugPrint("Skipping unreadable pack for '${bundle.townId}': $e");
    }
  }
  return packs;
}
