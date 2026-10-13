status: done
tier: mid
model: sonnet
effort: high
summary: Added `phase_in_flight` and the `## Streams` table in `backlog.md` (default row, own stream, every in-flight phase read live from its branch, `Host branch` column in nested). The filter closes D57 on `next`; `consolidation_owed` skips a stamped phase that is not yet `done`; root `parallel-start` stamps `execution.base_branch`.
files_changed: scripts/workflow.py, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P35/phase.md, works/phases/active/P35/slices/P35.S7/result.md
validation:
- `python3 installer/build.py --check`: pass
- `python3 scripts/workflow.py validate`: pass
- `bash tests/retrofit_smoke.sh` (alone): 292 PASS / 0 FAIL, same as after S6 (no assertion changed)
- scratch at-root and nested installs: see below
deviations: none. Optional item 5 was done (additive; smoke unchanged).
doc_impact: operations.md note appended to phase.md (Streams view, D57 filter, debt-line filter, root base_branch)

## What changed (`scripts/workflow.py`)

- `phase_in_flight(data)`: a parallel `execution` block AND (`execution.worktree` is not null OR status is not `done`). Works on phase records and `index.json` entries.
- `streams_section(phases, state)`, called by `rebuild_backlog` between `## Pointer` and `## Active Phases`. Rows: own parallel stream first (working tree), `default` (pointer; on a parallel stream read from `_phases_at_ref(execution.base_branch)`, else `local copy`), then each other in-flight phase from `branch`, `origin/branch`, else `local copy`. Git is used only when an own/other in-flight phase exists and `_git_available()`. Cells through `clean_cell`; the `Host branch` column only when `NESTED`. Worktree paths print relative to the host root / ROOT when under it (so the tracked backlog carries no home path); `.` / `workflow` for a worktree's own row.
- `_parallel_verdict_pair` returns `(short, long)`; `_parallel_verdict` (used by `parallel-status`) returns `[1]`, same text as before. Short forms: `in flight n/m`, `pending`, `blocked`, `ready to merge`, `merged — awaiting consolidation`, `merged + consolidated`, `torn down`, `review not passed`, `unknown`.
- `cmd_next`: `parallel_phases_elsewhere` uses `phase_in_flight` (D57).
- `consolidation_debt_line`: drops a phase that has an execution block and whose status is not `done`. Local to the function (the plan's condition held); `phases_owing_consolidation`, the archiving guard and `parallel-consolidated` are unchanged. Deliberate reading of the plan: a `done` + review-pass phase with its worktree still set owes (the "after its review passes it does, as before" rule), so the debt rule is narrower than `phase_in_flight` (which keeps a done-but-not-torn-down phase "in flight" for the Streams view and `next`).
- Root `parallel-start`: `execution.base_branch = git_current_branch()` (additive; nested already stamped it).

## Verification

1. This repo (at root), `rebuild`: `## Streams` has the single `default` row (`P35`, `P35.S7`, 8/14, `working tree`); `next` no longer prints `parallel_phases_elsewhere` (P33 is stamped, done, `worktree: None`). A logging `git` stub on `PATH` showed exactly one git call during `rebuild`: `symbolic-ref --short -q HEAD`, `current_stream`'s existing call (P33 is stamped). No Streams git call.
2. Scratch at-root install (`scratchpad/p35s7.JQgi/root`, built artifact, then the working engine copied in): P2 and P3 started in parallel. Main backlog: `default` row first, then P2 and P3 read from their branches. Advanced `P2.DECOMP` to done on P2's branch, ran `rebuild` in main: P2's row went `0/4` to `in flight 1/4`, current slice `P2.S1`. Simulated P3 as merged/torn down (worktree removed, branch deleted, `status: done`, `worktree: null`): P3 vanished from Streams and from `parallel_phases_elsewhere`; `consolidation_owed=P3` (done, owes) as before. In P2's worktree: own row first (`phase/P2-side_two`, `working tree`), then `default` from `branch main` (`execution.base_branch: "main"` stamped at root).
3. Scratch nested install (`scratchpad/p35s7.JQgi/host`, built artifact): the same flow with `--host-branch feat/side` / `feat/old`. The `Host branch` column shows `feat/side`; worktree cell `.claude/worktrees/P2-side_two/workflow`; in the worktree the default row reads `branch master` (the nested repo's branch). A freshly started phase shows `local copy` in the stamp commit's own backlog, because the branch is created after that rebuild; the next `rebuild` reads the branch.
4. In-flight phases are not named by `consolidation_owed` (P2 absent while P3 owes). In P2's worktree, setting P2 `done` + review `pass` (uncommitted, reverted) made `consolidation_owed=P2` appear.
5. Smoke 292 PASS before and after (the log is in the session scratchpad, `p35s7-smoke.log`).
6. `build.py --check` and `validate` pass.

Scratch left in place (`rm -rf` denied): `scratchpad/p35s7.JQgi` (the path is recorded in `scratchpad/S7_SCRATCH`; hand-edited P3 phase.json there fails its own `validate`, by design of the simulation).

## Notes

- A line ref update went into the phase.md Note (`streams_section` ≈1750, `rebuild_backlog` ≈1843).
- `phase.md`: Decision 24, Doc impact line, the S7 Note consumed, `## Now` rewritten.
- The `docs/index.json` timestamp that `validate` bumped was reverted.
- D57: the orchestrator closes it.
