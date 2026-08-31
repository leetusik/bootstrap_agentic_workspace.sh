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

## Operator Runtime

How the **operator** runs and views this product. Any slice claiming "verified in a real
browser" verifies here — this runtime, this access path, these devices — and additionally in
the production build when the two differ.

- Run command(s):
- Mode: <dev or production build; say where they differ — dev may enable StrictMode / Fast Refresh, production does not>
- Origin / host the operator browses: <localhost, LAN IP, Tailscale host, deployed URL>
- Devices / viewports / browsers: <e.g. desktop 1440px Chrome, phone 390px Safari>
- Browser instrument for the agent: <Aside (driven as `aside repl` over Bash) if installed here, else the real browser it may drive — optional; its absence alone never stops a slice>
- Agent's Aside account id (required whenever the instrument above is Aside): <the dedicated agent profile, e.g. u1 — never the operator's signed-in one; `aside account list` shows what exists. No instrument named above, no profile to record>
- Production build command + origin (when different):
- Also needed to see what the operator sees: <auth/test account, seeded data, feature flags>
- Status: UNFILLED — fill before any slice claims real-browser verification

An absent section and an unfilled one mean the same thing: the slice stops `pending` and asks
the operator, it never assumes. Remove the `Status:` line once the fields above are real.

## Environment Variables

| Name | Required | Purpose | Notes |
|---|---|---|---|
| <NAME> | yes/no | <purpose> | <notes> |

## Knowledge (phase explainers)

The `explain` skill ships with this workspace, in `.claude/skills/`.
Explaining is an **operator-run step, separate from the phase review**:
run `/explain` for a phase when you want one and it saves an interactive HTML explainer to
the knowledge service. The review itself writes no explainer — it only reports the pointer
`explain: not written — run /explain for this phase`.

**Setup is on first use, and it asks first.** Run `/explain`; if no knowledge base is
configured it offers to create one on the hosted service at `https://knowledge.hi2vi.com`
— it asks for an email, installs the `knowledge` CLI, signs you up (or logs you in), and
writes an org-level key to `~/.config/knowledge-kb/config.json` at mode 0600. One org key
serves every repo. Each document's project defaults to the repo's directory name.

Already have a knowledge base — hosted or self-hosted? Skip the setup entirely by exporting
the credentials in `~/.zshenv` (sourced by every zsh invocation) — never a repo `.env`,
which Claude Code does not auto-load and which risks committing the secret:

    export KB_API_BASE_URL="https://knowledge.hi2vi.com"
    export KB_API_TOKEN="vk_..."

- **Alternative (Claude Code plugin):** `/plugin marketplace add leetusik/knowledge` →
  `/plugin install knowledge@knowledge` → `/knowledge:setup`, then `/knowledge:explain`.
  A separate namespace from this workspace's `/explain`; you do not need both.

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
