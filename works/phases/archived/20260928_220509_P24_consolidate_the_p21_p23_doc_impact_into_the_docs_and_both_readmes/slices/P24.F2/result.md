# Result — P24.F2 (docs): correct the parallel consolidation field in operations

## Verdict

- **status:** done
- **summary:** Cut operations v0036 from v0035 and, in the returned `edit_path` only, corrected the two passages that called the parallel `execution.consolidation` field a pre-v38-only fallback — *The debt* (`## Durable-doc consolidation …`) and the archiving bullet in *Phase worktrees* — to match F1's corrected architecture facts: `parallel-start` also stamps the in-block field at the stamp (before any review), every write mirrors it via `set_phase_consolidation()`, and `phase_consolidation()` reads the top-level key first then falls back to the in-block field for both a stamped-but-unreviewed parallel phase and v24–v37 files alike. Also added the "only when `## Doc impact` has real notes" condition to the review-stamp sentence in *The debt*. `rebuild-docs` + `validate` both clean.
- **files_changed:**
  - `docs/versions/operations/v0036_p24_fix_the_parallel_execution_block_still_carries_and_mirrors_the_consolidation_debt.md` (via `doc-new-version` + edits, per the docs-slice carve-out)
  - `docs/current/operations.md`, `docs/index.json` (via `rebuild-docs`, regenerated only)
  - `works/phases/active/P24/phase.md` (`## Notes for later slices` — removed the consumed P24.REVIEW note; `## Now` — rewritten as the handoff to the re-review)
- **validation:**
  - `python3 scripts/workflow.py doc-new-version --doc operations --summary "P24 fix: the parallel execution block still carries and mirrors the consolidation debt" --source P24.REVIEW` — created `v0036`, `edit_path=docs/versions/operations/v0036_p24_fix_the_parallel_execution_block_still_carries_and_mirrors_the_consolidation_debt.md`. Run exactly once. The pre-edit note printed `oversized_doc_sections=3` for operations alone (visual-design runbook, phase-worktrees, `## Status`) — the split hint was ignored per plan/out-of-scope.
  - `python3 scripts/workflow.py rebuild-docs` — `rebuilt docs/current from latest versions`.
  - `python3 scripts/workflow.py validate` — exit 0, `Workflow validation passed.` Only warning: `oversized_doc_sections=7` (same 7 pre-existing sections as at REVIEW and at F1: decisions `## Decision Log`/`## Superseded Decisions`/`## Status`, operations visual-design runbook/phase-worktrees/`## Status`, qa verification doctrine — the docs-phase section, `## Durable-doc consolidation …`, is not among them). No `stale_docs=`, no `consolidation_owed=`.
  - Byte check (scratchpad Python, H2-span scan of the edited version file): `## Durable-doc consolidation — a docs phase the operator creates (since v38)` spans lines 775–832, **4,364 B**, well under the 10,240 B warn threshold.
  - `grep -n "fallback\|execution.consolidation\|review stamps" <edit_path>` — 8 hits total; the two facts-bearing ones (`:782` *The debt*, `:1044` the archiving bullet) now state the corrected facts, and the other six (`:388`, `:526`, `:741`, `:750`, `:904`, plus the unrelated "picking the option closest to the designed intent" hit) are about unrelated topics (offline API fallback, the instrument's fallback browser) and needed no change.
  - *Seven commands* table (`:994–1002`): `parallel-start` and `parallel-consolidated` rows are silent about the `consolidation` field's read/write mechanics — no contradiction, left unchanged per plan step 3.
  - `git diff docs/current/operations.md` inspected directly: exactly the two intended hunks changed (frontmatter version/commit/source/summary/previous, plus *The debt* and the archiving bullet), nothing else in the 126 KB file touched.
  - `python3 scripts/workflow.py docs` — operations shows `latest=v0036_…`, no STALE flag on any doc.
- **deviations:** none. All three "What to change" items done as specified:
  1. *The debt* (`:782–786` at planning, `:782–790` after edit): review-stamp sentence gained the "only when `## Doc impact` has real notes" condition; the parenthetical rewritten to the engine's truth (parallel-start stamps in-block at the stamp; every write mirrors it; `phase_consolidation()` reads top-level first then in-block fallback, covering both a stamped-but-unreviewed parallel phase and v24–v37 files, no migration).
  2. *Phase worktrees* archiving bullet (`:1035–1041` at planning, `:1040–1047` after edit): same correction, rest of the bullet (the gating behavior, `parallel-teardown`'s warn-only stance) kept.
  3. `grep -n "fallback\|execution.consolidation\|review stamps"`: every hit checked, all agree with the facts; *Seven commands* table rows checked and left alone (silent, not contradictory).
- **doc_impact:** none — this slice only corrects an already-owed doc-version wording error (`P24.REVIEW` Finding 1, operations half); it adds no new durable-truth change beyond what P21–P23 already recorded and paid, matching F1's precedent.

## Detail

**Passage 1 — *The debt* (`## Durable-doc consolidation — a docs phase the operator creates (since v38)`).**
Old gist: "a passing review stamps a top-level `consolidation: pending` field … (`phase_consolidation()` is the single reader every command shares; a v24–v37 phase's copy inside its `execution` block is read only as a fallback, never migrated)." Wrong at v44: every new parallel phase gets the in-block field too, stamped before any review.
New gist: same opening sentence plus "when the phase's `## Doc impact` list has real notes"; the parenthetical replaced with four sentences: `parallel-start` stamps `"pending"` inside the parallel block at the stamp, before any review, so a parallel phase owes from its stamp; every write goes through `set_phase_consolidation()`, which mirrors the top-level key into that block; `phase_consolidation()` reads the top-level key first, then falls back to the in-block field, covering a stamped-but-unreviewed parallel phase and v24–v37 files alike, nothing migrated. The closing sentence (an owing phase validates and runs to completion, stays in `active/`, `archive-phase`/`archive-all`/`rotate-backlog` behavior) kept verbatim.

**Passage 2 — the archiving bullet (`## Phase worktrees` → *Archiving and teardown*).**
Old gist: "archiving is gated … since v38 the debt is a top-level field … every owing phase reads it, and the v24–v37 `execution.consolidation` copy is read only as a fallback for phases stamped before v38, never migrated." Same wrong-at-v44 claim.
New gist: kept the gating sentence and the "since v38, top-level field, single source of truth" sentence verbatim; replaced the fallback clause with: `parallel-start` stamps the in-block field at the stamp, before any review, and every write mirrors it there too; `phase_consolidation()` reads the top-level key first and falls back to that in-block field, covering a stamped-but-unreviewed parallel phase and v24–v37 files alike, nothing migrated. Kept the closing `parallel-teardown` warn-only sentence verbatim.

Everything else in operations.md (the *Seven commands* table, the rest of *Phase worktrees*, *Durable-doc consolidation*'s *Surfacing*/*Staleness*/other subsections, and every default-stream passage) was left untouched — already correct and out of the plan's scope.

**`phase.md`:** removed the `## Notes for later slices` entry tagged `(from P24.REVIEW, for P24.F1 / P24.F2)` — both consumers (F1, F2) are now done, so the note is fully consumed; its detail lives in this file and in `slices/P24.F1/result.md`. Rewrote `## Now` to record both fixes done, point at the re-review as next, and note D23–D26 are already filed (no action needed here). Added no `## Doc impact` line, per plan step 6.
