# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P12`
- Current slice: `P12.REVIEW`
- Next slice: `none`
- Waiting on operator: `none`
- Open deferred jobs: `0`
- Rebuilt at: `2026-08-04T00:19:46+09:00`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [ ] `P12` | `in_progress` | `changes_requested` | Opt-in parallel phase execution: branch-per-phase with PR + CI | `P12.REVIEW` | `works/phases/active/P12` |

## Phase P12: Opt-in parallel phase execution: branch-per-phase with PR + CI

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P12.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P12/slices/P12.DECOMP` |
| [x] `P12.S1` | `done` | Parallel-mode schema + phase-scoped selection | `implementation` | `works/phases/active/P12/slices/P12.S1` |
| [x] `P12.S2` | `done` | Opt-in lifecycle: branch + worktree cut, teardown, proactive suggestion | `implementation` | `works/phases/active/P12/slices/P12.S2` |
| [x] `P12.S3` | `done` | Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation | `implementation` | `works/phases/active/P12/slices/P12.S3` |
| [x] `P12.S4` | `done` | Cross-stream status view | `implementation` | `works/phases/active/P12/slices/P12.S4` |
| [x] `P12.S5` | `done` | PR + CI layer, agent-driven integration | `implementation` | `works/phases/active/P12/slices/P12.S5` |
| [x] `P12.S6` | `done` | Skills + contract for parallel mode | `implementation` | `works/phases/active/P12/slices/P12.S6` |
| [x] `P12.S7` | `done` | README documentation for parallel mode | `implementation` | `works/phases/active/P12/slices/P12.S7` |
| [x] `P12.F1` | `done` | Guard doc-new-version against a parallel stream | `fix` | `works/phases/active/P12/slices/P12.F1` |
| [ ] `P12.REVIEW` | `changes_requested` | phase review | `review` | `works/phases/active/P12/slices/P12.REVIEW` |
