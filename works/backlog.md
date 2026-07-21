# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.
> Status box: `[x]` done · `[~]` pending — waiting on operator · `[r]` ready — plan approved, awaiting execution · `[ ]` open/in progress.

## Pointer

- Current phase: `P7`
- Current slice: `P7.DECOMP`
- Next slice: `P7.REVIEW`
- Waiting on operator: `none`
- Open deferred jobs: `1`
- Rebuilt at: `2026-07-21T13:17:18+09:00`

## Active Phases

| Phase | Status | Review | Name | Current Slice | Path |
|---|---|---|---|---|---|
| [x] `P4` | `done` | `pass` | Model-flexible attribution, installer split, versioned workspace updates | `none` | `works/phases/active/P4` |
| [x] `P5` | `done` | `pass` | Optional /explain install (--with-explain) | `none` | `works/phases/active/P5` |
| [x] `P6` | `done` | `pass` | Wire /explain to the KB document API | `none` | `works/phases/active/P6` |
| [ ] `P7` | `planned` | `pending` | Retire embedded /explain | `P7.DECOMP` | `works/phases/active/P7` |
| [ ] `P8` | `planned` | `pending` | Auto-explain at phase review | `P8.DECOMP` | `works/phases/active/P8` |

## Phase P4: Model-flexible attribution, installer split, versioned workspace updates

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P4.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P4/slices/P4.DECOMP` |
| [x] `P4.S1` | `done` | Split installer into installer/ with build + drift check | `implementation` | `works/phases/active/P4/slices/P4.S1` |
| [x] `P4.S2` | `done` | Model-flexible attribution sweep | `implementation` | `works/phases/active/P4/slices/P4.S2` |
| [x] `P4.S3` | `done` | CHANGELOG + integer workspace versioning in /update-workspace | `implementation` | `works/phases/active/P4/slices/P4.S3` |
| [x] `P4.REVIEW` | `done` | phase review | `review` | `works/phases/active/P4/slices/P4.REVIEW` |

## Phase P5: Optional /explain install (--with-explain)

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P5.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P5/slices/P5.DECOMP` |
| [x] `P5.S1` | `done` | Make /explain opt-in at install (--with-explain) | `implementation` | `works/phases/active/P5/slices/P5.S1` |
| [x] `P5.REVIEW` | `done` | phase review | `review` | `works/phases/active/P5/slices/P5.REVIEW` |

## Phase P6: Wire /explain to the KB document API

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P6.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P6/slices/P6.DECOMP` |
| [x] `P6.S1` | `done` | Rewire /explain steps 5–7 to POST /api/documents (API-first, manual fallback) | `implementation` | `works/phases/active/P6/slices/P6.S1` |
| [x] `P6.S2` | `done` | Sync updated /explain skill to ~/.claude/skills/explain (operator-authorized) | `implementation` | `works/phases/active/P6/slices/P6.S2` |
| [x] `P6.REVIEW` | `done` | phase review | `review` | `works/phases/active/P6/slices/P6.REVIEW` |

## Phase P7: Retire embedded /explain

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [ ] `P7.DECOMP` | `todo` | decompose phase | `decomposition` | `works/phases/active/P7/slices/P7.DECOMP` |
| [ ] `P7.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P7/slices/P7.REVIEW` |

## Phase P8: Auto-explain at phase review

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [ ] `P8.DECOMP` | `todo` | decompose phase | `decomposition` | `works/phases/active/P8/slices/P8.DECOMP` |
| [ ] `P8.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P8/slices/P8.REVIEW` |
