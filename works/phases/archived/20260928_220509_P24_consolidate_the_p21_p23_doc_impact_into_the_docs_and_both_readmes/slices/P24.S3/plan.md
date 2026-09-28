# Plan — P24.S3 (docs): consolidate the P21–P23 notes into qa

## Context

P24 is the operator's docs phase. This slice pays the **nine qa notes** that P21, P22 and P23 owe by cutting **one** new version of the qa doc. Read these parts of `works/phases/active/P24/phase.md` first: `## Decisions` (especially *Merge, don't append*, *Version source* and *No doc restructuring*) and the S1–S4 and S3 notes. They bind this slice.

This is a `docs` slice in an operator-created docs phase on the default stream. Under the executor's docs-slice carve-out you may run `doc-new-version` and `rebuild-docs` for the notes below, and you edit **only** the returned `edit_path`. You never run `docs-consolidated`, never touch `docs/current/*.md` or older versions by hand, and never commit.

The current qa doc is `docs/current/qa.md`: v0009, source v42, 21,872 B. It is small enough to read whole. Its sections at planning time were:
- `## Status` `:13`
- `## Purpose` `:23`
- `## Testing Philosophy` `:27`
- `## Verification doctrine …` `:33` (12.9 KB, over the advisory; do not split it)
- `## Test Commands` `:190`
- `## Acceptance Criteria Style` `:229`
- `## Manual QA Missions` `:233`
- `## Regression Checklist` `:242`
- `## Known Fragile Areas` `:268`
- `## Open Questions` `:272`

## The nine notes

Take only the qa half of any note that also names operations. Read the P23 notes in full in `works/phases/active/P23/phase.md` `## Doc impact`, because they are long.

1. **P21.S2**: smoke 140 → 144 PASS. These are the v38 probes: a pass defers and stamps the debt, archiving blocks, and `docs-consolidated` unblocks.
2. **P21.S3**: smoke 144 → 146, for the `consolidation_owed=` line in `next` and the `validate` warning.
3. **P21.S4**: smoke 146 → 149, for `docs-debt` and the route.
4. **P21.S5**: smoke 149 → 152, for the oversized-section warning.
5. **P22.S1**: the testing posture is now **core-only**. Test files exist for very core behavior (logic the product cannot afford to break) and never for style, cosmetic or trivial surface, which is verified live. Terseness and grow-on-demand are unchanged.
6. **P22.S2**: smoke 152 → 158 PASS, from the v39 D14 probes:
   - the marker under each doc
   - the STALE flag and the shared line
   - the `validate` warning
   - the flag clearing when the debt is paid
   - the HEAD sha in all three sinks
   - the no-git path writing `unknown`/null without raising
7. **P23.S2**: *Test Commands* / prose invariants. Test 0 dropped four contract pins (the fixed design-only waive note, `finish-slice P1.S1 --outcome`, `**findings land in `phase.md`**`, and the `phase-scope P1 …` synopsis). Each is still asserted on the do-* / design-cowork / review-phase / executor lists or functionally (Tests 9 and 11). The executor-body list gained the docs-slice carve-out and fractional-`--order` pins. The smoke baseline was **counted** at 180 PASS / 0 FAIL.
8. **P23.S3**: Test 0 gained a whitespace-normalized **`parallel-phase` pin list**, plus design-cowork additions, a review-phase negative, and a smaller contract list. Read the full note; the executor text is long. Its "40 contract positives" is an intermediate count, superseded by note 9.
9. **P23.S4**: the contract list dropped its last two moved pins, leaving **38 contract positives**, 19 negatives and the 3 Test 1 sidecar greps. Test 0's comments now describe the ≤ 12 KB stub contract. Smoke still counts **180 PASS / 0 FAIL**.

## Where each note lands (the orchestrator's read; confirm against the file)

- **Note 5 → `## Status` (`:15`) and `## Testing Philosophy` (`:27`–`:31`).**
  - The Status line "Default testing posture: **keep test files small**. Tests are welcome, but …" becomes the core-only posture. Test files are written only for very core behavior and never for style, cosmetic or trivial surface, which is verified live. What exists stays terse. Grow on demand.
  - In Testing Philosophy, add or reshape one bullet stating core-only, keeping *Minimal by default*, *Keep test files small* and *Grow on demand*.
  - The contract's Hard Rules first bullet states the same rule. Match its meaning, not its words.
- **Notes 1–4, 6, 7, 8, 9 → `## Test Commands`, the *Smoke / integration* bullet (`:195`–`:216`).**
  - Currently it says "Tests 0-10" and "Baseline **140 PASS / 0 FAIL** as of v37 (139 at v36, …)". The smoke file now has **Tests 0–12**: Test 11 is v41 phase-scope and Test 12 is v43 worktree-on-request; check the `echo "== Test N:` lines in `tests/retrofit_smoke.sh`.
  - Rewrite the baseline to the last count, **180 PASS / 0 FAIL as of v44 (counted at P23)**, followed by a compact history in the doc's existing parenthetical style: 152 at v38 (P21: +12 for the consolidation-debt, `consolidation_owed=`, `docs-debt` and section-size probes), 158 at v39 (P22: +6 for the staleness/marker probes), and 140 at v37. Between v39 and v44 the count rose to 180 through the v40–v43 work, which no owed note itemizes. Say that plainly rather than inventing a breakdown.
  - Describe Test 0's current pin state from notes 7–9. Keep it to a few sentences plus a short list at most. The **pin lists** are: contract (38 positives, 19 negatives, whitespace-sensitive raw substrings), do-* / design-cowork / review-phase / executor bodies, and the new whitespace-normalized `parallel-phase` list. Also note the 3 Test 1 sidecar greps.
  - The existing v36/v37 narrative in that bullet (the +2 and +1 explanations) is history. Compress it so the bullet doesn't grow without bound, but don't drop the v37 **Migration notes** CHANGELOG check, which is still live.
- **`## Test Commands`, the *Workspace state* bullet (`:217`)**: "exits 0 with warnings by design (an over-budget `phase.md`, a case-drifted `## Doc impact` heading)". Add the advisory lines that now exist, from P21 and P22: `consolidation_owed=`, `stale_docs=` and `oversized_doc_sections=`. This is a merge fact for the same bullet, not a new claim.
- **`## Status`**: add one short "As of **v38–v39**" / "**v44**" sentence or paragraph if needed to anchor the posture change and the baseline. Keep it short.
- **`## Regression Checklist`**: **do not edit.** It is the review's gate section, and no note names it.

Where a note is ambiguous, read `tests/retrofit_smoke.sh` (the Test 0 block and the test headers) or the contract. Never re-derive or re-count; do **not** run the smoke suite. 180 is the reviewed count.

## Steps

1. `python3 scripts/workflow.py doc-new-version --doc qa --summary "P21-P23: core-only tests and the smoke baseline at 180" --source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`, run once. Record the `edit_path` and ignore any split hint.
2. Edit only that `edit_path`. Replace superseded statements; keep the voice and wrap width.
3. `python3 scripts/workflow.py rebuild-docs`
4. `python3 scripts/workflow.py validate` must exit 0. The existing advisories are expected, and no new qa section may cross 10,240 B.
5. Write `result.md`, **verdict block first**. Then add a table of the nine notes with their landing sections, and the before/after byte size.
6. Edit `phase.md` under its budget:
   - Remove the S3-only note, which this slice consumes.
   - Rewrite `## Now` as the handoff to S4.
   - Add no `## Doc impact` line.

## Out of scope

- Splitting sections.
- `## Regression Checklist`.
- Running the smoke suite.
- Any other doc, README, code or machinery.
- `docs-consolidated`.

The executor tier is `slice-executor-mid` (`docs / low`). If this turns out to need anything beyond the one `edit_path`, return `escalate` with the findings.
