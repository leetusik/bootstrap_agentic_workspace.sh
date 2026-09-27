# Result — P23.DECOMP (decomposition)

## Verdict

- status: done
- summary: Cut P23 research-first — P23.S1 (research/high) maps every contract rule to its reader, then P23.DECOMP2 (decomposition/high, gated) cuts the edit slices from that map; phase.md seeded with six decisions and S1's agenda.
- files_changed:
  - works/phases/active/P23/slices/P23.S1/slice.json (new, via new-slice)
  - works/phases/active/P23/slices/P23.DECOMP2/slice.json (new, via new-slice)
  - works/phases/active/P23/phase.md (Decisions, Doc impact, Operator Questions, Notes for later slices, Now)
  - works/phases/active/P23/slices/P23.DECOMP/result.md (this file)
  - engine-regenerated: works/backlog.md, works/index.json, works/events.jsonl, works/state.json, docs/index.json (`last_rebuilt_at` timestamp only)
- validation:
  - `python3 scripts/workflow.py rebuild` — pass (exit 0)
  - `python3 scripts/workflow.py validate` — pass (exit 0; the pre-existing advisory warnings consolidation_owed=P21,P22 / stale_docs / oversized_doc_sections are expected)
  - `ls -la` on both new folders — each holds only `slice.json`
- deviations: none
- doc_impact: `(none from P23.DECOMP — decomposition changes no durable truth)`, plus the expected targets (architecture.md *Current Repo Shape*, operations.md installer build/release, qa.md *Test Commands*, decisions.md)

## Slices cut

| id | name | kind | risk | order | depends_on |
|---|---|---|---|---|---|
| P23.S1 | map every contract rule to the reader that needs it | research | high | 1 | — |
| P23.DECOMP2 | cut the editorial slices from the rule map | decomposition | high | 2 | P23.S1 |

Orders 3–9998 stay free for DECOMP2's slices, and REVIEW stays at 9999. The rationale for the cut, the six decisions, S1's 9-point agenda, the starting facts, DECOMP2's cutting constraints, the machinery discipline and the D13 trigger note are in `works/phases/active/P23/phase.md` (*Decisions*, *Notes for later slices*). They aren't restated here.

## Validation detail

- `rebuild` printed `rebuilt workflow and docs`. It regenerated `## Slices` as DECOMP → S1 → DECOMP2 → REVIEW (checked in `phase.md`).
- `validate` printed `Workflow validation passed.` after three advisory warnings that were already there: `consolidation_owed=P21, P22`, `stale_docs=architecture, decisions, operations, qa`, and `oversized_doc_sections=7`.
- `rebuild` also rewrites `docs/index.json` `last_rebuilt_at` (2026-09-17 → 2026-09-28). That is the engine's own side effect, and `docs/current/*` is unchanged.
- `wc -c works/phases/active/P23/phase.md` = 13,423 B, far under the 400 KB soft cap.

## Starting facts spot-checked

I re-measured these at DECOMP and they match the plan: `CLAUDE.md` 50,048 B; `slice-executor-high.md` 27,734 B; `slice-executor-mid.md` 27,717 B. That puts the per-dispatch prefix at 77,782 B with the high tier. `installer/main.py:38` has `WORKSPACE_VERSION = 43`, the CHANGELOG top heading is `## v43`, and smoke Test 0 reads the contract at `tests/retrofit_smoke.sh:369`. I didn't re-verify the rest of the plan's facts (section sizes, pin counts, inbound reference lines, adopter versions). `phase.md` records them as "re-measure rather than trust", for S1.

## Acceptance-gate read

Waive. The phase changes machinery and doctrine only (`CLAUDE.md`, `.claude/*`, `tests/retrofit_smoke.sh`, installer, CHANGELOG), and there's no running product for the operator to walk. Nothing in intent.md or this cut points to an operator-visible surface. The orchestrator declares it (`accept-gate P23 --waive --note "..."`) after `finish-slice P23.DECOMP`. This slice didn't run it.
