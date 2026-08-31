# Intent — P20

- Captured at: 2026-09-01T02:51:35+09:00
- Origin: operator

## Original Input (verbatim)

> aside cli installed. you check it up.

> you suggest one best way to use aside for repos which adapt this workspace. and update this repo accordingly.

> and I don't want to acitavte aside mcp all the time so it just consumes tokens even it's not browser related. can we handle those smartely?

## Confirmed Intent (refined + clarified)

Settle the one best way an adopting workspace uses Aside, and update this repo (contract, skills, seeded docs, tests) to match — shipping as workspace v37. The confirmed shape, in five parts:

1. **Surface taxonomy correction.** v36 names three surfaces (MCP / CLI / REPL); execution shows two: the `repl` surface (one tool, identical over `aside mcp` and the `aside repl` CLI — same Playwright-like environment, different transport) and `aside exec` (Aside's own model drives). Correct the doctrine.
2. **Default: `aside repl` over Bash, executor-driven.** The executor holds `page` + `snapshot()` and chooses each next action itself — agentic browsing on a Playwright surface. NOT the MCP transport: the operator explicitly objects to a standing MCP registration, and measurement agrees — `aside mcp` exposes one `repl` tool whose definition costs ~1,344 tokens in every session, browser-related or not, with no lazy-load option; while the JS scope lost between CLI invocations is bought back with a two-line re-attach preamble (`listBrowserTabs()` → `attachBrowserTab(targetId)`), verified live. Bash is already in both executor tiers' allowlists, so nothing ships and nothing registers. `claude mcp add -s local aside -- aside mcp` is named as an optional per-operator, per-session escape hatch the workspace neither ships nor prescribes.
3. **Profile safety (closes D11): dedicated profile, required.** Agent runs use a separate Aside profile/account via `aside --account <id>`, never the operator's signed-in one (probe reached a browser holding the operator's Google session, 49 imported passwords, 6 passkeys). The runtime manifest records which profile; an executor finding only the personal profile returns `needs_operator`.
4. **Fallback stands (closes D9).** The doctrine's demands bind, the instrument does not — Linux/CI runs the same sweep through whatever real browser exists. Unchanged from v36.
5. **Recorded surface facts (closes D10's surface half).** `repl` requires both `title` and `code`; snapshot refs are session- and snapshot-scoped and go stale on navigation (`RefStaleError`); `getByRole` survives it. Rewrite "not Playwright-style automation" as "not a pre-written assertion suite" — the surface IS Playwright; what differs is who picks the next action. The against-a-real-product half of D10 stays deferred until an adopting workspace has a browsable product.

## Clarifications Resolved

- Q: Which Aside profile may an executor drive? — A: Dedicated profile, **required** (doctrine-level; `needs_operator` when only the personal profile exists).
- Q: Does the Linux/CI fallback stand, or does Aside become a hard requirement? — A: **Fallback stands.**
- Q: How is the MCP server registered in an adopting repo? — A: Initially "documented one-liner, opt-in"; then superseded by the operator's objection to any standing MCP registration ("I don't want to activate aside mcp all the time…"). Final: **no registration at all** — `aside repl` over Bash is the default; the one-liner survives only as a named per-operator escape hatch.

## Notes

- Verified live on this machine, 2026-09-01: aside CLI 1.26.810.1915, account u0, daemon bridge reconnect after self-update, `example.com` open/snapshot/click/screenshot round trip over both transports; MCP tool definition measured at 4,974 JSON chars (~1,344 tokens).
- Deferred jobs D9, D10 (surface half), D11 close at this phase's review; D10's real-product half stays open.
