# Intent — P30

- Captured at: 2026-10-07T15:46:03+09:00
- Origin: operator

## Original Input (verbatim)

> for /rotate-backlog . and make it /rotate-backlog default behaviour is creating phase.

## Confirmed Intent (refined + clarified)

Today `/rotate-backlog` (`workflow.py rotate-backlog`) archives every cleanly archivable phase and leaves the rest active. A phase whose only blocker is unpaid doc consolidation (`consolidation: pending`, stamped by a passing review over `## Doc impact` notes) just stays active, and the operator has to remember to create the docs phase separately. At intake, P25 was archivable and P26–P29 were held back only by doc debt.

Change `/rotate-backlog` so that, **by default**:

1. It still archives every clean phase first, as it does today.
2. It then collects the phases held back **only** by doc-consolidation debt and turns them into a **proposed docs phase**. It drafts the name, the objective (naming the phases it pays) and the scope from `docs-debt`, then asks the operator to confirm **once**.
3. On the operator's yes it runs `new-phase` and fills `intent.md` exactly as create-phase's *docs-phase route* does: verbatim input, `docs-debt` scope, and the "one `--kind docs` slice per doc, then `docs-consolidated <P>` per covered phase" cut written for its `DECOMP`. Then it STOPs. It never decomposes the phase.
4. An **opt-out word**, e.g. `/rotate-backlog archive-only`, keeps today's behavior: archive and report, with no proposal.

Constraints held:
- **The create-phase confirmation gate does not move.** `new-phase` runs only after the operator confirms the name and objective; typing `/rotate-backlog` is not the confirmation.
- **No duplicate docs phase.** If an active docs phase already covers the owing phases, rotate reports it and creates nothing.
- **Other blockers are left alone.** A phase that is unfinished or unreviewed, or owes doc debt *and* is blocked for another reason, is reported as today; rotate never creates a phase for it.
- **The docs phase runs on the default stream**, never in a worktree, as the docs-phase route requires.
- This is an embedded-machinery change (the engine and/or skills, plus the docs that describe rotate-backlog). It ships a workspace version bump (v51 + CHANGELOG) and `python3 installer/build.py` in the same commit. DECOMP decides how the change splits between the engine (e.g. a printed docs-debt summary or proposal from `rotate-backlog`) and the skill.

## Clarifications Resolved

- Q: Which phase should /rotate-backlog create by default? — A: The docs phase for the doc-consolidation debt (create-phase's docs-phase route, scope from `docs-debt`).
- Q: The contract runs `new-phase` only after the operator confirms the name and objective; how should rotate handle that? — A: Propose, then one confirm. Rotate drafts the name and objective and asks once; the yes creates the phase. The contract is unchanged.
- Q: Should the operator be able to rotate without creating a phase? — A: Yes, through an opt-out word (e.g. `/rotate-backlog archive-only`) that keeps today's behavior.
- Agent-proposed refinements, accepted with the operator's "go": no duplicate docs phase when one already covers the debt; phases blocked for other reasons are reported, never phased.

## Notes

- Not a visual-design phase (no `## Design Style`).
- `rotate-backlog`'s SKILL.md is `disable-model-invocation: true` with `allowed-tools: Bash(python3 scripts/workflow.py:*)`. The new default runs `new-phase` and edits `intent.md`, so DECOMP should check the frontmatter still allows that flow.
- Docs that describe rotate-backlog today: `.claude/skills/rotate-backlog/SKILL.md`, `.claude/skills/archive-phase/SKILL.md`, `.claude/skills/create-phase/SKILL.md` (docs-phase route, which should name rotate as an entry point), `docs/current/operations.md` (~L790, ~L1041), `docs/current/decisions.md` (~L1734–1740).
