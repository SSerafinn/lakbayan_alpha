# Lakbayan CMS

Admin content management for the Lakbayan mobile app. React + TypeScript + Vite.

Lives in the same repo as the Flutter app **on purpose** — see `docs/DECISIONS.md`
D-10. The Firestore schema, security rules and design tokens are shared, and a
repo boundary would cut straight through changes that must land atomically.

## Run it

The emulators must be running — from the **repo root**:

```bash
docker compose up -d emulators
```

Then:

```bash
cd cms && npm install && npm run dev
```

`.env.development` points at the emulators by default, so nothing here touches
the live project. A green banner in the UI confirms which backend you are on.

## You need the admin claim

The CMS refuses anyone without `admin` on their ID token — the same claim
`firestore.rules` requires. Sign in once to create the account, then from the
repo root:

```bash
cd scripts && npm install && node grant-admin.mjs you@example.com
```

Sign out and back in afterwards: custom claims are baked into the ID token and
do not appear until it is reissued. Without this you see "Not an administrator"
rather than a login failure — you *are* signed in, you are just not staff.

## Design tokens are generated, not written

`src/styles/tokens.css` is produced from `design/tokens.json` by
`scripts/gen-tokens.mjs`, which runs automatically before `dev` and `build`.

**Do not edit `tokens.css`** — it is overwritten. Change `design/tokens.json`,
which is also the source the Flutter theme transcribes. That is what keeps the
two apps from drifting.

No raw hex in stylesheets. Use the custom properties, and prefer the design
system 2.x names, which are what the app uses: the surface ladder
(`--lk-surface-container-low` for a card), colour roles (`--lk-role-primary`,
`--lk-role-primary-text`, `--lk-role-error`), the type ramp
(`--lk-type-label-large-size` …) and shapes (`--lk-shape-md`). The 1.0.0 names
(`--lk-shadow-*`, `--lk-text-h1-*`, `--lk-radius-*`) are still emitted for
compatibility; do not reach for them in new styles. How the CMS applies the
design system, and where it departs from the phone-sized rules, is D-17 in
`docs/DECISIONS.md`.

Satoshi is loaded from the repo's `assets/fonts/`, the same files the app
bundles. `vite.config.ts` allows the dev server to read that one folder.

The design system's rules apply here too: **gold is never a button**, and green
text on a light background must be `/700` or darker for AA. See
`docs/DESIGN_SYSTEM.md`.

## Commands

| Task | Command |
|---|---|
| Dev server | `npm run dev` |
| Type check | `npm run typecheck` |
| Lint | `npm run lint` |
| Production build | `npm run build` |
| Regenerate tokens | `npm run gen:tokens` |
| Deploy | `firebase deploy --only hosting:cms --project project-lakbayan`, from the repo root — see below |

## Deploy

The CMS is a static site on Firebase Hosting, configured in the repo root's
`firebase.json` (target `cms`). `.firebaserc` maps that target to the dev
project's default site, `project-lakbayan`, which also serves
`project-lakbayan.web.app`. It sets no default project on purpose: every
deploy names its project, so nothing lands on a real one by accident.

**Before the first deploy**, once per machine and once per project:

1. `firebase login`, as an account with access to the project.
2. `cd cms && npm install`.
3. The rules the CMS depends on are live. Settings and the upload limits are
   newer than anything deployed so far, and without them the Settings page
   cannot save and photo uploads are refused:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage --project project-lakbayan
   ```

   **Offline bundles** also needs the `generateOfflineBundle` function
   (`--only functions`), which needs the project on the Blaze plan.
4. An admin exists on the live project. See *Becoming an admin* in the root
   README (`grant-admin.mjs --live`).

**Then, from the repo root:**

```bash
firebase deploy --only hosting:cms --project project-lakbayan
```

The deploy builds the CMS first, then refuses to continue if that build talks
to the emulators (`scripts/check-dist.mjs`). That happens when a
`VITE_USE_EMULATORS=true` is left in a `.env.local`, which Vite reads in every
mode. The topbar's pill says which backend a running CMS is on.

**Undo a deploy** in the Firebase console: Hosting → the site → *Release
history* → *Roll back*. It takes seconds and needs no rebuild.

### Who can use it

Anyone can load the page; only an admin can do anything with it. The site is
public files, so it holds nothing secret. The boundary is the `admin` claim,
which `firestore.rules` and `storage.rules` require for every write and for
every read of drafts, users and other unpublished data (see below). A signed-in non-admin gets "Not an administrator" and nothing else. The
site also asks search engines to stay away (`robots.txt`, `X-Robots-Tag`), and
cannot be framed by another site (`frame-ancestors 'none'`).

### The Content Security Policy is report-only, for now

`firebase.json` sends a full CSP as `Content-Security-Policy-Report-Only`: the
browser logs what it *would* block, and blocks nothing. It allows the CMS's own
files, the Firebase APIs, the photos and recordings in Storage, address lookup
(Nominatim) and the map preview (openstreetmap.org). A walk through every page
against a local build reported nothing. But the live backend's hosts
(`*.googleapis.com`, `*.cloudfunctions.net`) cannot be exercised against the
emulators.

After a deploy, open the live CMS with the browser console open, sign in and go
through each page, including a photo upload and Offline bundles → Build. If
the console shows no `[Report Only]` lines, move the policy into the enforced
`Content-Security-Policy` header, after the four directives already there, and
deploy again. If it shows some, add the host each one names first.

### Preview a build locally

```bash
cd cms && npx vite build --mode development
```

```bash
firebase emulators:start --only hosting --project demo-lakbayan
```

That serves `cms/dist` on http://127.0.0.1:5050 against the emulators, with
the deep-link rewrite applied. On Windows the Hosting emulator applies **no
headers at all**: its path matching turns `/assets/**` into `\assets\**`, which
never matches. Production is unaffected, but the headers cannot be checked this
way on Windows. A deploy always rebuilds, so the emulator build left in
`dist/` never ships.

## What is built

Everything except the AR editor:

- login with role gating
- the dashboard — counts, what needs attention, recent activity, quick actions
- destinations: the list, and the editor with location, photos and audio-guide stops
- tours, local guides, offline bundles, and users with admin roles
- settings: the town list, tags, the tourism office and emergency lines, a
  notice for Explore, and the privacy policy and terms

Every editor checks for another admin's save before writing its own (see
`src/lib/versioned.ts`). Hosting is configured but not yet deployed — see
*Deploy* below, and `PLAN.md`, Track B, for what is left.

## The security boundary is not here

The role gate in `App.tsx` is a convenience so non-staff see a sensible message.
It is **not** what protects content — `firestore.rules` is. Anyone can render
whatever they like in their own browser and still cannot write a document. Never
move a rule out of `firestore.rules` into this app.
