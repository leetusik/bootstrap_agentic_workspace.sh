# Result — P25.S1 (research): verify the baseline and screen a replacement longlist

## Verdict

- **status:** done
- **tier:** high
- **summary:** Checked both `intent.md` readings. (a) is **strongly indicated, and it needs a correction**. A stock `ocx claude` session loses the claude.ai login, so `DesignSync` fails with `needs_design_login`. Claude Code also ships `/design-login`, a separate design credential that its own text says works under a provider token, but that is unverified live. Separately, the docs **verify** that background subagents drop the built-in `DesignSync` tool. (b) is **verified**: the design loop diverges from Anthropic's intended flow, and it uses `DesignSync` outside that tool's own stated purpose. Mapped the loop to 12 requirements, screened 16 candidates plus the baseline against the 5 criteria, and shortlisted 4: a repo-native frames board, Storybook, self-hosted Penpot + MCP, and self-hosted Doop.
- **files_changed:** `works/phases/active/P25/slices/P25.S1/result.md` (new), `works/phases/active/P25/phase.md` (Decisions, Notes, Now)
- **validation:** `python3 scripts/workflow.py validate` — passed (exit 0). `git status --short` — shows changes only under `works/` (the P25 folder plus the generated `works/` files the orchestrator's `start-slice` had already touched).
- **deviations:** One. The plan asked for "two lines on the verified readings". Reading (a) got one line that includes the subagent sub-finding, because that finding (from the docs) is what explains the `DesignSync` "main-thread only" rule for S2's criterion 3. Beyond that: no product code, no machinery edits, no installs, no accounts. Every probe was read-only: static reads of the installed `claude` binary and of the `ocx` package source, `claude auth status` in a scratch cwd, and unauthenticated GitHub API metadata. The scratch output stays in the session scratchpad.
- **doc_impact:** none (findings-only phase; the existing "(none …) (P25.DECOMP)" line stands)

Notebook: the readings and the shortlist are in `phase.md` `## Decisions`, the S2 notes in `## Notes for later slices`, and the handoff in `## Now`. This file is the evidence log behind them.

---

## 1. What the loop needs from a design tool (the yardstick)

This list comes from `.claude/skills/design-cowork/SKILL.md` §The loop, §The handoff / §The card set, §The design record, §Read back, §The mockup, §Closing the round and §Mechanics. It covers only the **replaceable loop**. The governance (the three styles, rounds, literal signoff, the mockup gate, RESPECT THE DESIGN) is out of scope.

| # | Requirement | Level | From |
|---|---|---|---|
| R1 | **An agent-writable brief the design session consumes.** The brief is `handoff.md`: product context, scope checklist, locked vs in-play, where to look (real paths, never lorem), the required-output manifest and open questions. Under the new framing ("agent drafts, you decide") it becomes the drafting subagent's brief. | must | §The handoff |
| R2 | **One reviewable unit per card, addressed by a stable path with a two-digit reading-order number.** Grouped by the design system's own taxonomy, never a monolith. A superseding card keeps its path. | must | §The card set |
| R3 | **An operator view that renders the cards** at a viewport, grouped, in numbered order, with the current round findable (the round address on the group while under review). No chat surface needed. "Done" means the cards appear in the view, not that the files exist. | must | §The loop, §The card set |
| R4 | **A machine-checkable read-back an executor can run.** List what the round produced, check it against the numbered paths (gaps, unnumbered cards, monolith), and read the contents for the concreteness check. Criterion 3 requires this to work without main-thread-only tools. | must | §Read back |
| R5 | **A durable, read-only record in the repo.** It holds `handoff.md`, what was designed with every departure logged, an implementation contract (`build-prompt.md`) complete enough to build without inventing, and `SIGNOFF.md`. The mockup and apply executors get nothing else. | must | §The design record, §The mockup |
| R6 | **Design memory that persists across rounds and sessions:** tokens (`tokens.css`), the cumulative component library and taxonomy, and prior rounds' decisions. Next rounds supersede by path. | must | §The card set (taxonomy "cumulative and shared across rounds"), criterion 5 |
| R7 | **Signoff/regroup mechanics.** Literal words are recorded in `SIGNOFF.md`. After signoff, the round address comes off the group without touching content (byte-identical after line 1, path unchanged, idempotent). That requires the grouping label to be separable from the card content. | must | §Closing the round |
| R8 | **Operator decides, rounds are immutable.** The operator must be able to reject, and a design question starts a new superseding round. The tool must not force the agent to make a visual decision on its own. | must | §The loop, §The mockup (rejection split) |
| R9 | Operator direct edits or inline comments on a card. Claude Design offers chat, inline comments, direct edits and sliders. | nice | Anthropic launch post (below) |
| R10 | Rendered previews or screenshots the agent can inspect (a visual read-back). Claude Design's new tool has `render_preview`. | nice | binary (below) |
| R11 | Grounding in the real repo: real tokens and components, not a mirror. Claude Design gets this through Connect GitHub or a local dir. | nice | §The loop |
| R12 | Runs with nothing hosted: works offline and survives the operator's absence. Implied by criteria 1 and 2. | nice | criteria |

Every **must** except R3 and R4 is a *repo-record* property. Any tool whose output can be landed as files satisfies it. The tool-specific musts are **R3** (a real operator surface), **R4** (an executor can read the round back), **R6** (memory survives) and **R7** (the group label can be separated from content).

---

## 2. Reading (a): does `DesignSync` / Claude Design work under `ocx claude`?

**Verdict: strongly indicated, with a correction to the orchestrator's reading.**
- **A stock `ocx claude` session (the operator's config) cannot use `DesignSync`.** The claude.ai login is displaced by the proxy's `ANTHROPIC_AUTH_TOKEN`, so the tool falls back to a separate design credential. Without one it errors with `needs_design_login`.
- **Claude Code ships `/design-login` for exactly this case.** Its own message says the credential "works even when this session authenticates with an API key or a provider token", and `DesignSync` traffic goes to `api.anthropic.com` directly, not through the proxy. So after a one-time interactive `/design-login` it is **strongly indicated to work** under ocx. That is **unverified live**: it needs the operator's claude.ai account, which this slice may not touch.
- **It still requires a claude.ai account with a paid plan either way.** Claude Design runs on Pro, Max, Team and Enterprise.
- **"`DesignSync` is main-thread only" is verified.** The mechanism is Claude Code's background-subagent tool filter.

### Evidence

**How the tool reaches a session: a built-in Claude Code tool, not MCP.** This is a static read of the installed binary `~/.local/share/claude/versions/2.1.284` (Claude Code 2.1.284), done with Python byte searches. The offsets are into that file.
- `var cHt="DesignSync",dHt=["list_projects","get_project","list_files","get_file","finalize_plan","write_files","delete_files","register_assets","unregister_assets","create_project","report_validate"]` (≈184446698). It is exported as `DesignSyncTool` from a bundled chunk and registered alongside the other built-ins (≈192312564).
- Enablement: `function eD(){if(!Qt("allow_design_sync"))return!1;if(Tt())return!1;return qn()}`. That means org policy allows it, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is unset, and `qn()` holds, where `qn(){return Ie()==="firstParty"}` (≈178339931).
- `Ie()` returns `"gateway"` only for Claude Code's own gateway credential slots, and `bedrock`/`vertex`/`foundry`/… only for the `CLAUDE_CODE_USE_*` env vars (≈178339537). `ANTHROPIC_BASE_URL` alone does **not** change the provider.
- The precondition (≈197232000) tries three credentials in order: (1) the claude.ai login token carrying the `user:design:read` scope, (2) a stored `designOauth` credential (`ddr()`), (3) otherwise `needs_design_login`.
- The error text for that last case (≈208756887): *"DesignSync needs design-system authorization. Run /design-login to authorize it with your claude.ai account — this works even when this session authenticates with an API key or a provider token."*
- The wrong-provider case is separate: *"DesignSync is only available with claude.ai authentication. It is not supported through Bedrock, Vertex, or other third-party providers."*
- Where the traffic goes: the design RPCs use the `Nt` client, whose base URL is `ln().BASE_API_URL`, the OAuth config (≈180436259 module, `Ay("api")`). That is not `ANTHROPIC_BASE_URL`. The newer `ClaudeDesign` tool asserts it directly: *"Claude Design is only reachable from api.anthropic.com; the current OAuth base URL is not on the first-party allowlist."* (≈208824363), posting to `/v1/design/mcp`.

**What `ocx claude` changes.** Sources: `ocx claude --help`, `ocx claude config status` and `ocx status` (all read-only), plus the package source at `/opt/homebrew/lib/node_modules/@bitkyc08/opencodex/src/cli/claude.ts`. No ocx config was changed.
- The help text: `ocx claude` "execs `claude` with ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN, CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 and model slots".
- `ocx claude config status` shows **`authMode: proxy`**, `markerMode: proxy`, `authModeOrigin: manual`, `cliFirstParty: false`. The operator is on proxy auth, not ocx's subscription-preserving mode.
- The source comment at `claude.ts` ~253 says: *"setting ANTHROPIC_AUTH_TOKEN/API_KEY disables claude.ai connectors and overrides the user's Claude login."* In proxy mode ocx sets its admission token or marker as `ANTHROPIC_AUTH_TOKEN`, plus `CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST=1`.
- The source comment at `claude.ts` ~339 shows ocx gives up Design knowingly: *"do NOT set _CLAUDE_CODE_ASSUME_FIRST_PARTY_BASE_URL here. While it enables Design/Remote Control, it DISABLES gateway model discovery … Model routing through the proxy is essential; Design/Remote Control are secondary features."*
- The ocx source never sets `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (grep returned no hits), so `eD()` is not tripped by that.

**Cheap live probe.** No model call and no account use: `claude auth status --json` run from the scratchpad, once in this session's plain env and once in an ocx-shaped env (`ANTHROPIC_BASE_URL=http://127.0.0.1:10100 ANTHROPIC_AUTH_TOKEN=probe-marker CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST=1`). Output, filtered to non-identifying fields:

```
== plain
{'loggedIn': True, 'authMethod': 'claude.ai', 'apiProvider': 'firstParty', 'subscriptionType': 'max'}
== ocx-shaped env
{'loggedIn': True, 'authMethod': 'oauth_token', 'apiProvider': 'firstParty'}
   keys lose email / orgId / orgName / subscriptionType;  --text: "Auth token: ANTHROPIC_AUTH_TOKEN"
```

So under ocx the provider stays `firstParty`, which means the `DesignSync` tool is *listed*. But the claude.ai identity is gone, so the tool reaches its `needs_design_login` branch unless a `/design-login` credential exists. This matches the operator memory that a nested `claude -p` under ocx reports "Not logged in".

**Main-thread only: verified, and the cause is now known.** From [Claude Code docs — subagents](https://code.claude.com/docs/en/sub-agents): *"a background subagent keeps every MCP tool but only these built-in tools: `Read`, `Grep`, `Glob`, `LSP`, `Bash`, `PowerShell`, `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage`, and `Artifact` … Claude Code removes every other built-in tool from a background subagent, whether inherited or listed in the `tools` field."*
- `DesignSync` is a built-in that is not on that list.
- This workspace always dispatches executors in the background (`.claude/skills/do-next-slice/SKILL.md` step 3).
- The executors' `tools:` allowlist doesn't name it either.

**Consequence for criterion 3, and the key screening input:** background subagents keep **every MCP tool** and **Bash**. Any candidate reached through MCP or files and shell passes criterion 3 structurally, while a built-in tool (`DesignSync`, the new `ClaudeDesign`) cannot.

---

## 3. Reading (b): Claude Design's intended use vs ours

**Verdict: verified. The orchestrator's reading holds, and the binary adds a stronger point.** Our loop uses `DesignSync` for something its own tool description says it is not for.

### Anthropic's intended flow

- **Design happens in Claude Design, conversationally, and is refined on the canvas.** *"refine through conversation, inline comments, direct edits, or custom sliders (made by Claude)"*. The export side: *"When a design is ready to build, Claude packages everything into a handoff bundle that you can pass to Claude Code with a single instruction."* Plans: *"available for Claude Pro, Max, Team, and Enterprise subscribers."* ([Anthropic, Introducing Claude Design](https://www.anthropic.com/news/claude-design-anthropic-labs))
- **The handoff is pushed from Claude Design into Claude Code:** *"Send to local coding agent" or "Send to Claude Code Web"*, and Claude Code *"continues from your existing work instead of starting over."* ([Get started with Claude Design](https://support.claude.com/en/articles/14604416-get-started-with-claude-design)). A third-party write-up adds: *"The bundle is included in the Claude Code session's context"* ([Claude Code Playbook](https://claude-code-playbook.pages.dev/en/docs/level-4/claude-design-handoff), not first-party).
- **Design memory lives in org-level design systems.** They are *"artifacts Claude can use in any chat, including in Claude Code"*, created from chat, or from code with `/design-sync`, which *"reads your tokens and components directly, and works best for product design systems in code"*. They are managed under Settings > Design systems, and are *"in beta on Pro, Max, Team, and Enterprise plans"* ([Set up your design system](https://support.claude.com/en/articles/14604397-set-up-your-design-system-in-claude-design)).
- **What `DesignSync` is for, from its own tool description** in binary 2.1.284 (≈184446698): *"Read and update the user's claude.ai/design design-system projects through their claude.ai login (or, for sessions without one, a dedicated design authorization from /design-login). **Use this only with the /design-sync skill, which the user starts, to keep a local component library in sync with one of those projects — incrementally, one component at a time, never as a wholesale replace.**"* The `/design-sync` command description: *"Push a React design system to claude.ai/design. This runs a converter that bundles the real component code (from Storybook or a bare package) and uploads it."* Both `/design-sync` and `/design` carry `disableModelInvocation:!0`.
- **A native agent path now exists behind a flag.** Claude Code 2.1.284 also ships a `ClaudeDesign` tool that can list, create and write projects, `render_preview`, and read the design-conversation transcript. It is gated by GrowthBook flag `tengu_omelette_fouet` (default off) and the same first-party checks (`hwe()`, ≈192842773). Its prompt: *"a collaborative canvas … a Design project is a live shared canvas the user can open and edit alongside you."* It is a built-in, so background subagents would drop it too.

### Where ours diverges

1. **Direction.** The native flow is *design in Claude Design → push a bundle into Claude Code*. Ours is *the repo writes `handoff.md` → the operator carries it into Claude Design → the agent pulls the result back with `DesignSync`*.
2. **Tool purpose.** `DesignSync` is described for `/design-sync`'s push of a code component library. We use it to read back design rounds (`list_files`/`get_file`) and for the SIGNOFF regroup write (`finalize_plan` → `write_files`). Both are outside "use this only with the /design-sync skill".
3. **Review surface.** We repurpose the Design System pane's `@dsCard` component-preview index (built for synced libraries) as a round-review board with round-addressed groups. The native review surface is the canvas with inline comments.
4. **Record.** Our design-cowork skill already accepts the native handoff bundle as the record. That part converges; the rest of the loop does not.

---

## 4. Longlist screened against the 5 criteria

The criteria:
- **C1:** runs in both `claude` and `ocx claude`.
- **C2:** no vendor SaaS account and no paid subscription.
- **C3:** executor subagents can drive it.
- **C4:** a frames/cards surface for the operator.
- **C5:** persistent design memory.

`pass` / `fail` / `unclear`. **Musts** = R1–R8 from §1.

Two notes apply to every row:
- **MCP under ocx** works as MCP does anywhere; the proxy only carries model traffic. One cost: under a non-first-party `ANTHROPIC_BASE_URL`, Claude Code disables MCP tool-search deferral, so every MCP schema is inlined (ocx `claude.ts` ~366, issue #4838).
- **C3 for MCP- or file-based tools** rests on the sub-agents doc quoted in §2.

GitHub metadata comes from `api.github.com/repos/<r>`, fetched 2026-09-29.

| # | Candidate | C1 | C2 | C3 | C4 | C5 | Musts | Source |
|---|---|---|---|---|---|---|---|---|
| 0 | **Claude Design + `DesignSync` (baseline)** | unclear. Stock ocx fails; `/design-login` strongly indicated to fix it | **fail**: Pro/Max/Team/Enterprise | **fail**: a built-in, dropped from background subagents | pass: Design System pane cards | pass: design-system projects | R4 and R7 need `DesignSync` (main thread) | §2, §3 |
| 1 | **Repo-native static frames board**: agent-written HTML cards (line-1 marker, numbered paths) plus a generated `board.html` index of grouped, numbered iframes at viewport sizes, served by `python3 -m http.server`; screenshot read-back via Aside `repl` over Bash | pass: files + Bash, no network | pass: zero deps (python3, Aside present here) | pass: Write/Bash/Read are all on the background list | pass, *once built*. The index is ours to write; no inline comments | pass: all in the repo (`tokens.css`, `DESIGN.md`, rounds, library) | all met. R7 becomes a repo line-1 edit proven by `git diff` | design-cowork §The card set; sub-agents doc |
| 2 | **Storybook (+ `@storybook/addon-mcp`)**: stories as cards | pass: local dev server; MCP at `localhost:6006/mcp` | pass: MIT; Chromatic optional; no account found | pass: CSF files via Write/Bash, plus MCP preview and story URLs | pass: sidebar groups by `title` hierarchy; per-story canvas; viewports | pass: stories, tokens and MDX docs in the repo | all met. R2 via `title`/file numbering; R7 = change only the `title` line; R10 via MCP preview | [Storybook MCP docs](https://storybook.js.org/docs/ai/mcp/overview); storybookjs/storybook MIT, 91k★ |
| 3 | **Ladle** (React-only story gallery) | pass | pass: MIT | pass: files | pass | pass | met, React products only | tajo/ladle MIT, 3.0k★; [dev.co summary](https://dev.co/testing/open-source/ladle) "only works with ReactJS" |
| 4 | **Histoire** (Vue/Svelte story gallery) | pass | pass: MIT | pass: files | pass | pass | met, Vue/Svelte only | histoire-dev/histoire MIT, 3.6k★ |
| 5 | **Penpot, self-hosted, + official MCP** | pass: local MCP, model-agnostic | pass: MPL-2.0, Docker Compose; a user on *your own* instance | **unclear**: MCP tools reach subagents, but *"the MCP setup requires an active Penpot session with the MCP plugin running in the browser"*, so it is not headless | pass: a real design canvas with boards, comments and components | pass: files, shared libraries, W3C DTCG tokens, but held in the instance DB, not the repo | R5 needs an export step; R7 unclear (rename a board/page?) | [Penpot MCP](https://help.penpot.app/mcp/); [self-host](https://penpot.app/self-host); penpot/penpot MPL-2.0, 60k★ |
| 6 | **Doop, self-hosted** (multiplayer agent canvas) | pass: MCP over HTTP at `localhost:4300/mcp` | pass: AGPL-3.0; `bun run dev` with embedded PGlite; a local user; LLM keys only for its optional resident agent | pass (docs): `create_frame`, `set_frame_html`, `get_frame_screenshot`, `get_feedback`, comments; MCP OAuth once per approving user | pass: multi-frame canvas, comments, activity feed | unclear: Postgres canvases persist, but no design-system or tokens feature is documented, and nothing lands in the repo | R5 needs export; R2/R7 via frame names, unverified | [kgoedecke/doop](https://github.com/kgoedecke/doop). **Young: created 2026-08-22, 777★** |
| 7 | **OpenDesign** (nexu-io) | unclear: it *spawns* agent CLIs itself or uses BYOK | pass: Apache-2.0, local-first, no account | **fail**: MCP is *"read-only by default"* for external agents; the app drives the agent, not the reverse | partial: one active artifact per project in an iframe; no multi-frame canvas described | pass: `design-systems/<brand>/DESIGN.md`, SQLite | R3/R4 inverted | [nexu-io/open-design](https://github.com/nexu-io/open-design) Apache-2.0, 98.6k★ |
| 8 | **Open CoDesign** | unclear: BYOK, many providers | pass: MIT, local Electron | **fail**: no CLI or MCP for external agents | partial: iframe with responsive frames, comment mode | partial: `DESIGN.md` | R4 fails | [open-codesign](https://github.com/opencoworkai/open-codesign) MIT, 8k★ |
| 9 | **Excalidraw (+ community MCP)** | pass | pass: MIT; local canvas server | pass: MCP or `.excalidraw` JSON files | **fail**: whiteboard/wireframe fidelity; cannot show real tokens or type | pass: files in the repo | R3 at wireframe grade only | [yctimlin/mcp_excalidraw](https://github.com/yctimlin/mcp_excalidraw) MIT; excalidraw MIT, 133k★ |
| 10 | **tldraw (+ community MCPs)** | pass | unclear: SDK needs a licence key in production (hobby or commercial; dev use free) | pass: `.tldr` files or MCP | **fail**: diagrams; the official MCP app has shape tools, no HTML/UI rendering | pass: `.tldr` in the repo | R3 not met | [tldraw license](https://tldraw.dev/community/license); [tldraw MCP app](https://tldraw.dev/blog/tldraw-mcp-app) |
| 11 | **draw.io + official `drawio-mcp`** | pass | pass: Apache-2.0; `npx @drawio/mcp` or local Docker | pass | **fail**: diagram and wireframe shapes, not rendered UI frames | pass: `.drawio` XML | R3 not met | [jgraph/drawio-mcp](https://github.com/jgraph/drawio-mcp) Apache-2.0 |
| 12 | **pen.dev (ex-Pencil)**: `.pen` JSON canvas, MCP, CLI | pass | **fail**: *"The CLI requires authentication"* against `api.pen.dev`; not open source; free today | pass | pass | pass: `.pen` files in the repo | — | [pen CLI docs](https://docs.pencil.dev/for-developers/pen-cli) |
| 13 | **Onlook** (visual editor on the live app) | unclear | **fail**: self-host needs Supabase, CodeSandbox, and OpenRouter/Anthropic keys | unclear | pass | pass: edits code | — | [onlook-dev/onlook](https://github.com/onlook-dev/onlook) Apache-2.0 |
| 14 | **Superdesign** | — | **fail**: the maintained product is the web app | — | — | — | the open-source IDE extension is *"no longer actively maintained"*. Its `.superdesign/` local-HTML-iterations idea is what #1 generalizes | [superdesign](https://github.com/superdesigndev/superdesign) |
| 15 | **Figma (+ MCP / Make)** | pass | **fail**: write-to-canvas needs a Full/Dev seat on a paid plan | pass | pass | pass | — | [Figma MCP guide](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server) |
| 16 | **Other SaaS canvases** (Paper, Google Stitch, v0, Framer) | — | **fail**: hosted accounts | — | — | — | — | [doop.design comparison](https://doop.design/blog/claude-design-alternatives) (vendor-authored, used only for the account column) |

Two things are **not a surface, so not a candidate**. Anthropic's `frontend-design` plugin is a drafting-quality aid any repo-native option may use "only if needed". Aside is the agent's browser instrument for visual read-back.

---

## 5. Shortlist (4) and why

1. **Repo-native static frames board.** It is the only option that passes all five with **zero** dependencies. It maps 1:1 onto the existing card contract: numbered paths, a line-1 group marker, and a regroup that rewrites line 1 only, proven by `git diff`. The whole design memory sits in the repo. Its cost is that the operator surface (the board index) is ours to build and maintain, and it has no inline comments or direct editing (R9).
2. **Storybook (+ addon-mcp).** It passes all five. It is mature (MIT, 91k★) and the most "real": stories render the product's actual components and tokens, which also shortens the apply phase. Its costs:
   - It adds a Node/Storybook toolchain to each *product* repo.
   - Surfaces that do not exist yet must be drafted as story-local markup.
   - Non-JS products need `@storybook/html` or the server renderer.
   - Ladle and Histoire are its lighter framework-specific variants, folded in here rather than listed.
3. **Penpot, self-hosted, + official MCP.** This is the one genuine *design canvas* that passes C1, C2, C4 and C5: a Figma-class editor where the operator can edit and comment directly (R9). It made the list despite C3 being **unclear**, because the plugin-tab constraint may be solvable (the agent's own Aside profile could hold the tab). Its costs: heavy infrastructure (Postgres, Valkey, object storage), and memory that lives outside the repo, so R5 needs an export step.
4. **Doop, self-hosted.** Its MCP is the closest match to what Claude Design does for an agent: create and stream HTML frames, screenshot them, read and resolve the operator's comments. It is local with embedded PGlite. Its costs: it is **five weeks old** (created 2026-08-22, 777★, AGPL-3.0), C5 is unclear (no documented design-system or tokens feature), and records live in its DB.

### Notable near-misses

- **pen.dev** is the best UX match on paper (`.pen` in the repo, MCP, CLI), but it fails C2: a mandatory login against `api.pen.dev`, closed source, and "free" only for now.
- **OpenDesign** is Apache-2.0, local and hugely popular, but the control is inverted: the app spawns the agent, and external agents get read-only MCP. It also shows one artifact at a time, not a frames board.
- **Excalidraw, tldraw and draw.io** are agent-drivable and file-persistent, but they are diagram and wireframe tools. They cannot show a design at real token and type fidelity (C4). tldraw also carries a production licence key.
- **Ladle and Histoire** are folded into Storybook as framework-limited variants.
- **Open CoDesign, Onlook, Superdesign and Figma** fail C3 or C2 outright.

---

## 6. Probes, dead ends, and what was not done

- **Binary reads:** Python byte searches over `~/.local/share/claude/versions/2.1.284`. Contexts were written to the scratchpad (`designsync_ctx.txt`, outside the repo).
  - Dead end: `grep -o` with a 300-char context window hit ugrep's regex complexity limit, so I switched to Python.
  - Dead end: a regex hunt for a named subagent exclusion of `DesignSync` found only telemetry references. The public sub-agents doc then settled the question.
- **ocx:** only read-only `--help`, `config status`, `status` and `resolve --json`, plus reading the source. I deliberately did **not** run `ocx claude`. It rewrites `~/.claude/agents/ocx-*.md` and the gateway model cache on every launch (`cmdClaude`, `claude.ts` ~800–833), and it would spend the operator's Kiro quota.
- **Not done, by the hard limits:**
  - No live `DesignSync` call and no `/design-login`, since both need the operator's claude.ai account.
  - No self-hosted Penpot or Doop instance, since both need a local user account created. Whether that counts as "account creation" is flagged for S2 in `phase.md`.
  - No Storybook install.
- `claude auth status` ran in the scratchpad cwd. Only non-identifying fields were printed; the email and org fields were deliberately dropped.

## 7. Validation

- `python3 scripts/workflow.py validate`: exit 0 (run after the `phase.md` edit).
- `git status --short`: changes only under `works/`. That is `works/phases/active/P25/…` (this `result.md`, `phase.md`) plus the generated files (`works/backlog.md`, `works/events.jsonl`, `works/index.json`, `works/state.json`) the orchestrator's `start-slice` had already modified before dispatch.
