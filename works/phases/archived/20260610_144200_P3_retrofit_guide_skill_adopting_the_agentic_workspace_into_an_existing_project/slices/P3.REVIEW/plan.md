# Plan

- Phase ID: P3
- Slice ID: P3.REVIEW
- Slice: phase review
- Created at: 2026-06-10T13:44:03+09:00

## Goal

Review phase P3 against its objective, slices, docs, validation, and workflow
integrity; record the verdict with `review-phase`.

## Scope

- Invoke the read-only `phase-reviewer` subagent over `works/phases/active/P3/`.
- Verify the three deliverables: (1) retrofit guide + durable docs, (2) the
  `retrofit` skill mirrored + dual-applied, (3) committed E2E verification.
- Verify the phase constraints held: non-destructive; fresh path unchanged;
  docs/current not hand-edited (doc-new-version used); dual-apply maintained;
  workflow.py untouched.
- Record verdict; on `pass`, finish the slice (phase → done, stays in active/).

## Milestones

1. Run the phase-reviewer subagent; capture its verdict + justification.
2. `review-phase P3 --verdict <v> --reviewer phase-reviewer --note "..."`.
3. On pass: write result.md, finish-slice, commit. Do not archive.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `bash tests/retrofit_smoke.sh` passes (already green in S4).

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md`.

- None.
