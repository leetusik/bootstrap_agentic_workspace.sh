# Phase P2: Archiving Workflow: Explicit Archiving, First-Class Partial Archive, and rotate-backlog

## Objective

Refine the archiving workflow and document it consistently across the contract, the skills, the tooling, and the bootstrap script. Decisions already confirmed with the operator: (1) Archiving is manual and user-requested only, never automatic — a passing review still only marks a phase done and leaves it in active/. (2) Default end-state process stays: once every active phase is done, archive them all together with archive-all. (3) Promote single-phase partial archiving (archive-phase <P>) from a manual escape hatch to a first-class, supported option, useful when there are many phases and only some are done. (4) Add a new rotate-backlog operation (a skill plus a workflow.py command, mirrored into both .claude/skills and .agents/skills) that archives every phase currently done, leaves in-progress phases untouched, then rebuilds the backlog/index/state dashboards — the partial rotation that archive-all cannot do because it requires ALL phases to be done. CRITICAL CONSTRAINT: every rule, skill, and tooling change must be applied in BOTH the live repo files AND their embedded copies inside bootstrap_agentic_workspace.sh (CLAUDE.md, AGENTS.md, the affected skills, and workflow.py are all duplicated inside the bootstrap heredocs), and CLAUDE.md and AGENTS.md must stay in sync. Also update the Workflow Commands list and the wording in the archive-phase, do-next-slice, do-whole-phase, and review-phase skills to match, and consider recording the decision in docs (decisions.md). The DECOMP slice will break this into slices and verify the exact embed sites.

## Context

## Decomposition

_Slice breakdown and rationale — filled by the `P2.DECOMP` slice._

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

## Constraints

## Open Questions

-
