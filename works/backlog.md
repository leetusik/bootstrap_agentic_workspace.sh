# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P15`
- Current slice: `P15.F1`
- Next slice: `P15.REVIEW`
- Waiting on operator: `none`
- Open deferred jobs: `2`
- Rebuilt at: `2026-08-14T06:33:06+09:00`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [x] `P12` | `done` | `pass` | Opt-in parallel phase execution: branch-per-phase with PR + CI | `none` | `works/phases/active/P12` |
| [x] `P13` | `done` | `pass` | Codex workflow parity | `none` | `works/phases/active/P13` |
| [x] `P14` | `done` | `pass` | Codex visual-design cowork replacement | `none` | `works/phases/active/P14` |
| [ ] `P15` | `in_progress` | `changes_requested` | Drop Codex support | `P15.F1` | `works/phases/active/P15` |

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
| [x] `P12.REVIEW` | `done` | phase review | `review` | `works/phases/active/P12/slices/P12.REVIEW` |

## Phase P13: Codex workflow parity

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P13.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P13/slices/P13.DECOMP` |
| [x] `P13.S1` | `done` | Determine and land Codex executor tiers | `implementation` | `works/phases/active/P13/slices/P13.S1` |
| [x] `P13.S2` | `done` | Restore Codex do-whole-phase | `implementation` | `works/phases/active/P13/slices/P13.S2` |
| [x] `P13.F1` | `done` | Adjust Codex executor presets and enable flex | `fix` | `works/phases/active/P13/slices/P13.F1` |
| [x] `P13.S3` | `done` | Align Codex workflow contracts and command skills | `implementation` | `works/phases/active/P13/slices/P13.S3` |
| [x] `P13.S4` | `done` | Ship Codex parity through installation and updates | `implementation` | `works/phases/active/P13/slices/P13.S4` |
| [x] `P13.S5` | `done` | Audit and regression closure | `implementation` | `works/phases/active/P13/slices/P13.S5` |
| [x] `P13.REVIEW` | `done` | phase review | `review` | `works/phases/active/P13/slices/P13.REVIEW` |

## Phase P14: Codex visual-design cowork replacement

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P14.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P14/slices/P14.DECOMP` |
| [x] `P14.S1` | `done` | Research and select the Codex visual cowork contract | `implementation` | `works/phases/active/P14/slices/P14.S1` |
| [x] `P14.S2` | `done` | Implement the Codex-native design-cowork skill | `implementation` | `works/phases/active/P14/slices/P14.S2` |
| [x] `P14.S3` | `done` | Align Codex orchestration and shared contracts | `implementation` | `works/phases/active/P14/slices/P14.S3` |
| [x] `P14.S4` | `done` | Ship the replacement through installer and release lifecycle | `implementation` | `works/phases/active/P14/slices/P14.S4` |
| [x] `P14.S5` | `done` | Audit the complete visual-workflow parity and regressions | `implementation` | `works/phases/active/P14/slices/P14.S5` |
| [x] `P14.REVIEW` | `done` | phase review | `review` | `works/phases/active/P14/slices/P14.REVIEW` |

## Phase P15: Drop Codex support

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P15.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P15/slices/P15.DECOMP` |
| [x] `P15.S1` | `done` | Strip Codex from the workflow engine and executors.toml | `implementation` | `works/phases/active/P15/slices/P15.S1` |
| [x] `P15.S2` | `done` | Strip Codex from the installer and delete the Codex trees | `implementation` | `works/phases/active/P15/slices/P15.S2` |
| [x] `P15.S3` | `done` | Strip Codex from the contract and Claude skill prose | `implementation` | `works/phases/active/P15/slices/P15.S3` |
| [x] `P15.S4` | `done` | Rewrite the retrofit smoke test Codex-free | `implementation` | `works/phases/active/P15/slices/P15.S4` |
| [x] `P15.S5` | `done` | Strip Codex from READMEs, guides, and shipped doc bodies | `implementation` | `works/phases/active/P15/slices/P15.S5` |
| [x] `P15.S6` | `done` | Ship the removal as workspace v31 with a CHANGELOG entry | `implementation` | `works/phases/active/P15/slices/P15.S6` |
| [ ] `P15.F1` | `todo` | Settle the pending design exception | `fix` | `works/phases/active/P15/slices/P15.F1` |
| [ ] `P15.REVIEW` | `changes_requested` | phase review | `review` | `works/phases/active/P15/slices/P15.REVIEW` |
