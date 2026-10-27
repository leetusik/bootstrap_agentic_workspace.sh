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
- Browser instrument for the agent: <Claude in Chrome (the default; blank means it), or, where it cannot run here (WSL, CI, an API-key or Bedrock/Vertex/Foundry session), the other real browser the agent drives on a throwaway profile, e.g. the project's Playwright>
- Agent's Chrome browser name: <the dedicated agent profile's name exactly as `list_connected_browsers` prints it, e.g. agent: a separate Chrome profile with the Claude in Chrome extension, signed into none of the operator's accounts; not needed when the instrument above is another browser>
- Production build command + origin (when different):
- Also needed to see what the operator sees: <auth/test account, seeded data, feature flags>
- Status: UNFILLED — fill before any slice claims real-browser verification

An absent section and an unfilled one mean the same thing: the slice stops `pending` and asks
the operator, it never assumes. Remove the `Status:` line once the fields above are real.

## Environment Variables

| Name | Required | Purpose | Notes |
|---|---|---|---|
| <NAME> | yes/no | <purpose> | <notes> |

## Knowledge (/knowledge:explain)

Explaining a topic, a change or a phase into your knowledge base is done by the
**knowledge plugin**, not by this workspace. The plugin owns the skill, the CLI and the
document API, so they stay in step. Install it once:

    /plugin marketplace add leetusik/knowledge
    /plugin install knowledge@knowledge

then run `/knowledge:setup` once (connect to the hosted KB, or scaffold your own) and use
`/knowledge:explain <topic>`. A whole book (researched, outlined and signed, each chapter
checked by a fresh-eyes critic, published private) is an **explain phase**: ask
`/create-phase` to explain something as a book. Plugin version 0.6.0 or later is required. A book's research runs on your session's permissions (auto mode needs nothing; manual mode needs the rules its preflight prints, in `.claude/settings.local.json`) and its web searches count against Claude Code's per-session cap: raise `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` in your user settings' `env` (the plugin's README, *Explain: permissions and the search cap*).
To update: `/plugin marketplace update knowledge`, then update `knowledge@knowledge` from the
`/plugin` panel's Installed tab (or, from a shell, `claude plugin update knowledge@knowledge`).
The review never writes an explainer; it only reports
`explain: not written — run /knowledge:explain P<N> for one chapter, or create an explain phase for a book`.

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
