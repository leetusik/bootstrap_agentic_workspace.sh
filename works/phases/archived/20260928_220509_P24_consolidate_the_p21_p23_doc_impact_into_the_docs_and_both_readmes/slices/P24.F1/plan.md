# Plan — P24.F1 (docs): correct the parallel consolidation field in architecture

## Context

The P24 review returned `changes_requested` with one finding (see `slices/P24.REVIEW/result.md` *Finding 1*, and the REVIEW note in `phase.md` `## Notes for later slices`). Architecture v0008, cut by S1, describes the parallel `execution.consolidation` field as a **pre-v38-only fallback**. That is wrong at v44:

- `parallel_start` writes `"consolidation": "pending"` into every new parallel `execution` block (`scripts/workflow.py:1900`). So a parallel phase owes the debt from its stamp, before any review.
- `set_phase_consolidation()` (`:705`–`:711`) writes the top-level key **and mirrors it** into a parallel block.
- `phase_consolidation()` (`:677`–`:702`) reads the top-level key first. When that key is absent it reads the in-block field, so for a parallel phase a missing top-level key does **not** mean nothing is owed. Pre-v38 files read the same way.
- `review-phase --verdict pass` stamps top-level `pending` **only when the phase's `## Doc impact` has real notes** (`:1565`–`:1570`). A notebook whose list is only a `(none …)` placeholder stamps nothing.
- P21 decided exactly this (`works/phases/active/P21/phase.md:35`: "`execution.consolidation` stays readable and is mirrored on write, so `parallel-*` is unchanged"), and `.claude/skills/parallel-phase/SKILL.md:116` agrees.

Everything v0008 says about **default-stream** phases is correct; leave it.

This is a `docs` slice in P24, an operator-created docs phase, on the default stream. Under the docs-slice carve-out you may run `doc-new-version` / `rebuild-docs` and edit **only** the returned `edit_path`. You never touch `docs/current` or older versions by hand, never run `docs-consolidated`, and never commit.

## What to change (line numbers from `docs/current/architecture.md` at planning; re-grep in the edit_path)

1. **The parallel JSON example (`:115`–`:120`)**: put `"consolidation": "pending"` back as the block's last key, as v0007 had it.
2. **The `mode` bullet (`:127`–`:130`)**: "`validate` skips the branch/worktree/consolidation checks for it" refers to a pinned block. Check that it still reads true, and leave it alone if it does.
3. **The paragraph `**The `consolidation` debt is top-level, not part of this block (since v38).**` (`:147`–`:156`)**: rewrite it to the engine's truth. Keep the heading idea that the debt is a top-level field for every phase, but state all of the following:
   - A passing review stamps top-level `"pending"` **when the phase's `## Doc impact` list has real notes** (a `(none …)` placeholder stamps nothing).
   - `parallel-start` also stamps `"pending"` **inside the parallel `execution` block** at the stamp, before any review. A parallel phase therefore owes from its stamp.
   - Every write goes through `set_phase_consolidation()`, which sets the top-level key and **mirrors** it into a parallel block, so the `parallel-*` commands and `parallel-status` keep reading the field they know.
   - `phase_consolidation()` is the single reader. It takes the top-level key first and falls back to the in-block field. That covers both a parallel phase stamped but not yet reviewed and v24–v37 files, and nothing is migrated.
   - `docs-consolidated <P>` or a merged phase's `parallel-consolidated <P>` records `"done"`.
   - With neither key present, nothing is owed.
   - The archiving sentence (`done` + `pass` + `pending` validates but cannot be archived, for every phase) stays.
   - Delete "only for pre-v38 `phase.json` files that still carry it there — which is why the JSON example above no longer shows it".
4. **`:25`–`:27` (`## Status`) and `:211`–`:216` (*Doc versioning stays serial*)**: re-read them. If either says "a passing review stamps" without the notes condition, or implies the in-block field is legacy-only, fix it in the same terms. Otherwise leave them.
5. `grep -n "consolidation" <edit_path>`: every hit must agree with the facts above.

## Steps

1. `python3 scripts/workflow.py doc-new-version --doc architecture --summary "P24 fix: the parallel execution block still carries and mirrors the consolidation debt" --source P24.REVIEW`, run once. Record the `edit_path`.
2. Edit only that `edit_path`, as above. Keep the doc's voice and wrap width. This is a small correction, not a rewrite.
3. `python3 scripts/workflow.py rebuild-docs`
4. `python3 scripts/workflow.py validate` must exit 0. The only expected advisory is `oversized_doc_sections=7`: no `stale_docs=` and no `consolidation_owed=`. The *Execution Streams* section must stay under 10,240 B; it was 9,689 B at v0008.
5. Write `result.md`, **verdict block first**: each passage changed (old gist → new gist) and the section byte size.
6. Edit `phase.md` under budget:
   - Leave the REVIEW note in place, because F2 still needs it.
   - Rewrite `## Now` as the handoff to F2.
   - Add no `## Doc impact` line.

## Out of scope

- operations.md (that is F2).
- Any other doc, README, code or docstring (the docstring is D26).
- `docs-consolidated`.

Executor: `slice-executor-mid` (`docs / low`). If anything beyond the one `edit_path` is needed, return `escalate`.
