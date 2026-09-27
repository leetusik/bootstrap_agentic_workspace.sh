---
name: do-next-slice
description: (Kiro sidecar) Complete exactly one slice of the active phase in auto mode (dispatch to slice-executor-high), commit, then stop.
---

# do-next-slice (Kiro sidecar)

Operator arguments: `$ARGUMENTS`

1. Make sure `.kiro/sidecar/KIRO.md` and `CLAUDE.md` are in your context (the `workflow` agent loads both; otherwise read them now). KIRO.md's overrides win over everything below.
2. Read `.claude/skills/do-next-slice/SKILL.md` and follow it exactly, with the operator arguments above standing in for the arguments that skill expects, as modified by KIRO.md.
3. Before anything else, apply KIRO.md's mode-word rule to the operator arguments. Then run `python3 scripts/workflow.py next`. If the selected slice is `kind: co-work`, or its phase runs in a worktree, STOP and hand off to Claude Code.
