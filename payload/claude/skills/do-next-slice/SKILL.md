---
name: do-next-slice
description: Continue the active phase by completing exactly one slice, then stop.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent, EnterPlanMode, ExitPlanMode
disable-model-invocation: true
---

# do-next-slice

One slice of the `do-whole-phase` loop, then stop. Read `.claude/skills/do-whole-phase/SKILL.md` and follow it for exactly one slice: its reads, its modes (`auto`, `gate`, `plan only`), its stops (`WAITING ON OPERATOR` stops you before anything starts), its special slices and its references, read by path from `.claude/skills/do-whole-phase/reference/` (`dispatch.md`, `verdicts.md`, `decomposition.md`, `review.md`, `co-work.md`, `worktree.md`, `wave.md`, `explain-*.md`).

What differs from the whole-phase loop:

- **One slice.** `next` names it; `slice start` it when it is `todo` or `ready` (not in `plan only`, which readies one plan and stops). Plan, dispatch, read the verdict, `slice finish <slice_id> --outcome "<summary>"`, `check`, commit; then report and stop. Do not advance to the next slice in the same turn.
- **No preparing ahead** and **no wave.** In a declared phase (`next` prints `ready_slices=`), first run the wave's *Resume* (`.claude/skills/do-whole-phase/reference/wave.md`): finish and commit any slice whose commit still waits. If another slice is `in_progress`, or a stop is on disk, STOP and say so: a phase with slices in flight is finished by `/do-whole-phase`.
- **The review slice** is one slice like any other: its verdict, gate and fix slices follow `.claude/skills/do-whole-phase/reference/review.md`, one step per invocation.
