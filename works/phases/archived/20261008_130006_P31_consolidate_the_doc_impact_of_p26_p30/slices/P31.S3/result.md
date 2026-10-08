- status: done
- tier: mid
- summary: Cut qa v0013 folding the 13 P26-P30 qa notes. The smoke baseline is now 239 PASS / 0 FAIL as of v51 (the 180-at-v44 statements are replaced, with one chronological "how it rose" clause), Test Commands describes Tests 0-16 (the design contract, the nested engine and installs, P30's rotate asserts, the Test 7 utf-8 cookie), "fresh-install" means the `--at-root` path, and Known Fragile Areas gains the installer-under-Python-3.9 entry. The eight Regression Checklist lines are byte-identical.
- version: `docs/versions/qa/v0013_p26-p30_smoke_baseline_239_design_and_nested-install_pins_fragile_installer_tokenizer.md` (previous v0012; `docs/current/qa.md` rebuilt)
- validation:
  - `python3 scripts/workflow.py docs-debt` (read in full; 13 `qa.md` lines, matching *Cut*): pass
  - `python3 scripts/workflow.py doc-new-version --doc qa --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 smoke baseline 239, design and nested-install pins, fragile installer tokenizer"`: pass; its only warning was the oversized-section hint (the Verification doctrine H2, 12,853 B), ignored per the phase's *No restructuring* decision
  - `python3 scripts/workflow.py rebuild-docs`: pass
  - `python3 scripts/workflow.py validate`: pass (`Workflow validation passed.`; the expected `consolidation_owed` / `stale_docs` / `oversized_doc_sections` warnings only; the oversized count is 8, as before this slice)
  - diff of v0012 vs v0013: `## Regression Checklist` through `## Known Fragile Areas` (the checklist) and `## Verification doctrine` are byte-identical; `docs/current/qa.md` still carries 14 `- [ ]` lines (6 earlier + the 8 from P29.REVIEW and P30.REVIEW)
  - not run: `bash tests/retrofit_smoke.sh` (no code changed; the 239 figure is the owed notes' count, not re-derived)
- deviations: none from `plan.md`. One plan step had nothing to act on: see *Operator Runtime sentence* below.
- doc_impact: none (a docs phase leaves no notes)

# P31.S3 result: QA, P26-P30 notes

## Which note landed where

Section names are qa v0013's. *TC* = `## Test Commands`.

| Note | Landed in |
|---|---|
| P26.S1 (192 baseline, +5 in new Test 13; Test 0 pins the contract section against the engine constants) | `## Status` (239, Tests 0-16); TC baseline chain (192 at v47, +5); TC *Test 13* bullet; TC Test 0 *design pins* bullet |
| P26.S2 (195 baseline: +1 fresh install ships `design-drafter` with `Skill` and no `DesignSync`, +1 `executor-mode economy`, +1 dual-apply) | TC baseline chain (195 at v47, the three +1s). The notes name no test number for these three, so none is claimed |
| P26.S3 (Test 0's design-cowork pins moved to the file loop; drafter, `design-close`, literal signoff, "new visual direction", bundle import; frontmatter check) | TC Test 0 *design pins* bullet. Partly superseded by P27, see *Contradictions* |
| P26.S4 (Test 0's pins for the do-* skills, executor bodies, `CLAUDE.md`, create-phase, Test 1 sidecar, banner moved to the drafter loop) | TC Test 0 *design pins* bullet (same bullet; partly superseded by P27) |
| P26.F1 (Test 13's first assertion fails `//` and `http://` by name and passes the allowed forms; Test 0 pins the licence and revision handoff) | TC *Test 13* bullet; TC Test 0 *drafter and the self-contained rule* bullet |
| P26.F2 (Test 0 asserts the Self-contained bullet and drafter §Do 2 name every `DESIGN_ALLOWED_REFS` prefix) | TC Test 0 *drafter and the self-contained rule* bullet |
| P27.S3 (design pins are choice pins; Test 13's `claude-design/` and `design-migrate` probes join the regression set) | TC Test 0 *design pins* bullet (choice pins); TC *Test 13* bullet ("Added at v48") |
| P27.REVIEW (203 at v48: +6, +1 Test 7 cookie, +1 Test 13 pre-v47 root; Test 0's driver loop names `feedback.md` before `DesignSync`, no new PASS line; the fragile-area line) | TC baseline chain (203 at v48); TC *Test 7* bullet; TC Test 0 *design pins* bullet (the `feedback.md` order); `## Known Fragile Areas` |
| P28.S1 (Test 14 "nested engine"; at-root invariant = Tests 0-13 unchanged) | TC *Test 14* bullet; the lead of the smoke bullet (at-root invariant wording); baseline chain (226) |
| P28.S2 (Test 15 "nested install"; Test 14 now uses `.agentic-nested.json`) | TC *Test 14* bullet (marker name); TC *Test 15* bullet; baseline chain |
| P28.F1 (three Test 15 asserts; Tests 0-15 = 226) | TC *Test 15* bullet (the ignore-guarantee asserts); baseline chain (226 at v49, F1's +3) |
| P29.S1 (Test 16, 9 asserts; Tests 5, 12, 14 pass `--at-root`, so "fresh-install" means the `--at-root` path; 235) | `## Test Commands` smoke-bullet lead (the "fresh-install" sentence); TC *Test 16* bullet; baseline chain (235 at v50) |
| P30.S1 (4 rotate asserts beside the `docs-debt` fixture; 239, was 235) | TC *P30's rotate asserts* bullet; `## Status`; baseline chain (239 at v51) |

All 13 notes landed. No note landed in `## Regression Checklist`: its eight lines are the P29.REVIEW and P30.REVIEW appends from v0011 and v0012, kept unchanged as the plan asked.

## Edits beyond the notes

None of substance. Three small structural edits, each to carry a note's content:

- The old single parenthetical in the smoke bullet ("Test 9 covers ...; Test 10 ...; Test 11 ...; Test 12 ...") became a sub-bullet list so that Tests 7, 13, 14, 15 and 16 and the P30 asserts have a place. The Test 9-12 text itself is unchanged.
- The old baseline paragraph's pre-v44 history was reordered chronologically (it listed 152, 158, 140, 139, 137, 123 out of order) and kept as the first half of the one "how it rose" clause, so the old 180 statement is replaced by the 239 chain rather than stacked beside it.
- `## Status` v39 paragraph: the baseline sentence now says 239 as of v51 and adds one sentence saying the script runs Tests 0-16 (a pointer, not a new fact beyond the notes).

## Contradictions and observations

1. **P26.S3 and P26.S4 notes versus P27.S2/S3 (resolved by the supersession chain, P27 wins).** The P26.S3 note says Test 0 pins a design-cowork frontmatter with **no `DesignSync` in `allowed-tools`** and retires the DesignSync/Claude Design phrases as negatives. P27 brought them back for the `claude-design` tool, but the P27 qa note does not say what happened to those pins. I read `tests/retrofit_smoke.sh` only to place this (lines 107-111, 168-183, 310-326, 366-372, 628-645): the `design-cowork` frontmatter now asserts `"DesignSync" in allowed and "Agent" in allowed`; `DesignSync` and `Claude Design` are presence pins beside `claude-design`; what stays a negative is `_ds_manifest`, `never dispatched`, `one dispatched span`, and the push phrases; `create-phase`, the installer banner and `design-drafter` stay `DesignSync`-free. qa v0013 states that merged truth in the *design pins* bullet. The notes alone could not have produced it, so a reviewer who diffs only against the notes will see it as an addition. Nothing needs the operator.
2. **No "this repository has no runtime manifest" sentence exists in qa.** The plan's last step assumed one. qa v0012 has none: the nearest statements are "no verified Aside run has been made from an executor in this repository" and "This repository ships machinery rather than a browsable product" (the Regression Checklist intro), and both are still true beside operations v0037's `## Operator Runtime` (CLI, no browser, Aside n/a). I changed nothing there rather than invent a pointer. If the operator wants qa to name that section for this repo, it is a one-clause addition in a later docs phase.
3. **"230 assertions" in the doctrine.** `## Status` (v32 paragraph) and *Evidence stays terse* use "230 assertions" as an illustrative size for a conformance suite to reject. The smoke suite is now 239 PASS. The figure is rhetorical, unrelated to the smoke count, and was left alone.
4. **Test 0's pin counts are stale in kind.** "38 positives, 19 negatives" is as of P23.S4. P26-P27 re-pointed and added pins in Test 0 but no note recounts them, so the doc says "counts as of P23.S4; P26-P27 re-pointed and added pins without recounting them" rather than inventing numbers.
5. **Unitemized steps in the baseline chain.** 180 to 187 (v45-v46 work, per the plan's wording) and the v40-v43 rise to 180 have no owed note. P28's Tests 14 and 15 have no per-test count in the notes: only 226 total and F1's +3, so the doc gives "by subtraction 20 across the two" and labels it as subtraction. That subtraction assumes nothing else in Tests 0-13 changed at P28; the notes say Tests 0-13 passed unchanged.
6. **P30's asserts sit in Test 5.** The note says only "beside the `docs-debt` fixture". The smoke script's `rotate_backlog` asserts (lines 895-913) fall inside Test 5, so the doc says "beside Test 5's `docs-debt` fixture". That is a code read to place a note, which the phase allows.

## Section sizes (record only; no restructuring, per the phase)

| Section | v0012 | v0013 |
|---|---|---|
| `## Status` | 3,121 B | 3,248 B |
| `## Verification doctrine` | 12,854 B | 12,854 B (unchanged; over the 10 KB hint) |
| `## Test Commands` | 3,379 B | 9,210 B (under 10 KB) |
| `## Regression Checklist` | 3,557 B | 3,557 B |
| `## Known Fragile Areas` | 34 B | 412 B |
| whole doc | 24,399 B | about 30.7 KB |

`doc-new-version` named only the Verification doctrine section as oversized; it is unchanged and stays a deferred split candidate (D25).

## Notebook

`phase.md`: the S3 note was consumed; a note for S4 and the REVIEW names this version; `## Now` rewritten. No `## Doc impact` or `## Operator Questions` entries.
