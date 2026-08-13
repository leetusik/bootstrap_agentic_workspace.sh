---
name: do-next-slice
description: Continue the active phase by completing exactly one slice in automatic mode, then stop.
---

# do-next-slice

This Codex skill has one execution mode: automatic completion of exactly one slice. A bare invocation, `auto`, or wording such as “automatic” or “run unattended” all select that same mode.

Before running any workflow command or changing the repository, inspect the invocation. If it requests `gate` or `plan only`, report that Codex `do-next-slice` supports automatic execution only, make no workflow, state, or repository mutation, and STOP. Reject any other requested execution mode instead of guessing.

## Select and prepare one slice

Run `python3 scripts/workflow.py next`, then read `AGENTS.md` (or `CLAUDE.md`), the relevant `docs/current/*.md`, `docs/index.json`, `works/state.json`, `works/backlog.md`, the selected slice folder, and the phase's `phase.md` and `intent.md`. The intent file is the confirmed source of truth whenever the operator's request is unclear.

`next` is stream-scoped: on the default stream it skips phases opted into parallel mode and may report `parallel_phases_elsewhere=<P>:<branch>`; in a phase worktree it sees only that phase and reports `stream=`. Use `python3 scripts/workflow.py parallel-status` only when a cross-stream view is needed. Relay any `parallel-start` hint as an optional suggestion, and keep working on the selected slice unless the operator explicitly opts another phase into parallel mode.

If `next` reports `WAITING ON OPERATOR`, or the phase or selected slice is `pending`, report the required operator action and STOP. Never start, finish, or move past a pending item.

Read the selected slice's `slice.json` and current phase context, then prepare it:

- For a `todo` slice, run `python3 scripts/workflow.py start-slice <slice_id>`, research the relevant code and docs inline, write a complete free-form native plan to that slice's own `plan.md`, and continue immediately. Incorporate any operator note, but do not duplicate the verbatim phase intent. Never pre-fill another slice's plan.
- For a `ready` slice, preserve upgrade and cross-tool compatibility: read its existing approved `plan.md` and `phase.md`, run `python3 scripts/workflow.py start-slice <slice_id>`, and dispatch directly from that plan. Replace it only when concrete, visible workspace drift makes it unsafe or stale; record that drift and write the complete updated plan before dispatch.
- For an already `in_progress` or re-opened `changes_requested` slice, resume from its existing `plan.md` and current phase notes. If the plan is missing or visibly stale, write a complete current plan before dispatch. Do not redo work already recorded as complete.

A `co-work` slice is outside this automatic non-visual workflow: do not dispatch it or invent visual decisions. STOP and route it to the applicable `design-cowork` workflow.

## Dispatch the project executor

Select exactly one project-scoped custom executor from `slice.json` and the plan:

- `kind: decomposition` or `kind: review` always uses `slice-executor-high`.
- An implementation or `fix` slice with `risk` exactly `low` uses `slice-executor-mid` only when the plan is truly a one-line or few-line code edit or docs task.
- Every other slice uses `slice-executor-high`; all real code writing and every cross-file change belongs there. Planning may bump work up to high, never down.

The preset matrix comes from `executors.toml` and `sync-agents`: the no-mode `economy` fallback is Claude `sonnet@high` / `opus@high` and Codex `gpt-5.6-luna@high` / `gpt-5.6-terra@high`; `flex` is Claude `sonnet@xhigh` / `opus@xhigh` and Codex `gpt-5.6-terra@high` / `gpt-5.6-sol@high`. Per-tier overrides may replace any of these values.

Spawn the matching project custom agent from `.codex/agents/slice-executor-mid.toml` or `.codex/agents/slice-executor-high.toml`. Give it the slice ID and folder path and require it to execute that slice's `plan.md`, validate the work, write `result.md`, append durable notes and doc-impact lines to `phase.md`, and return its structured verdict. Wait for that executor; never implement the slice inline and never dispatch a second executor.

The decomposition executor may create only the planned bare middle-slice folders with `new-slice`; it never fills their plans. A design-bearing decomposition stops at the separate `design-cowork` boundary and follows that workflow's two-pass rules without inventing a Codex visual-design substitute here.

## Handle the verdict

Trust a `done` verdict. Read the verdict and `result.md`, then run only `python3 scripts/workflow.py validate` for state integrity; do not re-run the slice's behavioral checks. The phase review validates all slices together.

- `done` on a non-review slice: run `python3 scripts/workflow.py finish-slice <slice_id>`, run `python3 scripts/workflow.py validate`, and commit the clean slice boundary with the repository's conventional commit rules and attribution for the model that actually did the work. The executor never commits.
- `needs_operator`: set the slice to `pending`, report `operator_need`, and STOP without finishing or committing incomplete work.
- `blocked`: preserve the executor's blocker record, report it, and STOP without finishing.
- `escalate` from `slice-executor-mid`, or a failed/empty mid return: append one `## Escalation: mid → high` section to the same `plan.md` with the concrete findings, then immediately re-dispatch that slice once to `slice-executor-high`. There is at most one escalation per slice.
- Failed or empty `slice-executor-high` return: treat the slice as unfinished, do not finish or commit it, report the failure, and STOP.

Never commit or move workflow state while an executor is still running.

## Review handling

When the selected slice is the phase review, plan it from all completed slice plans and results, the objective, `intent.md`, current docs, and `docs/index.json`. Dispatch `slice-executor-high`. The review must run every completed slice's validation commands plus `python3 scripts/workflow.py validate`, judge the whole phase, and complete all findings before deciding `pass`, `changes_requested`, or `blocked`.

The review edits no source. On `pass` outside parallel mode, it consolidates every durable-truth area in the phase's “Doc impact” list into one new version per affected doc and rebuilds current docs. On a parallel branch it creates no doc versions and instead verifies that the list is complete; consolidation is deferred to the default stream. On `changes_requested` or `blocked`, it performs no pass-only doc work. It never writes an explainer and always reports `explain: not written — run /explain for this phase`.

Record the returned verdict with `python3 scripts/workflow.py review-phase <P> --verdict pass|changes_requested|blocked --reviewer slice-executor-high --note "..."`, then run `python3 scripts/workflow.py validate`.

- `pass`: `review-phase` closes the review slice and marks the phase done; do not call `finish-slice` for review. Commit the review boundary and leave the phase active. If the phase is in parallel mode, follow the `parallel-phase` integration lifecycle, including its quiet-point gate and deferred default-stream doc consolidation, and stop on any closed gate or failed check.
- `changes_requested`: create only the executor's proposed numbered `fix` slices, run `python3 scripts/workflow.py validate`, and commit the review boundary together with those bare fix-slice folders. Do not execute them in this invocation; this skill still stops after the one review slice.
- `blocked`: record and report the blocker, then STOP.

Stop after this one slice. Do not select or execute another slice in the same invocation.
