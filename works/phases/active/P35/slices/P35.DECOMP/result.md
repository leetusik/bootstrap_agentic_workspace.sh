# P35.DECOMP — result

## Verdict

- status: done
- tier: high
- model: opus
- effort: high
- summary: Cut P35 into S1 (docs/low, do-whole-phase prep N+1 only), S2 and S3 (research/high: nested paired worktrees; this repo's nested conversion dry run) and DECOMP2 (decomposition/high, cuts the build from S2+S3), all bare folders; recorded Decisions 1-9, the superseded-at-root Doc impact note, per-slice Notes and Now in phase.md.
- files_changed: works/phases/active/P35/phase.md; works/phases/active/P35/slices/P35.{S1,S2,S3,DECOMP2}/slice.json (via new-slice); works/phases/active/P35/slices/P35.DECOMP/result.md; generated works/ files (backlog.md, index.json, events.jsonl) via the engine's rebuild
- validation: `python3 scripts/workflow.py validate` — passed (pre-existing warnings only: consolidation owed P32-P34, stale docs, oversized doc sections)
- deviations: one addition, no amendment to the breakdown — Decision 9 routes the three related deferred jobs (D35 → S2(f), D57 → S2(g), D37 → S2(i)); the plan covered D35/D57 but intent.md's Notes also name D37 for DECOMP to decide, so it is routed to S2 rather than left unweighed. The S3 note records that `git filter-repo` is not installed (git 2.45.2).
- doc_impact: decisions.md: the "this upstream repo stays at-root" line (l.121-122) is superseded by the operator on 2026-10-13; v50's "nothing migrates an at-root install" still stands for adopters (P35.DECOMP)

## Breakdown

The proposed breakdown is confirmed as planned (rationale in phase.md Decision 1):

| Slice | Kind / risk | Order | Depends on |
|---|---|---|---|
| P35.S1 do-whole-phase prepares slice N+1 only | docs / low | 10 | P35.DECOMP |
| P35.S2 research: paired worktrees for a nested install | research / high | 20 | P35.S1 |
| P35.S3 research: converting this repo to the nested layout | research / high | 30 | P35.S2 |
| P35.DECOMP2 cut the build from the S2/S3 findings | decomposition / high | 40 | P35.S3 |

Reasons for the ratings: S1 is pinned wording with no design (low, cheap row); S2 and S3 are open design that only scratch experiments can settle (research routes high by kind); DECOMP2 routes high by kind. No research slice was split further: S2's nine questions share one scratch install, and S3's seven share one scratch clone.

## Checks made

- `new-slice` x4 with `--kind/--risk/--order/--depends-on`; each folder holds only `slice.json`.
- S1's line refs spot-checked: SKILL.md l.19 (delegated slices) and l.40-45 (the "While executor N runs" bullet and sub-bullets), CLAUDE.md:15 (Orchestrator and executor paragraph, which ends "Idle-window prep (`do-whole-phase` only) stays read-only").
- Deferred jobs D35, D37, D57 confirmed open (`deferred`).
- `git filter-repo` not on PATH; git 2.45.2.

## Phase notebook

Decisions 1-9, the Doc impact line, five Notes (S1, S2, S3, S2+S3, DECOMP2) and Now are in `works/phases/active/P35/phase.md`; not restated here. Gate: the orchestrator runs `accept-gate P35 --require` (Decision 7).
