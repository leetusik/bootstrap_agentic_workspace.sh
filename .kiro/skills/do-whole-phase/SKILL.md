---
name: do-whole-phase
description: (Kiro sidecar) Finish the active phase end-to-end in auto mode, including review and fix slices, committing each slice.
---

# do-whole-phase (Kiro sidecar)

Operator arguments: `$ARGUMENTS`

1. Make sure `.kiro/sidecar/KIRO.md` and `CLAUDE.md` are in your context (the `workflow` agent loads both; otherwise read them now). KIRO.md's overrides win over everything below.
2. Read `.claude/skills/do-whole-phase/SKILL.md` and follow it exactly, with the operator arguments above standing in for the arguments that skill expects, as modified by KIRO.md.
3. Before anything else, apply KIRO.md's mode-word rule to the operator arguments. Then run `python3 scripts/workflow.py next`. If the loop reaches a `kind: co-work` slice, or the phase runs in a worktree, STOP there and hand off to Claude Code. No idle-window preparation.
