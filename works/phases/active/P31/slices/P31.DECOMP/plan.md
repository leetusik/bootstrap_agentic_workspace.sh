# Plan — P31.DECOMP (decomposition, docs phase)

## Context

P31 pays the durable-doc consolidation debt of **P26, P27, P28, P29 and P30**. These five phases are all done with passing reviews; the only thing keeping them out of archiving is `consolidation: pending`. `/rotate-backlog` proposed the phase, and the operator confirmed it. Read `works/phases/active/P31/intent.md` in full first.

The worklist is `python3 scripts/workflow.py docs-debt`: 52 notes over 4 docs, with **no unassigned notes**. Every note names one of the four docs, and some name two.

| Doc | Notes | Latest version |
|---|---|---|
| architecture | 9 | v0009 |
| operations | 20 | v0036 |
| qa | 13 | v0012, which already carries P30.REVIEW's checklist lines |
| decisions | 12 | v0042 |

The precedent is **P24**, the last docs phase. Its `## Decisions` live in the archived `works/phases/archived/*P24*/phase.md`. Follow its rules unless this plan says otherwise.

**Operator answers at this DECOMP (2026-10-07):**
- **Fold D50 in.** The operations slice also writes an `## Operator Runtime` section for this repo. The product here is the CLI and the installer, run in scratch dirs, with no browser.
- **No section splits.** Follow the P24 precedent: the 10 KB warning is visibility, not surgery, and D25 stays deferred. The one exception is the operations heading "Visual-design runbook (Claude Design + DesignSync; …)": it is now false, so the P26/P27 notes that rewrite the runbook also retitle it.

## Orchestrator step before the executor runs

Promote D50 into the operations slice:

`python3 scripts/workflow.py promote-deferred D50 --phase P31 --slice P31.S2 --name "Operations: P26–P30 notes and the Operator Runtime section" --kind docs --risk low --order 20`

The DECOMP executor then creates only S1, S3 and S4 around it.

## The cut

One slice per doc, one new version per doc. All slices are `docs / low`, which routes them to `slice-executor-mid`: one `edit_path` each, and the notes are reviewed truth. The order follows P24, with decisions last so its entries can name the versions S1–S3 cut:

1. **`P31.S1` Architecture: P26–P30 notes.** 9 notes. Order 10.
2. **`P31.S2` Operations: P26–P30 notes and the Operator Runtime section.** 20 notes, plus D50. Created by the promotion above. Order 20.
3. **`P31.S3` QA: P26–P30 notes.** 13 notes. Order 30. It builds on v0012 and keeps P30.REVIEW's four checklist lines.
4. **`P31.S4` Decisions: P26–P30 notes.** 12 notes. Order 40.

Each of S2–S4 depends on the slice before it. There is no README slice: P26–P30 already edited the READMEs directly in their own slices.

## Decisions to record in phase.md `## Decisions` (compact, P24 style)

- **The cut:** as above, with per-slice coverage counted by source slice. Read every owing phase's `## Doc impact` list in full, and list the coverage per slice as P24 did.
- **Version source:** every doc slice runs `doc-new-version --doc <doc> --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "<short headline>"`. The summary's slug becomes the filename, so keep it short.
- **Merge, don't append:** fold each note into the section it names and replace every statement it supersedes. Where P26 → P27 → P29 supersede one another, the doc states the latest truth. Example: the design loop is P26's drafter loop, then P27's per-phase tool choice, and the install default is P28's opt-in nested install, then P29's nested default. Keep history only where the doc's own convention does, such as decisions' `## Superseded Decisions`. If an owed note contradicts text already in the doc, report it; never silently choose.
- **Notes are the input:** the reviews verified them. A slice reads code only to resolve an ambiguous note.
- **No restructuring:** no section splits, per the operator, with D25 deferred. Ignore `doc-new-version`'s split hint and record section sizes in `result.md`. The visual-design runbook heading is retitled to match the two-tool design loop, because the old title is false.
- **D50 (S2):**
  - Add an `## Operator Runtime` section to operations, in the shape the contract and the `review-phase` skill expect.
  - It records that the product is the workspace engine CLI (`python3 scripts/workflow.py`) plus the built installer `bootstrap_agentic_workspace.sh`. Both run in scratch directories, never against this checkout for mutating commands. There is no browser and no Aside account. "Verified in a real browser" claims do not apply.
  - The smoke suite is `bash tests/retrofit_smoke.sh`, run once, alone in its own foreground Bash call.
  - D50 is closed by the promotion; S2's `result.md` says so.
- **Payment:** when S4 finishes, S1–S4 have covered every note. The orchestrator then runs `docs-consolidated` for P26, P27, P28, P29 and P30 in S4's commit; none of them ran in a worktree. After that, `docs-debt` names no owing phase, `docs` shows no STALE flag, and `rotate-backlog` would archive P26–P30. The review checks the first two and never runs rotate here.
- **A docs phase leaves no `## Doc impact` notes of its own.**
- **Acceptance gate: waive.** Four new doc versions change no running surface. The orchestrator runs `accept-gate P31 --waive --note "docs phase: four durable-doc versions, no operator-visible surface"` right after `finish-slice P31.DECOMP`.
- **Out of scope, stay deferred:**
  - D17 and D21: both edit machinery.
  - D23: a skill text.
  - D24: README drift; the READMEs are not versioned docs, and the operator scoped the notes only.
  - D25: splits, which the operator declined.

  Their "next docs phase" triggers are relayed to the operator at the end.

## Notes for later slices (into `## Notes for later slices`)

- **For each doc slice:**
  - Read only the doc's current version (from `doc-new-version`'s `edit_path`) and the notes assigned to the slice.
  - Edit only the `edit_path`, then run `rebuild-docs`.
  - Run `validate` at the end.
- **For S3:** v0012 already has P30.REVIEW's four Regression Checklist lines. Keep them, and fold the P26–P30 qa notes around them. The smoke baseline is now 239 PASS.
- **For S4:** name the versions S1–S3 cut where an entry needs them.

## What this DECOMP executor does

1. Confirm P31.S2 exists (promoted by the orchestrator).
2. Create the other slices as **bare folders**, never pre-filling their `plan.md`:
   - `python3 scripts/workflow.py new-slice --phase P31 --slice P31.S1 --name "Architecture: P26–P30 notes" --kind docs --risk low --order 10`
   - `python3 scripts/workflow.py new-slice --phase P31 --slice P31.S3 --name "QA: P26–P30 notes" --kind docs --risk low --order 30 --depends-on P31.S2`
   - `python3 scripts/workflow.py new-slice --phase P31 --slice P31.S4 --name "Decisions: P26–P30 notes" --kind docs --risk low --order 40 --depends-on P31.S3`
3. Read all five owing phases' `## Doc impact` lists. `docs-debt` prints them in full. Assign every note to its slice or slices, and record the per-slice coverage. A note naming two docs is covered by both slices.
4. Edit `phase.md` under budget: `## Decisions`, `## Notes for later slices`, and `## Now` pointing at S1.
5. Write `result.md` with the verdict block first.
6. Run `python3 scripts/workflow.py validate`.

It does not commit or transition state, does not run `accept-gate`, `docs-consolidated` or `doc-new-version`, and does not edit any doc.

## Verification

- `python3 scripts/workflow.py validate` passes.
- `next` points at `P31.S1`.
- `phase.md` `## Slices` lists S1–S4 and REVIEW.
- The S1, S3 and S4 folders hold only `slice.json`.
- D50 shows as promoted in `works/deferred.md`.
