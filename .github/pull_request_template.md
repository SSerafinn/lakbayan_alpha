<!--
Base branch should be `staging`, not `main`. GitHub defaults to main — change it.
-->

## What

<!-- One or two sentences. The diff shows the detail. -->

## Why

<!--
The part that is hard to reconstruct in six months. If you rejected an obvious
alternative, or worked around something, say so here.
-->

## How I verified

<!-- Be specific: which screen, which device, what you actually saw. -->

- [ ] `flutter analyze`
- [ ] `dart run custom_lint`
- [ ] `flutter test`
- [ ] `cd test_rules && npm test` *(if `firestore.rules` changed)*
- [ ] Ran on a device or emulator

## Checklist

- [ ] Targets `staging`
- [ ] Conventional Commit messages
- [ ] Re-ran `build_runner` if a model or provider changed
- [ ] No hardcoded colours or spacing — used `lib/core/theme/` (`docs/DESIGN_SYSTEM.md`)
- [ ] Read paths still work from cache — offline-first is non-negotiable
- [ ] `docs/DATA_MODEL.md`, `firestore.rules` and `firestore.indexes.json` moved
      together if the schema changed (use `/add-collection`)
- [ ] Nothing secret committed — no `config/local.json`, no service accounts

## Screenshots

<!-- Required for UI changes. Before/after if you changed something existing. -->
