# Lakbayan — Build Plan (executable)

Two tracks run in parallel:

- **Track A — Mobile app** (this repo). Flutter, Android-first.
- **Track B — Admin CMS** (`cms/`, React — see `docs/DECISIONS.md` D-04 and D-10).

Work top-to-bottom within a track. Tick tasks as they land. Follow
`docs/CONVENTIONS.md`; use the Skills in `.claude/skills/`. Run `flutter analyze`
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
- [ ] Hive caching of assets *(Phase 3, with offline bundles).*
- **DoD:** browse real destinations end-to-end from Firestore, images loading.

## Phase 3 · Weeks 7–10 — Core value  → Milestone **M2 (Beta)**
- [ ] `features/maps`: map view (flutter_map), pins, tap-to-detail, pre-set routes
      *(wireframe 1d).*
- [ ] `features/audio`: just_audio player + `flutter_tts` fallback; segment list UI
      *(wireframe 1e).*
- [ ] `features/offline`: `generateOfflineBundle(townId)` function; per-town download
      manager; offline tile packs; cache assets in Hive *(wireframe 1f;
      `docs/ARCHITECTURE.md` → offline).*
- [ ] `features/itineraries`: create-your-own-tour + saved tours *(wireframe 1g).*
- [ ] `features/profile` + global loading/empty/offline states *(wireframe 1h).*
- **DoD:** download a town → maps + audio guides work fully offline.
- [x] **Spike — resolved without hardware, and it changed the renderer.**
      `scripts/extract-tiles.mjs` builds a town pack from the destinations'
      coords using D-11's buffer union (4.6× fewer tiles than a whole
      municipality at z16). The vector stack turned out to be uninstallable
      here; every tile package is locked out by *our own* `latlong2` pin, which
      `flutter_map` never required. Relaxed, raster resolves with one downgrade
      and no adapter code. **Renderer is now raster** — see D-11 and
      `docs/research/map-tiles.md`. `flutter_map_pmtiles` is in `pubspec.yaml`.
- [ ] **Tile pipeline:** rasterise a Protomaps pack per town. Build-time,
      Docker, `@maplibre/maplibre-gl-native` plus `pmtiles convert`. Needed
      before offline maps work end to end; not before `features/maps` starts,
      which can use a network raster source in development.
- [ ] Routes are authored polylines on the tour, not computed — `PolylineLayer`
      over the basemap, plus a `geo:` hand-off for driving directions (D-11).
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
- [ ] Offline Bundles: trigger `generateOfflineBundle`, show version and status *(screen 7)*.
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
