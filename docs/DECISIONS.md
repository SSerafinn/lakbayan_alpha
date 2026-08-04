# Decisions (current defaults for the scaffold)

These were open; the scaffold defaults to the left. Confirm with the team before large commitments.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D-01 | State management | **Riverpod 3** | Bloc |
| D-02 | Maps SDK | **flutter_map + raster OSM tiles** (free) | Mapbox (paid, easy offline) |
| D-03 | Local cache DB | **hive_ce** | Isar (complex queries) |
| D-04 | Admin app stack | **React** (separate repo) | Flutter Web |
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
  MapLibre (that would be `maplibre_gl`). Offline `.mbtiles` still needs an extra
  package — unresolved, and it blocks the Phase 3 offline bundle work.
