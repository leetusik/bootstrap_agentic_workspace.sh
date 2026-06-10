# Result

- Phase ID: P2
- Slice ID: P2.S4
- Slice: Decision record: decisions.md doc version
- Review status: pending
- Next action: phase review (P2.REVIEW)

## Outcome

Recorded the archiving-workflow decision as a durable, versioned ADR entry in the `decisions` doc (`v0002`). The entry captures all four confirmed decisions (manual/explicit archiving; `archive-all` default sweep; first-class `archive-phase`; new `rotate-backlog` partial sweep), the rejected alternatives (auto-archive on review pass; escape-hatch-only single archive; immediate `--dry-run`/`--force` on rotate-backlog), the consequences (three entry points sharing the `_phase_blockers` gate; dual-apply + CLAUDE≡AGENTS constraint), and the source (P2).

## Deviations from Plan

None.

## Validation Run

- `python3 scripts/workflow.py doc-new-version --doc decisions --source P2.S4` — created `v0002`.
- Edited only the returned version file (never `docs/current/decisions.md` directly).
- `python3 scripts/workflow.py rebuild-docs` — regenerated `docs/current/decisions.md`.
- `python3 scripts/workflow.py validate` — passed (confirms current == latest version).
- `python3 scripts/workflow.py docs | grep decisions` — latest is `v0002`.

## Files Changed

- New: `docs/versions/decisions/v0002_archiving_workflow_manual_archiving_first-class_archive-phase_rotate-backlog.md`.
- Regenerated: `docs/current/decisions.md`, `docs/index.json`.
- `works/phases/active/P2/slices/P2.S4/{plan,result}.md`.

## Doc Versions Created

- `decisions/v0002_archiving_workflow_manual_archiving_first-class_archive-phase_rotate-backlog` (source P2.S4, previous v0001_bootstrap).

## Roadmap Updates

- None.

## Retrospective

- Doc content versions have no bootstrap twin (the bootstrap only seeds `v0001_bootstrap`), so this slice was single-surface — no dual-apply needed. All four phase decisions are now durable beyond the slice notes.
