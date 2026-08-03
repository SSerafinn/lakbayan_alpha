# Lakbayan — Build Plan (executable)

Work top-to-bottom. Tick tasks as they land. Each phase ends at a **milestone**.
Follow `docs/CONVENTIONS.md`; use the Skills in `.claude/skills/`. Run `flutter analyze`
and `flutter test` before committing; commit with `/commit`.

> Tip for Claude Code: run `/implement-next` to pick up the first unchecked task.

## Phase 1 · Weeks 1–2 — Foundation  → Milestone **M1 (Alpha)**
- [ ] Confirm the open decisions in `docs/DECISIONS.md`; adjust `pubspec.yaml` if changed.
- [ ] `flutter pub get` + `/gen`; app boots to a placeholder home screen.
- [ ] Firebase: dev/prod projects, `flutterfire configure`, enable Auth (Google + email).
- [ ] Implement `features/auth` (splash, sign-in, Google + email) using Firebase Auth.
- [ ] Define base Firestore schema + `firestore.rules` (use `/add-collection` for `destinations`, `users`).
- [ ] Wire go_router with auth-gated routes; set up the theme from `lib/core/theme`.
- [ ] CI green (`analyze`, `test`, build APK).
- **DoD:** a user can sign in and reach an (empty) home screen; schema + rules deployed to the emulator.

## Phase 2 · Weeks 3–5 — Core content
- [ ] `/add-collection destinations` finalized (+ `segments` subcollection, storage paths).
- [ ] `features/destinations`: Explore/Home, Search/Browse, Destination Detail.
- [ ] Back-end: destinations + segments CRUD; Cloud Storage image upload; publish workflow.
- [ ] Seed a few real Cagayan destinations for demoing (content track in parallel).
- **DoD:** browse real destinations end-to-end from Firestore, images loading.

## Phase 3 · Weeks 6–8 — Core value  → Milestone **M2 (Beta)**
- [ ] `features/maps`: map view (flutter_map), pins, tap-to-detail, pre-set routes.
- [ ] `features/audio`: just_audio player + `flutter_tts` fallback; segment list UI.
- [ ] `features/offline`: `generateOfflineBundle(townId)` function; per-town download manager; offline tile packs; cache assets in Hive. (See `docs/ARCHITECTURE.md` → offline.)
- [ ] `features/itineraries`: create-your-own-tour + saved tours.
- **DoD:** download a town → maps + audio guides work fully offline.

## Phase 4 · Weeks 9–10 — AR pilot *(stretch — only if on schedule)*
- [ ] `features/ar`: ARCore Augmented Images native channel behind a Dart interface.
- [ ] One pilot museum exhibit; graceful fallback to Destination Detail when AR unsupported.
- [ ] AR content model + admin fields.
- **DoD:** one exhibit recognized and overlaid on a test device (or documented if cut).

## Phase 5 · Weeks 11–12 — Ship  → Milestone **M3 (MVP RC)**
- [ ] Integration pass; empty/error/loading states everywhere.
- [ ] Harden `firestore.rules`; wire Analytics + Crashlytics.
- [ ] QA, bug-fix, demo build; tag a release candidate.
- **DoD:** MVP release candidate runs on Android; core KPIs reporting; demo ready.
