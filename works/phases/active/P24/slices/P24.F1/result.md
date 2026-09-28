# Result — P24.F1 (docs): correct the parallel consolidation field in architecture

## Verdict

- **status:** done
- **summary:** Cut architecture v0009 from v0008 and, in the returned `edit_path` only, put `"consolidation": "pending"` back into the parallel `execution` JSON example and rewrote the "consolidation debt is top-level" paragraph to state that `parallel-start` stamps the in-block field at the stamp (before any review), every write mirrors it via `set_phase_consolidation()`, `phase_consolidation()` reads top-level first then falls back to the in-block field, and a passing review stamps top-level `"pending"` only when `## Doc impact` has real notes. Verified against `scripts/workflow.py` (`phase_consolidation` / `set_phase_consolidation` / `parallel_start` / `review_phase`'s pass branch) before writing, then `rebuild-docs` + `validate` both clean.
- **files_changed:**
  - `docs/versions/architecture/v0009_p24_fix_the_parallel_execution_block_still_carries_and_mirrors_the_consolidation_debt.md` (via `doc-new-version` + edits, per the docs-slice carve-out)
  - `docs/current/architecture.md`, `docs/index.json` (via `rebuild-docs`, regenerated only)
  - `works/phases/active/P24/phase.md` (`## Now`)
- **validation:**
  - `python3 scripts/workflow.py doc-new-version --doc architecture --summary "P24 fix: the parallel execution block still carries and mirrors the consolidation debt" --source P24.REVIEW` — created `v0009`, `edit_path=docs/versions/architecture/v0009_p24_fix_the_parallel_execution_block_still_carries_and_mirrors_the_consolidation_debt.md`. Run exactly once.
  - `python3 scripts/workflow.py rebuild-docs` — `rebuilt docs/current from latest versions`.
  - `python3 scripts/workflow.py validate` — exit 0, `Workflow validation passed.` The only warning is `oversized_doc_sections=7` (the same 7 pre-existing sections as at REVIEW: decisions `## Decision Log`/`## Superseded Decisions`/`## Status`, operations' visual-design runbook/phase-worktrees/`## Status`, qa's verification doctrine — none of them architecture's `## Execution Streams`). No `stale_docs=`, no `consolidation_owed=`.
  - Byte check (scratchpad Python, `re.search` for the H2 span): `## Execution Streams …` in `docs/current/architecture.md` is **10,182 B**, under the 10,240 B warn threshold (was 9,689 B at v0008; +493 B from the restored `"consolidation": "pending"` line and the longer, fact-correct paragraph). Confirmed via `oversized_doc_sections()` directly: architecture is absent from its 7-entry return list.
  - `grep -n "consolidation" <edit_path>` — 15 hits, each re-read against the plan's facts (frontmatter `summary`/`previous`, the `## Status` line 25–26, the JSON example line 119, the `mode` bullet line 131, the rewritten paragraph lines 148–160, the *Doc versioning stays serial* paragraph lines 219–220, and one unrelated hit in the *Operator acceptance gate* history section line 297 that already reads correctly and needed no change).
  - Re-confirmed the underlying engine facts by reading `scripts/workflow.py:671–712` (`phase_consolidation`, `set_phase_consolidation`) and `:1899` (`parallel_start`'s `"consolidation": "pending"` write) and `:1565–1570` (`review_phase`'s pass branch, gated on `phase_doc_impact_notes(pdir)` being non-empty) before writing the correction — matches the plan's citations exactly.
- **deviations:** none. All five "What to change" items done as specified:
  1. JSON example: `"consolidation": "pending"` restored as the block's last key.
  2. `mode` bullet (now `:126–130`): re-read, still true of the pinned-block case; left unchanged.
  3. The top-level-debt paragraph (now `:148–160`): rewritten to the engine's truth per every bullet in the plan, including deleting the "only for pre-v38 `phase.json` files … which is why the JSON example above no longer shows it" clause (now false, since the example shows it again).
  4. `## Status` (`:25–26`) and *Doc versioning stays serial* (`:219–220`): re-read; neither claims "a passing review stamps" without the notes condition nor implies the in-block field is legacy-only, so both left as-is.
  5. `grep -n "consolidation" <edit_path>`: every hit agrees with the facts above (detail in *Validation* row 5).
- **doc_impact:** none — this slice only corrects an already-owed doc-version wording error (`P24.REVIEW` Finding 1); it adds no new durable-truth change beyond what P21–P23 already recorded and paid.

## Detail

**Passage 1 — JSON example (`:114–120`).** Old: four-key block (`mode`, `branch`, `worktree`) with no `consolidation` key, matching v0008's (wrong) claim that the field is no longer shown. New: same three keys plus `"consolidation": "pending"` as the last key, matching what `parallel_start` (`scripts/workflow.py:1899`) actually writes.

**Passage 2 — the top-level-debt paragraph (`:147–160` old → `:148–160` new, 9 lines → 13 lines).** Old gist: "the debt is top-level, not part of this block (since v38)… `phase_consolidation()` reads the top-level key first and falls back to the identically-named field inside a parallel `execution` block **only for pre-v38 `phase.json` files that still carry it there** — which is why the JSON example above no longer shows it." That is wrong at v44: every new parallel phase gets the in-block field too. New gist: "the debt is top-level, **and the parallel block still mirrors it**." Kept the top-level-field description and the archiving sentence, and added: (a) a passing review stamps top-level `"pending"` only when `## Doc impact` has real notes (a `- (none ...)` placeholder stamps nothing); (b) `parallel-start` also stamps `"pending"` inside the parallel `execution` block at the stamp, before any review, so a parallel phase owes from its stamp; (c) every write goes through `set_phase_consolidation()`, which sets the top-level key and mirrors it into a parallel block; (d) `phase_consolidation()` is the single reader, top-level first then in-block fallback, which covers both a stamped-but-not-yet-reviewed parallel phase and v24–v37 files, and nothing is migrated. Deleted the false "only for pre-v38 files … no longer shows it" clause.

Everything else in the section (the schema intro, `branch`/`worktree` bullets, the two accessor paragraph, the stamp-commit/nested-worktree/stream-detection/scoping paragraphs, *Doc versioning stays serial*) was left untouched — it was already correct and out of the plan's scope.

`phase.md`: left the `## Notes for later slices` REVIEW entry in place (F2 still needs it, per plan step 6). Rewrote `## Now` as the handoff to F2; added no `## Doc impact` line.
