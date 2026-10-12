# Plan — P33.S1: Engine — rotate-backlog decides the chain, archives last

`implementation / high` (trigger: core invariant — this slice changes when phase folders leave `active/`, writes a phase's `order` on resume, and sets the docs phase's place in stream selection). Executor: `slice-executor-high`.

## Context

P33 makes one `/rotate-backlog` invocation do the whole clean-up: check the doc debt first, create and run the docs phase, then archive every done phase. This slice is the engine half. `P33.DECOMP` pinned the shape in `works/phases/active/P33/phase.md` `## Decisions` — read that section whole, plus the four notes tagged `for P33.S1` under `## Notes for later slices`, and `intent.md` for the operator's words. The skills and the contract come in `P33.S2`, written against the exact lines this slice prints, so **record those lines verbatim in `## Decisions`** when you finish (replace the engine Decision line; never stack versions).

This checkout is P33's parallel worktree. `current_stream` here is P33's branch, so **never run `rotate-backlog` or any other writing engine command in this tree to probe** — even a no-op run rewrites the generated `works/` files. Probe in a `cp -R` copy of `scripts/`, `works/` and `docs/` in the session scratchpad (outside git, which makes it the default stream), and delete it when done.

## What to build (all in `scripts/workflow.py`)

1. **`rotate_backlog` default path** (today ~l.3601; `--archive-only` keeps today's behaviour exactly — same output, no `rotate=` line, no docs line). The default run's **first stdout line is `rotate=<branch>`**, chosen in this precedence, each branch then printing its own report:
   1. `rotate=refused` — this checkout is on a parallel stream (`current_stream(all_active_phases())` is not None). Writes nothing; the line says consolidation and archiving are default-stream only, and exits non-zero (print the `rotate=` line before raising `SystemExit`).
   2. `rotate=archive` — nothing owes: no debt-only phase (`_debt_only`) **and** no live docs phase. Run today's sweep (archive every phase with empty `_phase_blockers`, whole phases, no `--force`, same manifest), rebuild, print today's rotated/left-active report, end with `docs_phase=none`. With no active phases at all, still `rotate=archive` first, then today's "no active phases to rotate" line.
   3. `rotate=stop_midflight midflight=<id:status, …>` — archives nothing. **Mid-flight** = on the default stream (`stream_phases(phases, None)`), any slice whose status is not `todo`, `ready` or `done`, or any phase whose status is `pending`, `blocked` or `in_review`; every live docs phase and its slices are excluded; parallel streams are never counted. List every offender as `<slice or phase id>:<status>`, comma-separated, in order.
   4. `rotate=resume docs_phase=<P>` — archives nothing. A **live docs phase** is a non-`done` default-stream phase with a non-empty `consolidates` (`phase_consolidates`), keyed directly (not through debt-only → `consolidation_cover`), so a docs phase that has paid everything but not passed its review still resumes. With several, name the first by order. Keep today's `docs_phase_covered=<P> (pays …)` lines after it. **Re-assert the queue jump**: when the docs phase does not already sort first among the non-`done` default-stream phases, write `order = min(order of every other non-done default-stream phase) - 1` into its `phase.json` (one write, `_clean_order`-normalised), `append_event` it (e.g. `phase_reordered`), rebuild, and print a line saying what was written (`docs_phase_order=<P> <old> -> <new>`), so the skill knows to commit it. `resume` beats `create`: uncovered debt waits until the live docs phase is done.
   5. `rotate=create` — archives nothing; print today's proposal block (`docs_phase_proposal=`, `phase=`, `name=`, `objective=`, `create:`, `scope:`) with the `create:` line carrying `--order <jump>` where jump = `min(order of every non-done default-stream phase) - 1` (omit `--order` when there is no such phase). **Put `--order` before `--consolidates`** so the smoke regex ending in `--consolidates P2$` stays valid. Reword the last line: the invocation is the yes now (e.g. `proposal only: nothing was created -- /rotate-backlog runs the create: line as is`).
   Keep `_debt_only`, `_phase_blocker_kinds`, `_archive_one`, `archive_all`, `archive_phase` and the manifest untouched. Factor small helpers (`_live_docs_phases`, `_midflight`, `_queue_jump_order` or similar) rather than inlining the logic twice. Update the `rotate-backlog` argparse help to the new default and the module comment above `rotate_backlog`. `review_phase`'s pass message mentioning `archive-all` may take the new wording; optional, minimal.

2. **Smoke test** `tests/retrofit_smoke.sh` l.888–913 (the v51 block on the copy `$ROT`), updated to the new default and extended. Assert, each as its own `ok`/`bad` line: no archive while debt stands (P2 still in `active/`, `rotate=create` first line, the `create:` line carries `--order` ahead of the planned phase's order); the `create:` line works and the docs phase sorts first (`next` points at it); `rotate=resume docs_phase=<P>` on the re-run with `docs_phase_covered=`; `stop_midflight` when a slice of another phase is `in_progress` (and **not** when the docs phase's own slice is `in_progress`); the order re-assert on `resume` for a docs phase created with a higher order; `rotate=archive` once `docs-consolidated` has run and the docs phase is `done` (the done phases leave `active/`); `rotate=refused` is not required in the smoke (hard to stage) — cover it in the scratch walkthrough instead. Keep the `--consolidates` refusal and the `--archive-only` assertions (no `rotate=`/`docs_phase` line). Keep the fixture `$F`'s later assertions untouched (l.915+). Update the header comment's v51 clause.

3. **Installer**: after the edits, `python3 installer/build.py`; `python3 installer/build.py --check` must pass. The rebuilt `bootstrap_agentic_workspace.sh` is part of this slice's `files_changed`.

## Not in this slice

No skill, contract, README or CHANGELOG edits, no `WORKSPACE_VERSION` bump (all `P33.S2`). No `doc-new-version`. No commit, no state transition.

## phase.md

- Replace the engine Decision with the exact printed lines per branch (first line, the follow-up lines, exit codes) — S2 writes the skill against them.
- Consume the `for P33.S1` notes; keep the shared `for P33.S1, P33.S2` notes for S2.
- Append `## Doc impact` notes for the durable truths this slice changes: `operations.md` (*Durable-doc consolidation — a docs phase*: the *Starting one*, *`/rotate-backlog` is the default entry point (v51)*, *Running one* paragraphs; the v51 release note; the pre-v51 migration line), `architecture.md` (~l.31, ~l.400), `decisions.md` (a decision superseding v0043's "rotate proposes, never creates"). One line each, `- <doc>.md: <what changed> (P33.S1)`.
- Rewrite `## Now` for S2.

## Validation

- `bash tests/retrofit_smoke.sh` — run it as the **only command in its Bash call**, foreground, and report the pass/fail counts (the pre-slice baseline is in the qa doc; every new assertion must pass and no old one may regress).
- `python3 installer/build.py --check` → pass.
- `python3 scripts/workflow.py validate` → pass (the two pre-existing warnings, `consolidation_owed=P33` and `oversized_doc_sections`, are expected).
- A scratch-copy walkthrough (outside git) exercising every branch in order — `refused` (run from a copy whose `works/` carries a phase stamped with the current git branch is not possible outside git; instead run the real `rotate-backlog` **read of `current_stream`** path by temporarily pointing a copy's phase `execution.branch` at a branch name and running from a git checkout on that branch only if trivially doable; otherwise state that `refused` was verified by code inspection and a unit-style Python call), `archive`, `stop_midflight`, `resume` (with the re-order), `create` with `--order`, and `--archive-only` — with the commands and their output in `result.md`.

## Verdict

`result.md` with the verdict block first: status, tier, summary, files_changed, validation (the smoke counts), deviations, doc_impact.
