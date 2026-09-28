# Plan — P24.REVIEW (review)

## Context

P24 is the operator's docs phase. Its objective: consolidate the `## Doc impact` notes from P21–P23 into new versions of architecture, decisions, operations and qa; bring README.md and README.en.md in line with the same changes; and record `docs-consolidated` for P21, P22 and P23. Read `works/phases/active/P24/intent.md` (confirmed intent: **both** READMEs) and `phase.md` (`## Decisions`, `## Now`).

All five middle slices are `done` and committed:
- S1: architecture v0008
- S2: operations v0035
- S3: qa v0010
- S4: decisions v0042, plus the orchestrator's `docs-consolidated P21/P22/P23` in S4's commit
- S5: README.md + README.en.md, direct edits

**The acceptance gate is waived** ("docs phase: new versions of four durable docs plus README edits; no running product surface changes"). So there is no gate stage, no walkthrough and no running-product check. Return `walkthrough: n/a (gate waived)`.

**The boundary**, from `python3 scripts/workflow.py phase-scope P24`: range `d80e9a0..628270d`, product files = `README.en.md` and `README.md`. `works/` and `docs/` are excluded from the product list, but the four doc versions are this phase's substance and **are** reviewed below. None of the six `## Regression Checklist` lines (installer fresh install, acceptance-gate refusal, Test 0 invariants, `## Slices` rendering, marker-less notebook, `--kind research`) is fed by a README or a doc version, so **no checklist line is inside the boundary**. Record that by count, and do not run the smoke suite. The phase touched no machinery; `python3 installer/build.py --check` is a cheap confirmation of that.

## Validate (all slices together)

1. `python3 scripts/workflow.py validate` exits 0. Only the pre-existing `oversized_doc_sections=7` advisory remains; no `consolidation_owed=` and no `stale_docs=`.
2. `python3 scripts/workflow.py docs-debt` prints `docs_debt=none`. `python3 scripts/workflow.py docs` shows no STALE flag, and each of the four docs' latest version has `source=P21.REVIEW, P22.REVIEW, P23.REVIEW` and a commit sha.
3. `docs/current/<doc>.md` equals its latest version file: run `python3 scripts/workflow.py rebuild-docs` and check that `git status --short docs/` stays clean. **No older `docs/versions/` file was modified**: `git diff --name-status d80e9a0..HEAD -- docs/versions` shows only four `A` lines.
4. `python3 installer/build.py --check` passes. No machinery changed: `git diff --stat d80e9a0..HEAD -- scripts .claude installer works/templates CLAUDE.md` is empty.
5. `phase.json` for P21, P22 and P23 carries `"consolidation": "done"`.

## Judge against the objective

- **Coverage.** For each owing phase, read its `## Doc impact` in `works/phases/active/P2{1,2,3}/phase.md`, then check every doc-bearing note (27; the two `Verified at …` stamps carry no content) against the landing tables in `slices/P24.S{1,2,3,4}/result.md`. **Spot-check each claim in the doc itself.** Grep or offset-read the section named, and never pass on the tables alone. Pick at least two notes per doc, including the ones most likely to be missed:
  - architecture: the top-level `consolidation` field, and the `commit` field
  - operations: every former "review consolidates" passage now states the v38 rule (`grep -n consolidat docs/current/operations.md`), and the 400 KB cap replaced the 200-line / 16 KB budget
  - qa: 180 PASS / 0 FAIL, Tests 0–12, 38 contract positives, and the core-only posture
  - decisions: v44 / v39 / v38 entries in newest-first order, the v35 budget clause marked superseded, the `## Superseded Decisions` bullets, and a `## Status` count matching the `### ` headings

  A note that didn't land, or landed wrong, is a finding.
- **Merge, not stack.** No doc states two contradictory current rules: two budgets, two baselines, or both "the review consolidates" and "a docs phase consolidates" as current. Pre-v38 wording is fine only when it is framed as history.
- **READMEs.**
  - Check both READMEs against operations v0035's *Durable-doc consolidation* section and `CLAUDE.md`.
  - `grep -n consolidat README.md README.en.md`: every hit agrees with v38.
  - The Korean `## 문서 통합: docs phase` says the same thing as the English `### Durable docs: a docs phase you start`, at its own depth.
  - Links and anchors resolve, including `README.en.md#phase-worktrees-on-request`, `#contributing` and `#durable-docs-a-docs-phase-you-start`.
  - S5's unplanned edit to the `archive-phase` / `rotate-backlog` rows is correct against the engine (an owing phase stays active).
- **Scope.**
  - No section was split.
  - No `## Doc impact` note was added by P24; the notebook keeps only the "(none …)" line.
  - No machinery changed.
- **Notebook.** `phase.md` agrees with every slice's `result.md`, and there are no unrouted `## Operator Questions` (there are none).

## Deferred-job candidates to return (the orchestrator files them; you never run `defer-job`)

These come from S5's `result.md` *Observations* and anything you notice outside the boundary. Give each a title, reason and trigger.
- The `doc-new-version` SKILL example `--source P1.S1` (machinery).
- The READMEs describe tier routing as risk-only and never name `research`.
- The English skill table has no `design-cowork` row.
- `README.en.md` read-order item 1 wording differs from the contract's.

**Merge candidates into one job** where natural (e.g. "README drift outside P21–P23"). Also note, as observations: D17's and D21's triggers ("the next docs phase") fire now, and they stay deferred because they touch machinery. And the `oversized_doc_sections` advisory now tells *this* phase to split: P24 declined by Decision 6. Say whether that deserves a deferred job, for example "split decisions.md's 247 KB Decision Log", with the reason and trigger.

## Return

- The structured verdict block first in `result.md`, containing:
  - `review_verdict: pass | changes_requested | blocked`
  - `doc_versions: none — deferred to a docs phase`. This phase *is* the docs phase: it writes no gate sections because it changed neither `## Regression Checklist` nor `## Operator Runtime`, and its own four versions were cut by S1–S4.
  - `walkthrough: n/a (gate waived)`
  - `explain: not written — run /explain for this phase`
  - the deferred-job list
- On anything short of `pass`, complete validation and judgment first, then return numbered findings and proposed `P24.F<n>` fix slices.
- Edit `phase.md` under budget: rewrite `## Now` as the closing state.

You never commit, never run `review-phase`, `defer-job`, `accept-gate` or any status transition, and never edit a README or doc on a review. Findings go in the verdict, never into silent fixes.
