# Repository settings

Settings that live on GitHub rather than in this repo, written down so they can
be re-applied after a transfer, a fork, or someone turning one off.

These are **not** cosmetic. Two commits have already been lost to merge
mechanics on this project:

- **PR #4** merged, then its follow-up fix landed on the same branch afterwards
  and never reached `staging`. The bug it fixed stayed live.
- **PR #7** merged into a stale base branch (`feat/cms-editor-ux`) *after* that
  branch had already been merged into `staging`, so the location search never
  arrived. It took a third PR (#8) to recover.

Both are prevented by the settings below.

## Pull requests

**Settings → General → Pull Requests**

- ✅ Allow squash merging — set as the **default**
- ❌ Allow merge commits — *except* they are wanted for `staging` → `main`, so
  leave enabled and choose it manually on release PRs
- ❌ Allow rebase merging
- ✅ **Automatically delete head branches**

That last one is what would have prevented PR #7's loss. GitHub only retargets a
stacked PR's base when the base branch is **deleted** after merging. Because
`feat/cms-editor-ux` lingered, PR #7 kept pointing at it and merged into a
branch nobody was watching.

## Branch protection

**Settings → Branches → Add branch ruleset**, applied to both `main` and
`staging`:

- ✅ Require a pull request before merging
  - Required approvals: **1**
  - ✅ Require review from Code Owners *(`.github/CODEOWNERS` routes everything
    to @SSerafinn, and names the files where a mistake is silent and costly)*
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - Required checks: **`app`**, **`cms`**, **`rules`**
    *(the three jobs in `.github/workflows/ci.yml` — the names must match
    exactly, so rename them there and here together)*
- ✅ Block force pushes
- ✅ Do not allow bypassing the above settings

**Do not skip the last one.** Without it an admin can still push straight to
`main`, which is precisely what happens at 2am before a demo.

### Via the CLI instead

```bash
gh api -X PUT repos/SSerafinn/lakbayan_alpha/branches/main/protection --input .github/branch-protection.json
```

```bash
gh api -X PUT repos/SSerafinn/lakbayan_alpha/branches/staging/protection --input .github/branch-protection.json
```

The payload is committed at `.github/branch-protection.json` so both branches
get identical rules and the intent is reviewable.

## Default branch

`staging` is the default, so new PRs target it automatically rather than
`main`. Only release PRs should target `main`.

## Dependabot

Configured in `.github/dependabot.yml` — monthly, across `pub`, both npm
projects and GitHub Actions.

Expect it to propose raising `riverpod_annotation`, `riverpod_lint` and
`json_annotation`. Those are **deliberately capped** (Dart SDK and analyzer
conflicts — see the comments in `pubspec.yaml`). Close those PRs rather than
forcing them, until the SDK moves.
