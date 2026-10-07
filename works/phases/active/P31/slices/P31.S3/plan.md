# Plan — P31.S3 QA: P26–P30 notes

## Goal

Fold the **13 qa notes** that `works/phases/active/P31/phase.md` `## Decisions` (*Cut*) assigns to S3 into **one** new qa version. Follow the phase's rules and the S3 note under `## Notes for later slices`.

## Steps

1. Read S3's input. `python3 scripts/workflow.py docs-debt` prints the notes; every line beginning `qa.md` belongs to S3. Check the count against *Cut*.
2. Create the version:
   ```
   python3 scripts/workflow.py doc-new-version --doc qa --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 smoke baseline 239, design and nested-install pins, fragile installer tokenizer"
   ```
   It builds on v0012.
3. Edit only the returned `edit_path`:
   - **Baseline.** The smoke baseline becomes **239 PASS / 0 FAIL as of v51** (P30). Replace the 180-at-v44 statements in `## Status` and `## Test Commands`.
     - Trace the count with the chain the notes give: 192 → 195 → 203 → 226 → 235 → 239.
     - Replace the old count; don't stack it. Keep only the doc's own convention of a short "how it rose" clause.
     - The notes cover P26 onwards. Where a note doesn't explain a step (for example 180 → 187 before P26.S1), say "through v45–v46 work" rather than inventing.
   - **Test descriptions.** Fold in the new and changed smoke tests the notes describe: Test 0's pins, Test 13 (the design contract), Tests 14–16 (nested), and P30's rotate asserts.
   - **`--at-root`.** P29.S1's note makes `## Test Commands`' "fresh-install" mean the `--at-root` path.
   - **Known Fragile Areas.** Add P27.REVIEW's entry: the installer body under system Python 3.9's stdin tokenizer, guarded by the utf-8 cookie and Test 7.
   - **Keep** the eight existing `## Regression Checklist` lines from P29.REVIEW and P30.REVIEW, unchanged.
   - **Operator Runtime.** Operations v0037 now has an `## Operator Runtime` section (CLI, no browser). Where qa's verification doctrine says this repository has no runtime manifest, update that sentence to match, and record it in `result.md`.
4. Run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate`.

## Notebook

- `result.md`, verdict block first. Include:
  - the version filename;
  - each note's landing section;
  - section sizes (record only);
  - any contradictions.
- In `phase.md`:
  - consume the S3 note;
  - add the version filename for S4;
  - rewrite `## Now`.
- No `## Doc impact` notes.

Do not commit, transition state, or run `docs-consolidated`. Touch no other doc.
