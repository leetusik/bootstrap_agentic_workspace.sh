# P12.S1 — Parallel-mode schema + phase-scoped selection

_Auto-mode plan (operator opted into `auto` for the rest of P12). Context: `phase.md` §Decomposition
(S1 row), §Findings & Notes, §Constraints, §Open Questions (the two decisions S1 owns)._

## Goal

Give `phase.json` an optional, backward-compatible parallel-execution block and make the engine's
selection layer stream-aware, so that (a) on main, phases opted out to a branch are skipped by the
pointer, (b) in a phase-branch checkout (worktree or plain clone), selection sees only that phase,
and (c) `pending` halts only its own stream. **No opt-in command yet** — that is S2. After S1 the
engine can *read* parallel phases; nothing can create one except a hand-stamped fixture.

Covers intent item 1 (phase-scoped selection; the operator's original point 3).

## Decisions S1 must settle (then record in `phase.md` for S2–S7)

1. **Schema — an optional `execution` block in `phase.json`:**

   ```json
   "execution": {
     "mode": "parallel",
     "branch": "phase/P13-some-slug",
     "worktree": "/abs/or/relative/path or null",
     "consolidation": "pending"
   }
   ```

   - Absence of the block (or `mode` != `"parallel"`) ⇒ the phase belongs to the default stream and
     behavior is exactly today's. Every existing phase.json stays valid untouched.
   - `branch` is required when mode is parallel; `worktree` is informational (null on a teammate's
     plain clone); `consolidation` is `"pending"` from opt-in until S3's post-merge step marks it
     `"done"` (`null`/absent on default phases).
   - Add a tiny reader helper (e.g. `phase_execution(data) -> dict | None`) so S2–S5 all read the
     block one way. Field names may be adjusted if implementation reveals a better shape — but then
     update the record in `phase.md`, since S2–S7 quote whatever S1 settles.

2. **Stream detection — current git branch vs. stamped branches.** A helper (e.g.
   `current_stream()`) runs `git rev-parse --abbrev-ref HEAD` (subprocess, cwd=ROOT) once and
   compares the result against every active phase's `execution.branch`:
   - match → this checkout IS that parallel phase's stream: selection sees only that phase;
   - no match (main, any other branch, detached HEAD, git missing/not a repo) → default stream:
     selection walks phases in `order` as today but **skips** parallel-mode phases.
   - This works identically in a worktree and in a teammate's plain clone (branch name is the key;
     no marker file). On any git failure, fall back silently to the default stream — a foreign
     workspace without git must keep validating (same tolerance style as the executor-tier check in
     `validate`, workflow.py:593-605).

## Implementation (all in `scripts/workflow.py` unless noted)

- **`resolve_current` (:449)** — accept the stream context: on the default stream, `continue` past
  phases whose `execution.mode` is parallel; on a parallel stream, consider only the matching
  phase. Simplest shape: filter `phases` once in `rebuild_index_and_state` / callers via a helper
  (`stream_phases(phases, stream)`), leaving `resolve_current`'s walk untouched — pick whichever
  keeps the diff smallest and the function readable.
- **`operator_wait_target` (:463)** — operates on `current_phase`/`current_slice` as today; with
  selection filtered upstream, a `pending` parallel phase no longer halts main (and vice versa).
  Verify, don't assume.
- **`rebuild_index_and_state` (:479)** — the pointer (`state.json`) reflects only the current
  stream's phases. Dashboards (`index.json`, `backlog.md`) still LIST every active phase folder
  (main should see that a parallel phase exists), but mark parallel-mode phases visibly — e.g. the
  backlog Active Phases table showing `parallel: <branch>` in place of (or beside) the current
  slice, and `index.json` entries carrying the execution block. **Hard constraint:** when no phase
  has an `execution` block, every generated file (`state.json`, `index.json`, `backlog.md`,
  `deferred.md`) must be byte-identical to today's output — add nothing, not even an empty field,
  in that case. On a parallel-phase stream, `state.json` may carry the stream identity (e.g.
  `"stream": "phase/P13-..."`) — again only when actually on one.
- **`cmd_next` (:796)** — no output change on the default stream with no parallel phases. On a
  parallel stream, the same pointer block scoped to that phase. (The proactive suggestion hint is
  S2's, not S1's — it must name the opt-in command.)
- **`validate` (:539)** — accept and check the new block: `mode` must be `"parallel"` if present,
  `branch` non-empty string, `consolidation` in `{"pending", "done"}` (or absent), duplicate
  `execution.branch` across phases is an error. Confirm a phase that is `done` + review `pass` +
  `consolidation: "pending"` (the merged-awaiting-consolidation state, per phase.md finding) passes
  `validate` cleanly; archive-side gating on that state is S3's job, not S1's.
- `new_phase` (:665) writes no execution block — creation stays main-side and default; opt-in
  stamping is S2's.

## Validation (lean, per Constraints)

1. **Backward-compat proof:** before touching code, capture `python3 scripts/workflow.py rebuild`
   outputs (`state.json`, `index.json`, `backlog.md`, `deferred.md`); after implementation, re-run
   and `diff` — must be byte-identical (timestamps aside: compare with the `updated_at`/
   `last_rebuilt_at`/`Rebuilt at` lines normalized).
2. **Scenario smoke (temp copy, not the live repo):** copy the workspace skeleton to the session
   scratchpad (or `git worktree`-free temp git repo), hand-stamp a second phase with
   `execution: {mode: parallel, branch: "phase/PX-test", consolidation: "pending"}`, then check:
   on `main` the pointer skips it (`next` selects the default phase; a `pending` on the parallel
   phase does not halt main); on a checkout of branch `phase/PX-test` the pointer selects only it
   (and a `pending` there does not halt it when read from main). Also `validate` passes on the
   stamped tree and fails on a malformed block (bad mode, duplicate branch).
3. `python3 scripts/workflow.py validate` on the real tree — passes.
4. **Installer rebuild:** `python3 installer/build.py` after the workflow.py edits, then
   `python3 installer/build.py --check` — passes (the rebuilt `bootstrap_agentic_workspace.sh` must
   be part of this slice's changes; the orchestrator commits it together with workflow.py).

## Boundaries

Executor: no commits, no slice/phase status transitions, no `doc-new-version`, no other slice's
`plan.md`. Write `result.md` in this slice's folder; append to `phase.md`: the settled schema +
detection decision (resolving the two S1-owned Open Questions), plus a one-line "Doc impact" note
(this changes durable truth about the engine — likely `architecture`/`operations`) for the REVIEW
slice to consolidate.
