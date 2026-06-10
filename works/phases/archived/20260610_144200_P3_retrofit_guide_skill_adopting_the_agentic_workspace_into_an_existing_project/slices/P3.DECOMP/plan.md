# Plan

- Phase ID: P3
- Slice ID: P3.DECOMP
- Slice: decompose phase
- Created at: 2026-06-10T13:44:03+09:00

## Goal

Decompose P3 (retrofit guide + skill for adopting the workspace into an existing
repo) into concrete middle slices, and record the slice breakdown, the
non-destructive collision policy, and the dual-apply map in `phase.md` so each
later slice shares that context. Create the middle slices as **bare folders
only** — do not pre-fill their `plan.md`.

## Scope

- Evaluate the phase's open question (extend the installer vs. skill-only) and
  record the resolution: **extend `bootstrap_agentic_workspace.sh` with a
  flag-gated `--into-existing` mode**, with **additive idempotent merges**
  allowed, and a **committed smoke test** as the verification artifact
  (operator-confirmed during planning).
- Create middle slices S1–S4 with kinds/risks/order via `new-slice`.
- Seed `phase.md` (Context, Decomposition, Findings & Notes, Constraints) with
  the design, the four-tier install model, the seeding approach, and the
  dual-apply surfaces.
- Not in scope: writing any slice's `plan.md`, the guide, the installer change,
  the skill, or the smoke test — those are the middle slices' own jobs.

## Milestones

1. Create S1 (guide), S2 (installer mode), S3 (skill), S4 (verification) with
   `new-slice` (orders 10/20/30/40).
2. Seed `phase.md` with breakdown + four-tier collision policy + seeding lever +
   dual-apply map + constraints.
3. Finish DECOMP, `validate`, commit.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `python3 scripts/workflow.py next` shows P3.S1 as the next slice.
- `works/backlog.md` lists S1–S4 between DECOMP and REVIEW in order.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None in this slice. Durable docs (operations adoption procedure, decisions
  v0003) are written by S1.
