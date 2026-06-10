# Plan

- Phase ID: P2
- Slice ID: P2.S4
- Slice: Decision record: decisions.md doc version
- Created at: 2026-06-10T12:51:40+09:00

## Goal

Record the archiving-workflow decision in `docs/current/decisions.md` as a durable, versioned ADR entry, so the rationale (manual archiving; archive-all default; first-class archive-phase; new rotate-backlog) survives beyond this phase's slice notes.

## Scope

- Create a new `decisions` doc version via `doc-new-version --doc decisions --source P2.S4`, edit only the returned `edit_path`, then `rebuild-docs`.
- Content: one Decision Log entry capturing the four confirmed decisions and the rejected alternative (auto-archive on review pass), with `Source: P2`.
- Out of scope: workflow.py/skills/contract (S1–S3, done). No bootstrap twin — doc content versions are not embedded in the bootstrap.

## Milestones

1. `doc-new-version --doc decisions --summary "..." --source P2.S4`.
2. Edit the returned version file: fill the Decision Log entry.
3. `rebuild-docs`; confirm `docs/current/decisions.md` matches; `validate`.

## Validation

- `python3 scripts/workflow.py rebuild-docs` — regenerates `docs/current/decisions.md`.
- `python3 scripts/workflow.py validate` — passes (checks current == latest version).

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- `decisions` — new version recording the archiving-workflow decision (source P2.S4).
