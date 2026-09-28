# Plan — P24.F2 (docs): correct the parallel consolidation field in operations

## Context

The P24 review returned `changes_requested` with one finding (see `slices/P24.REVIEW/result.md` *Finding 1*, and the REVIEW note in `phase.md` `## Notes for later slices`). F1 fixed architecture (v0009). Operations v0035, cut by S2, carries the same error: it says the parallel `execution.consolidation` field is read **only as a fallback for phases stamped before v38**. That is wrong at v44:

- `parallel_start` writes `"consolidation": "pending"` into every new parallel `execution` block (`scripts/workflow.py:1900`). So a parallel phase owes the debt from its stamp, before any review.
- `set_phase_consolidation()` (`:705`–`:711`) writes the top-level key **and mirrors it** into a parallel block.
- `phase_consolidation()` reads the top-level key first and then the in-block field. For a parallel phase, a missing top-level key does not mean nothing is owed.
- `review-phase --verdict pass` stamps top-level `pending` **only when `## Doc impact` has real notes** (`:1565`–`:1570`). A `(none …)` placeholder stamps nothing.
- P21 decided this (`works/phases/active/P21/phase.md:35`), and `.claude/skills/parallel-phase/SKILL.md:116` agrees.

For consistent wording, read F1's corrected paragraph in `docs/current/architecture.md` (grep `consolidation\` debt is top-level`) and match its facts, but not its length. Everything operations says about **default-stream** phases is correct; leave it.

This is a `docs` slice in P24, an operator-created docs phase, on the default stream. Under the docs-slice carve-out you may run `doc-new-version` / `rebuild-docs` and edit **only** the returned `edit_path`. You never touch `docs/current` or older versions by hand, never run `docs-consolidated`, and never commit. operations.md is ~126 KB, so **never read it whole**: grep, then do offset reads.

## What to change (line numbers from `docs/current/operations.md` at planning; re-grep in the edit_path)

1. **`## Durable-doc consolidation …` → *The debt* (`:782`–`:786`)**:
   - "A passing review stamps a top-level `consolidation: "pending"` field …" gains the condition: "… when the phase's `## Doc impact` list has real notes".
   - The parenthetical "a v24–v37 phase's copy inside its `execution` block is read only as a fallback, never migrated" becomes the engine's truth:
     - `parallel-start` also stamps `pending` inside the parallel block at the stamp;
     - every write mirrors into that block;
     - `phase_consolidation()` reads the top-level key first and then the in-block field, which covers a stamped-but-unreviewed parallel phase and v24–v37 files alike, with no migration.
2. **`## Phase worktrees` → the archiving bullet (`:1035`–`:1041`)**: "the v24–v37 `execution.consolidation` copy is read only as a fallback for phases stamped before v38, never migrated" gets the same correction. The in-block field is stamped by `parallel-start`, mirrored on every write, and read as the fallback. Keep the rest of the bullet.
3. `grep -n "fallback\|execution.consolidation\|review stamps" <edit_path>`: every hit must agree with the facts above. Also check the *Seven commands* table rows for `parallel-start` / `parallel-consolidated`. If they're silent about the field, leave them; if they contradict it, fix them.

## Steps

1. `python3 scripts/workflow.py doc-new-version --doc operations --summary "P24 fix: the parallel execution block still carries and mirrors the consolidation debt" --source P24.REVIEW`, run once. Record the `edit_path` and ignore the split hint.
2. Edit only that `edit_path`, as above. This is a small correction, not a rewrite.
3. `python3 scripts/workflow.py rebuild-docs`
4. `python3 scripts/workflow.py validate` must exit 0, with only the `oversized_doc_sections=7` advisory: no `stale_docs=` and no `consolidation_owed=`. The docs-phase section must stay under 10,240 B.
5. Write `result.md`, **verdict block first**: each passage changed (old gist → new gist).
6. Edit `phase.md` under budget:
   - Remove the REVIEW note for F1/F2, which is consumed now.
   - Rewrite `## Now` as the handoff to the re-review, noting that D23–D26 are already filed.
   - Add no `## Doc impact` line.

## Out of scope

- architecture (F1 did it).
- Any other doc, README, code or docstring (the docstring is D26).
- `docs-consolidated`.

Executor: `slice-executor-mid` (`docs / low`). If anything beyond the one `edit_path` is needed, return `escalate`.
