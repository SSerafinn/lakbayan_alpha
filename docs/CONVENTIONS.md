# Conventions

## Structure (feature-first)
```
lib/
  core/        theme, router, services, models, utils
  features/
    <name>/
      data/         repositories + Firestore/Storage/Hive sources
      domain/       freezed models + Riverpod providers
      presentation/ screens + widgets
```

## Patterns
- **State:** Riverpod (prefer `@riverpod` codegen). No singletons/global mutable state.
- **Navigation:** go_router, routes declared in `lib/core/router/app_router.dart`.
- **Models:** freezed + json_serializable; field names mirror Firestore exactly.
- **Theming:** use `lib/core/theme/` (Endless Fun palette). Never hardcode colors.
- **Codegen:** run `/gen` after touching models/providers/Hive adapters.

## Git & CI
Branching, commit format, PR rules and release tagging live in one place —
**the Git workflow section of `README.md`**. Summary: `main` ← `staging` ←
`feat/*`, never commit directly to the first two, squash into `staging`.

CI must pass: `dart analyze`, `flutter test`, `flutter build apk --debug`,
and the rules tests in `test_rules/`. Use `dart analyze` rather than
`flutter analyze` — riverpod_lint is a native analyzer plugin and only the
former reliably loads it.

## Firebase
- Separate dev/prod projects; Android flavors; Emulator Suite for local dev.
- Security rules live in the repo and are reviewed like code.

## Definition of Done (MVP)
Sign-in · browse destinations · audio (TTS) · map with pins + static route ·
download a town → fully offline · one museum AR (or documented) · admin can publish
a destination · crash-free + analytics · runs on Android.
