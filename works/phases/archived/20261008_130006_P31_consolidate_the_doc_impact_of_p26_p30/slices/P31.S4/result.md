- status: done
- tier: mid
- summary: Cut decisions v0043 folding the 12 P26-P30 decisions notes: five new Decision Log entries (P30, P29, P28, P27, P26, newest first), two new Superseded Decisions bullets (P29 over P28's opt-in install default; P26/P27 over the v27/v28 Claude Design loop) and a Status lead brought to v51 (fifty decisions).
- version: `docs/versions/decisions/v0043_p26-p30_repo-file_design_contract_per-phase_design_tool_nested_install_default_rotate_docs-phase_proposal.md` (previous v0042; `docs/current/decisions.md` rebuilt)
- validation:
  - `python3 scripts/workflow.py docs-debt` (read in full): pass. It printed 12 `decisions.md` notes, matching *Cut*: P26 x5 (S3, S4, the REVIEW-added schema-1 line, F1, F2), P27 x2 (S2, S3), P28 x2 (S3, F1), P29 x1 (S1/S2), P30 x2 (S1, S2).
  - `python3 scripts/workflow.py doc-new-version --doc decisions --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 repo-file design contract, per-phase design tool, nested install default, rotate docs-phase proposal"`: pass. Its only note was the oversized-section hint (Decision Log, Superseded Decisions, Status), ignored on purpose (D25 stays deferred).
  - `python3 scripts/workflow.py rebuild-docs`: pass (run twice, after the last wording fixes).
  - `python3 scripts/workflow.py validate`: pass (`Workflow validation passed.`; the expected `consolidation_owed`, `stale_docs` and `oversized_doc_sections=8` warnings only, the oversized count unchanged from before this slice).
  - Read-back checks: `grep -c '^### '` on the new version gives 50 entries (45 before, plus 5), matching "fifty decisions" in `## Status`; no `??` placeholder text remains (one fixed during the slice).
  - not run: `bash tests/retrofit_smoke.sh` (no code changed; every figure cited is from the notes, and from qa v0013 for the smoke baselines).
- deviations: none from `plan.md`. Two additions the plan did not name, both inside the notes' content: the P27 entry carries one sentence on P27.F3's utf-8 cookie fix (a P27 decision the operator ordered, cited to qa v0013 `## Known Fragile Areas`), and the Superseded bullet for the design loop also names the Claude Design mechanics inside the v34 and v42 entries, since those entries describe the same `DesignSync` read-back and pane checks.
- doc_impact: none (a docs phase leaves no notes)

# P31.S4 result: Decisions, P26-P30 notes

## Note landings

Section names are decisions v0043's. Every entry is in `## Decision Log` unless stated.

| Note | Landed in |
|---|---|
| P26.S3 (why the loop moved off Claude Design + `DesignSync`: P25, the claude.ai login, `ocx claude`, no `DesignSync` in a subagent; repo files plus a dedicated drafter; the `frontend-design` ban lifted for the drafter on new-direction rounds only) | P26 entry: Status, Context, Decision bullets *The loop runs on repo files* and *The `frontend-design` licence*; Alternatives; the P26 Superseded bullet |
| P26.S4 (the hard-rule reword, operator-confirmed at intake; what it leaves untouched) | P26 entry, Decision bullet *The hard rule is reworded* |
| P26.REVIEW (schema-1 choices from S1/S2: fixed root, one project per repo, close-time snapshots, derived `supersedes`, registry outside the repo; the drafter follows the high tier) | P26 entry, Decision bullets *The schema-1 contract choices, and why* and *`design-drafter` follows the high tier*; Alternatives (own `design/` tree, git refs, a third tier) |
| P26.F1 (`design-check` follows the contract's reference text strictly; `#` kept as "a reading") | P26 entry, Decision bullet *`design-check` follows the contract's reference text strictly* (the F1 half, with the `#` reading named as superseded by F2) |
| P26.F2 (`#` fragments named in the contract text; replaces F1's `#` half; the engine unchanged; Test 0 pins against `DESIGN_ALLOWED_REFS`) | Same bullet (the final rule is stated once); Alternatives (*Forbid `#` in cards*) |
| P27.S2 (under claude-design: one push per round, superseding rounds in the same slice with `feedback.md` and a root `SIGNOFF.md`, a missing `DesignSync` stops `pending` with no fallback) | P27 entry, Decision bullet *Under `claude-design`*; Alternatives (push per slice) |
| P27.S3 (the per-phase choice, absent reads as `drafter`; the `claude-design/` record outside schema 1, skipped by `design-*` and design-deck; where the loops differ P26's governance wins) | P27 entry, Decision bullets *The choice is per phase*, *One skill, one governance* and *The `claude-design/` record sits outside schema 1*; the P26/P27 Superseded bullet |
| P28.S3 (nested mode gated on the marker; the contract is `CLAUDE.workspace.md`, imported from `CLAUDE.local.md`; paths rewritten once with a post-check; `wf-<name>` clashes; the convention asked after install; parallel off; the rules in the `CLAUDE.local.md` block; the acceptance gate waived) | P28 entry, Decision bullets (all eight) and Alternatives. The install-time rewrite and the clash map are written out in full there, as architecture v0010 and operations v0037 point to decisions for them |
| P28.F1 (the ignore guarantee: per-skill `.gitignore` of `*`, a preflight that refuses with no override, a post-write status assert; v49 amended in place) | P28 entry, Decision bullet *The ignore guarantee (P28.F1)*; Status line (amended in place); Alternatives (`info/exclude` alone, an override flag) |
| P29.S1/S2 (nested by default with `git init` and the convention confirmed; `--at-root` / `--into-existing`; `--update` detects the layout; `--nested` a no-op; no migration; a new dir inside another repo refuses) | P29 entry, all Decision bullets; the P28/P29 Superseded bullet; Status lead |
| P30.S1 (`consolidates` as the explicit marker; rotate proposes rather than creates; a finished docs phase covers nothing; an unmerged parallel phase is never debt-only) | P30 entry, Decision bullets 1-3; Alternatives |
| P30.S2 (the rotate skill writes `intent.md` itself, so `allowed-tools` gain `Read`/`Edit`/`Write` while `disable-model-invocation` stays; the create-phase gate unchanged) | P30 entry, Decision bullets 2 and 4 |

All 12 notes landed. `## Status` now opens "Current in v51: fifty decisions" with one sentence per phase, ending in the old v44 lead (reworded to "The decision before those ships as workspace v44") so the rest of the rollup is unchanged. `## Superseded Decisions` gained two bullets, at the top as that section orders them (newest superseding decision first): P29 over P28's opt-in default, then P26/P27 over the Claude Design + `DesignSync` loop. Older entries' text is untouched.

## Version cites

Each entry names architecture v0010, operations v0037 and qa v0013 for the runbook, install modes, engine helpers, smoke baselines and Test coverage instead of restating them: P26 (v0010 `## Design Record and Design Subagent`, v0037 `## Visual-design runbook`, qa Tests 0 and 13, 187 to 195), P27 (same, plus the v48 upgrade steps, 195 to 203), P28 (v0010 `## Nested Install`, v0037 `## Nested personal install`, qa Tests 14 and 15), P29 (the same two, qa's "fresh-install means `--at-root`" and Test 16), P30 (v0010 `## Docs Phase Marker and the Rotate Proposal`, v0037, qa's four rotate asserts, baseline 239). S2's note offered to let a decisions entry about "no browser, so real-browser claims do not apply" point at operations' `## Operator Runtime`. No decisions note asked for such an entry, so none was written and `## Operator Runtime` is not cited.

## Contradictions and observations

1. **P28.S2 vs P28.S3 on the rewrite's coverage.** S2's note says the rewrite is not applied to `workflow/executors.toml` or `workflow/docs/README.md`; S3's note says both now go through it. The P28 entry states S3's later text, and keeps "the doc seeds stay root-relative", which both agree on.
2. **P29's `## Doc impact` says "any run on a nested install's `workflow/` refuses"; S2's correction says a bare install or `--update` only** (`--at-root` and `--into-existing` are not covered). The P29 entry and the Superseded bullet use the narrower, later statement.
3. **P26.F1 vs P26.F2 on `#`.** Resolved as the plan directed: the entry states the final rule once, and names F1's "reading" as superseded by F2.
4. **The P29 operator question** (a new dir inside another repo's work tree: refuse or auto-init) was routed at P29.REVIEW and the gate was cleared with "D1: no answer given, current refusal stands" (from `phase.json`'s `acceptance.note`). The P29 entry records the refusal as standing and auto-init as a follow-up. This is already routed, so no entry was added to `## Operator Questions`.
5. **Gap, not fixed: decisions has no entry for v45 or v46** (`executor-mode` and the mid-default routing), since no owed note named them. `## Status` therefore jumps v44 to v47, and the v23 "Drop the `low` executor tier" entry's mid-tier routing text is not marked as superseded by v46. Same shape as operations' observation 1 in S2's `result.md`. A deferred-job candidate for the review to list (title: bring decisions' and operations' executor-tier text and Status up to v45/v46; reason: no docs phase had a note for them; trigger: the next docs phase).
6. **The P28 entry's `Date` is the release date, not the P28 creation timestamp.** All three of P28, P29 and P30 shipped on 2026-10-07 (CHANGELOG v49, v50, v51).

## Section sizes (record only; the Decision Log stays unsplit, D25 is deferred)

| Section | v0042 | v0043 |
|---|---|---|
| `## Status` | 16,678 B | 19,244 B |
| `## Decision Log` | 246,694 B | 274,598 B |
| `## Superseded Decisions` | 19,110 B | 22,227 B |
| whole doc | 283,043 B | 316,678 B |

`doc-new-version` named all three sections as oversized, and `validate` counts 8 oversized sections doc-set wide, as before.

## Dead ends

None. One placeholder (`2026-08-??`) written for the P17 date in the Superseded bullet was caught on read-back and corrected to 2026-08-29 from the entry's own `Date`.
