---
doc_id: operations
version: v0002
created_at: 2026-06-10T14:09:08+09:00
source: P3.S1
summary: Adopting the workspace into an existing repo (retrofit): --into-existing, four-tier collision policy, seed P1 from state
previous: v0001_bootstrap
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

- **Invoke:** `bootstrap_agentic_workspace.sh . --into-existing [--phase-name … --phase-objective …]`, or the `/retrofit` skill (`$retrofit` in Codex).
- **Four-tier collision policy:** (1) skip-if-exists for pure content (skills, templates, `.codex/config.toml`, `phase-reviewer`); (2) install the `docs/` and `works/` subsystems only if wholly absent (gate on `docs/index.json` / `works/state.json`), and gate the final rebuild to installed subsystems; (3) additive idempotent merge for `.claude/settings.json` (union permissions) and `CLAUDE.md`/`AGENTS.md` (marked section + `*.workspace.md` sidecar); (4) hard abort on a pre-existing `scripts/workflow.py`.
- **Two passes:** classify everything first (no writes), abort up front on a tier-4 collision, then apply — so a retrofit never half-installs.
- **Seed P1 from state:** pass `--phase-name`/`--phase-objective` (the skill synthesizes them from the README/manifest/language/HEAD); P1 stays `DECOMP`+`REVIEW`-only.
- **Git:** the installer runs no git; review the diff (`git status` shows only additions plus the additive `.claude/settings.json` merge) and commit yourself. Add `__pycache__/` to `.gitignore`.
- **Verify:** `python3 scripts/workflow.py validate` then `next`. Retrofit is idempotent — re-running is a clean no-op.

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
