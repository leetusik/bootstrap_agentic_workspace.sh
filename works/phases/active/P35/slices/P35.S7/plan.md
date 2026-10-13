# P35.S7 — plan: the Streams view in backlog.md, and the in-flight filter for next (D57)

## Context

The operator asked to "see the backlog that shows all the worktree run + main run at the main backlog" (`../../intent.md`). Today `rebuild_backlog` (`scripts/workflow.py` ≈1726) shows a worktree phase's **stale stamp-time copy** plus `· parallel: <branch>`. Its live state is read only by `parallel-status` (`_phase_json_at_ref` / `_slices_at_ref` / `_parallel_verdict` ≈3395). And `next`'s `parallel_phases_elsewhere` (≈3970) lists every phase with an execution branch, including one that is done, merged and torn down: D57, with P33 in this repo. S2 (g) pinned the design (`../P35.S2/result.md` (g); the `(from P35.DECOMP2, for P35.S7)` Note). This slice changes output **at root and nested alike, on purpose**. S4 stamps `execution.base_branch` in nested and S5 nulls `worktree` / `host_worktree` at teardown.

## Changes (`scripts/workflow.py`; then `python3 installer/build.py`)

The line refs below are from before S4-S6 and have drifted, so locate by name.

1. **One shared in-flight predicate**, e.g. `phase_in_flight(p)`: the phase has an execution block (`phase_execution(p)`) **and** either `execution.worktree` is not null or the phase status is not `done`. A torn-down `done` phase is not in flight. Use it in 2, 3 and 4.
2. **`## Streams` in `backlog.md`,** right after `## Pointer` and before `## Active Phases`:
   - Columns: `Stream | Phase | Status | Current slice | Done | Host branch | Worktree | Source`. The `Host branch` column appears **only when nested**.
   - **The default row first** (`default`): the default stream's pointer phase and slice, `n/m` done for that phase, source `working tree`.
   - **On a parallel stream:** the stream's **own** row first, from its working tree. The default row then comes from the in-flight phase's `execution.base_branch`, i.e. its pointer as `_phases_at_ref(base_branch)` would compute it. When `base_branch` is absent (a phase stamped at root before this slice), it reads the local copy, labelled `local copy`.
   - **Then one row per other in-flight phase,** read from `branch`, then `origin/branch`, else the local copy labelled so.
   - **The status cell** is a short form of `_parallel_verdict` (e.g. `in flight 3/7`, `pending`, `ready to merge`, `merged — awaiting consolidation`).
   - **Git is read only when at least one in-flight phase is stamped** (the same gate as `current_stream`). With nothing stamped and in flight, no git call happens and the section is a single default row.
   - Cells go through `clean_cell`.
3. **`next`'s `parallel_phases_elsewhere`** lists in-flight phases only, with the same predicate (closes D57). `consolidation_owed` is unchanged for done phases.
4. **`consolidation_owed` for a phase still in flight** (S4's note): `parallel-start` stamps `execution.consolidation: "pending"` at start, so `consolidation_debt_line` (≈1464) names the phase as owing from its first minute. This is true at root too. Exclude in-flight phases from the debt line: they owe nothing until their review passes. Confirm by reading `phase_consolidation` / `consolidation_command` first. If the change is not local to `consolidation_debt_line`, leave it and say so in `result.md`.
5. **Optional, additive at root:** stamp `execution.base_branch` in at-root `parallel-start` too (the branch the stamp commit lands on), so the parallel-stream default row has a source at root. Only when it stays additive (`validate` already type-checks it at root, S4 Decision 22).

## Doc impact (append to phase.md)

- `operations.md`: `works/backlog.md` has a `## Streams` section (the default stream plus each in-flight worktree phase, read live from its branch; a host branch column in nested); `next`'s `parallel_phases_elsewhere` and `consolidation_owed` skip a stamped phase still in flight (P35.S7)

## Verification

1. **This repo (at root):** after `python3 scripts/workflow.py rebuild`, `works/backlog.md` has `## Streams` with only the default row: P33 is stamped but done and torn down, so it is not in flight. `next` no longer prints `parallel_phases_elsewhere=P33:…` (D57). Show no git call happens: run under a stub `git` on `PATH`, or trace with `strace`-free logging, e.g. temporarily wrapping `_git` in the scratch copy, never this checkout. The simplest form is a scratch copy of this repo with no stamped in-flight phase.
2. **A scratch at-root install** with one phase started in parallel (in flight) and one torn down: the default row comes first, then the in-flight phase's row read from its branch (advance a slice on the branch and show the main checkout's backlog picks it up after `rebuild`). The torn-down phase is absent. In the worktree, its own row comes first.
3. **A scratch nested install** (S2's recipe + S4's start): the same, plus the `Host branch` column showing `feat/side`.
4. While a phase is in flight, `consolidation_owed` does not name it. After its review passes it does, as before.
5. **`bash tests/retrofit_smoke.sh` as the only command in its Bash call:** the same PASS count as after S6, or explain each changed assertion. Record both counts.
6. `python3 installer/build.py --check` and `python3 scripts/workflow.py validate`.

Scratch goes in the session scratchpad (`rm -rf` is denied, so leave it). No `claude -p`.

## Must not

Touch the hooks (S6), the skills, the installer text or the READMEs (S8), or the teardown and start logic beyond reading their fields; bump the version; commit; or move workflow state.

## Dispatch

route=mid
reason=kind implementation rated low
tier=mid
subagent_type=slice-executor-mid
model=sonnet
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Sonnet 5.5
explore_model=haiku
explore_effort=high
