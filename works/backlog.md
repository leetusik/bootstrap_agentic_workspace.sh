# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P35`
- Current slice: `P35.S9`
- Next slice: `P35.S10`
- Waiting on operator: `none`
- Open deferred jobs: `46`

## Streams

| Stream | Phase | Status | Current slice | Done | Worktree | Source |
|---|---|---|---|---|---|---|
| `default` | `P35` | planned | `P35.S9` | 10/14 | - | working tree |

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [x] `P32` | `done` | `pass` | One executor route table: dispatch-time model and effort, no presets, Haiku cheap route | `none` | `works/phases/active/P32` |
| [x] `P33` | `done` | `pass` | One-shot /rotate-backlog: consolidate the doc debt, then archive | `none` · parallel: `phase/P33-one-shot_rotate-backlog_consolidate_the` | `works/phases/active/P33` |
| [x] `P34` | `done` | `pass` | Boundary-gated compaction: veto mid-process, resume at the slice boundary | `none` | `works/phases/active/P34` |
| [ ] `P35` | `planned` | `pending` | nested-install parallel worktrees and one-slice prep | `P35.S9` | `works/phases/active/P35` |

## Phase P32: One executor route table: dispatch-time model and effort, no presets, Haiku cheap route

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P32.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P32/slices/P32.DECOMP` |
| [x] `P32.S1` | `done` | Engine: route table, executors.toml rows, sync-agents, executor-route; retire the presets and executor-mode | `implementation` | `works/phases/active/P32/slices/P32.S1` |
| [x] `P32.S2` | `done` | Engine: record-dispatch and dispatch-summary | `implementation` | `works/phases/active/P32/slices/P32.S2` |
| [x] `P32.S3` | `done` | Agents: Agent tool and delegation paragraph in both tiers, model/effort in the verdict block, new Explore.md | `implementation` | `works/phases/active/P32/slices/P32.S3` |
| [x] `P32.S4` | `done` | Skills and contract: dispatch through executor-route, Explore for lookups, attribution by recorded model; executor-route skill replaces executor-mode | `implementation` | `works/phases/active/P32/slices/P32.S4` |
| [x] `P32.S5` | `done` | Installer and release: v53, Explore.md managed, executors.toml seed derivation, rebuild, full smoke run and new baseline | `implementation` | `works/phases/active/P32/slices/P32.S5` |
| [x] `P32.S6` | `done` | CHANGELOG v53 entry with Migration notes; README.md and README.en.md executor sections | `docs` | `works/phases/active/P32/slices/P32.S6` |
| [x] `P32.REVIEW` | `done` | phase review | `review` | `works/phases/active/P32/slices/P32.REVIEW` |

## Phase P33: One-shot /rotate-backlog: consolidate the doc debt, then archive

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P33.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P33/slices/P33.DECOMP` |
| [x] `P33.S1` | `done` | Engine: rotate-backlog decides the chain, archives last | `implementation` | `works/phases/active/P33/slices/P33.S1` |
| [x] `P33.S2` | `done` | Skills, contract and release v54: the one-shot chain | `implementation` | `works/phases/active/P33/slices/P33.S2` |
| [x] `P33.REVIEW` | `done` | phase review | `review` | `works/phases/active/P33/slices/P33.REVIEW` |

## Phase P34: Boundary-gated compaction: veto mid-process, resume at the slice boundary

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P34.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P34/slices/P34.DECOMP` |
| [x] `P34.S1` | `done` | Engine: compact-gate and compact-resume | `implementation` | `works/phases/active/P34/slices/P34.S1` |
| [x] `P34.S2` | `done` | Ship the hooks: settings, installer hooks merge, smoke | `implementation` | `works/phases/active/P34/slices/P34.S2` |
| [x] `P34.S3` | `done` | Texts: Compact Instructions, skill reorder, doc notes | `implementation` | `works/phases/active/P34/slices/P34.S3` |
| [x] `P34.S4` | `done` | Release v55 | `implementation` | `works/phases/active/P34/slices/P34.S4` |
| [x] `P34.REVIEW` | `done` | phase review | `review` | `works/phases/active/P34/slices/P34.REVIEW` |

## Phase P35: nested-install parallel worktrees and one-slice prep

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P35.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P35/slices/P35.DECOMP` |
| [x] `P35.S1` | `done` | do-whole-phase prepares slice N+1 only | `docs` | `works/phases/active/P35/slices/P35.S1` |
| [x] `P35.S2` | `done` | research: paired worktrees for a nested install | `research` | `works/phases/active/P35/slices/P35.S2` |
| [x] `P35.S3` | `done` | research: converting this repo to the nested layout | `research` | `works/phases/active/P35/slices/P35.S3` |
| [x] `P35.DECOMP2` | `done` | cut the build from the S2/S3 findings | `decomposition` | `works/phases/active/P35/slices/P35.DECOMP2` |
| [x] `P35.S4` | `done` | nested paired parallel-start, stream claim and host wiring | `implementation` | `works/phases/active/P35/slices/P35.S4` |
| [x] `P35.S5` | `done` | nested paired teardown, merge-finish and consolidation | `implementation` | `works/phases/active/P35/slices/P35.S5` |
| [x] `P35.S6` | `done` | compaction hooks follow the session's cwd | `implementation` | `works/phases/active/P35/slices/P35.S6` |
| [x] `P35.S7` | `done` | Streams view in backlog.md and the in-flight filter for next (D57) | `implementation` | `works/phases/active/P35/slices/P35.S7` |
| [x] `P35.S8` | `done` | skills, installer and text for nested parallel and the host custom | `implementation` | `works/phases/active/P35/slices/P35.S8` |
| [ ] `P35.S9` | `todo` | smoke tests for the nested lifecycle and the hook redirect | `implementation` | `works/phases/active/P35/slices/P35.S9` |
| [ ] `P35.S10` | `todo` | convert this repo to the nested layout | `implementation` | `works/phases/active/P35/slices/P35.S10` |
| [ ] `P35.S11` | `todo` | v58 release in the new layout | `implementation` | `works/phases/active/P35/slices/P35.S11` |
| [ ] `P35.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P35/slices/P35.REVIEW` |
