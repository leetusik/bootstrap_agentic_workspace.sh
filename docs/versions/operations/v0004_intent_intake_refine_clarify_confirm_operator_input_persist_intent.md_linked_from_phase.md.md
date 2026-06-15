---
doc_id: operations
version: v0004
created_at: 2026-06-15T09:40:29+09:00
source: operator-request
summary: Intent intake: refine, clarify, confirm operator input; persist intent.md linked from phase.md
previous: v0003_retrofit_git_step_operator_reviews_and_approves_agent_commits
---

# Operations

## Status

Adoption is documented two ways: a **fresh** install into an empty dir (README
Quickstart) and a **non-destructive retrofit** into an existing repo
(`--into-existing` / the `/retrofit` skill). Full runbook:
[`docs/retrofit-guide.md`](../../retrofit-guide.md).

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Adopting into an existing repo (retrofit)

The plain bootstrap installs only into an empty directory. To add the workspace
to a repo that already has code/docs/history, use the retrofit path. It is
**non-destructive**: it adds the workspace's files, skips anything already
present, additively merges a small known set, and aborts before writing on an
unresolvable collision. See [`docs/retrofit-guide.md`](../../retrofit-guide.md)
for the full procedure; the operational essentials:

- **Invoke:** the `/retrofit` skill (`$retrofit` in Codex) — the agent runs the installer — or directly: `bootstrap_agentic_workspace.sh . --into-existing [--phase-name … --phase-objective …]`.
- **Four-tier collision policy:** (1) skip-if-exists for pure content (skills, templates, `.codex/config.toml`, `phase-reviewer`); (2) install the `docs/` and `works/` subsystems only if wholly absent (gate on `docs/index.json` / `works/state.json`), and gate the final rebuild to installed subsystems; (3) additive idempotent merge for `.claude/settings.json` (union permissions) and `CLAUDE.md`/`AGENTS.md` (marked section + `*.workspace.md` sidecar); (4) hard abort on a pre-existing `scripts/workflow.py`.
- **Two passes:** classify everything first (no writes), abort up front on a tier-4 collision, then apply — so a retrofit never half-installs.
- **Seed P1 from state:** pass `--phase-name`/`--phase-objective` (the skill synthesizes them from the README/manifest/language/HEAD); P1 stays `DECOMP`+`REVIEW`-only.
- **Git:** the installer runs no git; the operator reviews the diff (`git status` shows only additions plus the additive `.claude/settings.json` merge) and the agent commits the adoption on their approval. The agent adds `__pycache__/` to `.gitignore`.
- **Verify:** `python3 scripts/workflow.py validate` then `next`. Retrofit is idempotent — re-running is a clean no-op.

## Capturing operator intent (intake)

Operator requests can carry grammar slips, awkward phrasing, or genuine
ambiguity, and a misread of intent silently propagates into decomposition and
every downstream slice. So intent is **refined, clarified, and confirmed before
any work starts**, and preserved as durable, linked truth.

- **When:** wherever operator intent first enters a unit of work — always at phase creation, and at the slice level when an operator note is ambiguous.
- **Flow:** **refine** the request into clear language → **clarify** anything ambiguous by asking the operator → **confirm** the interpretation. Only after the operator confirms does the agent run `new-phase`; it never creates the phase on an unconfirmed guess.
- **Persist (phase level):** the agent writes `intent.md` in the phase folder — the operator's **verbatim original** request (immutable) plus the **confirmed refined intent** and any resolved clarifications — and links it near the top of `phase.md`. The verbatim original is never edited; only the confirmed wording is the refined version.
- **Persist (slice level):** when a slice's operator note is ambiguous, the agent records the verbatim note under `## Operator Input (verbatim)` and its refined, operator-confirmed reading under `## Operator Intent (refined)` in that slice's `plan.md`.
- **Reference:** when any later agent is unsure of intent, it consults the phase's `intent.md` (linked from `phase.md`) — the confirmed source of truth for what was asked.
- **Seeded phases:** the installer seeds P1 with a placeholder `intent.md` (Origin `bootstrap-placeholder`, or `synthesized-from-repo` on retrofit, which the `/retrofit` skill then enriches from the README/manifest/`git log`).

## Local Development

- Install:
- Run:
- Test:
- Build:

## Environment Variables

| Name | Required | Purpose | Notes |
|---|---|---|---|
| <NAME> | yes/no | <purpose> | <notes> |

## Deployment

- Target:
- Process:
- Rollback:

## Scheduled Jobs / Workers

- <job>: <schedule/trigger>

## Observability

- Logs:
- Metrics:
- Alerts:

## Backup / Restore

- <policy>

## Open Questions

-
