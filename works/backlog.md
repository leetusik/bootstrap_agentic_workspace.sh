# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.

## Pointer

- Current phase: `P2`
- Current slice: `P2.DECOMP`
- Next slice: `P2.REVIEW`
- Open deferred jobs: `0`
- Rebuilt at: `2026-06-10T12:34:05+09:00`

## Active Phases

| Phase | Status | Review | Objective | Current Slice | Path |
|---|---|---|---|---|---|
| `P1` | `done` | `pass` | Create a user-friendly root README.md that makes this workspace approachable to newcomers. It should: (1) explain what the project is and the problem it solves; (2) show how to bootstrap a workspace by running bootstrap_agentic_workspace.sh, with prerequisites and what gets created; (3) cover how to get started and use it day-to-day — the phase/slice workflow, scripts/workflow.py, and the Claude Code / Codex skills; (4) explain how to contribute; (5) include a FEATURED, opinionated 'how to work with coding agents' methodology section sharing the operator's approach; and (6) add a 'Related / inspired by' see-also section linking similar projects such as oh-my-claude-code, oh-my-zsh-style frameworks, and Claude Code skills/plugins. Keep docs/current/*.md and CLAUDE.md as the source of truth and link to them rather than duplicating. | `none` | `works/phases/active/P1` |
| `P2` | `planned` | `pending` | Refine the archiving workflow and document it consistently across the contract, the skills, the tooling, and the bootstrap script. Decisions already confirmed with the operator: (1) Archiving is manual and user-requested only, never automatic — a passing review still only marks a phase done and leaves it in active/. (2) Default end-state process stays: once every active phase is done, archive them all together with archive-all. (3) Promote single-phase partial archiving (archive-phase <P>) from a manual escape hatch to a first-class, supported option, useful when there are many phases and only some are done. (4) Add a new rotate-backlog operation (a skill plus a workflow.py command, mirrored into both .claude/skills and .agents/skills) that archives every phase currently done, leaves in-progress phases untouched, then rebuilds the backlog/index/state dashboards — the partial rotation that archive-all cannot do because it requires ALL phases to be done. CRITICAL CONSTRAINT: every rule, skill, and tooling change must be applied in BOTH the live repo files AND their embedded copies inside bootstrap_agentic_workspace.sh (CLAUDE.md, AGENTS.md, the affected skills, and workflow.py are all duplicated inside the bootstrap heredocs), and CLAUDE.md and AGENTS.md must stay in sync. Also update the Workflow Commands list and the wording in the archive-phase, do-next-slice, do-whole-phase, and review-phase skills to match, and consider recording the decision in docs (decisions.md). The DECOMP slice will break this into slices and verify the exact embed sites. | `P2.DECOMP` | `works/phases/active/P2` |

## Phase P1: User-Facing README & Onboarding Guide

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P1.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P1/slices/P1.DECOMP` |
| [x] `P1.S1` | `done` | Core README | `implementation` | `works/phases/active/P1/slices/P1.S1` |
| [x] `P1.S2` | `done` | Methodology & related projects | `implementation` | `works/phases/active/P1/slices/P1.S2` |
| [x] `P1.REVIEW` | `done` | phase review | `review` | `works/phases/active/P1/slices/P1.REVIEW` |

## Phase P2: Archiving Workflow: Explicit Archiving, First-Class Partial Archive, and rotate-backlog

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [ ] `P2.DECOMP` | `todo` | decompose phase | `decomposition` | `works/phases/active/P2/slices/P2.DECOMP` |
| [ ] `P2.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P2/slices/P2.REVIEW` |
