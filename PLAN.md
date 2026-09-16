# Lakbayan — Build Plan (executable)

Two tracks run in parallel:

- **Track A — Mobile app** (this repo). Flutter, Android-first.
- **Track B — Admin CMS** (`cms/`, React — see `docs/DECISIONS.md` D-04 and D-10).

Work top-to-bottom within a track. Tick tasks as they land. Follow
`docs/CONVENTIONS.md`; use the Skills in `.claude/skills/`. Run `dart analyze`
and `flutter test` before committing; commit with `/commit`.

> Tip for Claude Code: run `/implement-next` to pick up the first unchecked task.

> **Timeline is 15 weeks, not 12.** The original plan had no CMS tasks, yet the MVP
> Definition of Done requires "admin can publish a destination" and the admin
> wireframes specify 11 screens. See D-09.

---

# Track A — Mobile app

## Phase 1 · Weeks 1–2 — Foundation  → Milestone **M1 (Alpha)**
- [x] Confirm the open decisions in `docs/DECISIONS.md`; adjust `pubspec.yaml` if changed.
      *(D-01→Riverpod 3 and D-03→hive_ce forced; D-06 confirmed; D-07, D-08, D-09 added.)*
- [x] `flutter pub get` + `/gen`; app boots to a placeholder home screen.
- [x] Firebase: dev project, `flutterfire configure`, enable Auth (Google + email).
      *Prod project still outstanding — see Phase 5.*
- [x] Implement `features/auth` (splash, sign-in, Google + email) using Firebase Auth.
      *Guest browsing included per wireframe 1b / D-07.*
- [x] Define base Firestore schema + `firestore.rules`
      *(`users` + `destinations` + `segments`: models, rules, indexes,
      `docs/DATA_MODEL.md`. 13 rules tests — `cd test_rules && npm test`.)*
- [x] Wire go_router with routes; set up the theme from `lib/core/theme`.
- [x] Bootstrap the `admin` custom claim (`scripts/grant-admin.mjs`).
      *Nothing could write content before this: every content rule gates on
      `request.auth.token.admin`, and nothing set it.*
- [x] CI green (`analyze`, `custom_lint`, `test`, rules tests, build APK).
      *Three jobs — `app`, `cms`, `rules` — all passing on GitHub Actions.*
- **DoD:** a user can sign in and reach an (empty) home screen; schema + rules on the emulator.
- **Phase 1 complete.**

## Phase 2 · Weeks 3–6 — Core content
- [x] `features/destinations`: Explore/Home, Search/Browse, Destination Detail
      *(wireframes 1c and 1d).*
- [x] Wire the design system components to real data — `LakbayanListRow`,
      badges, filter chips, `StorageImage` for Storage-path photos.
- [x] Firestore offline persistence enabled explicitly, unbounded cache; every
      query filters on `status == published` or the rules deny it wholesale.
- [x] Seed real Cagayan destinations **via the CMS** *(CMS-1 landed; content
      verified flowing end to end).*
- [ ] Nearby Places by distance — needs location permission; deferred to the
      Phase 3 maps work. Explore currently shows Featured in that slot.
- [x] Serve downloaded assets from disk.
      *`localAssetFor` asks each downloaded town whether it holds a given
      Storage path. The downloader already mirrors the path under the town, so
      the local one is derivable — no second index to keep in step with the
      files. `StorageImage` reads the file directly and `audioUrlResolver`
      returns a `file://` URI, so neither a photo nor a recording touches the
      network once its town is on the phone. Deliberately **not** gated on the
      town being current, unlike the map pack: every upload gets a fresh path,
      so whatever sits on disk under one is still the right bytes for it.*
- **DoD:** browse real destinations end-to-end from Firestore, images loading.

## Phase 3 · Weeks 7–10 — Core value  → Milestone **M2 (Beta)**
- [x] `features/maps`: map view (flutter_map), pins, tap-to-detail
      *(wireframe 1c's ◈ toggle).*
      *The toggle swaps Browse's grid for a map of **the same results**, so the
      search box and category chips drive both — a change of representation, not
      of subject. It stays inside the tab rather than pushing a route, because
      wireframe 1a keeps the bottom navigation on every screen but Splash, Auth,
      Player and AR. Tile source is a provider with two shapes, network and
      pack; it returns the network one until the rasterisation step exists, and
      never falls back silently, because a missing pack must be loud rather than
      invisible. ODbL attribution is on the map, which the licence requires.*
- [x] Pre-set routes: a tour's stops joined over the basemap, plus the `geo:`
      hand-off for driving directions (D-11).
      *`ActiveMapRoute` holds an ordered list of destination **ids** and the
      name they came from. The map resolves them against every destination
      rather than the filtered results, so a category chip cannot quietly
      redraw a trip as a shorter one. Stops carry their number — the order
      **is** the route, and a bare line does not say which end you start from.
      Only the banner's dismiss clears it, because panning and tapping are
      things you do *while* reading a route. A province tour is openable from
      Saved tours, where the row had previously been something you could only
      delete.*
      *"Take me there" leaves for the device's map app: directions need live
      traffic and a routing engine, which no offline pack can provide. It asks
      for `geo:lat,lng?q=…` rather than a bare coordinate, since the bare form
      centres a map without marking anything to be taken **to**, and falls back
      to a web map when nothing claims `geo:`. Both schemes need a `<queries>`
      entry in `AndroidManifest.xml` or `canLaunchUrl` answers false on API 30+
      with nothing thrown. `url_launcher` arriving also wires the ODbL
      copyright link the map attribution had been deferring for want of it.*
- [x] `features/audio`: just_audio player + `flutter_tts` fallback; segment list UI
      *(wireframe 1e).*
      *One `Narrator` interface over both engines, so the UI never asks which is
      playing and a fake drives every widget test — neither plugin runs in a test
      harness. Recording wins when a stop has both; a stop whose recording will
      not resolve falls back to its script rather than going silent. Speech gets
      no scrubber, because the engine reports no length and cannot seek, and
      drawing one would be a fabrication. Auto-advance skips stops with nothing
      to play. **Background and lock-screen playback are not wired** —
      `audio_service` needs a foreground service and a background isolate; this
      interface is what such a handler would delegate to.*
- [x] `features/offline` — manifest, download engine, screen, and packs on the map.
      - [x] `generateOfflineBundle(town)` in `functions/`, plus the CMS screen
            that drives it. Writes `offlineBundles/{townId}`: which places, how
            many bytes, and a content fingerprint a phone can compare against.
            Verified end to end against the emulator, including the status
            flipping to `ready` once a real rendered pack was uploaded.
      - [x] Per-town download manager: resolve the manifest's assets, fetch
            them, report progress, survive a cancelled or failed download.
            *Everything lands in a `.partial` directory and is moved into place
            only when the last file arrives, so a failed, cancelled or killed
            download leaves no trace that the town is present. The record is
            dropped before the old directory is, so a crash mid-swap reads as
            absent rather than downloaded-but-missing.*
      - [x] Hive tracking of what is downloaded and at which version, so a
            stale town can be told from a missing one.
            *JSON in a `Box<dynamic>`, matching `AppPreferences`. A record an
            older build cannot decode reads as absent, which offers a
            re-download rather than crashing the one screen whose job is to
            work when nothing else does.*
      - [x] Downloaded packs render on the map.
            *All current packs are layered **over** the network basemap rather
            than one being chosen. A pack covers only its own town, so each
            draws where it has coverage and nothing elsewhere — which sidesteps
            "which town is the user in" and degrades correctly: with no signal
            the downloaded towns appear and the rest is blank. `OfflinePackTiles`
            is gone from the `TileSource` union; it had become a variant nothing
            returned, which is dead code wearing a design's clothes.*
      - [x] Wireframe 1f: the download screen itself.
            *Reached from Profile, offered to guests too — wireframe 1b keeps
            discovery open without an account, and taking a town with you is
            discovery. A `pending` bundle is shown but not offered: downloading
            one would produce a town with no map and no way to say why.*
- [x] `features/itineraries`: create-your-own-tour + saved tours *(wireframe 1g).*
      *A new collection, `users/{uid}/itineraries` — a visitor's plan cannot
      live in `tours`, which `firestore.rules` gates on the admin claim, and
      relaxing that would open the province's catalog to anybody with an
      account. Owner-only in both directions, unlike `users/{uid}` itself:
      admins can read a profile for the CMS, but nobody has business reading
      what somebody is doing on Saturday. Four rules tests pin that.
      Saving a province tour records the **id** rather than a copy, so a tour
      the province later edits stays correct. The selected tab moved into a
      provider so Explore's "Create your own tour" hero can send somebody to
      Itineraries without threading a callback through two widgets.*
- [x] `features/profile` *(wireframe 1h, on the 2.1 redesign: brand block,
      Saved places, Downloaded towns, Appearance, Sign out)*. Global
      loading/empty/offline states exist per screen; a shared pass is still
      Phase 5 work.
- [x] **Redesign 2a–2k (D-14)** across Home, swipe mode, Map, Place detail,
      Itineraries, Profile, on tokens 2.1.0.
- [x] **Motion on one vocabulary.** `motor` added; `AppMotion` is two
      `CupertinoMotion` springs (`chrome`, `arrive`) and one fade, in
      `lib/core/theme/app_motion.dart`. The tab bar, search capsule, swipe
      flight, thumbnail pop-in and save heart all ride them; the hand-tuned
      `SpringDescription`, the tab bar's `AnimationController` and the
      `easeOutBack` tweens are gone. Bring-back flights run concurrently, so
      spam-tapping the skipped stack never waits.
- [x] **Explore search rebuilt** as a 48dp circle pinned top-right over the
      hero (`HomeChromeLayer`), growing leftward into a field with a scrim and
      a results panel under it; the tab bar hides while it is open. Search
      logic (`homeQuery`, `homeResults`) unchanged. The swipe entry row is a
      fan of three featured covers, no longer a text row.
- [x] **Place detail expanded**: category and tags as badges, history folded
      to four lines, audio guide inline (stops and player, no longer behind a
      row), Plan your visit (hours, entry, best time, getting around, See it
      on the map), More in the town. Every field shown is already editable in
      the CMS. Sample data carries history, practical facts, tags and TTS
      stops for four places so the full screen previews.
- [x] **Density and type tightened**: section 16, row pad 8, group inset 4;
      `titleLarge` 24/800, `titleMedium` 19/800, `hero` 28/800, mirrored in
      `design/tokens.json` and `docs/DESIGN_SYSTEM.md`.
- [x] **Tests behind the redesign.** Widget tests updated to assert against
      the 2.1 screens (`audio_guide_test`, `auth_sheet_test`,
      `destinations_test`, `itineraries_test`, `landing_test`,
      `map_view_test`, `widget_test`). All 89 Flutter tests pass.
- [ ] **Explore hero**: FEATURED and AR badges sit under the status bar; the
      hero draws from y = 0 and insets them by the gutter only.
- [ ] **Share on Place detail** is a placeholder snackbar.
- **DoD:** download a town → maps + audio guides work fully offline. **Met.**
      The pack draws the basemap, and photos and recordings now come off disk
      through `localAssetFor`, so a downloaded town needs no network at all.
      The files had been written since #65; for three PRs nothing read them.
- [x] **Spike — resolved without hardware, and it changed the renderer.**
      `scripts/extract-tiles.mjs` builds a town pack from the destinations'
      coords using D-11's buffer union (4.6× fewer tiles than a whole
      municipality at z16). The vector stack turned out to be uninstallable
      here; every tile package is locked out by *our own* `latlong2` pin, which
      `flutter_map` never required. Relaxed, raster resolves with one downgrade
      and no adapter code. **Renderer is now raster** — see D-11 and
      `docs/research/map-tiles.md`. `flutter_map_pmtiles` is in `pubspec.yaml`.
- [x] **Tile pipeline:** rasterise a Protomaps pack per town.
      *`docker/tiles` plus `tools/tiles/rasterise.mjs`. Renders each tile with
      MapLibre Native at 512px, writes MBTiles, converts to PMTiles. Verified
      end to end against the real Protomaps planet build — 23 tiles of
      Peñablanca at z14, legible, correctly labelled. The source may be a URL:
      PMTiles is range-readable, so no planet download is needed. Two traps are
      documented in `docs/DOCKER.md` because both fail silently or
      incomprehensibly: the renderer needs a virtual display, and `xvfb-run`
      deadlocks as PID 1.*
- **Biggest risk in the project.** Offline bundles alone are a Cloud Function
  manifest, a download manager, Hive tracking, version invalidation and tile
  serving. Source and renderer are both settled — Protomaps PMTiles, rendered
  as raster (D-11). What remains unproven is the rasterisation step, which is
  build-time tooling rather than app code, and how the result looks.

## Phase 4 · Weeks 11–12 — AR pilot *(stretch — only if on schedule)*
- [ ] `features/ar`: ARCore Augmented Images native channel behind a Dart interface.
- [ ] One pilot museum exhibit; graceful fallback to Destination Detail when unsupported.
- **DoD:** one exhibit recognized and overlaid on a test device (or documented if cut).

## Phase 5 · Weeks 13–15 — Ship  → Milestone **M3 (MVP RC)**
- [ ] Create the **production** Firebase project; keep its config out of the repo (D-08).
- [ ] Integration pass; empty/error/loading states everywhere.
- [ ] Harden `firestore.rules`; extend the rules test suite; wire Analytics + Crashlytics.
- [ ] Release signing config + release SHA-1 registered for Google Sign-In.
- [ ] QA, bug-fix, demo build; tag a release candidate.
- **DoD:** MVP release candidate runs on Android; core KPIs reporting; demo ready.

---

# Track B — Admin CMS

Lives in `cms/` in this repo, React (D-04 for the stack, D-10 for the monorepo —
the schema and design tokens are shared, and a repo boundary would split changes
that must land atomically). Eleven screens per the admin wireframes. Reuses
`tokens.json` from the design system — it is platform-agnostic W3C design tokens,
so the same ramps and type scale become CSS custom properties.

Firestore rules, indexes and `docs/DATA_MODEL.md` stay owned by **this** repo. The
CMS consumes that contract; it does not redefine it.

## CMS-0 · Week 3 — Scaffold
- [x] `cms/` — React + TypeScript + Vite, Firebase SDK. *(Monorepo, not a
      separate repo — D-10.)*
- [x] `design/tokens.json` committed as the shared source of truth;
      `cms/scripts/gen-tokens.mjs` generates CSS custom properties from it so the
      palette is derived rather than retyped.
- [x] Admin login + role gating *(screen 1)*. Non-admins get a distinct
      "not an administrator" state — they signed in fine, they are just not staff.
- [x] Point at the Firebase emulators in dev, same demo project as the app.
- [x] App shell with the seven-section sidebar; dashboard with live counts *(screen 2)*.
- [ ] Firebase Hosting target + deploy.

## CMS-1 · Weeks 4–6 — Destinations  → **unblocks mobile Phase 2**
- [ ] Dashboard *(screen 2)* — activity feed and quick actions. The live counts
      shipped with CMS-0; this box is the rest of the screen.
- [x] Destinations list — the table pattern reused by every later list *(screen 3)*.
      *(Search, status filter, bulk publish/unpublish.)*
- [x] Destination Editor: Details, Location and Media tabs *(screen 4)*.
      *No interactive map picker: the Location tab searches OpenStreetMap by
      name, accepts manual coordinates, and renders a read-only preview to
      confirm the pin. Click-to-place lands with the Phase 3 maps work.*
- [x] Cloud Storage image upload to `/destinations/{id}/images/`.
      *(Filenames are `{timestamp}.{ext}`, not `{n}.jpg` — no renumbering on delete.)*
- [x] Publish / unpublish workflow writing `status`, gated on `publishBlockers`.
- **DoD:** a real Cagayan destination can be created, illustrated and published,
  and appears in the mobile app.

## CMS-2 · Weeks 7–9 — Content depth
- [x] Audio Guide segments editor: ordering, audio upload, TTS text *(screen 5)*.
      *A tab on the Destination Editor sharing its savebar, Ctrl+S and unsaved
      guard — segments are a subcollection but not a second save model. Ordering
      is move up/down, not drag: keyboard-reachable for a handful of stops.
      A stop with neither recording nor narration text blocks publishing.*
- [x] Tours: stop picker, cover image, featured flag *(screen 8)*.
      *One screen like guides. Stops reorder with the segment editor's controls
      — the order **is** the tour. The document id is `slugify(title)`, matching
      the importer, so a re-import updates rather than duplicates. No draft
      state: `allow read: if true` makes a tour public the moment it exists, so
      the editor refuses to save one that is not fit to be read, and warns when
      a stop is unpublished or deleted.*
- [x] Local Guides directory *(screen 9)*.
      *One screen, not two: the editor opens above the table rather than on its
      own route — six fields do not justify a second screen, and the wireframe
      only draws one. No draft state, because `firestore.rules` exposes the
      collection to every signed-in user the moment a document exists; removal
      is a hard delete, which is how a withdrawn consent gets honoured.*

## CMS-3 · Weeks 10–12 — Operations
- [x] Offline Bundles: trigger `generateOfflineBundle`, show version and status *(screen 7)*.
      *One row per town with publishable content, built or not — listing only
      existing bundles would hide the towns that need one, which is the question
      the screen exists to answer. **Check** runs the function in dry-run mode
      and compares versions, so an admin can find out whether a rebuild is
      needed without bumping the version and sending every phone off to
      re-download. A bundle is `ready` only when the map pack is in Storage too.*
- [x] Users + Admin team & roles *(screen 10)*. Replace `scripts/grant-admin.mjs`
      with a callable Cloud Function so promotion no longer needs a service account.
      *Two lists from two places: the admin team is whoever holds the custom
      claim (Auth, via `listAdmins`/`setAdminRole` in `functions/`), app users
      are the `users/` collection (Firestore, now admin-readable). The script
      stays as the bootstrap for the first admin only. The function refuses a
      self-revoke. First `functions/` in the repo — see D-12 for the conventions
      the offline-bundle function inherits.*
- [ ] AR Content editor: marker upload, exhibit binding *(screen 6)*.
      *Cut with Phase 4 if AR is dropped.*

## CMS-4 · Weeks 13–15 — Settings and ship
- [ ] Settings: taxonomy, app settings, policies *(screen 11)*.
- [ ] Global states — loading, empty, error, saving/conflict *(screen 1i)*.
- [ ] Deploy to Firebase Hosting; restrict access to admins.
- **DoD:** the province can maintain content without a developer.

---

## Cross-track dependencies

| Needed by | Depends on | Why |
|---|---|---|
| Mobile Phase 2 DoD | **CMS-1** | Content writes are admin-only; nothing to browse without it |
| CMS-0 login | `scripts/grant-admin.mjs` | The first admin has to come from somewhere |
| CMS-3 bundles | Mobile Phase 3 function | `generateOfflineBundle` lives in this repo |
| Both | `docs/DATA_MODEL.md` | One schema, owned here, consumed there |

**If the schedule slips, cut in this order:** AR (Phase 4 + screen 6), then CMS-4
Settings, then itineraries. Do **not** cut CMS-1 — the MVP DoD depends on it and
there is no content without it.
