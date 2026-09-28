---
description: Pick the next unchecked task in PLAN.md, implement it following project conventions, then check it off.
---

## Current plan
!`sed -n '1,120p' PLAN.md`

## Instructions
1. Identify the **first unchecked** `- [ ]` task in `PLAN.md` (respect phase order).
2. Restate the task and your approach in one or two sentences.
3. Implement it following `docs/CONVENTIONS.md`; use `/add-feature` or
   `/add-collection` where they apply; run `/gen` if models changed.
4. `dart analyze` and relevant `flutter test` must pass.
5. Tick the task (`- [x]`) in `PLAN.md`.
6. Stop and summarize; suggest `/commit`. Do not start the next task automatically.
