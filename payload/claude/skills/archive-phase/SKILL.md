---
name: archive-phase
description: "Archive review-passed phases: phase archive --all (full sweep), phase rotate (partial), or phase archive <P> (single)."
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# archive-phase

Archiving is manual: a pass leaves a phase `done` in `active/`, and invoking this skill is the operator's decision to move it. Whole phases only.

- **Everything done:** `python3 scripts/workflow.py phase archive --all` (refuses unless every active phase is `done` with a passing review).
- **The done ones:** `python3 scripts/workflow.py phase rotate` (the `/rotate-backlog` skill; `--archive-only` for the plain sweep).
- **One phase:** `python3 scripts/workflow.py phase archive <P>`.

All three need `done` with a passing review. **A phase with an open PR:** `phase rotate` leaves it active until `pr sync <P>` reads it `state=merged` (`next`'s `pr_open=` says what is due); `phase archive` archives it with an `advice:` line, and `next` stops listing its PR. `--force` (on `phase archive --all` / `phase archive`) is for exceptional cleanup of an unfinished phase only, on the operator's word.
