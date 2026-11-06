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
- Agent's Chrome deviceId: <the `deviceId` that `list_connected_browsers` prints for the dedicated agent profile (a separate Chrome profile with the Claude in Chrome extension, signed into none of the operator's accounts) while it is the only browser connected; never its `name`, a position label ("Browser 1") that moves between connections; re-record after an extension reinstall or sign-out; not needed when the instrument above is another browser>
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
`/knowledge:explain <topic>`. Every explain is its own **explain phase**, one per publishable
unit: a standalone document by default, a book or one chapter of a book only when you ask. After
one confirmation the phase is created **and** run, in its own worktree under `.claude/worktrees/`,
and merged back by itself (a nested install names no host branch for it): one writer reads this
repository's code and the records of the phases that built the subject, a critic on a second
model checks the draft against them, and it is published private. An explain does no research of
its own and covers only this repository's code; a subject no phase recorded is offered a research
phase first. A book still stops for its outline sign-off and its acceptance gate. Plugin version
0.10.0 or later is required. The writer runs on your session's permissions: auto mode needs
nothing, and manual mode needs the rules the explain skill's §3.2 *Permissions, and the payload
builder* prints, in `.claude/settings.local.json` (the plugin's README, *Explain: permissions*).
To update: `/plugin marketplace update knowledge`, then update `knowledge@knowledge` from the
`/plugin` panel's Installed tab (or, from a shell, `claude plugin update knowledge@knowledge`).
The review never writes an explainer; it only reports
`explain: not written — run /knowledge:explain P<N> for a document, or ask it for a book`.

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
