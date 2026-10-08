# Intent — P31

- Captured at: 2026-10-07T16:40:16+09:00
- Origin: operator

## Original Input (verbatim)

> /rotate-backlog

> go

## Confirmed Intent (refined + clarified)

A docs phase that pays the durable-doc consolidation debt of **P26, P27, P28, P29 and P30**. These phases are done with passing reviews and are held out of archiving only by `consolidation: pending`. `/rotate-backlog` proposed the phase after archiving P25; the operator confirmed the name and objective unchanged:

- **Name:** Consolidate the doc impact of P26–P30
- **Objective:** consolidate the '## Doc impact' notes from P26, P27, P28, P29, P30 into new versions of architecture, decisions, operations, qa

The phase was created with `new-phase --consolidates P26,P27,P28,P29,P30`, so `docs-debt` shows those phases as `paid by: P31` and `rotate-backlog` proposes no duplicate.

**Scope, from `python3 scripts/workflow.py docs-debt` at intake:** 5 phases, 52 notes, 4 docs. Re-read `docs-debt` at `DECOMP` as the live worklist.

| Doc | Notes | From |
|---|---|---|
| operations | 20 | P26–P30 |
| qa | 13 | P26–P30 |
| decisions | 12 | P26–P30 |
| architecture | 9 | P26–P30 |

A note can name more than one doc, which is why the per-doc counts sum past 52. Each phase's notes are under its `phase.md` `## Doc impact`.

**What this phase's `DECOMP` will cut** (recorded here, not cut now):

- **One slice per doc, `--kind docs`, rated by the normal rule (`low` → mid).** `doc-new-version` is per doc, and one doc collects notes from several phases, so per-doc keeps each doc to a single new version. Each slice runs, per doc:
  ```sh
  python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <P>.REVIEW
  # edit only the returned edit_path, folding in every note for that doc, then:
  python3 scripts/workflow.py rebuild-docs
  ```
- **Payment, once all of a phase's notes are consolidated:** `python3 scripts/workflow.py docs-consolidated <P>` for each of P26, P27, P28, P29 and P30. None ran in a worktree, so `docs-debt`'s `pay:` lines all say `docs-consolidated`. That is also what unblocks archiving them.
- **The acceptance gate is normally `--waive`d at the `DECOMP` boundary:** a docs phase changes no operator-visible surface.
- **Constraints:**
  - This phase runs on the **default stream**, never in a worktree, because doc versions come from one shared index.
  - It leaves **no `## Doc impact` notes of its own**: it pays others' notes and creates no new durable truth.

## Clarifications Resolved

- Q: Create P31 with the proposed name and objective over P26–P30? — A: "go" (confirmed unchanged, no phase narrowed out).

## Notes

- `docs-debt` flags oversized sections to split at the next consolidation, by per-doc judgment and never as a sweep. They include decisions.md `## Decision Log` (~246 KB) and operations.md's Visual-design runbook (~21 KB, still titled for Claude Design + DesignSync, which P26/P27 replaced). `DECOMP` decides whether any split belongs in this phase.
- Deferred D50 (an `## Operator Runtime` section for this repo's operations doc) is triggered by "the next docs phase". `DECOMP` may fold it in or leave it deferred; the operator decides on promotion.
