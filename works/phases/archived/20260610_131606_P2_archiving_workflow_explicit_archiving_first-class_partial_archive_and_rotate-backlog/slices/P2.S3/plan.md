# Plan

- Phase ID: P2
- Slice ID: P2.S3
- Slice: Contract: CLAUDE.md/AGENTS.md + bootstrap WORKFLOW_DOC sync
- Created at: 2026-06-10T12:51:40+09:00

## Goal

Make the routing contract consistent with the new archiving story: add `rotate-backlog` to the Workflow Commands list, reposition `archive-phase` as first-class, and reword the Hard Rules archiving bullet — in `CLAUDE.md`, `AGENTS.md`, the bootstrap `WORKFLOW_DOC` embed, and the bootstrap P1 `phase.md` template line. Keep `CLAUDE.md` ≡ `AGENTS.md`.

## Scope

Per the embed-site map + S2 phrasing notes in `phase.md`:

- Hard Rules archiving bullet (live `CLAUDE.md` L54 / `AGENTS.md` / embed `WORKFLOW_DOC`): state archiving is a separate manual step listing all three ops.
- Workflow Commands list `archive-*` line: add `rotate-backlog`; reword `archive-phase` from "escape hatch" to first-class single-phase archive.
- Bootstrap P1 `phase.md` template line (bootstrap ~L1085): reword to "archived manually later (archive-all, rotate-backlog, or archive-phase)".
- Method: edit bootstrap `WORKFLOW_DOC` (+ the P1 template line), regenerate live `CLAUDE.md`/`AGENTS.md` from the bootstrap (auto-keeps them in sync), verify.

Out of scope: workflow.py (S1), skills (S2), decisions doc (S4). Live P1 `phase.md` archiving lines are historical (P1 done) — left as the record of what P1 did; not rewritten.

## Milestones

1. Edit bootstrap `WORKFLOW_DOC`: Hard Rules archiving bullet + Workflow Commands `archive-*` line. Edit the P1 `phase.md` template archiving line.
2. Regenerate live `CLAUDE.md` + `AGENTS.md` from the edited bootstrap (temp bootstrap + copy).
3. Verify: `diff` CLAUDE.md vs AGENTS.md bodies identical; `diff -q` each vs fresh bootstrap; `validate`.

## Validation

- `diff <(tail -n +4 CLAUDE.md) <(tail -n +4 AGENTS.md)` — identical bodies.
- `diff -q CLAUDE.md <tmp>/CLAUDE.md` and AGENTS.md — identical (live == bootstrap-generated).
- Standing invariants: live skills == fresh bootstrap; live workflow.py == fresh bootstrap.
- `python3 scripts/workflow.py validate` — passes.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None in this slice. Decision doc is P2.S4.
