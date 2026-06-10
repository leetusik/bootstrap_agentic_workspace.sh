# Result

- Phase ID: P2
- Slice ID: P2.S3
- Slice: Contract: CLAUDE.md/AGENTS.md + bootstrap WORKFLOW_DOC sync
- Review status: pending
- Next action: execute P2.S4 (decision doc)

## Outcome

Made the routing contract consistent with the new archiving story, in `CLAUDE.md`, `AGENTS.md`, and the bootstrap `WORKFLOW_DOC`/P1 template:

- Hard Rules archiving bullet: now states "Archiving is a separate, manual step" and lists all three ops — `archive-all` (full sweep), `rotate-backlog` (partial — archive the done phases, leave the rest), `archive-phase <P>` (single review-passed phase).
- Workflow Commands list: added `rotate-backlog` and reworded the `archive-phase P1` entry from "manual single-phase escape hatch" to "archive a single review-passed phase".
- Bootstrap P1 `phase.md` template line: reworded to "archived manually later (archive-all, rotate-backlog, or archive-phase)" for future workspaces.

`CLAUDE.md` and `AGENTS.md` regenerated from the edited `WORKFLOW_DOC`, so they stay byte-equal (modulo the H1 title + "Equivalent to" cross-ref line).

## Deviations from Plan

- Live `works/phases/active/P1/phase.md` has two archiving mentions (lines 68, 75). Left unchanged: P1 is a completed/historical phase and its notebook records what P1 actually did; rewriting it would misrepresent history. Only the bootstrap P1 template line (which seeds future workspaces) was updated. Documented this choice in the phase notebook.

## Validation Run

- `diff <(tail -n +4 CLAUDE.md) <(tail -n +4 AGENTS.md)` — identical bodies (CLAUDE ≡ AGENTS).
- Fresh bootstrap into temp — exit 0; `diff -q` live `CLAUDE.md`/`AGENTS.md` vs bootstrap — IDENTICAL.
- Standing invariants re-checked: live `.claude`/`.agents` skills == fresh bootstrap; live `scripts/workflow.py` == fresh bootstrap. All IDENTICAL.
- `python3 scripts/workflow.py validate` — passed.

## Files Changed

- `CLAUDE.md`, `AGENTS.md` — Hard Rules archiving bullet + Workflow Commands list.
- `bootstrap_agentic_workspace.sh` — `WORKFLOW_DOC` (same two edits) + P1 `phase.md` template archiving line.
- `works/phases/active/P2/slices/P2.S3/{plan,result}.md`.

## Doc Versions Created

- None (decision doc is P2.S4).

## Roadmap Updates

- None.

## Retrospective

- With the contract generated from `WORKFLOW_DOC` and written to both files, "edit the embed, regenerate live" is the only safe way to keep `CLAUDE.md` ≡ `AGENTS.md`; hand-editing the two files independently would risk drift. The full set of standing invariants (CLAUDE≡AGENTS; live==bootstrap for contract/skills/engine; validate) now all pass — good state to enter REVIEW.
