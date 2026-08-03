# Lakbayan

Self-guided tourism companion for the Province of Cagayan. Flutter + Firebase, Android-first.
This repository is set up to be built with **Claude Code** as the AI pair-programmer.

## Prerequisites
- Flutter SDK (stable) + Android Studio + an Android emulator/device
- Firebase CLI + FlutterFire CLI
- Node.js (for Cloud Functions, optional at start)

## First-run
```bash
flutter pub get
dart run build_runner build
flutterfire configure          # links a Firebase project, writes firebase_options.dart
cp .env.example .env           # add your map tile token, etc.
firebase emulators:start       # local Auth/Firestore/Storage/Functions
flutter run                    # against the dev flavor
```

## Working with Claude Code
- Project context loads automatically from `CLAUDE.md`.
- Reference docs live in `docs/`; procedures are Skills in `.claude/skills/`.
- Handy Skills / commands:
  - `/add-feature <name>` — scaffold a feature module the project way
  - `/add-collection <name>` — add a Firestore collection + model + rules
  - `/gen` — run build_runner codegen
  - `/commit` — write a Conventional Commit for staged changes
  - `/implement-next` — pick and implement the next task from `PLAN.md`

## Layout
```
lib/core/        shared theme, router, services, models
lib/features/    one folder per feature (data/domain/presentation)
docs/            architecture, data model, conventions, plan, decisions
.claude/         skills, commands, agents, settings for Claude Code
```

See `PLAN.md` for the 12-week build plan.
