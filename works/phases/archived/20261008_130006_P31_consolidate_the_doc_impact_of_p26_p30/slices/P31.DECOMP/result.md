# Result: P31.DECOMP (decomposition, docs phase)

## Verdict

- **status:** done
- **tier:** high
- **summary:** The phase is cut into four `docs / low` slices, one new version per doc. DECOMP created S1 architecture, S3 qa and S4 decisions as bare folders around the orchestrator-promoted S2 operations slice, which also carries D50. All 52 P26–P30 notes are assigned by source slice (54 doc assignments), and the decisions are recorded in `phase.md`.
- **files_changed:**
  - `works/phases/active/P31/slices/P31.S1/slice.json`
  - `works/phases/active/P31/slices/P31.S3/slice.json`
  - `works/phases/active/P31/slices/P31.S4/slice.json`
  - `works/phases/active/P31/phase.md`
  - this `result.md`
  - the engine-regenerated `works/backlog.md` and `works/index.json`, via `new-slice`
- **validation:**
  - `python3 scripts/workflow.py validate`: PASS ("Workflow validation passed."). The only warnings are the expected `consolidation_owed`, `stale_docs` and `oversized_doc_sections`.
  - `python3 scripts/workflow.py next`: `next_slice=P31.S1`.
- **deviations:** none.
- **doc_impact:** none. A docs phase leaves no notes of its own.

## What was done

1. **P31.S2 exists.** The orchestrator promoted it from D50 with `docs / low`, order 20. Its `plan.md` is the engine-seeded D50 context, and DECOMP left it untouched. `works/deferred.md` shows `D50 | promoted | P31.S2`.
2. **Created bare folders.** Each holds only `slice.json`, and no `plan.md` was pre-filled:
   - `new-slice --phase P31 --slice P31.S1 --name "Architecture: P26–P30 notes" --kind docs --risk low --order 10`
   - `new-slice --phase P31 --slice P31.S3 --name "QA: P26–P30 notes" --kind docs --risk low --order 30 --depends-on P31.S2`
   - `new-slice --phase P31 --slice P31.S4 --name "Decisions: P26–P30 notes" --kind docs --risk low --order 40 --depends-on P31.S3`
3. **Read the full worklist** with `python3 scripts/workflow.py docs-debt`. I cross-checked it against each owing phase's raw `## Doc impact` section with `awk` over `works/phases/active/P2{6..9}/phase.md` and `P30/phase.md`. The two sources match line for line: P26 has 19 notes, P27 11, P28 12, P29 4 and P30 6, for 52 in total. Neither source has a stamp line or an unassigned note.
4. **Recorded the per-slice coverage** in `phase.md` `## Decisions` (*Cut*), counted by source slice: S1 9, S2 20 plus D50, S3 13, S4 12. That sums to 54 because P28.F1 and P29.S1 each name both architecture and operations. The per-doc totals match `docs-debt`'s summary (9, 20, 13, 12).
5. **Edited `phase.md`** (10,490 B, far under budget):
   - `## Decisions`: the cut, version source, merge-don't-append with the supersession chains found while reading, notes-are-input, no restructuring with the runbook retitle, D50 in S2, payment, no own Doc impact, gate waive, and out of scope.
   - `## Notes for later slices`: one shared note for all four slices, plus one note for each of S1–S4.
   - `## Now`: points at S1.

   I did not touch the generated `## Slices` block. `## Doc impact` and `## Operator Questions` stay empty.

## Facts checked at DECOMP (for the doc slices)

- **Latest versions:**
  - architecture v0009 (P24.REVIEW)
  - operations v0036 (P24.REVIEW)
  - qa v0012 (P30.REVIEW)
  - decisions v0042 (P21–P23.REVIEW)

  `docs` flags all four STALE, which is expected until the payment.
- **qa v0012:** `## Regression Checklist` already carries 4 `(P29)` lines and 4 `(P30)` lines. The doc's stated smoke baseline is still "180 PASS / 0 FAIL as of v44", and the owed notes bring it to 239.
- **operations v0036:**
  - It has no `## Operator Runtime` section; "Operator Runtime" appears 9 times, only in prose.
  - The seeded section shape is in `installer/payloads/doc_bodies/operations.md`.
  - The runbook heading is still `## Visual-design runbook (Claude Design + DesignSync; single-harness since v31)`, at 21,161 B.
- **Supersession chains** the doc slices must resolve to the latest truth, recorded in *Merge, don't append*:
  - the design loop, P26 then P27
  - the install default, P28 then P29
  - the nested marker rename inside P28
  - the self-contained card rule, P26.F1 then P26.F2
  - the smoke baseline, 192 → 195 → 203 → 226 → 235 → 239

## Observation (no action taken)

- **P31.S2's `slice.json` has `depends_on: []`.** The plan's prose says "each of S2–S4 depends on the slice before it", but the plan's own `promote-deferred` line passes no `--depends-on`.
  - `depends_on` is advisory, and `order` (10 < 20) already runs S1 first, so sequencing is unaffected.
  - I left S2's `slice.json` alone because it is the orchestrator's state.
