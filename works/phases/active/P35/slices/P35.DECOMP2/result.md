# P35.DECOMP2 — result: cut the build from the S2/S3 findings

- status: done
- tier: high
- model: opus
- effort: high
- summary: Cut P35's build into eight bare slices, S4-S11 (S4 nested parallel-start, S5 paired teardown/merge, S6 hook cwd redirect and S10 the repo conversion at high; S7 Streams view + D57, S8 skill/installer text, S9 smoke and S11 the v58 release at mid), with the gated REVIEW last. Turned the operator's answers into Decisions 17-21 and consumed the S2/S3/DECOMP Notes into per-slice Notes. One amendment: S4 also stamps `execution.base_branch`, and S4 must keep smoke Test 14 green.
- files_changed: works/phases/active/P35/phase.md, works/phases/active/P35/slices/P35.DECOMP2/result.md, works/phases/active/P35/slices/P35.S4..S11/slice.json (via new-slice), generated works/backlog.md, works/index.json, works/events.jsonl, works/state.json
- validation: `python3 scripts/workflow.py validate` — pass; `executor-route` for S4/S7/S10 prints the expected kind; each new folder holds only `slice.json`
- deviations: (1) S4's field list gains `execution.base_branch`, which S2 (a) step 3 lists and S7 reads, but the plan's list left out. (2) S4 must update smoke Test 14's exact-refusal assertion (≈1846-1847) so the suite stays green between S4 and S9. Lifting the guard breaks that assertion; the plan gave the whole Test 14 rewrite to S9. (3) Decisions 3, 9 and 15 were edited in place, because Decisions 18 and 21 and the operator's `payload/` answer superseded them.
- doc_impact: none (no durable truth changed; each build slice writes its own notes)

## Breakdown

| Slice | Kind / risk | Order | Depends on | Trigger / reason |
|---|---|---|---|---|
| P35.S4 nested paired parallel-start, stream claim and host wiring | implementation / high | 50 | P35.DECOMP2 | core invariant: worktrees, stamp commit, `host_anchors`, `execution` fields |
| P35.S5 nested paired teardown, merge-finish and consolidation | implementation / high | 60 | P35.S4 | deletion: worktree and branch removal, the ignored-files guard |
| P35.S6 compaction hooks follow the session's cwd | implementation / high | 70 | P35.S5 | wide blast radius: every install's compactions, at root included |
| P35.S7 Streams view in backlog.md and the in-flight filter for next (D57) | implementation / low | 80 | P35.S6 | design pinned in S2 (g) |
| P35.S8 skills, installer and text for nested parallel and the host custom | implementation / low | 90 | P35.S7 | pinned wording plus installer lines |
| P35.S9 smoke tests for the nested lifecycle and the hook redirect | implementation / low | 100 | P35.S8 | core behavior, kept small |
| P35.S10 convert this repo to the nested layout | implementation / high | 110 | P35.S9 | deletion and history; wide blast radius (build, hook, smoke, CI) |
| P35.S11 v58 release in the new layout | implementation / low | 120 | P35.S10 | release bump, pinned steps |
| P35.REVIEW (existing, 9999) | review, gated | — | — | — |

This matches the plan's breakdown, which merges S2's 7-slice cut (its slice 7, the v58 bump, becomes S11 after the conversion, as S3 recommends) with S3's C1/C2. Each slice depends on the one before it. That is advisory only; dispatch follows the order. S6 is independent of S4-S5 in substance (S2), but it runs third so that S9 can test all three.

## What went into phase.md (by reference)

- Decisions 17-21 are new. Decision 3 now points at Decision 18's custom, and Decision 9 is a pointer to 21. Decision 15's "name is an Operator Question" now records `payload/`.
- `## Notes for later slices`: the three DECOMP2 Notes (from S2, S3 and DECOMP) were consumed into one shared Note for S4-S11, plus one Note each for S4-S11 and REVIEW. They carry the line refs (re-checked against today's `scripts/workflow.py`; they match S2's), the exact validations from S2's and S3's last sections, the patches' path, P35's full anchor sha `8ea3b7bfe8f3d6b94a27bf2d1e70877eb91dfe79`, and "smoke runs alone".
- `## Now` is rewritten in 9 lines.
- The Operator Questions are untouched (append-only). Every S2/S3 question is answered by the two `(operator, 2026-10-13)` entries, which become Decisions 18-20; the REVIEW routes them.

## Findings that shaped the amendments

- `grep base_branch scripts/workflow.py` finds nothing today, and the at-root `execution` is `{mode, branch, worktree, consolidation}` (≈2582). S7's default Streams row on a parallel stream reads `execution.base_branch`. So S4 stamps it in nested, and S7 may add it at root as an additive field (a pinned fallback exists when it is absent).
- `tests/retrofit_smoke.sh` ≈1846-1847 asserts `grep -qx "parallel worktrees are disabled in a nested personal install"`. S4 removes that refusal, so S4 has to touch the assertion, and S9 then rewrites it as the lifecycle check. The S4 and S9 Notes both say so.
- The smoke baseline 292 is the pre-P35-tests count. S9 records the new count, which becomes S10's baseline. This is in the S9 and S10 Notes.

## For the orchestrator

- **Deferred-job candidate to file** (`defer-job`): title "shared scratch paths linked into phase worktrees"; reason: a symlinked `temp` shows as `?? temp`, which blocks `worktree remove`, counts as `compact-gate` dirt and gets swept by `git add -A`, so any such list needs a non-directory exclude line per path and belongs in the nested marker (per install), not `executors.toml` (S2 (e)); trigger: "an operator asks to see main's `temp/` from a worktree".
- **D57** folds into S7: close it when S7 lands. D35 and D37 stay deferred (Decision 21).
- S10's plan is made at the gate, and its switch is the inline exception (Decision 20).
