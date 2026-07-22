# Operations

## Status

No operations truth is finalized yet.

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Local Development

- Install:
- Run:
- Test:
- Build:

## Environment Variables

| Name | Required | Purpose | Notes |
|---|---|---|---|
| <NAME> | yes/no | <purpose> | <notes> |

## Knowledge (phase explainers)

A passing phase review can auto-save an interactive HTML phase explainer to the
knowledge service. Default, plugin-free setup — one org-level key serves every repo:

1. Sign up at the knowledge service and mint an API key.
2. Export it in `~/.zshenv` (sourced by every zsh invocation) — never a repo `.env`,
   which neither Claude Code nor Codex auto-loads and which risks committing the secret:

       export KB_API_BASE_URL="https://knowledge.hi2vi.com"
       export KB_API_TOKEN="vk_..."

With the env vars set, a passing review auto-saves the phase explainer via plain REST —
Claude Code and Codex equally, no plugin install required. Each document's project
defaults to the repo's directory name.

- **Codex caveat:** its `workspace-write` sandbox blocks outbound network by default, so
  the save is skipped. Opt in with `[sandbox_workspace_write] network_access = true` in
  `~/.codex/config.toml` — this loosens all Codex workspace-write runs (your call); Claude
  Code needs nothing.
- **Alternative (Claude Code plugin):** `/plugin marketplace add leetusik/knowledge` →
  `/plugin install knowledge@knowledge` → `/knowledge:setup`, then `/knowledge:explain` on
  demand for a richer path.

Drive knowledge through the skill/agents; REST is the substrate.

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
