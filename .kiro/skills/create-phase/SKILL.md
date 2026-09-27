---
name: create-phase
description: (Kiro sidecar) Capture operator intent (refine, clarify, confirm), then create the phase (intent.md + DECOMP/REVIEW only). Stops before decomposition.
---

# create-phase (Kiro sidecar)

Operator arguments: `$ARGUMENTS`

1. Make sure `.kiro/sidecar/KIRO.md` and `CLAUDE.md` are in your context (the `workflow` agent loads both; otherwise read them now). KIRO.md's overrides win over everything below.
2. Read `.claude/skills/create-phase/SKILL.md` and follow it exactly, with the operator arguments above standing in for the arguments that skill expects, as modified by KIRO.md.
3. If the work is product visual design, you may still capture its Design Style in intent.md, but tell the operator its co-work design slices must run in Claude Code.
