# Plan

- Phase ID: P2
- Slice ID: P2.REVIEW
- Slice: phase review
- Created at: 2026-06-10T12:34:05+09:00

## Goal

Review phase P2 against its objective and record a verdict. Confirm the archiving-workflow change shipped consistently across engine, skills, contract, and docs, and that the critical dual-apply constraint (live ≡ bootstrap-embedded; CLAUDE.md ≡ AGENTS.md) holds.

## Scope

- Run the read-only `phase-reviewer` subagent over P2.
- Independently re-check the standing invariants (live == fresh bootstrap for contract/skills/engine; CLAUDE≡AGENTS; validate).
- Record the verdict with `review-phase`.

## Milestones

1. Invoke `phase-reviewer` subagent; capture verdict + findings.
2. Record verdict via `review-phase P2 --verdict ... --reviewer phase-reviewer --note "..."`.
3. On pass: finish the review slice. Do not archive (sequencing caution: would archive P1).

## Validation

- Subagent verdict captured in `result.md`.
- `python3 scripts/workflow.py validate` — passes.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None (review slice).
