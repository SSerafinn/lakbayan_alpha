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
docker compose run --rm toolchain dart analyze
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

## Cloud Functions

`functions/` is TypeScript, compiled to `functions/lib/` by `tsc`. The functions
emulator runs `lib/`, so **the emulators container builds it on every start**
(`docker/firebase/start.sh`): `npm install` into a named volume, `tsc`, then
`firebase emulators:start`. That is why `docker compose up emulators` is still
one command after a checkout, and why a stale build cannot silently serve last
week's function. The first start after a dependency change is slower by however
long `npm install` takes.

The build output lands on the host through the bind mount, gitignored. If you
want to run the functions tests or lint on the host — CI does — install there
too:

```bash
cd functions && npm install && npm test
```

Host and container installs do not collide: the container's `node_modules` is
the `functions-modules` volume, not the host directory.

The rules job in CI passes `--only firestore` to `emulators:exec` so it does not
try to start functions without a build. Do the same for any other
`emulators:exec` you add that does not need them.

**Region.** Every function is declared in `asia-southeast1`, and the CMS calls
that region explicitly. A mismatch does not error; the call 404s. Both sides
point at D-12 in `docs/DECISIONS.md`.

**Deploying** needs the project on the Blaze plan — Cloud Functions are not
available on Spark. Nothing in this repo deploys them yet.

## Map tile packs

D-11 settles the renderer as **raster**, and Protomaps publishes **vector**, so
a pack has to be rasterised before the app can read it. That happens in the
`tiles` image, behind its own profile:

```bash
docker compose --profile tiles build tiles
```

Plan the region on the host, then render it in the container:

```bash
cd scripts && node extract-tiles.mjs "Peñablanca" --maxzoom 16 --out ../tiles
```

```bash
docker compose --profile tiles run --rm tiles node rasterise.mjs --source https://demo-bucket.protomaps.com/v4.pmtiles --region /app/out/penablanca.geojson --maxzoom 16
```

Output lands in `tiles/` on the host (gitignored): a `.raster.pmtiles` to upload
to Storage at `/tiles/{townId}/`, and the intermediate `.mbtiles`, kept because
it is what you check when a pack looks wrong.

`--source` takes a local file **or an https URL**. PMTiles is range-readable, so
the remote planet build works without downloading it — there is no need to run
`pmtiles extract` first unless you want a vector pack of your own.

**On Git Bash, prefix the command with `MSYS_NO_PATHCONV=1`.** Otherwise MSYS
rewrites `/app/out/...` into `C:/Program Files/Git/app/out/...` before Docker
ever sees it, and the error names a path you never typed. PowerShell is
unaffected.

Three things about this image worth knowing before you change it:

- **It needs a virtual display.** MapLibre Native goes through GLFW and opens an
  X display even rendering offscreen. Without one it core-dumps with
  `Failed to open X display`.
- **The entrypoint starts `Xvfb` itself rather than using `xvfb-run`.** That
  wrapper deadlocks as PID 1 — it backgrounds the server and then waits while
  also being the reaper, so the container hangs with no output at all.
- **It is not in CI.** The renderer's prebuilt binaries are Linux-only and
  several hundred MB, and this is operator tooling rather than shipped code.
  The part that could silently go wrong — the tile arithmetic — lives in
  `scripts/lib/tile-region.mjs`, which CI does test.

## Emulator data

State lives in `.emulator-data/` (gitignored). It is written by
`--export-on-exit`, which fires **only on a clean shutdown**:

```bash
docker compose down
```

**Treat persistence as a convenience, not a guarantee.** `docker restart`, a
crash, `docker compose kill`, Docker Desktop restarting and a host reboot all
skip the export, and the suite comes back empty. That is the single most
confusing local failure on this project, because an empty backend and a
misconfigured one look identical from the app: a blank Explore tab, no error.

When it happens, re-seed rather than rebuilding by hand:

```bash
cd scripts && node seed-emulator.mjs
```

That restores six published destinations and an admin account in a couple of
seconds. See [Becoming an admin](../README.md#becoming-an-admin).

If the app is still empty afterwards, the emulator is not the problem — check
`FIREBASE_EMULATOR_HOST` against your current LAN IP, which a DHCP lease change
will quietly invalidate.

To share a seed dataset with the team later, export it deliberately and commit it
under a named folder rather than committing the scratch directory:

```bash
docker compose exec emulators firebase emulators:export /app/.emulator-data/seed --force
```

## Bumping versions

The Flutter version is pinned in **three** places and they must move together:

- `docker/flutter/Dockerfile` — the `FLUTTER_VERSION` build arg
- `.github/workflows/ci.yml` — `flutter-version`
- whatever the three of you have installed locally (`flutter --version`)

The toolchain image installs the SDK itself — a `git clone` at the exact tag on
a plain JDK 17 base — rather than starting from a prebuilt Flutter image. The
public ones (`cirruslabs/flutter`, `instrumentisto/flutter`) both stopped
tracking stable in 2026, which had left every SDK bump waiting on a third
party. Bumping now means changing the arg and running
`docker compose --profile tools build`.

When you bump, also check the Android SDK args at the top of the Dockerfile
against what the new Flutter wants (`compileSdkVersion`, `ndkVersion` in
`packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` at that
tag). They usually move a version or two behind.

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
