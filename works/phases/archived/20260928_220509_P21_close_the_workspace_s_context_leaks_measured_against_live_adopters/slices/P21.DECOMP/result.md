# Result — P21.DECOMP (decomposition)

- **status:** done
- **summary:** Cut P21 research-first: created `P21.S1` (research, high, order 2) and `P21.DECOMP2` (decomposition, high, order 3, depends on S1) as bare folders, and recorded the breakdown, the read-only adopter evidence paths, and the research agenda in `phase.md`. No remedy slices — those are DECOMP2's to cut from the findings.
- **files_changed:**
  - `works/phases/active/P21/slices/P21.S1/slice.json` (created via `new-slice`)
  - `works/phases/active/P21/slices/P21.DECOMP2/slice.json` (created via `new-slice`)
  - `works/phases/active/P21/phase.md` (Decisions / Notes for later slices / Now)
  - `works/phases/active/P21/slices/P21.DECOMP/result.md` (this file)
  - engine-regenerated: `works/backlog.md`, `works/index.json`, `works/state.json`, `works/events.jsonl`, `docs/index.json` (rebuild timestamp only)
- **validation:**
  - `python3 scripts/workflow.py new-slice --phase P21 --slice P21.S1 ... --kind research --risk high --order 2` — passed (folder created, bare)
  - `python3 scripts/workflow.py new-slice --phase P21 --slice P21.DECOMP2 ... --kind decomposition --risk high --order 3 --depends-on P21.S1` — passed (folder created, bare)
  - `ls -la` on both new slice folders — passed: each holds `slice.json` only, no `plan.md`
  - `python3 scripts/workflow.py rebuild` — passed ("rebuilt workflow and docs"); `## Slices` table now lists DECOMP → S1 → DECOMP2 → REVIEW in order
  - `python3 scripts/workflow.py validate` — passed ("Workflow validation passed.", exit 0), no `phase.md` budget warning
  - `wc -lc works/phases/active/P21/phase.md` — 56 lines / 7,375 bytes, inside the 200-line / 16 KB budget
- **deviations:** none
- **doc_impact:** none — this slice changed no durable truth
- **doc_versions:** n/a (not a review slice)

## The cut, and why it is only two slices

The operator already settled the shape in `intent.md` ("I choose one" — one phase, research-first), and the phase objective states the structural fact this decomposition rests on: **the fix list is not knowable before the measurement**. Five of the six leak candidates are open questions, not confirmed defects, and even the one confirmed leak (per-review whole-doc rewrite) comes with a proposed remedy whose blast radius — what a review still records, where "Doc impact" notes go, what happens to the parallel-mode deferred-consolidation path — is exactly what the research has to weigh. Any remedy slice cut today would be re-cut by `DECOMP2` tomorrow, so none were cut.

That makes this the `research` → `DECOMP2` origin described in `CLAUDE.md` (the first of `DECOMP2`'s two origins, not the `build-after` design one). Both middle slices are `--risk high`: `research` and `decomposition` route to `slice-executor-high` by **kind** regardless of risk, and rating them `high` keeps the recorded rating from contradicting the routing.

Orders: DECOMP is 0 and REVIEW is 9999, so the plan's suggested 2 and 3 slot cleanly between them with room on either side for `DECOMP2` to insert remedy slices (fractional orders are available if it wants to interleave).

## Notes relocated to the notebook

Per the slice-files split, the durable handoff lives in `works/phases/active/P21/phase.md` and is not restated here: three `## Decisions` lines (research-first cut; scope boundary at this repo's machinery/doctrine; the acceptance-gate read), five tagged `## Notes for later slices` (adopter evidence paths and re-measure instruction; the research agenda drawn from `intent.md`; the findings-only + notebook-budget discipline for S1; the risk-rating guidance for DECOMP2; the `installer/build.py` rule and the P20 version-number coordination), and a rewritten `## Now`.

`## Doc impact` and `## Operator Questions` were left empty on purpose: this slice settled nothing durable and raised no question the operator must answer — the five open questions in `intent.md` are the *research agenda*, answerable by measurement, and are deliberately not filed as Operator Questions. If the research turns one of them into a genuine operator call (for example, whether to accept a lossier notebook budget), S1 files it there.

## Acceptance-gate read for the orchestrator

`--waive` is expected, and nothing in this decomposition changes that. P21 touches workflow machinery and doctrine only — `scripts/workflow.py`, `.claude/*`, `works/templates/*`, `CLAUDE.md`, and the rebuilt installer — with no operator-visible running product, no route, no mockup, and no UI. The four adopter repos are read as evidence and receive at most a documented procedure or a command they run themselves, so nothing ships into an operator-facing surface from here either.

Suggested call: `accept-gate P21 --waive --note "machinery and doctrine only; no operator-visible running product"`.

One caveat for `DECOMP2` rather than for now: if a remedy it cuts turns out to change something the operator actually looks at — the shape of a generated dashboard such as `works/backlog.md` or `works/deferred.md`, say — the gate decision is worth revisiting at that point. That is a possibility, not a prediction; a waiver taken now is the right call on the evidence in hand.

## Boundaries observed

No `plan.md` was written for `P21.S1` or `P21.DECOMP2` (bare folders only). No commit, no `accept-gate`, no status transitions beyond what `new-slice` itself performed. No adopter repository was read or touched — the paths were handed to S1 as notes, as the plan directed.
