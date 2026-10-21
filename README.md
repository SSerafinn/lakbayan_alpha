# Lakbayan

Self-guided tourism companion for the **Province of Cagayan** — the official digital
companion of *Endless Fun, Cagayan*. It **complements local guides, never replaces
them**. Flutter + Firebase, Android-first.

New to the project? Work straight down this file. It should take about 30 minutes,
most of it downloads.

---

## 1 · Install the prerequisites

| Tool | Version | Why this version |
|---|---|---|
| **Flutter SDK** | **3.47.2** | Pinned. CI and the Docker image use exactly this; a different minor can change generated code. |
| **JDK** | **17** | **Not 21, not 26.** Gradle 8.14 fails on anything newer — see step 2. |
| **Android Studio** | latest | For the Android SDK, platform-tools and a device emulator. |
| **Docker Desktop** | latest, WSL2 backend | Runs the Firebase emulators. |
| **Node.js** | 22+ | Only for the security-rules tests. |

Get JDK 17 from [Microsoft Build of OpenJDK](https://learn.microsoft.com/java/openjdk/download)
or Temurin. You can keep other JDKs installed — step 2 makes sure Gradle uses this one.

> **You do NOT need the Firebase or FlutterFire CLI**, and you should **not** run
> `flutterfire configure`. The dev project's config is already committed
> (`android/app/google-services.json`, `lib/firebase_options.dart`). Running it
> would repoint the app at a project of your own. See `docs/DECISIONS.md` D-08.

## 2 · Pin Gradle's JVM ⚠️

**Do this before your first build.** It is the single most common way to lose an
hour on this project.

Create `~/.gradle/gradle.properties` — on Windows, `C:\Users\<you>\.gradle\gradle.properties`:

```
org.gradle.java.home=C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot
```

Use **forward slashes**, and correct the path to your actual JDK 17.

Why: Gradle 8.14 cannot run on JDK 26, and it reports that as a bare
`* What went wrong: 26.0.1` with no explanation. Setting `flutter config --jdk-dir`
is *not* enough — other tools (VS Code, Android Studio) start their own Gradle
daemon under `JAVA_HOME`, and Gradle reuses it. The tell is a build that fails in
under two seconds.

## 3 · Clone and generate

```bash
git clone https://github.com/SSerafinn/lakbayan_alpha.git
```

```bash
cd lakbayan_alpha && flutter pub get
```

```bash
dart run build_runner build
```

**Codegen is not optional.** `*.freezed.dart` and `*.g.dart` are gitignored, so a
fresh clone will not compile until you run it. Re-run after touching any model,
provider or Hive adapter — or use `/gen`.

## 4 · Start the local backend

```bash
docker compose up -d emulators
```

Emulator Suite UI: <http://localhost:4000>. Leave it running while you work.

First run builds the images (~13 GB of disk, mostly the Flutter/Android SDK base).
To also build the optional CI-parity toolchain image:

```bash
docker compose --profile tools build
```

The `--profile tools` flag is required — without it that service is skipped silently.

### Put something in it

A fresh emulator is empty, and an empty backend looks exactly like a broken
connection: both give you a blank Explore tab and a CMS with nothing in it.
Seed it:

```bash
cd scripts && npm install
```

```bash
node seed-emulator.mjs
```

That gives you six published Cagayan destinations — two with audio guides, one
stop of which is a real recording — two tours, three local guides, a bundle per
town for the Downloads screen, and an admin account, `test@gmail.com` /
`password`. A town is only *downloadable* once its map pack has been rendered on
your machine ([Map tile packs](docs/DOCKER.md#map-tile-packs)); until then it is
seeded as not ready, which the app shows as such. Pass a different address as an
argument if you prefer. Re-run it whenever you like: documents are keyed by slug,
so it overwrites rather than duplicates.

You will need it again after any reset — see
[Emulator data](docs/DOCKER.md#emulator-data) for when that happens.

> Emulator only. It refuses to run against anything but a `demo-` project,
> because unlike `import-content.mjs` it writes **published** documents.

## 5 · Run the app

```bash
flutter run --dart-define-from-file=config/dev.json
```

**That flag is required.** Without it the app talks to the *live* Firebase project
instead of your emulators, and Google Sign-In has no client ID. Everything appears
to work, so this is easy to miss.

Confirm from the first lines of output:

```
Lakbayan config — emulators: true, host: 10.0.2.2, googleWebClientId: set
```

`emulators: false` means the flag did not take effect. Dart-defines are compiled in,
so a **hot restart will not pick up edits** to `config/dev.json` — stop and rerun.

---

## Verify your setup

You are ready when all of these pass:

```bash
dart analyze
```

```bash
flutter test
```

```bash
cd test_rules && npm install && npm test
```

**`dart analyze`, not `flutter analyze`.** Both read the same
`analysis_options.yaml`, and riverpod_lint is a native analyzer plugin
(`plugins:` in that file) rather than a separate command. But `flutter analyze`
does not reliably load the plugin — on at least one machine here it reports a
clean tree while `dart analyze` flags real violations, and CI catches them
either way. Run the one that catches more.

It does not check formatting, and CI does:

```bash
dart format $(git ls-files '*.dart')
```

Tracked files only — the generated `*.freezed.dart` and `*.g.dart` belong to
build_runner, not to us.

Then in the app: sign up with an email, and check the user appears in the Emulator
UI Auth tab plus a `users/{uid}` document in the Firestore tab. Nothing will appear
in the Firebase *console* — that is correct, you are on the emulator.

---

## Testing on a physical phone

Recommended over the emulator: real GPS, real performance, and no virtualization
overhead.

Enable **Developer options → USB debugging**, plug in, then let the helper work
out your LAN IP and write it into a per-developer config:

```bash
node scripts/emulator-host.mjs --write
```

It skips the virtual adapters a phone cannot reach (WSL, VirtualBox, Hyper-V)
and confirms the emulator actually answers on the address it picks. Then:

```bash
flutter run --dart-define-from-file=config/local.json
```

`config/local.json` is gitignored, so your IP never lands in the shared config.

`10.0.2.2` only works on the Android *emulator* — it is the emulator's alias for
host loopback, meaningless to a real phone. You will also need a Windows Firewall
rule; both are covered in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Google Sign-In needs your own SHA-1

Every developer signs with their own debug keystore, so Google Sign-In fails on a
teammate's machine until **their** fingerprint is registered:

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android
```

Send the **SHA1** line to the project owner to add in Firebase console → Project
settings → your Android app → *Add fingerprint*. Then re-download
`google-services.json` into `android/app/` and commit it.

Email/password sign-in works without any of this.

---

## Everyday commands

| Task | Command |
|---|---|
| Run the app | `flutter run --dart-define-from-file=config/dev.json` |
| Codegen after model/provider changes | `dart run build_runner build` (or `/gen`) |
| Static analysis (includes riverpod_lint) | `dart analyze` — not `flutter analyze`, see above |
| Format Dart before pushing | `dart format $(git ls-files '*.dart')` |
| Flutter tests | `flutter test` |
| Security-rules tests | `cd test_rules && npm test` |
| Start / stop the backend | `docker compose up -d emulators` / `docker compose down` |
| Seed content + an admin after a reset | `cd scripts && node seed-emulator.mjs` |
| Plan an offline map pack for a town | `cd scripts && node extract-tiles.mjs "Peñablanca"` (add `--run` to build it) |
| Rasterise that pack for the app | `docker compose --profile tiles run --rm tiles node rasterise.mjs …` — see [docs/DOCKER.md](docs/DOCKER.md#map-tile-packs) |
| Add or remove an admin | CMS → **Users & roles** (first admin on a fresh project: `scripts/grant-admin.mjs`) |
| Deploy the CMS | `firebase deploy --only hosting:cms --project project-lakbayan` — see [cms/README.md](cms/README.md#deploy) first |
| Cloud Functions tests on the host | `cd functions && npm install && npm test` |
| Find the emulator host for a phone | `node scripts/emulator-host.mjs` |
| Refill an empty emulator | `cd scripts && node seed-emulator.mjs` |
| Reproducible build, matching CI | `docker compose run --rm toolchain flutter test` |
| Design system specimen | run the app → Profile tab → **Design system** |

`flutter run` must be on the **host** — a container cannot reach the Android
emulator or a USB device. Everything else can run in the pinned toolchain image.

Stop the backend with `docker compose down` rather than killing it: emulator data
is exported on clean shutdown, so your test users survive.

## Gotchas that have already cost us time

1. **Build fails in <2s with `26.0.1`** — JDK 26. See step 2.
2. **Fresh clone will not compile** — you skipped `build_runner` in step 3.
3. **Config edits ignored** — dart-defines are compile-time; hot restart is not enough.
4. **Emulator calls hang on a physical device** — Windows Firewall. Load
   `http://<your-ip>:4000` in the phone's browser to confirm before touching code.
5. **Every list in the app is empty** — usually a stale `FIREBASE_EMULATOR_HOST`
   after a DHCP change, or a phone still signed in from before an emulator
   reset; not missing content. The app logs which on startup
   (`adb logcat -s flutter`, look for "Firebase emulators");
   `node scripts/emulator-host.mjs` gives you the current address.
6. **Google Sign-In fails on web** — needs `GOOGLE_WEB_CLIENT_ID`; Android reads it
   from `google-services.json` instead. Android is the platform that matters here.

## Becoming an admin

Every content write in `firestore.rules` requires the `admin` custom claim.
Without it the CMS signs you in and then tells you that you are not an
administrator, which reads like a broken login but is working as designed.

On the emulator, `node seed-emulator.mjs` already creates an admin account for
you — nothing further is needed. To promote a *different* account, sign in
through the app or CMS once so the account exists, then:

```bash
cd scripts && npm install
```

```bash
node grant-admin.mjs you@example.com
```

That targets the **emulator** by default. Sign out and back in afterwards —
custom claims are baked into the ID token and do not appear until it is reissued.
For a real project, `--live` with `GOOGLE_APPLICATION_CREDENTIALS` set.

`grant-admin.mjs` is the tool for promoting a real person on a real project.
`seed-emulator.mjs` is the local shortcut and cannot touch a real project at all.

## Git workflow

### Branches

```
main            protected · release-ready · only ever receives PRs from staging
 └─ staging     integration · where feature branches land and are tested together
     └─ feat/…  your work · one branch per task, short-lived
```

**Never commit directly to `main` or `staging`.** Branch from `staging`, PR back
into `staging`. `staging` → `main` is a separate PR, made when a milestone is
ready to cut.

```bash
git switch staging && git pull
```

```bash
git switch -c feat/destination-detail
```

### Branch names

`<type>/<short-kebab-description>`, using the same types as our commits:

| Prefix | For |
|---|---|
| `feat/` | new functionality — `feat/audio-player` |
| `fix/` | bug fixes — `fix/offline-tile-cache` |
| `chore/` | tooling, deps, config — `chore/bump-flutter` |
| `docs/` | documentation only — `docs/data-model-tours` |
| `refactor/` | no behaviour change — `refactor/extract-repo` |

Keep them short-lived. A branch open for two weeks is a merge conflict waiting to
happen — especially across `lib/core/theme/`, which everything imports.

### Commits

[Conventional Commits](https://www.conventionalcommits.org/), scoped to the feature:

```
feat(auth): add guest mode to the sign-in screen
fix(maps): stop tile requests when the bundle is stale
docs(data-model): record the tours schema
```

Explain **why** in the body, not just what — the diff already shows what. If you
changed an approach or rejected an obvious alternative, that belongs here; it is
the context the next person needs and the hardest to reconstruct later.

`/commit` writes one for staged changes.

### Before you open a PR

All three must pass. CI runs them anyway, but locally is faster than a red build:

```bash
dart analyze && flutter test
```

```bash
cd test_rules && npm test
```

Re-run `dart run build_runner build` if you touched a model or provider —
generated files are gitignored, so a stale build only fails for the reviewer.

### Pull requests

- Open against **`staging`** (GitHub will default to `main` — change it).
- One task per PR. A reviewable PR is a few hundred lines; a 2,000-line PR gets
  rubber-stamped, which defeats the point.
- Fill in the template: what changed, why, and how you verified it.
- **@SSerafinn approves and merges.** Do not merge your own PR.
- **Squash merge** into `staging` so one feature is one commit and `staging`
  stays readable. `staging` → `main` uses a **merge commit**, preserving the
  individual features in release history.
- Delete the branch after merge.

### Things that must never be committed

`.gitignore` covers these, but know why:

- `config/local.json` — your LAN IP and any paid tokens
- `.env`, `**/serviceAccount*.json` — real credentials
- A **production** Firebase config — the committed one is dev-only, see D-08
- `*.g.dart`, `*.freezed.dart` — generated; committing them creates conflicts on
  every merge for no benefit

### Repository settings

Branch protection, merge strategy and Dependabot live on GitHub rather than in
this repo, so they are documented in [docs/REPO_SETTINGS.md](docs/REPO_SETTINGS.md)
— including *why*: two commits have already been lost to merge mechanics on this
project, and both are prevented by settings listed there.

### Releases

`PLAN.md` defines three milestones. Cutting one is four steps, in this order.

**1. Bump `version:` in `pubspec.yaml`**, in the PR that prepares the release.
With the tag, never ahead of it — the comment on that line records what
happened both times it drifted.

**2. Promote.** Open `staging` → `main` and merge it with a **merge commit, not
a squash**. A squash would fold every commit since the last release into one
and leave `main` unable to say what it contains.

**3. Tag `main`.**

```bash
git tag -a v0.4.0-m2 -m "M2 Beta: an offline town end to end"
```

```bash
git push origin v0.4.0-m2
```

One tag by name rather than `--tags`, which pushes every local tag you have.

**4. Merge `main` back into `staging`**, straight away, through a small PR:

```bash
git switch -c chore/sync-main-into-staging origin/staging
```

```bash
git merge origin/main
```

```bash
git push -u origin chore/sync-main-into-staging
```

Open it against `staging` and merge it with a **merge commit** as well.

Step 4 is not housekeeping; skip it and the next release is blocked. Both
branches require a PR to be up to date before it merges, and the promotion
leaves a merge commit on `main` that `staging` does not have. So the next
`staging` → `main` is refused as behind — and the obvious repair, a PR from
`main` into `staging`, is refused too, because `main` lacks everything
`staging` has gained since. Updating the branch from GitHub fails for the same
reason: it would push to a protected branch. The one shape both rules accept is
a branch cut *from* `staging` with `main` merged into it, which is what the
commands above build.

Done right after a release the two trees are identical and the PR changes no
files. It has to be a merge commit: a squash would land a new commit on
`staging` without making `main`'s commits its ancestors, and nothing would be
unblocked. This cost a release three pull requests to discover (#74, #75, #76).

## Layout

This is a **monorepo**: the Flutter app at the root, the admin CMS in `cms/`, and
the things they share — schema, rules, design tokens, emulators — at the root
where neither owns them. See `docs/DECISIONS.md` D-10.

```
lib/core/        theme, router, models, services shared across features
lib/features/    one folder per feature (data/domain/presentation)
lib/features/landing/  the first screens a new visitor sees, before sign-in
cms/             admin CMS — React + Vite (see cms/README.md)
design/          tokens.json — single source of truth for BOTH apps' styling
config/          run configuration — dev.json shared, local.json yours
scripts/         operational scripts, e.g. granting the admin claim
test_rules/      security-rules tests (Node — the emulator evaluates them, not Dart)
docker/          images for the Firebase emulators and the build toolchain
docs/            architecture, data model, conventions, decisions, docker, troubleshooting
.claude/         skills, commands, agents and settings for Claude Code
```

`firestore.rules`, `firestore.indexes.json` and `docs/DATA_MODEL.md` are owned at
the root and consumed by both apps. Change them together — use `/add-collection`.

Read `docs/DESIGN_SYSTEM.md` before touching UI, and `docs/DATA_MODEL.md` before
touching Firestore. `docs/DECISIONS.md` records why things are the way they are.

## Working with Claude Code

Project context loads from `CLAUDE.md`; procedures are Skills in `.claude/skills/`.

- `/add-feature <name>` — scaffold a feature module the project way
- `/add-collection <name>` — Firestore collection + model + rules + indexes together
- `/gen` — run build_runner
- `/commit` — Conventional Commit for staged changes
- `/implement-next` — pick up the next task from `PLAN.md`

See [PLAN.md](PLAN.md) for the 12-week build plan. Phase 1 is complete.
