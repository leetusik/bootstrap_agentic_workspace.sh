# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P12`
- Current slice: `P12.S4`
- Next slice: `P12.S5`
- Waiting on operator: `none`
- Open deferred jobs: `0`
- Rebuilt at: `2026-08-03T23:19:50+09:00`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [ ] `P12` | `planned` | `pending` | Opt-in parallel phase execution: branch-per-phase with PR + CI | `P12.S4` | `works/phases/active/P12` |

## Phase P12: Opt-in parallel phase execution: branch-per-phase with PR + CI

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P12.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P12/slices/P12.DECOMP` |
| [x] `P12.S1` | `done` | Parallel-mode schema + phase-scoped selection | `implementation` | `works/phases/active/P12/slices/P12.S1` |
| [x] `P12.S2` | `done` | Opt-in lifecycle: branch + worktree cut, teardown, proactive suggestion | `implementation` | `works/phases/active/P12/slices/P12.S2` |
| [x] `P12.S3` | `done` | Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation | `implementation` | `works/phases/active/P12/slices/P12.S3` |
| [ ] `P12.S4` | `todo` | Cross-stream status view | `implementation` | `works/phases/active/P12/slices/P12.S4` |
| [ ] `P12.S5` | `todo` | PR + CI layer, agent-driven integration | `implementation` | `works/phases/active/P12/slices/P12.S5` |
| [ ] `P12.S6` | `todo` | Skills + contract for parallel mode | `implementation` | `works/phases/active/P12/slices/P12.S6` |
| [ ] `P12.S7` | `todo` | README documentation for parallel mode | `implementation` | `works/phases/active/P12/slices/P12.S7` |
| [ ] `P12.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P12/slices/P12.REVIEW` |
