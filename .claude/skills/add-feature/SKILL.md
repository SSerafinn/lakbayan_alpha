---
name: add-feature
description: Scaffold a new feature module in this Flutter app following the project's feature-first conventions (Riverpod, go_router, freezed). Use when adding a new screen, feature, or module such as destinations, maps, audio, offline, itineraries.
argument-hint: [feature-name]
allowed-tools: Bash(dart run build_runner *) Read Grep
---

# Add a feature module

Create a new feature named `$ARGUMENTS` under `lib/features/`, following
`docs/CONVENTIONS.md` and `docs/ARCHITECTURE.md`.

## Steps
1. Create the folder structure:
   - `lib/features/$ARGUMENTS/data/` — repositories, Firestore/Storage/Hive sources
   - `lib/features/$ARGUMENTS/domain/` — freezed models + provider(s)
   - `lib/features/$ARGUMENTS/presentation/` — screens + widgets
2. Add a Riverpod provider for the feature's state (prefer `@riverpod` codegen).
3. Define models with `freezed` + `json_serializable`; run `/gen` (build_runner).
4. Register the route(s) in `lib/core/router/app_router.dart` (go_router).
5. Read data **local-first** (cache/Firestore offline) per the offline strategy.
6. Add a widget/unit test under `test/features/$ARGUMENTS/`.
7. `flutter analyze` clean; then `/commit` with `feat($ARGUMENTS): ...`.

Keep UI theming from `lib/core/theme/` — never hardcode brand colors.
