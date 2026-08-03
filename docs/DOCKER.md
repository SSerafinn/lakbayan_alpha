# Docker setup

Two containers, both optional-but-recommended:

| Service | What it is | When you use it |
|---|---|---|
| `emulators` | Firebase Emulator Suite (Auth · Firestore · Storage) | Every day, while developing |
| `toolchain` | Pinned Flutter + JDK + Android SDK | Analyze, test, codegen, reproducible APK builds |

## What is NOT containerized

**`flutter run` stays on your host machine.** A container cannot drive the Android
emulator (needs `/dev/kvm`) or a USB device (needs passthrough Docker Desktop on
Windows does not provide). You still install Flutter locally to actually run the app.

The containers exist to kill two specific problems:

1. **The JDK conflict.** Gradle 8.14 fails on JDK 26; `firebase-tools` refuses to
   run below JDK 21. No single JDK on a Windows host satisfies both. In containers
   each tool gets the Java it wants.
2. **Version drift between the three of us.** Flutter, Dart, and `firebase-tools`
   are pinned in the images, so "works on my machine" stops being a category of bug.

## Prerequisites

Docker Desktop for Windows with the WSL2 backend. Nothing else.

**Budget ~13 GB of disk.** The images are large and mostly not our doing:

| Image | Size | Where it goes |
|---|---|---|
| `lakbayan-toolchain` | 10.4 GB | ~7.8 GB base (Flutter + Android SDK), 2.4 GB NDK + CMake, 240 MB pub cache |
| `lakbayan-emulators` | 1.6 GB | Ubuntu + JDK 21 + firebase-tools + emulator jars |

If disk is tight, the 2.4 GB NDK layer is the only part worth attacking — see the
comment in `docker/flutter/Dockerfile`. Nothing in the current dependency set
compiles native code, so dropping `ndkVersion` from `android/app/build.gradle.kts`
would remove it. That stops being safe the moment a plugin ships C++.

## First run

Build both images. The `--profile tools` flag is **required** — `toolchain` sits
behind a profile so that `docker compose up` doesn't start it, and a bare
`docker compose build` skips it silently, leaving you without the image:

```bash
docker compose --profile tools build
```

Then start the backend:

```bash
docker compose up emulators
```

The Emulator Suite UI is at <http://localhost:4000>. Leave this running while you work.

## Everyday commands

Start the shared backend (add `-d` to background it):

```bash
docker compose up emulators
```

Run the exact checks CI runs:

```bash
docker compose run --rm toolchain flutter analyze
```

```bash
docker compose run --rm toolchain dart run custom_lint
```

```bash
docker compose run --rm toolchain flutter test
```

Code generation after touching a model or provider:

```bash
docker compose run --rm toolchain dart run build_runner build
```

Interactive shell, if you want to poke around:

```bash
docker compose run --rm toolchain bash
```

## Building an APK

The container's `build/` is a named volume, deliberately isolated from your Windows
working tree. To get the APK onto your host, copy it into `artifacts/`:

```bash
docker compose run --rm toolchain bash -c "flutter build apk --debug && cp build/app/outputs/flutter-apk/app-debug.apk artifacts/"
```

It lands in `artifacts/app-debug.apk` on Windows. `artifacts/` is gitignored.

## Pointing the app at the emulators

The emulator ports are published to your host, so the address depends on where the
app is running:

| Running on | Host to use |
|---|---|
| Android emulator | `10.0.2.2` (the emulator's alias for host loopback) |
| Physical device on Wi-Fi | Your PC's LAN IP, e.g. `192.168.1.x` |
| Code inside the `toolchain` container | `emulators` (the compose service name) |

`firebase.json` binds the emulators to `0.0.0.0` so they are reachable from the
container and from a phone on your Wi-Fi. That does mean they listen on your LAN
while running — fine on a dev machine, but don't run them on untrusted Wi-Fi.

This is wired up. Run against the emulators with:

```bash
flutter run --dart-define-from-file=config/dev.json
```

On a physical device, add your PC's LAN IP — the app cannot discover it:

```bash
flutter run --dart-define-from-file=config/dev.json --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.42
```

Without those defines the app still boots, but skips Firebase entirely and logs
why. `AppConfig.useFirebaseEmulators` is a `const`, so the emulator branch is
tree-shaken out of release builds — a shipped app cannot be pointed at a laptop.

### Known startup noise until `flutterfire configure` is run

Every launch logs an unhandled `PlatformException`:

```
java.lang.IllegalStateException: FirebaseApp name [DEFAULT] already exists!
```

**This is benign and the app works** — `bootstrapFirebase` catches it and adopts
the existing app, which is why `Firebase emulators: ...` prints right after. The
cause is running with placeholder options and no `google-services.json`: Android's
`FirebaseInitProvider` and our explicit `initializeApp` race to create `[DEFAULT]`.
It disappears once Phase 1 runs `flutterfire configure` and a real
`google-services.json` lets native auto-init succeed. Don't chase it before then.

## Do not mix host and container builds carelessly

`.dart_tool/package_config.json` stores absolute paths. The Windows one points at
`C:\...`, the container one at `/app/...`. Compose keeps them in separate named
volumes so they cannot overwrite each other — but if you ever see a bizarre
"package not found" error right after switching between host and container, that is
the cause. Fix:

```bash
docker compose run --rm toolchain flutter pub get
```

and on the host, `flutter pub get`. They are independent; run both.

## Cloud Functions (Phase 3)

The functions emulator is intentionally **not** in `firebase.json`. Declaring it
without a `functions/` directory makes the whole suite print a hard error on every
startup. When Phase 3 adds `functions/`, add both a top-level `"functions"` block
and `"functions": { "port": 5001, "host": "0.0.0.0" }` under `"emulators"`. Port
5001 is already published in `docker-compose.yml`.

## Emulator data

State persists in `.emulator-data/` (gitignored) and is exported on shutdown, so
your test users and documents survive a restart. Stop cleanly to keep it:

```bash
docker compose down
```

To share a seed dataset with the team later, export it deliberately and commit it
under a named folder rather than committing the scratch directory:

```bash
docker compose exec emulators firebase emulators:export /app/.emulator-data/seed --force
```

## Bumping versions

The Flutter version is pinned in **three** places and they must move together:

- `docker/flutter/Dockerfile` — the base image tag
- `.github/workflows/ci.yml` — `flutter-version`
- whatever the three of you have installed locally (`flutter --version`)

`firebase-tools` is pinned in `docker/firebase/Dockerfile`.

## Troubleshooting

**Ports already in use** — you probably have a native `firebase emulators:start`
running, or another project's containers. `docker compose down` and check port 8080.

**Emulator won't start, Java error** — that is the host's JDK leaking in. Inside the
container it should never happen; if you see it, you are running the emulator
natively, not in Docker.

**Gradle downloads everything on each build** — the `gradle-home` volume was
removed or pruned. `docker volume ls` should show `lakbayan_gradle-home`.

**`toolchain` image missing / "service has no image"** — you ran `docker compose
build` without `--profile tools`, which skips profiled services without warning.
Re-run `docker compose --profile tools build`.

**`Failed to install the following SDK components: ndk;...`** — the toolchain image
predates the NDK layer. Rebuild it: `docker compose --profile tools build toolchain`.
