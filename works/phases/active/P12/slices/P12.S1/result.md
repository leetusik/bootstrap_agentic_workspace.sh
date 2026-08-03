# P12.S1 result — Parallel-mode schema + phase-scoped selection

**Status: done.** The engine can now *read* parallel phases: an optional `execution` block in
`phase.json`, stream detection from the current git branch, and stream-scoped selection. No opt-in
command exists yet (S2), so nothing can create a parallel phase except a hand-stamped fixture — which
is exactly what the smoke does.

## What landed

All code changes are in `scripts/workflow.py` (plus the mandatory installer rebuild).

**New helpers** (`scripts/workflow.py`, between `rebuild_deferred_dashboard` and `resolve_current`):

- `phase_execution(data)` — the single reader for the block; returns `None` unless it is a dict with
  `mode == "parallel"`. Every other call site goes through it.
- `git_current_branch()` — `git symbolic-ref --short -q HEAD`, falling back to
  `git rev-parse --abbrev-ref HEAD`. Detached HEAD / no git / not a repo → `None`, silently.
- `current_stream(phases)` — collects the stamped `execution.branch` values and, **only if there is
  at least one**, asks git. Untouched workspaces never shell out.
- `stream_phases(phases, stream)` — the scoping filter (default stream = non-parallel phases only;
  parallel stream = that one phase).

**Wired in:**

- `rebuild_index_and_state` — computes `stream` once, feeds `stream_phases(...)` to `resolve_current`
  and `operator_wait_target` (both functions themselves untouched — the smallest diff that gets the
  scoping *and* the per-stream `pending` halt), keeps the full phase list for the dashboards, adds
  `execution` to an `index.json` entry only when the phase has one, and adds `"stream"` to
  `state.json` only when on a parallel stream.
- `rebuild_backlog` — a `- Stream: ...` Pointer line (parallel checkouts only) and a
  `` · parallel: `<branch>` `` marker on the Active Phases row of an opted-in phase.
- `validate` — accepts and checks the block: `mode` must be `"parallel"`, `branch` a non-empty
  string, `worktree` a string or `null`, `consolidation` in `{"pending","done"}` or absent, and
  duplicate `execution.branch` across phases is an error. A non-object `execution` is an error too.
- `cmd_next` — `stream=<branch>` on a parallel stream; `parallel_phases_elsewhere=<P>:<branch>` when
  opted-in phases sit outside the current stream. Both silent otherwise.
- `new_phase` — untouched, as planned (stamping is S2's).

The settled schema + detection decision is recorded in `phase.md` → *Settled Decisions → S1*, which
resolves both S1-owned Open Questions and is what S2–S7 must quote.

## Validation

| # | Command / check | Result |
|---|---|---|
| 1 | Backward-compat: `python3 scripts/workflow.py rebuild` before vs. after, diffing `works/{state.json,index.json,backlog.md,deferred.md}` with `updated_at`/`last_rebuilt_at`/`Rebuilt at` normalized | **pass** — all four byte-identical |
| 2 | Scenario smoke, temp workspace copy (`scratchpad/smoke.py`, 27 checks) | **pass** — `SMOKE PASSED` |
| 3 | `python3 scripts/workflow.py validate` (real tree) | **pass** — `Workflow validation passed.` |
| 3b | `python3 scripts/workflow.py next` (real tree) | **pass** — output unchanged (`current_phase=P12`, `current_slice=P12.S1`, `next_slice=P12.S2`; no stream lines) |
| 4 | `python3 installer/build.py` then `python3 installer/build.py --check` | **pass** — `wrote bootstrap_agentic_workspace.sh (300287 bytes)`, then `OK: ... in sync` |

The smoke builds a throwaway workspace in the session scratchpad (`workflow.py` + `works/templates`
+ `docs` copied, `git init -b main`, no commits — branch switching is done with
`git symbolic-ref HEAD refs/heads/<name>`), stamps `P2` parallel, and asserts:

- **baseline** (no block anywhere): pointer, `state.json` keys and `next` output all unchanged;
- **on main**: pointer still selects `P1`; `next` names the elsewhere stream; `backlog.md` still
  lists `P2` with its branch; `index.json` carries the execution block; no `stream` key;
- **cross-stream `pending`**: `P2.S1` pending does **not** halt main (no `WAITING ON OPERATOR`), and
  later `P1.S1` pending does **not** halt the parallel stream;
- **on `phase/PX-test`**: pointer scoped to `P2` only, `stream` in `state.json` and in `next`'s
  output, `P2.S1` pending halts *this* stream, no `P1` slice ever visible;
- **unknown branch** (`feature/unrelated`) → default stream, `P2` skipped;
- **`validate`**: passes on the stamped tree; passes on `done` + review `pass` +
  `consolidation: "pending"`; fails on bad `mode`, missing `branch`, bad `consolidation`, and
  duplicate `branch`;
- **no git at all** (`.git` removed): default stream resolves and `validate` still passes.

## Deviations from `plan.md`

1. **`git symbolic-ref` before `git rev-parse`.** The plan named `git rev-parse --abbrev-ref HEAD`
   (as an "e.g."). Measured: on a branch with no commit yet, rev-parse prints `HEAD` and exits 128,
   which would misreport the stream. `symbolic-ref --short -q HEAD` is correct there and returns
   nothing on detached HEAD; rev-parse is kept as a fallback. Same answer in every normal case.
2. **`cmd_next` prints one extra informational line on the default stream when a parallel phase
   exists** (`parallel_phases_elsewhere=...`). The plan required "no output change on the default
   stream **with no parallel phases**" — that holds exactly. The line names no command, so the
   proactive opt-in hint remains entirely S2's.
3. **`validate` also rejects a non-object `execution` and a bad `worktree` type** — one step beyond
   the listed checks, same spirit (fail loudly on a malformed block).
4. The smoke uses `git symbolic-ref` to switch branches instead of `git checkout -b`, because the
   executor may not create commits and `checkout -b` needs a commit to switch away from later. It
   also lives in the scratchpad only — nothing was added under `tests/`.

Nothing else departed from the plan. No commits, no status transitions, no `doc-new-version`, no
other slice's `plan.md` touched.

## Doc impact (recorded in `phase.md`, for the REVIEW slice)

- **`architecture`** — `phase.json` gains an optional `execution: {mode, branch, worktree,
  consolidation}` block, and selection becomes stream-scoped: the `works/state.json` pointer and the
  `pending` halt cover only the current git branch's stream (the default stream skips opted-in
  phases), while dashboards keep listing every active phase.

## Notes for S2+

- Stamp `execution.branch` on **both** sides (main and the branch) — main needs it to skip the phase,
  the branch needs it to claim the stream.
- `worktree` is informational; do not make any logic depend on it.
- `validate` will fail the moment a stamp is half-written (missing/empty `branch`), which is a useful
  guard for the opt-in command to lean on.
