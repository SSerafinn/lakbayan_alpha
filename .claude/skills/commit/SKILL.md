---
name: commit
description: Create a Conventional Commit for the currently staged changes.
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *)
---

# Commit

## Staged changes
!`git diff --staged --stat`

## Instructions
Write a single **Conventional Commit** for the staged changes:
- format: `type(scope): summary` (≤ 72 chars), types: feat, fix, chore, refactor, docs, test, ci.
- add a short body only if the change isn't obvious.
- if nothing is staged, run `git status` and tell the user what to stage.
Do not push.
