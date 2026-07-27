# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P11`
- Current slice: `P11.S2`
- Next slice: `P11.REVIEW`
- Waiting on operator: `none`
- Open deferred jobs: `0`
- Rebuilt at: `2026-07-28T03:57:37+09:00`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [x] `P7` | `done` | `pass` | Retire embedded /explain | `none` | `works/phases/active/P7` |
| [x] `P8` | `done` | `pass` | Auto-explain at phase review | `none` | `works/phases/active/P8` |
| [x] `P9` | `done` | `pass` | Knowledge-by-default in bootstrapped workspaces | `none` | `works/phases/active/P9` |
| [x] `P10` | `done` | `pass` | Pipelined slice planning and verbatim plan capture | `none` | `works/phases/active/P10` |
| [ ] `P11` | `planned` | `pending` | Free the orchestrator's idle window | `P11.S2` | `works/phases/active/P11` |

## Phase P7: Retire embedded /explain

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P7.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P7/slices/P7.DECOMP` |
| [x] `P7.S1` | `done` | Remove explain from the distribution | `implementation` | `works/phases/active/P7/slices/P7.S1` |
| [x] `P7.REVIEW` | `done` | phase review | `review` | `works/phases/active/P7/slices/P7.REVIEW` |

## Phase P8: Auto-explain at phase review

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P8.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P8/slices/P8.DECOMP` |
| [x] `P8.S1` | `done` | Auto-explain the phase at a passing review | `implementation` | `works/phases/active/P8/slices/P8.S1` |
| [x] `P8.REVIEW` | `done` | phase review | `review` | `works/phases/active/P8/slices/P8.REVIEW` |

## Phase P9: Knowledge-by-default in bootstrapped workspaces

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P9.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P9/slices/P9.DECOMP` |
| [x] `P9.S1` | `done` | Installer/product knowledge-setup wiring | `implementation` | `works/phases/active/P9/slices/P9.S1` |
| [x] `P9.S2` | `done` | Repo docs alignment: env-var/REST knowledge default | `implementation` | `works/phases/active/P9/slices/P9.S2` |
| [x] `P9.REVIEW` | `done` | phase review | `review` | `works/phases/active/P9/slices/P9.REVIEW` |

## Phase P10: Pipelined slice planning and verbatim plan capture

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P10.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P10/slices/P10.DECOMP` |
| [x] `P10.S1` | `done` | Pipelined prefetch in do-whole-phase | `implementation` | `works/phases/active/P10/slices/P10.S1` |
| [x] `P10.S2` | `done` | Copy-based verbatim plan capture | `implementation` | `works/phases/active/P10/slices/P10.S2` |
| [x] `P10.REVIEW` | `done` | phase review | `review` | `works/phases/active/P10/slices/P10.REVIEW` |

## Phase P11: Free the orchestrator's idle window

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P11.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P11/slices/P11.DECOMP` |
| [x] `P11.S1` | `done` | Drop slice-planner; make idle-window preparation optional | `implementation` | `works/phases/active/P11/slices/P11.S1` |
| [ ] `P11.S2` | `todo` | Refresh the stale README tier facts | `implementation` | `works/phases/active/P11/slices/P11.S2` |
| [ ] `P11.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P11/slices/P11.REVIEW` |
