# Result — P24.DECOMP (decomposition)

## Verdict

- **status:** done
- **summary:** Cut P24 into five bare `docs` slices, one per durable doc (S1 architecture, S2 operations, S3 qa, S4 decisions, all `docs / low`) plus S5 for both READMEs (`docs / high`, depends on S4). Seeded `phase.md` with the ten decisions, the per-slice note coverage, the tagged notes and the S1 handoff. `rebuild` and `validate` both pass.
- **files_changed:** `works/phases/active/P24/slices/P24.S1/slice.json` … `P24.S5/slice.json` (five new bare folders), `works/phases/active/P24/phase.md`, `works/phases/active/P24/slices/P24.DECOMP/result.md`, plus the regenerated `works/backlog.md`, `works/index.json`, `works/events.jsonl`, `works/state.json`, and `docs/index.json` (only `last_rebuilt_at` changed)
- **validation:** `python3 scripts/workflow.py rebuild` passed (exit 0). `python3 scripts/workflow.py validate` passed (exit 0), with the three expected advisory warnings: `consolidation_owed=`, `stale_docs=` and `oversized_doc_sections=7`.
- **deviations:** none in substance. Beyond the plan's text, two small clarifications went into the notebook: (a) Decision 1 lists each slice's notes by source slice, and the procedure note explains that the per-doc counts sum to 30 but there are only 27 doc-bearing notes (this is D17's count, not a missing note); (b) the S3 note marks P23.S3's "40 contract positives" as an intermediate count that P23.S4's 38 supersedes.
- **doc_impact:** `(none — a docs phase pays P21–P23's notes and creates no durable truth of its own; the READMEs are not versioned docs) (P24.DECOMP)`

## What was done

1. **Re-checked the planning facts before relying on them** (2026-09-28):
   - `docs-debt` still reports `docs_debt=P21, P22, P23 (3 phase(s), 29 note(s), 4 doc(s))`. By doc: architecture 6, decisions 7, operations 8, qa 9, (unassigned) 2.
   - `docs` flags all four docs STALE: architecture v0007, decisions v0041 and operations v0034 (all from v43), and qa v0009 (from v42).
   - `PHASE_MD_BUDGET = (200 lines, 16 KB)` is still at `operations.md:593` and `decisions.md:557`.
   - The decisions log headings are still at `:44` (v43), `:103` and `:202` (v42), and `:279` (P20/v37).
   - `README.en.md:44–45` and `:317–318` still say the review "consolidates".
   - File sizes: decisions.md is 269,799 B and operations.md is 117,990 B.
2. **Read both unassigned notes in full** in the notebooks (P21 `phase.md:63`, P22 `phase.md:61–66`). Each is only the review's "verified; no version created" stamp summarizing the lines above it, with no doc content. This confirms Decision 5 and what `intent.md` expected DECOMP to check.
3. **Checked the per-doc coverage** against the `docs-debt` output. Every one of the 27 doc-bearing notes maps to exactly the slices named in `phase.md`'s `## Decisions` (first bullet).
4. **Created the five slices** with the plan's exact `new-slice` commands:

   | Slice | Kind / risk | Order | depends_on | Status |
   |---|---|---|---|---|
   | S1 | docs / low | 1 | — | todo |
   | S2 | docs / low | 2 | — | todo |
   | S3 | docs / low | 3 | — | todo |
   | S4 | docs / low | 4 | — | todo |
   | S5 | docs / high | 5 | P24.S4 | todo |

   Each folder holds only `slice.json`. `find … -name plan.md` under P24 returns only DECOMP's own plan. REVIEW is still at 9999.
5. **Seeded `phase.md`**, editing around the generated `## Slices` block and never inside it:
   - `## Decisions`: the ten decisions, tagged `(P24.DECOMP)`.
   - `## Doc impact`: the one "none" line.
   - `## Operator Questions`: `(none from P24.DECOMP)`.
   - `## Notes for later slices`: six tagged notes (the S1–S4 procedure, read-sections-not-files, and one each for S2, S3, S4 and S5).
   - `## Now`: 9 lines.

   The notebook is 10,696 B, far under the 400 KB soft cap. The rationale lives there and is not repeated here.

## Validation output

```
$ python3 scripts/workflow.py rebuild
rebuilt workflow and docs                                   (exit 0)
$ python3 scripts/workflow.py validate
warning: consolidation_owed=P21, P22, P23 (...)
warning: stale_docs=architecture, decisions, operations, qa (4 doc(s) named by 30 unconsolidated '## Doc impact' note(s) from P21, P22, P23; ...)
warning: oversized_doc_sections=7 (...) decisions.md '## Decision Log' 236,975 B; operations.md '## Visual-design runbook ...' 21,161 B; decisions.md '## Superseded Decisions' 16,903 B; +4 more -- split them at the next consolidation (a docs phase), by per-doc judgment, never a sweep
Workflow validation passed.                                 (exit 0)
```

## Observations for the orchestrator (not deviations)

- **The `validate` split hint conflicts with Decision 6.** `oversized_doc_sections=` now tells the operator to "split them at the next consolidation (a docs phase)". That is exactly this phase, but Decision 6 says not to split here. The plan already expected `doc-new-version` to print this hint and says to ignore it, so the doc slices will see it and should follow Decision 6. If the operator wants the split done in P24 after all, that is their call.
- **The "30" in `stale_docs=` is D17.** It counts one entry per doc per note, so the three P21 notes that name both operations and qa count twice. The note is out of scope (Decision 10), and the per-slice procedure note explains the count so the mid-tier doc slices do not go looking for a missing note.
