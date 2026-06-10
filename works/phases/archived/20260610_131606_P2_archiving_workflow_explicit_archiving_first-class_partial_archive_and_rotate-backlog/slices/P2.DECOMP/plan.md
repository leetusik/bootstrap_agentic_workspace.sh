# Plan

- Phase ID: P2
- Slice ID: P2.DECOMP
- Slice: decompose phase
- Created at: 2026-06-10T12:34:05+09:00

## Goal

Break phase P2 (archiving-workflow refinement) into concrete middle slices, and verify the exact embed sites so each later slice can keep the live repo files and their bootstrap-embedded copies in sync. Seed `phase.md` with the decomposition, the verified embed-site map, and a precise `rotate-backlog` spec.

## Scope

- In scope: create the middle slice folders (bare, no pre-filled `plan.md`); record breakdown + findings + embed-site map + rotate-backlog spec in `phase.md`.
- Out of scope: implementing any code, skill, contract, or doc change (that is the middle slices' job).

## Milestones

1. Verify embed sites across `scripts/workflow.py`, `CLAUDE.md`/`AGENTS.md`, the skills, and `bootstrap_agentic_workspace.sh` (done during exploration; confirmed embedded workflow.py is byte-identical to live).
2. Write the decomposition, embed-site map, and `rotate-backlog` spec into `phase.md`.
3. Create the middle slices `P2.S1`..`P2.S4` with `new-slice` (folders only).

## Validation

- `python3 scripts/workflow.py validate` passes after creating the slices.
- `python3 scripts/workflow.py next` selects `P2.S1` as the next slice.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None in this slice. `P2.S4` records the archiving decision in `decisions.md` via a new doc version.
