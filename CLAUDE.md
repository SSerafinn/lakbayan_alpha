# Lakbayan — Project Memory

Self-guided tourism companion app for the **Province of Cagayan**; the official
digital companion of *Endless Fun, Cagayan*. It **complements local guides, never
replaces them**. Android-first, Flutter + Firebase.

> Full references live in `docs/`. Procedures live in `.claude/skills/`. Read the
> relevant `docs/*.md` before non-trivial work; don't inline their contents here.

## Stack
- **Client:** Flutter (Dart) · Riverpod · go_router · freezed
- **Backend:** Firebase (Auth, Firestore, Storage, Cloud Functions)
- **Local cache:** hive_ce (+ Firestore offline persistence)
- **Maps:** flutter_map + raster OSM tiles — Mapbox is the paid alt
- **Audio:** just_audio + audio_service · flutter_tts for narration
- **AR:** ARCore Augmented Images (Android, native channel) — stretch, isolated

## Key commands
- Install deps: `flutter pub get`
- Codegen (freezed/json/riverpod/hive): `dart run build_runner build`
- Run app: `flutter run` (**host only** — never in Docker; see `docs/DOCKER.md`)
- Analyze / test: `flutter analyze` · `dart run custom_lint` · `flutter test`
- Firebase emulators: `docker compose up emulators` (UI at localhost:4000)
- Same checks in the pinned container: `docker compose run --rm toolchain <cmd>`

`flutter analyze` does **not** run custom_lint plugins — riverpod_lint rules only
fire under `dart run custom_lint`. Run both before committing.

## Architecture (summary — see docs/ARCHITECTURE.md)
Flutter client (offline-first) ↔ Firebase. Reads are **local-first** (cache → network);
writes are minimal (user data only). External device SDKs: maps, ARCore, TTS.
Admin CMS is a separate web app on the same Firebase project.

## Conventions (see docs/CONVENTIONS.md)
- **Feature-first** folders under `lib/features/<name>/` (`data/`, `domain/`, `presentation/`); shared code in `lib/core/`.
- State = Riverpod; navigation = go_router; models = freezed + json_serializable.
- **Conventional Commits** (`feat:`, `fix:`, `chore:` …); small PRs.
- Run codegen after touching any `@freezed` / provider / Hive model.

## Data model = the FE↔BE contract (see docs/DATA_MODEL.md)
Firestore collections: `destinations` (+ `segments` sub), `offlineBundles`, `tours`,
`guides`, `users`. Change the schema only alongside `firestore.rules`,
`firestore.indexes.json`, and a `schemaVersion` bump. Use the `add-collection` skill.

## Guardrails
- **Never commit secrets** (API keys, `google-services.json`, service accounts). Use `.env` / `--dart-define`.
- **Offline-first is non-negotiable** — every read path must work from cache.
- **Keep AR isolated** — it's a stretch module built last; the app must run fully without it.
- **Security rules are code** — review every change; test with the emulator suite.
- Prefer editing existing feature modules over adding new top-level structure.
- Don't hardcode brand colors — use the theme in `lib/core/theme/`.

## Build plan
Work through `PLAN.md` phase by phase. Use `/implement-next` to pick up the next task.

## Open decisions / current defaults (see docs/DECISIONS.md)
State=Riverpod 3 · Local=hive_ce · Maps=flutter_map+raster OSM · Auth=Google+email (v1).
These are defaults, not final — confirm with the team before large commitments.
D-01 and D-03 were forced during scaffold setup; see the note in `docs/DECISIONS.md`.
