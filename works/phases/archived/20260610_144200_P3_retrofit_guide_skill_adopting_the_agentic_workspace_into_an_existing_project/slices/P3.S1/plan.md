# Plan

- Phase ID: P3
- Slice ID: P3.S1
- Slice: retrofit guide and durable docs
- Created at: 2026-06-10T14:04:40+09:00

## Goal

Ship the human-facing retrofit deliverable: a standalone `docs/retrofit-guide.md`
runbook that fully specifies the non-destructive adoption procedure (so S2
implements to a written spec), link it from the README, and record the durable
truth in the versioned docs (`operations` + `decisions`).

## Scope

- `docs/retrofit-guide.md`: when to retrofit, prerequisites, the recommended
  paths (`/retrofit` skill and `--into-existing`), the **four-tier collision
  policy** in human terms, seeding P1 from project state, post-install steps,
  verification, idempotency, a manual fallback, and troubleshooting.
- `README.md`: a Quickstart "retrofit it" subsection + a pointer in the Safety note.
- Durable docs via `doc-new-version` (edit version files only, then `rebuild-docs`):
  - `operations` v0002 — adoption/retrofit procedure (pointer-style, links the guide).
  - `decisions` v0003 — the decision to support `--into-existing` retrofit.
- Out of scope: implementing `--into-existing` (S2), the skill (S3), tests (S4).

## Milestones

1. Write `docs/retrofit-guide.md` matching the four-tier model in `phase.md`.
2. Link the guide from `README.md` (Quickstart + Safety).
3. `doc-new-version` operations + decisions; edit version files; `rebuild-docs`.
4. `validate`; finish; commit.

## Validation

- `python3 scripts/workflow.py validate` passes (docs index/current in sync).
- `docs/current/operations.md` and `docs/current/decisions.md` reflect the edits.
- README links resolve to `docs/retrofit-guide.md`.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- `operations` (adoption procedure) — done via v0002.
- `decisions` (retrofit decision) — done via v0003.
