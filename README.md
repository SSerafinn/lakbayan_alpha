# Lakbayan

Self-guided tourism companion for the Province of Cagayan. Flutter + Firebase, Android-first.
This repository is set up to be built with **Claude Code** as the AI pair-programmer.

## Prerequisites
- Flutter SDK 3.41.6 + Android Studio + an Android emulator/device
- Docker Desktop (WSL2 backend) — runs the Firebase emulators and the pinned
  build toolchain; see `docs/DOCKER.md`
- Firebase CLI + FlutterFire CLI (only needed to link a real Firebase project)

> **JDK note:** Gradle 8.14 rejects JDK 26 and the Firebase CLI requires JDK 21+, so
> no single host JDK works for both. Keep JDK 17 for Gradle on the host and let the
> emulators run in Docker with their own Java 21.
>
> Pin Gradle's JVM in `~/.gradle/gradle.properties` — **not** just
> `flutter config --jdk-dir`, which other tools bypass. If you see a build fail in
> under two seconds with `* What went wrong: 26.0.1`, that's this. Fix in
> [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## First-run
```bash
flutter pub get
dart run build_runner build
flutterfire configure          # links a Firebase project, writes firebase_options.dart
cp .env.example .env           # add your map tile token, etc.
docker compose up emulators    # local Auth/Firestore/Storage/Functions
flutter run                    # against the dev flavor, from the host
```

`flutter run` always runs on the host — a container cannot reach the Android
emulator or a USB device. Everything else (analyze, test, codegen, APK builds)
can run in the pinned container: `docker compose run --rm toolchain flutter test`.

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
docs/            architecture, data model, conventions, plan, decisions, docker
docker/          images for the Firebase emulators and the build toolchain
.claude/         skills, commands, agents, settings for Claude Code
```

See `PLAN.md` for the 12-week build plan.
