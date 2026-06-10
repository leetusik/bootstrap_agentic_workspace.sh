# Backlog

> Generated dashboard. Do not put detailed task context here; edit phase/slice/deferred folders instead.

## Pointer

- Current phase: `P3`
- Current slice: `P3.S4`
- Next slice: `P3.REVIEW`
- Open deferred jobs: `0`
- Rebuilt at: `2026-06-10T14:28:53+09:00`

## Active Phases

| Phase | Status | Review | Objective | Current Slice | Path |
|---|---|---|---|---|---|
| `P3` | `planned` | `pending` | Enable developers to adopt this agentic workspace into a repository that is already under active development — not just a fresh/empty directory. Today bootstrap_agentic_workspace.sh assumes an empty target (it refuses non-empty dirs without --force-empty-ok and aborts if managed files already exist), and there is no documentation for retrofitting onto a project with existing code, README, scripts/, docs, or git history. This phase closes that gap.  Deliverables (the DECOMP slice sets the final slice breakdown; the form is fixed as guide + skill): 1. A retrofit guide (markdown) that walks an operator/agent through adding the workspace — contracts (CLAUDE.md/AGENTS.md), the works/ state machine, scripts/workflow.py, docs/ versioning, and skills — to an existing repo, including how to handle collisions with existing files, preserve git history, and seed the first phase from the project's current state instead of from scratch. 2. A delivered Skill, mirrored in .claude/skills and .agents/skills (with the Codex agents/openai.yaml) per project convention, that drives an agent through the retrofit; explicit-invocation only, consistent with the other workflow skills. 3. End-to-end verification that the guide + skill actually work on a representative existing repo (e.g., a dry-run adoption into a sample project).  Constraints: - Treat docs/current/*.md and CLAUDE.md as source of truth; if guide content becomes durable doc truth, add it via doc-new-version — never hand-edit generated snapshots under docs/current/. - Whether to extend bootstrap_agentic_workspace.sh with a non-empty/existing-repo retrofit mode is for DECOMP to evaluate; IF the script is changed, the live script and the copy embedded in the bootstrap script must stay in sync (dual-apply), matching the constraint established in P2. - Adoption must be safe and non-destructive — never clobber a target repo's existing files. - Per the contract, this phase is created with DECOMP + REVIEW only; the DECOMP slice creates the middle slices (bare folders) and records the breakdown, findings, and notes in phase.md. | `P3.S4` | `works/phases/active/P3` |

## Phase P3: Retrofit Guide & Skill: Adopting the Agentic Workspace into an Existing Project

| Slice | Status | Name | Kind | Path |
|---|---|---|---|---|
| [x] `P3.DECOMP` | `done` | decompose phase | `decomposition` | `works/phases/active/P3/slices/P3.DECOMP` |
| [x] `P3.S1` | `done` | retrofit guide and durable docs | `docs` | `works/phases/active/P3/slices/P3.S1` |
| [x] `P3.S2` | `done` | installer into-existing retrofit mode | `implementation` | `works/phases/active/P3/slices/P3.S2` |
| [x] `P3.S3` | `done` | retrofit skill dual-applied | `implementation` | `works/phases/active/P3/slices/P3.S3` |
| [ ] `P3.S4` | `todo` | end-to-end verification and smoke test | `qa` | `works/phases/active/P3/slices/P3.S4` |
| [ ] `P3.REVIEW` | `todo` | phase review | `review` | `works/phases/active/P3/slices/P3.REVIEW` |
