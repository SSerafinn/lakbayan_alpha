# Decisions (current defaults for the scaffold)

These were open; the scaffold defaults to the left. Confirm with the team before large commitments.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D-01 | State management | **Riverpod 3** | Bloc |
| D-02 | Maps SDK | **flutter_map + raster OSM tiles** (free) | Mapbox (paid, easy offline) |
| D-03 | Local cache DB | **hive_ce** | Isar (complex queries) |
| D-04 | Admin app stack | **React** (separate repo) | Flutter Web |
| D-05 | AR implementation | **native channel to ARCore** | ar_flutter_plugin |
| D-06 | Social auth (v1) | **Google + email** | add Facebook/Twitter later |

Accepted: province-first scope · Android-first · Firebase backend · companion positioning.

## Forced during scaffold setup (2026-08-03)

- **D-01 is now Riverpod 3, not 2.** On Dart 3.11.4 no `riverpod_lint` release
  co-resolves with `flutter_riverpod` 2.x. Taken while zero Riverpod code existed.
  Note the v3 API differences before writing providers.
- **D-03 is now `hive_ce`,** the maintained community fork. Plain `hive` 2.x and
  `hive_generator` no longer resolve.
- **D-02 wording corrected.** `flutter_map` renders *raster* tiles; it is not
  MapLibre (that would be `maplibre_gl`). Offline `.mbtiles` still needs an extra
  package — unresolved, and it blocks the Phase 3 offline bundle work.
