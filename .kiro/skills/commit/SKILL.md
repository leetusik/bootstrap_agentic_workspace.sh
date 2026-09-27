---
name: commit
description: (Kiro sidecar) Group pending changes by topic into focused conventional commits (never push).
---

# commit (Kiro sidecar)

Operator arguments: `$ARGUMENTS`

1. Make sure `.kiro/sidecar/KIRO.md` and `CLAUDE.md` are in your context (the `workflow` agent loads both; otherwise read them now). KIRO.md's overrides win over everything below.
2. Read `.claude/skills/commit/SKILL.md` and follow it exactly, with the operator arguments above standing in for the arguments that skill expects, as modified by KIRO.md.

