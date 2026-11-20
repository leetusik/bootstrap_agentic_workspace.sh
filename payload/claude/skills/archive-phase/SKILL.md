---
name: archive-phase
description: "Archive review-passed phases: archive-all (full sweep), rotate-backlog (partial), or archive-phase (single)."
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# archive-phase

Archiving is manual: a pass leaves a phase `done` in `active/`, and invoking this skill is the operator's decision to move it. Whole phases only.

- **Everything done:** `python3 scripts/workflow.py archive-all` (refuses unless every active phase is `done` with a passing review).
- **The done ones:** `python3 scripts/workflow.py rotate-backlog` (the `/rotate-backlog` skill; `--archive-only` for the plain sweep).
- **One phase:** `python3 scripts/workflow.py archive-phase <P>`.

All three need `done` with a passing review. **A phase with an open PR is held too:** until `pr-sync <P>` reads it `state=merged` (`next`'s `pr_open=` says what is due); a PR closed unmerged keeps the hold: reopen it on GitHub and sync, or archive with `--force`. `--force` (on `archive-all` / `archive-phase`) is for exceptional cleanup only, on the operator's word.
