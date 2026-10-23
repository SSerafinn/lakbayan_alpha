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
      to play. **Background and lock-screen playback are wired, and not yet
      tried on a phone.** `GuideAudioHandler` gives the lock screen, the
      notification and headset buttons the same controller the in-app player
      drives, so the two cannot disagree; speech shows no length and offers no
      seek. No second isolate is needed: `MainActivity` shares the plugin's
      engine. If the service will not start, the guide plays in the app as it
      did before. The container cannot run Android, so these still need a
      device: lock-screen and notification controls, Bluetooth and headset
      buttons, TTS and auto-advance with the screen off, and a recording
      picking itself up after a phone call — Android 12+ will not let a
      backgrounded app restart its foreground service unprompted, and if that
      bites, `androidStopForegroundOnPause: false` is the known fix, at the
      cost of a wake lock held while paused.*
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
      motor springs (`chrome`, `arrive`) and one fade, in
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
- [x] **Explore hero**: FEATURED and AR badges sit under the status bar; the
      hero draws from y = 0 and insets them by the gutter only.
      *Badges now sit below the top inset, level with the search circle. The
      bars are transparent app-wide, with light icons over photo headers
      (`SystemBars`). Scrolled content meets a status bar ground
      (`StatusBarGround`); photo headers reach the top edge at rest.*
- [x] **Overflow at large text sizes and with the keyboard.** The Recently
      viewed rail, category strip, chip rows, badges and the landing greeting
      size from the scaled text (`TextScaler.lineHeightOf`), not fixed
      heights. Modal sheets share `AppSheet`, which sits on the keyboard
      instead of squeezing under it. Loose icon, stroke and radius literals
      are named tokens.
- [x] **Place to trip flow.** Add to itinerary confirms in the same sheet
      (check, "View trip"), opens the trip scrolled to the new stop, and
      retries a failed write on its row. A trip made from the sheet opens.
      Guests get Sign in. Dates can be changed after creation, with an inline
      calendar. Writes go through one `ItineraryActions`.
- [x] **Motion pass.** Press feedback is a spring shrink (`Pressable`), with
      no ripple. Glyph changes morph (`SymbolSwap`): heart, play and pause.
      The audio player grows in. Stops land, fold and slide. Pushed screens
      use the app's push, and a place photo zooms into Place detail
      (`ZoomPage`, `PhotoHero`).
- [x] **Performance pass.** Photos decode at display size. Long lists are
      lazy slivers. Browse filters without re-subscribing. The audio list
      ignores position ticks. Home's feeds stay alive across tab switches.
      Map tiles draw without a fade, and the camera flies (`CameraFlight`).
- [x] **Share on Place detail** is a placeholder snackbar.
      *It now shares text through share_plus: the name, town, a short
      description and a Google Maps pin (`placeShareText`), so it works
      offline. A link that opens the app needs a public domain for app
      links — a separate decision. Share on a trip is still a placeholder,
      pending a product call.*
- [ ] **Stops by day** (wireframe 2j). Needs a schema change; see
      `my-docs/backend-requests/itinerary-days.md`.
- [x] **Tabs keep their scroll position.** `HomeShell` keeps each visited
      tab alive offstage and cross-fades between them.
- [x] **Local guides on Explore** (#77), reading the existing `guides`
      collection. Signed-in only, as the rules require, so a guest sees no
      section at all — whether to tell guests it exists is an open product
      question. A tap calls or emails; #78 made it dial the first number
      rather than every digit in the field joined together, and hand over
      the contact itself when the phone has nothing to open it with.
- [x] **Follow-up on the #77 review** (#78). The search debounce, lost when
      search moved from Browse into the bar, is back. The trip header credits
      OpenStreetMap at rest, where it had shown tiles with none. `SwipeDeck`,
      `TripDates` and `ItineraryActions` have tests, having arrived with
      none. On a Galaxy A34 on 2026-10-01 the debounce was confirmed, and
      the credit was seen on the trip header over live emulator data. The
      guide-contact fix has **not** been checked on a phone: see the note on
      #81 below for why an earlier report of it could not have been one.
- [x] **Photographs in the sample preview** (#79). Nine of the ten sample
      places carry a real photograph from Wikimedia Commons, credited in
      `assets/images/samples/CREDITS.md` and under Profile → Photo credits.
      Anguib Beach keeps the placeholder: no freely licensed photograph of it
      exists, and a stand-in would be a different beach under its name.
      They add about 1.7 MB to every build, releases included.
- [x] **Android runs as the emulators' project, and starts once** (#81).
      In emulator mode the app came up as `project-lakbayan`, the real dev
      project, because `FirebaseInitProvider` builds the default Firebase app
      from `google-services.json` before `main()` and a default app cannot be
      replaced. The seeder and the CMS write `demo-lakbayan`, and the
      emulator keeps each project's data apart, so a phone signed in fine and
      read an empty database, with nothing denied and nothing logged — in
      every session back to 2026-09-14. The debug manifest now removes that
      provider, and the dev strip says "Not the emulators' project" if the
      two ever differ again. It was also a safety gap: with the real options
      in force, anything not routed to an emulator reached the real project.
      Separately, `audio_service` was spawning a second engine and running
      `main()` twice on every launch; `MainActivity` now extends
      `AudioServiceActivity`. Confirmed on a Galaxy A34: one startup, and a
      profile and an itinerary written from the phone land in `demo-lakbayan`.
- [x] **The seeder covers what a device test needs.** `seed-emulator.mjs`
      now writes three guides, one recorded narration and a bundle per town,
      `ready` where the map pack has been rendered locally and `pending`
      otherwise. Each had been a throwaway script, written twice.
- **DoD:** download a town → maps + audio guides work fully offline. **Met.**
      The pack draws the basemap, and photos and recordings now come off disk
      through `localAssetFor`, so a downloaded town needs no network at all.
      The files had been written since #65; for three PRs nothing read them.
- **M2 (Beta) cut at `v0.4.0-m2`.** The DoD above is what the milestone turns
  on, and it holds. Said plainly because the tag is slightly ahead of the
  checklist: **Nearby Places** (Phase 2's last box, which needs the location
  permission) and **Share** are still open. The **Explore hero** insets
  have since been fixed on `feat/home-screen`, and **Share** has since
  landed as a text share.
  None of them is what Beta means here — an offline town is — but a reader
  comparing the tag against the ticks deserves to know which is which.
  Of the two hardware checks, one is done. The `geo:` hand-off (#72) was
  confirmed on a Galaxy A34 on 2026-10-01: "Take me there" opens the phone's
  map app with the place pinned. **The airplane-mode pass (#71) has still not
  been run.** A downloaded town working with the network off is the claim this
  milestone rests on, and it is proven by tests, not yet by a phone.
  **Until #81 it could not have been run at all.** On Android the app was
  reading a different project inside the emulator from the one the seeder
  fills, so Downloads listed no town to download. Every phone check before
  #81 was therefore made in the sample-data preview, which is populated
  whatever the backend holds. That is good enough for the `geo:` hand-off,
  search, the map credit and the photographs, none of which need a backend.
  It is not good enough for anything that exists only in emulator data: the
  guide cards and the Downloads screen.
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
- [x] `features/ar`: ARCore Augmented Images native channel behind a Dart interface.
      *D-18. `ExhibitScanner` in Dart; `ExhibitScanActivity`, a separate
      native screen, over a method channel. AR is optional at install
      (ARCore 1.56.0). The theme's colours travel with each scan, so the
      native screen holds no copy of the brand.*
- [x] One pilot museum exhibit; graceful fallback when unsupported.
      *Two stand-ins on the Cagayan Museum in the emulator seed, their
      markers two of the sample photos. The fallback is the exhibits as a
      list, not Destination Detail: a phone without ARCore, a refused camera
      or markers not on the phone each land there, saying why.*
- [x] **DoD:** one exhibit recognized and overlaid on a test device (or documented if cut).
      *2026-10-21 on the Galaxy A34 (ARCore 1.57 services), against the
      emulators: both stand-in markers recognised from a monitor, the card
      named each, and the lock-on outline held to the picture as the phone
      moved.*

## Phase 5 · Weeks 13–15 — Ship  → Milestone **M3 (MVP RC)**
- [ ] Create the **production** Firebase project; keep its config out of the repo (D-08).
- [x] Integration pass; empty/error/loading states everywhere.
      *Explore's kinds, search and Add a stop showed "nothing here" while
      their places were loading or had failed: the lists they derive from
      every place dropped the `AsyncValue`. They keep it now, so each shows a
      spinner, then an error with Try again, and empty copy only when loaded
      and empty. What is on the phone outranks a later failure:
      `whenLocalFirst` and `deriveKeepingValue` (`lib/core/errors/`) decide
      by what there is, since Riverpod's `when` and `whenData` blank the
      screen through its ~38 s of retries; tests check it with the default
      retry on. The audio guide holds a capsule-shaped placeholder while
      loading and says when it cannot be read. No screen shows an
      exception's text any more, the narrator's included: `errorCopy` says
      what failed and what to do, offline or not, and logs the detail once.
      `QuietNote` and `MessageScreen` take `onRetry`, a text button wired to
      `ref.invalidate` on the source that failed; a link to nowhere gets
      `MessageScreen` rather than go_router's page. Optional rails still
      hide, each saying whether it hides on an error too. The rules are in
      `docs/DESIGN_SYSTEM.md`; widget tests inject the failures. A
      walk-through on a phone, online and off, stays part of the QA item
      below.*
- [ ] Harden `firestore.rules`; extend the rules test suite; wire Analytics + Crashlytics.
      *Rules suite extended to the rules as they stand (47 → 92 tests, no rule
      changes): admin reads and deletes of drafts and their segments, segment
      list queries, creates vs overwrites, `role` on an existing profile,
      anonymous and cross-user profile writes, who may delete in each
      collection, guides list queries, a non-boolean `admin` claim and default
      deny in both files; Storage now covers AR markers, map packs, metadata
      updates, and who may read and delete each path. Left open for the
      hardening pass: an admin can delete a `settings` document, privacy
      policy included (unpinned, TODO in firestore.test.mjs).*
      *Crashlytics is wired on the Dart side (`lib/core/diagnostics/`): on a
      live profile or release launch only, `FlutterError.onError` and
      `PlatformDispatcher.onError` report fatals; debug builds turn collection
      off and delete unsent reports, and emulator and unavailable launches
      never touch it. Every repository reports the documents it drops as
      malformed as non-fatals (`decodeOrSkip`) — `decodeOrSkip` is tested, the
      repository wiring only reviewed, as there is no Firestore fake to drive
      it. Still open: symbol upload for obfuscated release builds, and enabling
      Crashlytics in the console. Rules hardening and Analytics remain.*
- [ ] Release signing config + release SHA-1 registered for Google Sign-In.
- [x] Show what the CMS's Settings now hold (`settings/app`, `settings/policies`,
      `AppSettings`/`PolicySettings` in `lib/core/models/app_settings.dart`):
      Profile → Privacy policy and Terms (needed for the Play Store), Help and
      contact with the emergency lines (cached for offline), and the Explore
      notice while `Announcement.isLiveAt`.
      *Profile gains a second group: Help and emergency lines, Privacy policy,
      Terms of use. Help lists the province's lines, each a row that calls,
      then 911, which is there even on a phone that has never been online;
      then the tourism office as written. The lines are offline because
      Explore reads `settings/app` on every launch for its notice, so Firestore
      has cached it before Help is ever opened. A document this phone has
      never read reads as "connect once", not as "nothing published"
      (`SettingsNotYetLoaded`). The policies are selectable paragraphs under
      their "last updated" date. The notice sits above Featured on the
      surface step with an ink info glyph, and names its last day.
      The Play Console also wants the privacy policy at a public URL, which
      this does not provide.*
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
- [x] Firebase Hosting target + deploy.
      *Target `cms` in `firebase.json`, mapped in `.firebaserc` to the dev
      project's default site, with no default project so every deploy names
      one. The deploy builds first and refuses a build that talks to the
      emulators. Deep links rewrite to the app, hashed assets are cached for a
      year and the page itself never. Security headers: no framing, no
      sniffing, no indexing, and a full CSP sent report-only until the live
      site has been walked through with it. Steps, rollback and the local
      preview are in `cms/README.md` → Deploy. The deploy itself is CMS-4.*

## CMS-1 · Weeks 4–6 — Destinations  → **unblocks mobile Phase 2**
- [x] Dashboard *(screen 2)* — activity feed and quick actions. The live counts
      shipped with CMS-0; this box is the rest of the screen.
      *Plus a **Needs attention** list, which is the part that earns the
      screen: drafts with what they still lack (ready ones first), towns whose
      offline bundle is missing, behind the content or incomplete, and tours
      with stops visitors cannot see — each linking to where the fix happens.
      The feed is built from `updatedAt`, not an audit log, so deletions do not
      appear and publishing reads as an edit; who made an edit is known for
      destinations only, since tours and guides record no `updatedBy`.*
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
- [x] AR Content editor: marker upload, exhibit binding *(screen 6)*.
      *The destination editor's AR tab, open once Museum site is on (D-18):
      exhibits in order, each with a marker photo, its real width (typed in
      centimetres, stored in metres), a story, and narration recorded or read
      aloud. Exhibits save with the destination, as the audio guide does, and
      that save sets `hasAR` — there is no switch for it. A replaced marker or
      recording is deleted only after the save that drops it, so Discard
      always keeps the saved one, and deleting a destination takes its
      exhibits with it.*

## CMS-4 · Weeks 13–15 — Settings and ship
- [x] Settings: taxonomy, app settings, policies *(screen 11)*.
      *Three documents in a new `settings` collection, each saved and
      version-checked on its own: `taxonomy` (the town list the editor offers,
      replacing the hard-coded one; tags get rename, merge and remove across
      destinations; categories stay fixed, since the app draws each), `app`
      (tourism office, emergency lines, a notice for Explore) and `policies`
      (privacy and terms, each with its own "last updated"). Public read, admin
      write to those three ids only. The app shows `app` and `policies` —
      see Phase 5.*
      *Then made harder to get wrong: towns, tags and subcategories are picked
      from what exists, with "did you mean" for slips and accents, a
      non-official town never one keypress away, Undo on removal, a misspelt
      town fixable on every place that uses it, and a warning in the editor.
      Subcategories (destinations v3) sit under the six fixed categories and
      take their look, so the province adds them without an app release; the
      app shows them on a place and as a second chip row on Browse.*
- [x] Global states — loading, empty, error, saving/conflict *(screen 1i)*.
      *Loading, empty and error states shipped with each screen; the missing
      one was conflict. Saves are now checked against the version the editor
      loaded (`updatedAt`, in a transaction), so two admins can no longer
      silently overwrite each other: the second gets a dialog to load the
      other's version, overwrite, or keep editing. The destination editor
      also watches its document, quietly taking another admin's save when it
      has no edits of its own and saying so when it does. Tours and guides
      now record `updatedBy`, so both the dialog and the dashboard can say
      who.*
- [ ] Deploy to Firebase Hosting; restrict access to admins.
      *Ready to run — `cms/README.md` → Deploy, rules first. Access needs
      nothing new: the site is public files, and the rules already require the
      `admin` claim for every write and every read of unpublished data. Then promote the CSP
      from report-only.*
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
