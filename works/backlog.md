# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P22`
- Current slice: `P22.S1`
- Next slice: `P22.S2`
- Waiting on operator: `none`
- Open deferred jobs: `10`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [x] `P20` | `done` | `pass` | make the Aside prescription true: the repl surface over Bash, on a dedicated profile | `none` | `works/phases/active/P20` |
| [x] `P21` | `done` | `pass` | close the workspace's context leaks, measured against live adopters | `none` | `works/phases/active/P21` |
| [ ] `P22` | `planned` | `pending` | make doc staleness explicit and right-size the notebook and test guardrails | `P22.S1` | `works/phases/active/P22` |

## Phase P20: make the Aside prescription true: the repl surface over Bash, on a dedicated profile

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P20.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P20/slices/P20.DECOMP` |
| [x] `P20.S1` | `done` | correct the surface taxonomy and prescribe aside repl over Bash | `implementation` | `works/phases/active/P20/slices/P20.S1` |
| [x] `P20.S2` | `done` | require a dedicated Aside profile for agent runs | `implementation` | `works/phases/active/P20/slices/P20.S2` |
| [x] `P20.S3` | `done` | ship workspace v37: version, changelog, consistency sweep | `implementation` | `works/phases/active/P20/slices/P20.S3` |
| [x] `P20.REVIEW` | `done` | phase review | `review` | `works/phases/active/P20/slices/P20.REVIEW` |

## Phase P21: close the workspace's context leaks, measured against live adopters

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P21.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P21/slices/P21.DECOMP` |
| [x] `P21.S1` | `done` | measure context spend across four live adopters | `research` | `works/phases/active/P21/slices/P21.S1` |
| [x] `P21.DECOMP2` | `done` | cut remedy slices from research findings | `decomposition` | `works/phases/active/P21/slices/P21.DECOMP2` |
| [x] `P21.S2` | `done` | defer doc consolidation out of the review (R1+R2) | `implementation` | `works/phases/active/P21/slices/P21.S2` |
| [x] `P21.S3` | `done` | surface consolidation debt in next/validate (R3) | `implementation` | `works/phases/active/P21/slices/P21.S3` |
| [x] `P21.S4` | `done` | docs-phase entry point (R4) | `implementation` | `works/phases/active/P21/slices/P21.S4` |
| [x] `P21.S5` | `done` | split oversized doc sections (R5) | `implementation` | `works/phases/active/P21/slices/P21.S5` |
| [x] `P21.REVIEW` | `done` | phase review | `review` | `works/phases/active/P21/slices/P21.REVIEW` |

## Phase P22: make doc staleness explicit and right-size the notebook and test guardrails

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P22.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P22/slices/P22.DECOMP` |
| [ ] `P22.S1` | `todo` | relax the notebook budget and sharpen keep-tests-small (D15+D16) | `implementation` | `works/phases/active/P22/slices/P22.S1` |
| [ ] `P22.S2` | `todo` | make doc staleness explicit in docs/index.json and where docs are read (D14) | `implementation` | `works/phases/active/P22/slices/P22.S2` |
| [ ] `P22.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P22/slices/P22.REVIEW` |
