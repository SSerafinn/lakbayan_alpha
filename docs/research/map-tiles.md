# Offline map tiles — options for D-02

Research for Phase 3's offline bundles. Written August 2026; package versions
and licence terms move, so re-check anything load-bearing before committing.

**Bottom line:** D-02's current default cannot deliver Phase 3, for a legal
reason rather than a technical one. The recommendation is Protomaps PMTiles for
the data, but the vector-versus-raster question should be settled by measuring
on a real low-end phone, not by reading — see [The spike](#the-spike).

---

## The blocker: D-02's current default is not usable offline

D-02 says *"flutter_map + raster OSM tiles (free)"*. That is fine for online
browsing and **cannot** support offline bundles.

OpenStreetMap's [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
prohibits bulk downloading, and names our exact feature:

> Bulk downloading is *prohibited*… downloading tiles in advance instead of
> downloading when a user views those tiles… features such as "Download
> city/country for offline use" or "Save area for later".

The servers are donation-funded and offenders are blocked without notice. So the
source has to change regardless of which Flutter package renders it.

**Two separate decisions**, and conflating them is what left D-02 stuck:

1. **Where the tiles come from** — a source whose terms permit offline storage.
2. **How they are stored and rendered** — the Flutter package.

---

## Decision 1 — the source

| Source | Cost | Offline allowed | Format | Notes |
|---|---|---|---|---|
| **Protomaps** planet builds | Free | Yes — self-hosted | Vector | BSD tooling, ODbL data. `pmtiles extract` slices a region straight from the remote daily planet without downloading it. |
| **Geofabrik** tile packages | Paid | Yes, sold for it | Raster | Purpose-built for offline. Quote needed. |
| **MapTiler / Stadia / Thunderforest** | Free tier → paid | **Usually not on free tiers** | Both | Check the specific tier; most free tiers forbid permanent offline storage. |
| **Mapbox** | Paid | Yes, first-class | Both | Least engineering effort, most cost, needs a token. |
| **osm.org tiles** | Free | **No — prohibited** | Raster | The current D-02 default. Ruled out. |

Whatever is chosen, **ODbL attribution is required** and must appear on the map.

### Protomaps in practice

```bash
pmtiles extract https://build.protomaps.com/YYYYMMDD.pmtiles penablanca.pmtiles \
  --bbox=121.695,17.595,121.945,17.845 --maxzoom=15
```

Region can be a GeoJSON polygon instead of a bbox. One file per town drops
straight into Firebase Storage at `/tiles/{townId}/pack.pmtiles`, which is the
shape `docs/DATA_MODEL.md` already assumes.

---

## Decision 2 — the Flutter side

`flutter_map` [documents three approaches](https://docs.fleaflet.dev/tile-servers/offline-mapping):
caching, bulk downloading, and bundled containers. Bundled containers are what
the offline bundle design needs.

| Package | Version | Licence | flutter_map | Fit |
|---|---|---|---|---|
| `flutter_map_mbtiles` | 1.0.4 | MIT | `>=6.0.0 <9.0.0` | Raster `.mbtiles` from the filesystem. 100% offline. |
| `flutter_map_pmtiles` | 1.0.5 | MIT | `>=6.0.0 <9.0.0` | PMTiles, local file or URL, HTTP range requests. |
| `vector_map_tiles` + `vector_map_tiles_pmtiles` | 8.x stable / 10.0.0-beta | — | — | Needed to *render* vector PMTiles. v10 uses `flutter_gpu`; **8.0.0 is the recommended production version**. |
| `flutter_map_tile_caching` (FMTC) | 10.x | **GPL-3.0** | current | See warning below. |

Our `pubspec.yaml` pins `flutter_map: ^8.3.1`, which is inside both plugins'
supported range. Both were last published ~18 months ago — compatible, but not
actively developed. Worth weighing.

### FMTC's licence is a real constraint

FMTC is **GPL-3.0**. Its docs are explicit: *"if you're developing an
application that isn't licensed under GPL, this affects you and your
application's legal right to distribution."*

There is a paid commercial licence, and a **free alternative licence for
non-GPL open-source projects** — a German government contractor uses that
arrangement. If Lakbayan is going to be open-source, FMTC may be free to us.
If the province wants it proprietary, it is a cost.

Either way FMTC does **not** solve Decision 1: it still needs a source that
permits bulk downloading. It is a downloader, not a licence to download.

---

## Size — computed, not guessed

Tile counts for the Cagayan bbox `120.7,17.2 → 122.4,19.4` (including the
Babuyan Islands), and for one ~27 km municipality box.

**Whole province, cumulative:**

| maxzoom | tiles | raster @20 KB | raster @8 KB |
|---|---|---|---|
| 13 | 2,962 | 58 MB | 23 MB |
| 14 | 11,308 | 221 MB | 88 MB |
| 15 | 44,380 | 867 MB | 347 MB |
| 16 | 175,933 | **3.4 GB** | 1.4 GB |

**One municipality, cumulative:**

| maxzoom | tiles | raster @20 KB | raster @8 KB |
|---|---|---|---|
| 14 | 232 | 4.5 MB | 1.8 MB |
| 15 | 832 | 16 MB | 6.5 MB |
| 16 | 3,135 | 61 MB | 25 MB |
| 17 | 11,967 | 234 MB | 94 MB |

Each zoom level roughly quadruples the tile count. Vector PMTiles are
substantially smaller than the raster figures — Protomaps reports 70%+ savings
from internal de-duplication — so treat the raster column as the pessimistic
bound.

### The design consequence

**Do not bundle a whole municipality at high zoom.** A tourist needs street-level
detail *at the destinations*, not across 700 km² of Baggao.

Bundle the **union of small buffers around that town's destinations** — say 2 km
around each — at high zoom, plus the whole municipality at low zoom for context.
That keeps a town pack in single-digit MB while still giving z16–17 where someone
is actually standing. `pmtiles extract --region` takes a GeoJSON polygon, so the
bundle generator can build that shape from the destinations' `coords`.

This is worth designing in from the start; retrofitting it after shipping
whole-municipality packs means re-downloading everything.

**Implemented** as `scripts/extract-tiles.mjs`. Measured on six destinations
spread across one municipality, which is the realistic case:

| maxzoom | buffer union | whole municipality |
|---|---|---|
| 15 | 208 tiles · 1.6–4.1 MB | 828 tiles · 6.5–16.2 MB |
| 16 | 666 tiles · 5.2–13.0 MB | 3,037 tiles · 23.7–59.3 MB |
| 17 | 2,421 tiles · 18.9–47.3 MB | 11,501 tiles · 89.9–224.6 MB |

**4.6× fewer tiles at z16**, and the whole-municipality column reproduces the
independently-calculated table above to within 3%, which is the cross-check that
the script's tile arithmetic is right. Low-zoom context does come free: a z10
tile spans ~40 km, so it covers the municipality whether or not the region asks
for it. Figures are the raster bounds; a vector pack is materially smaller.

---

## Decided (2026-08-10)

**Source: Protomaps. Renderer: vector. Routes: authored polylines.** See D-11.

Vector was chosen for download size, which also keeps the chain free — Protomaps
publishes vector, so raster would have meant paying for a source or adding a
rasterisation step. The trade is explicit: **lighter to download, heavier to
draw**. The spike below still runs, as validation rather than a decision.

The original comparison is kept below, because the fallback matters if the
spike fails.

---

## Recommendation (as written before the decision)

**Source: Protomaps.** Free, permissive, legal for offline, one file per region,
and its shape already matches the bundle design. Nothing else is free *and*
permits offline.

**Rendering: undecided — measure it.** The honest trade-off:

- **Vector** (`vector_map_tiles_pmtiles`) — smallest files, styling flexibility,
  but rendering is CPU-heavy and `vector_map_tiles` v10 is still beta. Risk sits
  on exactly the low-end Android hardware this app targets.
- **Raster** (`flutter_map_mbtiles`) — simple, predictable, fast on cheap
  devices. But Protomaps is vector, so raster means either paying Geofabrik or
  adding a rasterisation step to the bundle pipeline.

### The spike

Half a day, before Phase 3 planning is finalised:

1. `pmtiles extract` a Peñablanca pack at maxzoom 15.
2. Render it with `vector_map_tiles_pmtiles` on the **lowest-end phone the team
   can find** — not a flagship, not an emulator.
3. Measure pan/zoom frame times and cold-start time to first tile.

If it holds up, take vector and the whole chain is free. If it stutters, fall
back to raster and price Geofabrik. Either way the decision is made on a
measurement rather than on documentation, which is the part that cannot be
researched from here.

---

## Resolution findings (2026-09-09) — the renderer decision is reopened

Before running the spike, the packages were resolved against this project as it
actually stands (Flutter 3.47.2, `flutter_map ^8.3.1`, `latlong2 ^0.10.1`). **The
stack D-11 recommended does not resolve**, and neither does anything else off the
shelf. Every line below is a `flutter pub add --dry-run` result, not a reading of
the pubspecs.

| Attempt | Outcome |
|---|---|
| `vector_map_tiles_pmtiles` (the recommended path) | ❌ every version pins `pmtiles ^1.2.0` → `latlong2 ^0.9.0` |
| `vector_map_tiles 9.0.0-beta.13` + `pmtiles ^2.2.0` | ❌ `pmtiles` 2.x wants `protobuf ^6`; `vector_tile_renderer` (**every** version, including 7.0.0-beta.1) wants `vector_tile ^2.0.0` → `protobuf ^3` |
| `vector_map_tiles 9.0.0-beta.8` | ❌ `latlong2 ^0.9.1` against our `^0.10.1` |
| `flutter_map_pmtiles` (the raster package) | ❌ same `pmtiles ^1.2.0` → `latlong2 ^0.9.0` |
| `pmtiles ^2.2.0` alone | ✅ resolves |
| **`vector_map_tiles 9.0.0-beta.9` + `pmtiles ^1.3.0` + downgrades** | ✅ **resolves** |

### What the working combination costs

The last row is the only way to render vector tiles here today. It requires, in
the app's own `pubspec.yaml`:

- **`latlong2` ^0.10.1 → ^0.9.1.** Not a `flutter_map` problem — 8.3.2 declares
  `latlong2 >=0.9.1 <0.11.0` and is happy either way. The pin is ours.
- **`lottie` ^3.3.2 → 3.3.0.** `pmtiles` 1.3.0 needs `archive ^3`, and `lottie`
  from 3.3.1 needs `archive ^4`. `lottie` is currently unimported, so this costs
  nothing today, but it is a real ceiling on a package we are keeping.
- **A beta renderer**, `vector_map_tiles 9.0.0-beta.9`.
- **Glue we write and own.** `vector_map_tiles_pmtiles` pins
  `vector_map_tiles ^8.0.0` and so cannot be used with the beta. The interface is
  small — `VectorTileProvider.provide(TileIdentity) → Future<Uint8List>` over
  `PmTilesArchive.tile(ZXY(z,x,y).toTileId())` — but it becomes ours to maintain.
- Plus `unicode` 1.1.9 → 0.3.1 and `protobuf` pinned to 3.x transitively.

### What this means

The spike was framed as "measure vector on a cheap phone, fall back to raster if
it stutters". That framing no longer holds, because **raster is not the cheap
fallback any more**:

- `flutter_map_mbtiles` and `flutter_map_pmtiles` are both blocked by the same
  `latlong2` conflict, so a raster path also means writing our own `TileProvider`.
- Protomaps publishes **vector**. Raster still means paying for a source or
  adding a rasterisation step, exactly as before.

So the three options, with what each actually costs:

1. **Take the beta stack.** Two downgrades, a beta dependency, and ~60 lines of
   glue we own. Keeps the chain free and keeps Protomaps. The spike then runs and
   measures what it was always meant to measure.
2. **Own the raster path.** `pmtiles ^2.2.0` resolves cleanly on its own, so we
   read the archive ourselves and feed bytes to a plain `flutter_map`
   `TileProvider` — the simplest code by far, no downgrades. But it needs raster
   tiles, which Protomaps does not publish, so it adds a rasterisation step or a
   paid source.
3. **Wait.** `vector_map_tiles` 10.0.0-beta.2 tracks `flutter_map ^8.2.1`; when
   its dependencies settle and a PMTiles adapter follows, options 1 and 2 both
   get cheaper. Phase 3 is scheduled now, so this is only viable if the map
   slips.

**No harness has been built**, deliberately: building one means committing to a
stack in this table, and that is the decision this section exists to put in front
of a human. Once it is made, the harness is a small job — a `FlutterMap`, a
provider, and `SchedulerBinding.addTimingsCallback` for build and raster frame
times.

`scripts/extract-tiles.mjs` is unaffected and is in the repo now. The pack it
produces is the same file under every option; only the renderer differs.

## Still open

- Which zoom levels the guides actually need — a walking tour may want z17, a
  driving route z14. Content-dependent, and it drives every size figure above.
- Whether Lakbayan will be open-source, which decides whether FMTC is free.
- Attribution placement for ODbL.
- Whether the Babuyan Islands are in scope; they extend the bbox considerably
  for very little content.

## Sources

- [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
- [flutter_map — Offline Mapping](https://docs.fleaflet.dev/tile-servers/offline-mapping)
- [FMTC docs](https://fmtc.jaffaketchup.dev/) · [pub.dev](https://pub.dev/packages/flutter_map_tile_caching)
- [flutter_map_mbtiles](https://pub.dev/packages/flutter_map_mbtiles) · [flutter_map_pmtiles](https://pub.dev/packages/flutter_map_pmtiles)
- [vector_map_tiles](https://pub.dev/packages/vector_map_tiles) · [vector_map_tiles_pmtiles](https://pub.dev/packages/vector_map_tiles_pmtiles)
- [PMTiles docs](https://docs.protomaps.com/pmtiles/) · [pmtiles CLI](https://docs.protomaps.com/pmtiles/cli)
- [Geofabrik tile packages](https://www.geofabrik.de/maps/tile-packages.html)
