# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P34`
- Current slice: `P34.DECOMP`
- Next slice: `P34.REVIEW`
- Waiting on operator: `none`
- Open deferred jobs: `44`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [x] `P32` | `done` | `pass` | One executor route table: dispatch-time model and effort, no presets, Haiku cheap route | `none` | `works/phases/active/P32` |
| [x] `P33` | `done` | `pass` | One-shot /rotate-backlog: consolidate the doc debt, then archive | `none` · parallel: `phase/P33-one-shot_rotate-backlog_consolidate_the` | `works/phases/active/P33` |
| [ ] `P34` | `planned` | `pending` | Boundary-gated compaction: veto mid-process, resume at the slice boundary | `P34.DECOMP` | `works/phases/active/P34` |

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
| [ ] `P34.DECOMP` | `todo` | decompose phase | `decomposition` | `works/phases/active/P34/slices/P34.DECOMP` |
| [ ] `P34.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P34/slices/P34.REVIEW` |
