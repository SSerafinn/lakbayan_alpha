# Decisions (current defaults for the scaffold)

These were open; the scaffold defaults to the left. Confirm with the team before large commitments.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D-01 | State management | **Riverpod 3** | Bloc |
| D-02 | Maps SDK | **flutter_map** — tile source superseded by D-11 | Mapbox (paid, easy offline) |
| D-03 | Local cache DB | **hive_ce** | Isar (complex queries) |
| D-04 | Admin app stack | **React** — *in `cms/`, not a separate repo; see D-10* | Flutter Web |
| D-05 | AR implementation | **native channel to ARCore** | ar_flutter_plugin |
| D-06 | Social auth (v1) | **Google + email** — *confirmed, see below* | add Facebook/Twitter later |

Accepted: province-first scope · Android-first · Firebase backend · companion positioning.

## D-06 · Auth providers — CONFIRMED (2026-08-03)

**Firebase Auth with email/password and Google Sign-In only for v1.**

This closes the conflict with the mobile wireframes, which draw Facebook and
Twitter buttons on the auth screen. Those two are **not** in v1 scope: each carries
a real external cost (Meta app review, X API pricing) that a provider toggle in the
Firebase console does not.

Note this is the one place the wireframes are *not* followed — D-07 gives wireframes
authority over app structure, but provider choice is scope, not structure. Build the
auth screen's layout from the wireframes; render two providers, not four.

## D-07 · Design system vs wireframes precedence

**Accepted.** The Claude Design *design system* governs visual design (colour, type,
spacing, component styling). The *wireframes* govern app structure (screens, layout,
navigation). Wireframes win on structure; the design system wins on styling.

First application: bottom navigation is *Explore · Map · Itineraries · Profile* per
the wireframes, not the specimen's *Trips · Saved*. See `docs/DESIGN_SYSTEM.md`.

## D-08 · Commit the dev Firebase config (2026-08-04)

**Accepted.** `android/app/google-services.json` and `lib/firebase_options.dart`
for the **dev** project (`project-lakbayan`) are committed.

They are not secrets. Firebase Android and Web API keys are public identifiers —
every shipped APK contains them and anyone can extract them in minutes. Access is
controlled by `firestore.rules`, `storage.rules` and App Check, not by hiding the
key.

Committing them is also load-bearing: the `com.google.gms.google-services` Gradle
plugin reads `google-services.json` at **build** time, so with it gitignored, CI
and every teammate fail with `File google-services.json is missing`.

A **production** project is different — keep its config out of the repo and inject
it in CI from a secret.

## D-11 · Offline tiles — source decided, renderer pending a spike (2026-08-07)

**Partially accepted.** Full analysis in `docs/research/map-tiles.md`.

**Source: Protomaps PMTiles.** D-02's default — raster tiles from
`tile.openstreetmap.org` — **cannot** be used for Phase 3, and the reason is
legal rather than technical: the [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
prohibits bulk downloading and names "download city for offline use" as an
example. Protomaps is free, permissively licensed, permits self-hosting, and
`pmtiles extract` slices a region from the daily planet build into a single file
— which is already the shape `/tiles/{townId}/` assumes.

**Renderer: vector** (`vector_map_tiles` + `vector_map_tiles_pmtiles`), chosen
for download size. It also keeps the whole chain free: Protomaps publishes
vector, so raster would have meant paying for a raster source or adding a
rasterisation step.

One thing this trades, stated plainly so nobody is surprised: **vector is
lighter to download and heavier to draw.** Files shrink (Protomaps reports 70%+
from de-duplication), but glyphs and geometry are rasterised on-device every
frame instead of being decoded as images. The saving is in bandwidth and
storage, not CPU.

So the Phase 3 spike still runs — but as **validation, not a decision**. Pin
`vector_map_tiles` to a stable release (8.x; v10 uses `flutter_gpu` and is
beta), render a Peñablanca pack on the lowest-end phone available, and measure
pan/zoom frame times. If it stutters there, the fallback is raster and the cost
is a paid tile source, so it is worth knowing early rather than after
`features/maps` is built on top.

### Renderer reopened (2026-09-09) — the paragraph above is out of date

**The source stands. The renderer is undecided again**, and the spike has not
run because there is nothing it can currently be run against.

Resolving the packages against this project — Flutter 3.47.2, `flutter_map
^8.3.1` — shows the recommended stack **cannot be installed**.
`vector_map_tiles` 8.x requires `flutter_map ^7.0.2`, and every version of
`vector_map_tiles_pmtiles` pins `pmtiles ^1.2.0`, which pins `latlong2 ^0.9.0`.
The raster packages fail the same way. Full evidence table in
`docs/research/map-tiles.md`.

One combination does resolve — `vector_map_tiles 9.0.0-beta.9` with `pmtiles
^1.3.0` — and it costs: `latlong2` down to ^0.9.1, `lottie` down to 3.3.0, a
beta renderer, and PMTiles glue we write ourselves because the adapter package
pins the older renderer. Raster is no longer the cheap fallback either: it needs
its own `TileProvider` *and* a rasterisation step or a paid source.

**Three options, priced in the research doc.** This needs a human decision before
`features/maps` starts. `scripts/extract-tiles.mjs` is unaffected and landed —
the pack is the same file under every option.

Routes are **authored polylines**, not computed. `CONVENTIONS.md` already
specifies "map with pins + static route", so no routing engine is needed:
`PolylineLayer` draws a tour's path over the basemap, fully offline. For "take
me there", hand off to the device's map app via a `geo:` URI — driving
directions need live traffic, which no offline pack can provide.

**Do not use FMTC without checking the licence.** It is GPL-3.0, which would
oblige us to release the app's source. A free alternative licence exists for
open-source projects, so this hinges on whether Lakbayan is open-source. FMTC
also does not solve the source problem — it is a downloader, not permission.

**Design consequence:** bundle the union of ~2 km buffers around each town's
destinations at high zoom, plus the whole municipality at low zoom — not the
whole municipality at high zoom. Measured: a municipality at maxzoom 16 is
~25–60 MB of raster, at maxzoom 15 ~6–16 MB. Retrofitting this after shipping
whole-municipality packs means re-downloading everything.

## D-12 · Cloud Functions: `functions/`, Singapore, callables for what a browser must not do (2026-09-04)

**Accepted.** The first Cloud Functions land with the CMS Users screen, and they
set the shape for the ones Phase 3 adds (`generateOfflineBundle`):

- **One codebase, `functions/`**, TypeScript compiled to `lib/`, ESM, Node 22.
  Linted and unit-tested in the `cms` CI job alongside `scripts/` — the
  required-check list is fixed by name (see `docs/REPO_SETTINGS.md`), so a new
  job would not gate merges.
- **Region `asia-southeast1`** (Singapore), the nearest that offers 2nd-gen
  functions. Firestore's own location is separate and unaffected. The CMS
  names the region explicitly; a mismatch 404s rather than errors, which is
  why both sides carry a comment pointing here.
- **Callables, not Firestore triggers, for admin actions.** `setAdminRole` and
  `listAdmins` exist because custom claims can only be set by the Admin SDK,
  and the Admin SDK must never run in a browser. The alternative — an
  `admins/` collection the rules read — would cost a document read on every
  write check and give the claim two sources of truth. Rejected; the claim
  stays the only authority, as D-09 established.
- **The function refuses a self-revoke.** The last admin revoking their own
  claim would lock content editing until someone found a service account key.
  Two admins can still revoke each other, so this is a guard against the
  likely mistake, not a guarantee.
- **`scripts/grant-admin.mjs` stays** — as the bootstrap for the first admin
  on a fresh project, which by definition cannot be done from a screen that
  requires an admin. It is no longer the way to add a colleague.

Consequences: the emulators container now builds `functions/` on every start
(`docs/DOCKER.md`), and deploying will need the Blaze plan.

## D-10 · Monorepo — the CMS lives in `cms/`, not a separate repo (2026-08-04)

**Accepted. This reverses D-04's "separate repo"**; the React choice stands.

D-04 was made before the schema tooling existed. Three things now cross the app
boundary and would be split by a repo boundary:

- **The schema.** A change to `destinations` touches `docs/DATA_MODEL.md`,
  `firestore.rules`, `firestore.indexes.json`, the Dart model *and* the CMS
  editor form. That is one logical change. Two repos make it two PRs that must
  land in order — and the `/add-collection` skill exists precisely to keep those
  files moving together.
- **Design tokens.** `design/tokens.json` is consumed by both. Two copies drift,
  and `docs/DESIGN_SYSTEM.md` already states that if they diverge one is wrong.
- **Local infrastructure.** The emulator suite, the rules tests and
  `scripts/grant-admin.mjs` are shared. Duplicating Docker and ports across two
  repos is friction for three developers with no upside.

Layout: Flutter stays at the root (no disruptive move), CMS in `cms/`, shared
infrastructure at the root. Deployment stays independent — the CMS ships to
Firebase Hosting, the app to Play.

`design/tokens.json` is now committed here and is the single source of truth.
`cms/scripts/gen-tokens.mjs` generates CSS custom properties from it, so the
CMS palette is derived rather than retyped. The Flutter theme still transcribes
it by hand — that remains a drift risk worth automating later.

## D-09 · Admin CMS is in scope; timeline extends to 15 weeks (2026-08-04)

**Accepted.** Build the Admin CMS as wireframed — all 11 screens — and extend the
plan from 12 to 15 weeks rather than cutting scope.

The CMS was missing from `PLAN.md` entirely, despite being required by three
existing documents: `ARCHITECTURE.md` describes it, D-04 fixes its stack, and the
MVP Definition of Done in `CONVENTIONS.md` says *"admin can publish a destination"*.
The admin wireframes specify Login, Dashboard, Destinations list, Destination
Editor, Audio Guide segments, AR Content, Offline Bundles, Tours, Local Guides,
Users + roles, and Settings.

It is also a hard dependency, not a parallel nicety: every content write in
`firestore.rules` requires the `admin` claim, so mobile Phase 2's DoD — "browse
real destinations end-to-end" — cannot be met until the CMS can publish.

Cut order if the schedule slips: AR, then CMS Settings, then itineraries. Never
CMS-1.

### Bootstrapping the admin claim

`isAdmin()` reads `request.auth.token.admin`, and until now **nothing set it** —
no account could write content, including the project owner. `scripts/grant-admin.mjs`
fills that gap: emulator by default, `--live` with a service account for a real
project. CMS-3 replaces it with a callable Cloud Function once the Users screen
exists, so promoting a teammate no longer needs a service account key.

## Forced during scaffold setup (2026-08-03)

- **D-01 is now Riverpod 3, not 2.** On Dart 3.11.4 no `riverpod_lint` release
  co-resolves with `flutter_riverpod` 2.x. Taken while zero Riverpod code existed.
  Note the v3 API differences before writing providers.
- **D-03 is now `hive_ce`,** the maintained community fork. Plain `hive` 2.x and
  `hive_generator` no longer resolve.
- **D-02 wording corrected.** `flutter_map` renders *raster* tiles; it is not
  MapLibre (that would be `maplibre_gl`). Offline tiles still need an extra
  package — see D-11.
