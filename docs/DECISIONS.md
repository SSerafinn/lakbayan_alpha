# Decisions (current defaults for the scaffold)

These were open; the scaffold defaults to the left. Confirm with the team before large commitments.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D-01 | State management | **Riverpod** | Bloc |
| D-02 | Maps SDK | **flutter_map + MapLibre/OSM** (free) | Mapbox (paid, easy offline) |
| D-03 | Local cache DB | **Hive** | Isar (complex queries) |
| D-04 | Admin app stack | **React** (separate repo) | Flutter Web |
| D-05 | AR implementation | **native channel to ARCore** | ar_flutter_plugin |
| D-06 | Social auth (v1) | **Google + email** | add Facebook/Twitter later |

Accepted: province-first scope · Android-first · Firebase backend · companion positioning.
