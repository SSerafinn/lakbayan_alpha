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

No raw hex in stylesheets. Use the custom properties, and prefer semantic names
(`--lk-primary`) over raw ramps (`--lk-green-500`).

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

## What is built

CMS-0 only: login with role gating, the app shell, and a dashboard with
destination counts. Every other route is a placeholder naming the phase it
belongs to.

**CMS-1 is the priority** — destinations list, editor and publish workflow. The
mobile app's Phase 2 cannot meet its Definition of Done until it exists, because
all content writes are admin-only. See `PLAN.md`, Track B.

## The security boundary is not here

The role gate in `App.tsx` is a convenience so non-staff see a sensible message.
It is **not** what protects content — `firestore.rules` is. Anyone can render
whatever they like in their own browser and still cannot write a document. Never
move a rule out of `firestore.rules` into this app.
