# Result — P25.S2 (research): evaluate the shortlist and rank the top 3

## Verdict

- **status:** done
- **tier:** high
- **summary:** Probed three of the four shortlisted options live in scratch and read Doop from its docs and source. The ranking is: **1. a repo-native frames board**, **2. Storybook (+ addon-mcp)**, **3. self-hosted Penpot + its built-in MCP**. Doop drops out: it is five weeks old, has effectively one maintainer, keeps its memory outside the repo and allows MCP access only through OAuth. The recommendation on Claude Design is to **retire the `DesignSync` read-back/regroup loop**. Claude Design stays only as an optional, operator-driven import of its native handoff bundle.
- **files_changed:** `works/phases/active/P25/slices/P25.S2/result.md` (new); `works/phases/active/P25/phase.md` (`## Decisions`, `## Operator Questions`, `## Notes for later slices`, `## Now`)
- **validation:**
  - `python3 scripts/workflow.py validate`: passed (exit 0).
  - `git status --short`: only `works/` changes.
  - `docker ps -a`: no container this slice started. The scratch Penpot stack was torn down with `down -v` and its 8 pulled images were removed. §8 has the one baseline difference, which this slice did not cause.
- **deviations:**
  - **Doop was judged from docs and source, not probed live.** The plan allows this. A probe could not have answered its decisive question, and running it would have broken the 127.0.0.1-only condition (§3.4).
  - **Penpot's `export_shape` PNG path is unverified.** The exporter was OOM-killed under the memory cap I set to protect the operator's running containers, and I chose not to raise the cap (§3.3).
  - **Aside was not used.** This repo records no `## Operator Runtime` and no agent account id. Every browser read-back ran in throwaway headless Chromium contexts driven by Playwright from scratch.
  - No product code, no machinery edits, no repo installs, no vendor or operator accounts.
- **doc_impact:** none. The phase is findings-only, and the existing "(none …) (P25.DECOMP)" line stands.

**Notebook:** the ranked summary and the Claude Design recommendation are in `phase.md` `## Decisions`. The operator's picking questions are in `## Operator Questions`, and the handoff to `P25.REVIEW` is in `## Now`. This file is the full report and evidence log.

Scratch artifacts, all outside the repo and never shipped, are in the session scratchpad `…/1aa717b3-0250-45dc-9d55-868a00349f51/scratchpad/`: `board/`, `sb/`, `penpot/`, `doop/`, `pw/` (screenshots in `pw/shots/`), and `mcpcall.py`.

---

## 1. Executive summary

| Rank | Option | Why it ranks here | What it costs |
|---|---|---|---|
| **1** | **Repo-native frames board.** Agent-written numbered HTML cards, a generated `board.html` index and a small check/regroup script, all in the repo. | It passes all five criteria with **zero dependencies** and **zero MCP cost**. Every tool-specific must was verified in a working prototype: R3 view, R4 read-back (textual and visual), R7 regroup (one-line diff). The whole design memory is the repo plus git. It keeps today's card contract (`@dsCard` line 1, numbered paths) almost unchanged. | We build and maintain the board (~150 lines of Python in the probe). The operator gets **no on-canvas editing and no element-pinned comments**. Feedback comes back through per-card notes (verified) and the operator's words at their return. Draft quality rests on the drafting model, with `frontend-design` for rounds that set a new visual direction. |
| **2** | **Storybook 10.6 + `@storybook/addon-mcp`** | It passes all five. It is mature and MIT-licensed. For **JS component-library products it renders the real components and tokens**, which also shortens the apply work. An R7 regroup changes only the `title` line, and story URLs stay stable when each card sets an explicit meta `id` (verified). An MDX page gives a one-page round board (verified). | A toolchain in each product repo: 4 devDeps, ~100 MB, 212 packages, ESM config. The canvas shows one story at a time, and the MDX board renders at docs width, not at per-card viewports. The MCP adds little outside React: only the 4-tool dev toolset works on `html-vite`, costing ~3.6k tokens per turn if registered session-wide under ocx. For non-JS products it is a heavier frames board. |
| **3** | **Self-hosted Penpot 2.18 + built-in MCP** | This is the **only real design canvas**: direct edits, pinned comments, token sets and live multiplayer (all verified). The criterion that looked decisive, **C3, passes conditionally**. A background client drives the file only while a Penpot tab holding the user's MCP connection is open, and an **agent-held headless tab works** (verified). | Heavy infra: 8 images, **~7.5 GB pulled**, ~1.0–1.4 GB RAM idle. The agent-tab sidecar must be running before any drafting. **Memory lives in the instance DB**, so R5 needs an export step every round, and HTML/CSS export is absolute-positioned, inspect-grade. The MCP is labelled beta. Agent and operator must be **separate Penpot users** (verified hazard, §3.3). |
| dropped | **Self-hosted Doop** | It is the closest to Claude Design's agent UX (HTML frames, screenshots, comments, style guides, saved decisions over MCP). | It is **five weeks old** (created 2026-08-22), and **86% of its commits come from one author**. Memory lives in its DB with **no tokens**. MCP is **OAuth-only**, so background use depends on one interactive approval plus an unverified connection reuse. It has no published image, and its server binds all interfaces. It is worth re-checking once it matures (§3.4). |

**Claude Design:** retire the `DesignSync`-driven loop, both the read-back and the SIGNOFF regroup write. Claude Design remains optional in **its native form only**. The operator designs in Claude Design on their own paid plan, then hands the **handoff bundle** into the repo. The agent files it into the record as-is, and the rest of the loop runs on the chosen replacement. I do **not** recommend keeping the current pull loop as an opt-in behind `/design-login`:
- it is main-thread only;
- it needs a paid plan;
- it runs outside `DesignSync`'s own stated purpose;
- it would double the skill.

Still unverified: `/design-login` under ocx, whether "Send to local coding agent" reaches an `ocx claude` session, and how a bundle's files map onto numbered card paths (§6).

**What hinges on your preference.** The two entries now in `phase.md` `## Operator Questions`:
- **(a) What are your design-bearing products built on?** If they are mostly JS/React with a real component library, Storybook overtakes the frames board. Mixed or non-JS stacks favour the board, which is how I ranked it.
- **(b) Do you want on-canvas editing and pinned comments (R9) enough to run Penpot's stack and a held agent tab?** If yes, Penpot moves up.

---

## 2. Trade-off table

Legend:
- **✓** passes.
- **✓v** passes and was **verified in this slice's probe**.
- **◐** passes with a stated condition.
- **✗** fails.
- **?** unverified.

"Docs" or "src" means the claim was read, not probed. Section refs point at the evidence below.

| | Frames board | Storybook + addon-mcp | Penpot + MCP | Doop (dropped) | Claude Design (baseline, S1) |
|---|---|---|---|---|---|
| **C1** both `claude` and `ocx claude` | ✓v files + `python3` + headless browser; no provider involvement (§3.1) | ✓v local dev server, MCP over plain HTTP (§3.2) | ✓v MCP over plain HTTP from a non-Claude client (§3.3) | ✓ docs: HTTP MCP; OAuth is to the local instance, not a model vendor | stock ocx ✗; `/design-login` strongly indicated (S1) |
| **C2** no SaaS account, no paid plan | ✓v zero deps | ✓v MIT, no account prompt; telemetry is on by default and must be disabled | ✓v MPL-2.0, throwaway local user; upstream compose enables telemetry by default | ✓ src: AGPL, local user; model keys optional | ✗ Pro/Max/Team/Enterprise |
| **C3** executor subagents can drive it | ✓v Write/Bash/Read + headless screenshots | ✓v files + HTTP MCP (background subagents keep MCP tools) | ◐v only while a tab holds the user's MCP connection; an agent-held headless tab works (sidecar) | ◐ docs: one interactive OAuth approval; reuse by subagents strongly indicated, **?** live | ✗ built-in, dropped from background subagents |
| **C4** frames/cards surface | ✓v basic board: grouped, numbered, viewport frames, round address; no element comments or direct edits | ◐v sidebar tree + one canvas at a time; MDX round board at docs width | ✓v real canvas: pages/boards, comments, direct edits, live multiplayer | ✓ docs: HTML-frame canvas, comments, live streaming | ✓ Design System pane |
| **C5** persistent design memory | ✓ repo: `tokens.css`, cumulative card library, rounds, SIGNOFF, git | ✓ repo: stories, tokens, MDX, git | ◐v file, library, **token sets** (verified), comments, history, all **in the instance DB** | ◐ src: style guides, pinned references, saved decisions, all in its DB; **no tokens** | ✓ org design-system projects |
| **R2** numbered, grouped units | ✓v numbered paths + `group` | ✓v `title` path + numbered file | ✓v page = group, board = `NN-slug` | ◐ src: frame names only; no group primitive | ✓ |
| **R3** operator view renders the cards | ✓v | ✓v | ✓v | ✓ docs | ✓ |
| **R4** executor read-back | ✓v contract check + per-card screenshots | ✓v `/index.json` + preview URLs + iframe screenshots | ✓v MCP listing of pages/boards, comments read; `export_shape` PNG **?** (§3.3) | ✓ docs: `get_canvas`/`get_frame`/`get_frame_screenshot` | main thread only |
| **R5** durable repo record | ✓ native | ✓ native | ◐v export step each round; `generateMarkup`/`generateStyle` produce absolute-positioned HTML/CSS | ◐ src: export step (`get_frame` HTML, `export_frame` public PNG URLs) | ✓ bundle |
| **R6** memory survives rounds and sessions | = C5 | = C5 | = C5 | = C5 | = C5 |
| **R7** label separable from content | ✓v line-1 rewrite; `git diff` 1/1 per card; idempotent | ✓v `title`-only diff; ids stable with an explicit meta `id` | ✓v page rename; shape content hash identical | ? `update_frame` rename (src), not probed | main thread only |
| **R8** operator decides, immutable rounds | ✓ governance, tool-independent | ✓ | ✓ | ✓ | ✓ |
| **Setup cost** | small: build the board script + skill rewrite | per product repo: 4 devDeps, ~100 MB, 212 pkgs, ~33 s install, ESM | ~7.5 GB images, ~5 min pull, ~1.0–1.4 GB RAM, user + MCP key + agent-tab sidecar | bun + build from source; one OAuth approval | paid plan; `/design-login` under ocx |
| **Ongoing maintenance** | ours (small, fully owned) | upstream; fast-moving addon (10.x) | upstream, mature; MCP is beta; open bug #11957 on background plugins | upstream, 5 weeks old, bus factor ≈ 1 | upstream, flag-gated churn (`ClaudeDesign`) |
| **MCP schema cost per turn under ocx**, if registered session-wide | **0** (no MCP) | **~3.6k tokens** (4 tools, 14,406 chars, measured) | **~0.9k tokens** (4 tools, 3,643 chars, measured), plus a 29,430-char overview agents are told to read first | ~6k tokens (32 tools; crude estimate from source), plus a 24.9k-char guide | n/a (built-in) |

**The MCP-cost mitigation applies to every MCP option.** Claude Code's sub-agents doc: *"To keep an MCP server out of the main conversation entirely and avoid its tool descriptions consuming context there, define it inline here [the subagent's `mcpServers:` field] rather than in `.mcp.json`. The subagent gets the tools; the parent conversation doesn't."* ([sub-agents](https://code.claude.com/docs/en/sub-agents)). Under ocx, deferral is off (S1), so this is the adoption-time lever: scope the server to a drafting subagent only. Whether an **OAuth** server (Doop) can be first authorized from an inline, backgrounded definition is not documented, so that is **?**.

---

## 3. Probes and evidence

The environment: `docker info` gave Docker Desktop 28.2.2, 12 CPUs, a **3.83 GiB VM shared with the operator's running `changple5` stack (~1.8 GiB in use)**. That VM limit shaped the Penpot probe. Node 24.3.0, Python 3.9 (system). Browser: the cached Playwright `chromium_headless_shell-1223`, driven by `playwright@1.63.0` installed in `scratch/pw/`; every launch used a fresh throwaway context. The dedicated MCP client was `scratch/mcpcall.py`, a ~60-line streamable-HTTP JSON-RPC client that runs initialize → tools/list or tools/call. It stands in for "any MCP client", which is what a background subagent's MCP tool reaches.

### 3.1 Frames board: scratch prototype (`scratch/board/`)

**What was built:**
- A toy round `P99.S1`: `design/tokens.css`, four cards and a `rounds/01-signin/handoff.md` listing the numbered paths.
  - `cards/01-colors.html` and `02-type.html`: group `⏳ P99.S1 · Foundations`, viewport `960x320`.
  - `cards/03-button.html` (`480x200`) and `04-signin.html` (`390x600`): group `⏳ P99.S1 · Components`.
  - Line 1 of each is today's marker, e.g. `<!-- @dsCard group="⏳ P99.S1 · Components" viewport="480x200" -->`.
- `board.py`, a throwaway script of ~150 lines with three commands:
  - `build` writes `board.html` and a `manifest.json`, the textual index that plays `_ds_manifest.json`'s role.
  - `check <paths…>` runs the card-contract check.
  - `regroup <round> <paths…>` rewrites line 1 only and asserts every byte after line 1 is unchanged.

**Outcomes:**
- `python3 board.py build design` → `{"cards": 4, "groups": ["⏳ P99.S1 · Foundations", "⏳ P99.S1 · Components"], "problems": []}`. Round-addressed groups sort first, and cards follow numbered order within each group.
- `python3 board.py check design cards/01-colors.html … cards/04-signin.html` → `{"ok": true, …}`, exit 0.
- **Negative test:** with `02-type.html` renamed `type.html`, the check returned `{"ok": false, "missing": ["cards/02-type.html"], "gaps": [2], "problems": ["type.html: unnumbered card path"], …}`, exit 1. The first run over-reported gaps: unnumbered cards were counted as number 999. I fixed that in the probe script.
- **Operator view:** `python3 -m http.server 8765 --bind 127.0.0.1`, then `pw/readback.mjs` loaded `board.html` headlessly.
  - DOM read-back: `[{"group":"⏳ P99.S1 · Foundations","cards":["cards/01-colors.html","cards/02-type.html"]},{"group":"⏳ P99.S1 · Components","cards":["cards/03-button.html","cards/04-signin.html"]}]`.
  - Screenshot `pw/shots/board.png`, which I viewed: a sticky header reading "under review: P99.S1 · 4 cards"; two orange round-addressed group headings; each card in an iframe at its own viewport, scaled to fit, with its path, size and an "open" link.
- **Executor visual read-back:** a per-card screenshot at the card's own viewport (`pw/shots/01-colors.png` … `04-signin.png`) plus its text, e.g. `card cards/04-signin.html @390x600 -> … text="Sign in to Acme We'll send a magic link to your work email. Work email Send magi…"`.
- **Operator feedback, settled:** each card has a note field persisted in the browser's `localStorage`, and a header button "Copy notes as markdown". Probe: typed a note on card 03, clicked, and read `"- \`cards/03-button.html\`: secondary button too faint on dark"`. Feedback therefore returns through three channels, none needing a server:
  1. The operator's words at their return, referencing card numbers. This is today's channel; SIGNOFF words are taken there anyway.
  2. The copied notes block, pasted into the session.
  3. Optionally, a `rounds/<NN>/feedback.md` the operator edits. That one is reasoned, not probed.

  A design question still opens a superseding round (R8), unchanged.
- **R7 regroup:** `git init` in `design/` and committed, then `regroup` ran twice.
  - The second run printed `already clean` (idempotent).
  - `git diff --numstat` gave `1 1` for each of the 4 cards.
  - `git diff -U0` shows only line 1: `-<!-- @dsCard group="⏳ P99.S1 · Components" …` / `+<!-- @dsCard group="Components" …`.
  - A rebuild gives groups `["Foundations", "Components"]`: the clean library taxonomy, paths and numbers unchanged.
- **Not built:** live refresh (the operator reloads), zoom/pan, and element-pinned comments. Live refresh is a small poll the adoption phase can add; the other two are the honest gap against Claude Design and Penpot.

### 3.2 Storybook 10.6 + addon-mcp: scratch install (`scratch/sb/`)

- `npx -y storybook@10.6.0 init --type html --builder vite --features docs ai --no-dev --yes --disable-telemetry --package-manager npm --no-agent`: 20:05:53 → 20:06:26, **33 s**, exit 0. The `ai` feature added `@storybook/addon-mcp`.
- **Footprint** (`package.json` + `du`): devDeps `storybook`, `@storybook/html-vite`, `@storybook/addon-docs`, `@storybook/addon-mcp` (all `^10.6.0`); `node_modules` **100 MB**, 92 top-level entries, **212 packages** (`npm ls --all --parseable`).
- **Dead end:** the first `storybook dev` died with `SyntaxError: Unexpected token 'export'`. `npm init -y` (npm 11.4) wrote `"type": "commonjs"`, while the generated `.storybook/main.js` is ESM. Setting `"type": "module"` fixed it, and the next start was **ready in ~4 s** on `--host 127.0.0.1 -p 6006`. A product repo needs an ESM-compatible config.
- **Drafting surfaces that don't exist in code:** four stories under `cards/0N-*.stories.js` with **story-local markup** (`render: () => \`<button …>\``) and `import './tokens.css'`. Each sets `title: '⏳ P99.S1/<Group>/<NN> <Name>'` and an **explicit meta `id: 'card-<NN>-<slug>'`**.
- **Index** (`/index.json`): `card-01-colors--default | ⏳ P99.S1/Foundations/01 Colors`, and so on for 02–04.
- **MCP** (`mcpcall.py http://127.0.0.1:6006/mcp list`): server `@storybook/addon-mcp 10.6.0`, **4 tools, 14,406 chars**:
  - `stories-preview` 7,139 chars;
  - `stories-find-by-component` 5,111;
  - `get-storybook-story-instructions` 1,427;
  - `stories-changed` 721.

  So on `html-vite` **only the dev toolset** exists. The docs toolset (`docs-list`/`docs-show`/`docs-show-story`) needs a components manifest, which the docs grant to React frameworks, `angular-vite` and `vue3-vite` (behind a flag) only ([Storybook MCP docs](https://storybook.js.org/docs/ai/mcp/overview)). `test-run` needs the test addon, and `review-create` needs Storybook's review feature. Neither was installed, and neither was probed.
- `stories-preview` with `card-03-button--default` and `card-04-signin--default` (+ `globals.viewport.value: mobile1`) returned **URLs only**, e.g. `http://localhost:6006/?path=/story/card-04-signin--default&globals=viewport.value:mobile1`. The docs say it renders inline only for clients that support MCP Apps. So a visual read-back still needs a browser; the probe screenshotted `iframe.html?id=…` headlessly (`pw/shots/sb-iframe-before.png`).
- `stories-changed` failed outside a git repo: `git rev-parse --show-toplevel failed`. A product repo is a git repo, so this is not a real limitation.
- **Operator view:** `pw/shots/sb-before.png` shows a sidebar with a `⏳ P99.S1` root holding `Foundations` and `Components` folders, `03 Button` and `04 Sign-in`, and one story on the canvas.
  - **Round board:** `cards/00-review.mdx` (`<Meta title="⏳ P99.S1/00 Round board" />` + `<Canvas of={…}>` per card under `## Foundations` / `## Components`) rendered all four cards on one page (`pw/shots/sb-board.png`, viewed).
  - **Caveat:** docs mode renders stories **inline at docs width on the docs theme**. The type card's dark body style did not apply. So it is not the per-card-viewport view a frames board gives. Per-viewport review happens one story at a time through the viewport toolbar.
- **R7 regroup:** `git init` + commit, then `sed` stripped `⏳ P99.S1/` from each `title`.
  - `git diff --numstat`: `1 1` per story file. `--word-diff` shows **only the title string** changed.
  - `/index.json` afterwards: `card-03-button--default | Components/03 Button`. **The ids and URLs are unchanged.**
  - Without an explicit `id`, ids derive from the title, as the MDX entry shows: `⏳-p99-s1-00-round-board--docs`. A regroup would then change every story URL, which matters only if URLs are recorded (e.g. in `build-prompt.md` or SIGNOFF). **Rule for adoption: always set the meta `id`.**
- **Telemetry:** Storybook's anonymous telemetry is **on by default** ([Storybook telemetry](https://storybook.js.org/docs/configure/telemetry)). `core.disableTelemetry` and `--disable-telemetry` turn it off, but a metadata-free `boot` event is still sent before the config is read. Only `STORYBOOK_DISABLE_TELEMETRY=true` stops everything, and the probe set it on every run. It is not an account, but a C2-minded adoption should set that variable.
- **Non-React products:** `html-vite` works, as the probe shows, but then stories are story-local markup, which is a frames board with a heavier toolchain. Storybook's real advantage (R11: rendering the product's own components) exists only where the product's components are importable into Storybook.

### 3.3 Penpot 2.18 self-hosted + built-in MCP: scratch instance (`scratch/penpot/`)

**Set-up:**
- **Compose file:** derived from `penpot/penpot` `docker/images/docker-compose.yaml` (2.18, fetched into scratch).
  - The upstream file already ships `enable-mcp`, a `penpotapp/mcp` service, and `PENPOT_TELEMETRY_ENABLED: "true"`.
  - My scratch changes: port `127.0.0.1:9001` only; `restart: "no"`; telemetry off; no SMTP/mailcatch; no admin console; `enable-registration`; `disable-email-verification`.
  - **Per-container `mem_limit`s**, so the stack could not starve the operator's containers in the shared VM.
- **Pull:** `docker compose -p p25s2-penpot pull` took **4 min 55 s**.

  | Image (2.18) | Size |
  |---|---|
  | `exporter` | **3.32 GB** |
  | `backend` | 1.23 GB |
  | `frontend` | 1.06 GB |
  | `postgres:15` | 649 MB |
  | `admin-console` | 566 MB |
  | `mcp` | 287 MB |
  | `mailcatcher` | 228 MB |
  | `valkey` | 187 MB |

  That is ≈ **7.5 GB** in all, ≈ 6.7 GB without the two optional services.
- **Bring-up:** `up -d` to `get-profile` → 200 in **~14 s**.
- **Memory:** the frontend was **OOM-killed under a 192 MiB cap** (`OOMKilled=true`; its nginx runs 12 workers on 12 CPUs), so I raised it to 448 MiB. Idle use after that: backend 470–701 MiB, frontend 214–339 MiB, postgres 60–128, mcp 56–74, exporter 76–133, valkey 6–8. That is ≈ **1.0–1.4 GiB**.

**The throwaway user**, per the orchestrator's ruling:
- Created through the backend RPC: `prepare-register-profile` then `register-profile`, with `agent@p25s2-scratch.test` and a throwaway password → `isActive: true`.
- File created with `create-file` ("P25S2 design memory probe").
- A headless context logged in through the UI and opened **Settings → Integrations → MCP Server (labelled "Beta")**. It flipped the per-user switch and clicked "Generate MCP key".
- The page then shows the client URL `http://localhost:9001/mcp/stream?userToken=<key>`. The key was kept in scratch only and died with the instance.

**The MCP surface** (`mcpcall.py <url> list`): server `penpot 1.0.0`, **4 tools, 3,643 chars**: `execute_code`, `high_level_overview`, `penpot_api_info`, `export_shape`. There is no `import_image` in remote mode, matching [help.penpot.app/mcp](https://help.penpot.app/mcp/). `high_level_overview` returns **29,430 chars**, and every tool description tells the agent to read it first.

**C3, the decisive question:**
1. **No tab:** `execute_code` → `Tool execution failed: Error: No Penpot instance connected for user token. Please ensure that Penpot is connected …`.
2. **Agent-held headless tab** (`pw/pp_agent_tab.mjs`, a throwaway context holding only the scratch user's session). Opening the workspace **auto-connected** the built-in plugin. The console showed `Penpot version: 2.18.0, MCP version: 2.17.0` … `Connected to MCP server` … `MCP STATUS status="connected"`. No plugin install or click was needed.
   - My first attempt crashed on a menu click and closed the tab, which disconnected the plugin; that confirms the dependency.
   - The tab then held the connection for **340 s**, and every call succeeded while it did.
3. **The agent drafts over MCP.** One `execute_code` renamed page 1 to `⏳ P99.S1 · Foundations` and created boards `01-colors` (960×320) and `02-type` (960×320) with swatches and text. A second created page `⏳ P99.S1 · Components` with `03-button` (480×200) and `04-signin` (390×600).
4. **The operator views the same file** (`pw/pp_operator.mjs`, a second throwaway context standing in for the operator).
   - Its layers panel listed the agent's pages and boards.
   - While it stayed open, the agent created `06-live-added`. The operator's tab showed it **without a reload**: `layers after agent edit (no reload): … 06-live-added | 02-type | 01-colors`. Screenshot `pw/shots/pp-op3-2-live.png` (viewed) shows the boards, the new board, and two presence avatars.
5. **Hazard: one live tab per user token.** The operator's same-user tab was refused the connection and looped `connecting` → `Disconnected from MCP server` about once a second. A probe call proved the **agent tab kept executing**, with `executingTabPage: "⏳ P99.S1 · Components"` (the agent tab's page).
   - When the agent tab closed, the operator's tab **silently took over**. The next call ran there: `storage.tabTag` was absent, and `op4 console: Connected to MCP server`.
   - **So the agent and the operator must be separate Penpot users.** The operator's user keeps MCP off; only the agent's user enables it. That remedy is reasoned (the keys are per user) and was not probed with a second user.

**C3 verdict:** conditional pass. A background executor drives Penpot through MCP as long as an agent-held browser tab, a sidecar process, is running. The operator watches live from their own user.

**Plugin-API gotchas**, which an adoption skill must spell out:
- `penpot.openPage()` is asynchronous. A board created right after it landed on the *previous* page.
- Modifying a non-active page fails: `Value not valid: Cannot modify a page that is not currently active. Code: :remove`.

**R5 export path:**
- `penpot.generateStyle([board], {type:"css", withChildren:true})` and `generateMarkup([board], {type:"html"})` work.
- Their output is **absolute-positioned, per-shape CSS** (`.rectangle-b67c… { position: absolute; left: 24px; … background: #0f1115FF; }`). That is inspect-grade, not token-semantic, so the repo record needs a written `build-prompt.md`, not a code dump.
- `export_shape` (PNG, then SVG) failed with `page.evaluate: Target crashed` / `locator.waitFor: Target crashed`. `docker inspect` showed the **exporter `OOMKilled=true`** under its 320 MiB cap. The exporter is a headless Chromium and needs more than that. I did **not** raise the cap: the shared VM held the operator's live containers, and the headroom was ~0.4 GiB. So **PNG export is unverified here**; the docs list it.
- The agent's own tab can be screenshotted instead (shown above), which serves as a visual read-back without the exporter.

**R7:** a single `execute_code` renamed both pages (`⏳ P99.S1 · Foundations` → `Foundations`, and likewise Components), non-active page included. A hash over every shape's `[id, name, type, x, y, w, h, fills]` was **identical before and after**: 873554954 both times, over 10 + 11 shapes.
- **Mapping caveat, reasoned:** rounds accumulate. A later round's boards on an already-signed `Components` page would need either per-round pages that stay separate, or a move at signoff. A move is a content operation.
- A cleaner mapping is probably **signed boards → library components**, whose `/`-path is the display group. That is not probed.

**C5 and feedback:**
- A comment posted through the same RPC the UI uses (`create-comment-thread`, "01-colors: first swatch is invisible on the board fill") was read back by the agent via `page.findCommentThreads()` → `findComments()`.
- `penpot.library.local.tokens.addSet({name:"acme"})` + `addToken({type:"color", name:"color.accent", value:"#5B8CFF"})` read back as `[{"set":"acme","tokens":[["color.accent","#5B8CFF"]]}]`.
- Memory is real, but it lives **in the instance** (Postgres + an assets volume). The repo gets it only by export.

**Maturity:** penpot/penpot is MPL-2.0 with ~60k★ (S1). The MCP is labelled **Beta** in the UI. Open issue [#11957](https://github.com/penpot/penpot/issues/11957) (background MCP plugin loses its registry entry when another plugin opens) has a fix in a PR that was open when read.

### 3.4 Doop: docs and source only (`scratch/doop/`)

**Why no live probe:**
- No image is published: its `docker-compose.yml` uses `build: .` with Chromium.
- `server/index.ts:1764` calls `server.listen(PORT, …)` with no host, so a native `bun run dev` would bind **all interfaces**, against the 127.0.0.1-only condition.
- The MCP is **OAuth-only**: `server/mcp.ts` ~1443 returns 401 with `WWW-Authenticate: Bearer … resource_metadata=…`, "this MCP server requires OAuth".
- Most importantly, the decisive question, whether a background subagent reuses the parent's OAuth'd connection, is **Claude Code behaviour**. A scratch instance driven by my own client could not answer it.

**Maturity** (GitHub API, fetched 2026-09-29):
- Created **2026-08-22**, last push 2026-09-25; 777★, 95 forks, AGPL-3.0.
- **162 commits, 139 of them (86%) by `kgoedecke`**; 11 contributors.
- 14 releases, the latest `v0.6.0` on 2026-09-19 (plus `desktop-v0.4.0`).
- 27 issues, 13 open. The open ones include "Add support to import design system", "Figma import/export" and "New frames always go in one row instead of near where you're working".

**MCP surface** (`server/mcp.ts`): **32 tools**, more than the README lists.
- Design and read-back: `create_frame`, `set_frame_html`, `append_frame_html`, `edit_frame_html`, `get_frame`, `get_frame_screenshot`, `update_frame` (rename/move/resize), `get_canvas`, `get_comments`, `reply_to_comment`, `resolve_comment`, `get_feedback`.
- **Memory:** `list_guidelines` / `get_guidelines` / `set_guidelines` (per-canvas markdown style guides, max 24,000 chars), `get_reference` (pinned exemplar frames) and `save_decision` (records "a design decision your human made while talking to YOU").
- Export: `export_frame` returns **public, unauthenticated** PNG/JPG URLs.
- Size: names, descriptions and zod schemas come to ≈ 24k source chars. That is a crude estimate of ~6k tokens of schema; it was not measured. `server/guide.ts` (the `get_guide` playbook) is 24,909 chars.

**C5:** real but partial. Style guides, references and decisions live **in Doop's DB, per canvas**. There is **no tokens system**. The guideline "distiller" needs `ANTHROPIC_API_KEY` (README: it "quietly turns off without it").

**C3 and subagents:**
- Claude Code's MCP doc: OAuth tokens *"are stored securely and refreshed automatically"*. A 401 triggers a refresh and one retry. A rejected refresh token needs `/mcp` → Re-authenticate, which is interactive ([MCP](https://code.claude.com/docs/en/mcp)).
- The sub-agents doc: string-referenced servers *"share the parent session's connection"*, and a background subagent *"keeps every MCP tool"* ([sub-agents](https://code.claude.com/docs/en/sub-agents)).
- So reuse after one interactive approval is **strongly indicated, not verified live**. A token that needs re-authentication mid-run would stop a background executor until the operator re-approves.

**R2/R7:** frames have only names; there is no group or section primitive. Grouping would be per canvas or by name prefix, and a regroup would be an `update_frame` rename. That is plausible but unverified.

### 3.5 What was reasoned rather than probed

- **Background subagents and MCP** rest on the docs quoted in §3.4 and S1 §2. No background subagent was run against any server. My `mcpcall.py` is a stand-in client, so it proves the servers work headless over HTTP, not Claude Code's plumbing.
- **Doop** is entirely docs and source (§3.4).
- **Penpot PNG export** is from the docs only (§3.3).
- **`frontend-design`** was read from its local `SKILL.md`, not run (§5).

---

## 4. Loop mapping for the top 3 (governance untouched)

The fixed governance stays exactly as it is: the three styles, rounds, literal signoff, the mockup gate and RESPECT THE DESIGN. **One thing changes for every option, by the operator's confirmed framing ("agent drafts, you decide"):** a **drafting subagent** produces the round that the operator used to produce in Claude Design. PENDING #1 becomes "the operator reviews the drafted round and returns with their words".

### 4.1 Frames board (rank 1)

| Loop step | Mapping |
|---|---|
| `handoff.md` → draft | Same `handoff.md`, now the **drafting subagent's brief**. The required-output manifest names numbered card paths under the repo's design tree, e.g. `docs/reference/design/cards/NN-slug.html`, plus `tokens.css`, `rounds/<NN>/output/result.md` and `build-prompt.md`. The drafter writes cards with the line-1 `@dsCard group="⏳ P<N>.S<n> · <Group>" viewport="WxH"` marker, then runs `board build`. |
| Operator view | `board.html`, served locally (`python3 -m http.server --bind 127.0.0.1`, a command recorded in `## Operator Runtime`): round-addressed groups first, numbered order, per-card viewport frames, per-card notes with "copy as markdown". |
| Executor read-back | `board check <handoff paths>` for missing paths, gaps, unnumbered cards and markers. Reading the card files for the concreteness check. Per-card screenshots at their viewport through Aside `repl` on the agent's account, or the fallback real browser. |
| SIGNOFF regroup | `board regroup <round> <paths>` rewrites line 1 and asserts the rest byte-identical. The proof is a `git diff` of one line per card. It is a normal repo commit, with no remote write and no `finalize_plan` prompt. |
| Design memory | The repo: `tokens.css`, `cards/` (the cumulative library, superseded by path), `rounds/<NN>/` records, `SIGNOFF.md`, and git history for prior rounds. |

**What survives:**
- `handoff.md` survives. It stops being carried into Claude Design.
- The **numbered card contract survives unchanged**: the same marker, numbering and path stability.
- The regroup survives as a local, byte-checked edit.

**What changes:**
- The `DesignSync` read-back is **replaced** by `board check` plus file reads plus screenshots.
- "The cards stay in the design project — do not copy them down" **inverts**: the repo is the cards' only home, so there is no mirror problem.

### 4.2 Storybook (rank 2)

| Loop step | Mapping |
|---|---|
| `handoff.md` → draft | Same brief. Required outputs are story files `NN-slug.stories.*`, each with `title: '⏳ P<N>.S<n>/<Group>/<NN> <Name>'` and an **explicit meta `id: 'card-NN-slug'`**, plus a round MDX board page, `tokens.css` or the theme, and the record files. On component-library products, stories compose the real components; otherwise they are story-local markup. |
| Operator view | `storybook dev --host 127.0.0.1` (command and port in `## Operator Runtime`): the sidebar round folder, the MDX round board, and the canvas with its viewport toolbar per card. |
| Executor read-back | `/index.json` is the machine-checkable manifest (ids, titles, import paths) → the numbering and id check. `stories-preview` URLs over MCP, or `iframe.html?id=…` screenshots, give the visual read-back. |
| SIGNOFF regroup | Change **only the `title` string** (a one-line diff, verified). The ids and URLs are unchanged. The round's MDX board page is retired, deleted or re-titled under `Rounds/`. |
| Design memory | The repo: stories, tokens, MDX docs, records, git. |

**What survives:** `handoff.md` and the regroup, which becomes a title edit.

**What changes:**
- The card contract changes form: the line-1 marker becomes the `title` line plus the meta `id`, and numbers sit in the title and the file name.
- The `DesignSync` read-back is replaced by `/index.json` plus MCP or a browser.

### 4.3 Penpot (rank 3)

| Loop step | Mapping |
|---|---|
| `handoff.md` → draft | Same brief, plus the Penpot **file id**: target by id, never by name. Before dispatch, the **agent-tab sidecar** must be running: a headless browser on a throwaway profile, logged in as the **agent's** Penpot user, with the file open. The drafter, holding `mcp__penpot` tools scoped inline to it, creates pages `⏳ P<N>.S<n> · <Group>` and boards `NN-slug` at viewport sizes, and adds token sets. |
| Operator view | The Penpot workspace in the operator's own browser, as a **separate** Penpot user: live multiplayer, pinned comments, direct edits. |
| Executor read-back | `execute_code` lists pages and boards (names, numbers, sizes) → the card-contract check. `findCommentThreads` reads feedback. The visual read-back is `export_shape`, which needs an adequately sized exporter, or a screenshot of the agent tab. |
| Record (R5) | An **export step each round**: `generateMarkup`/`generateStyle` output, PNGs and a token-set JSON, landed into `rounds/<NN>/output/`, plus a written `build-prompt.md`. The apply executor never sees the canvas. |
| SIGNOFF regroup | A page rename (verified content-identical). A convention for accumulating rounds is needed (§3.3). |
| Design memory | The **instance** (file, library, token sets, comments, version history), which becomes a second source of truth to back up, plus the per-round exports in the repo. |

**What survives:** `handoff.md`, and the regroup as a page or component-path rename.

**What changes:**
- The card contract becomes board and page names.
- The `DesignSync` read-back becomes MCP `execute_code`.
- A new standing piece appears: the agent-tab sidecar.

---

## 5. Where `frontend-design` is needed

It is Anthropic's official plugin, installed here at `~/.claude/plugins/cache/claude-plugins-official/frontend-design/…/SKILL.md`. Its description reads: *"Guidance for distinctive, intentional visual design when building new UI or reshaping an existing one. Helps with aesthetic direction, typography, and making choices that don't read as templated defaults."*

- **Needed:** in the **drafting step of the HTML-authored options** (the frames board, and Storybook's story-local markup) on rounds that **set a visual direction**: a product's first round, a redesign, or a new brand or surface family. On those rounds nothing in the repo constrains the drafter, and "templated defaults" is exactly the failure a draft without it risks.
- **Not needed, and counter-productive:** on rounds that **extend an established system** (`tokens.css` plus a card library exist). There the drafter must follow the system, and a skill pushing for "distinctive" choices works against RESPECT THE DESIGN's spirit. The same goes for Storybook on a real component library, where drafts compose existing components.
- **Penpot:** it barely applies. Drafting is vector shapes through the Plugin API, not HTML/CSS; at most it serves as aesthetic prose.
- **Mechanics for adoption:** executors' `tools:` lists lack `Skill` (`.claude/agents/slice-executor-*.md`: `Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch`). Today's design-cowork also bans it ("Load `artifact-design` or `frontend-design` … they will make you design"). Both change in adoption, for the drafter only.

---

## 6. Claude Design: recommendation in full

**Recommendation.** Retire the `DesignSync`-driven loop, meaning the read-back and the SIGNOFF regroup write, and stop making Claude Design the loop's engine. Keep Claude Design only as an **optional, operator-driven import in its native form**. The operator, on their own paid plan and in their own session, designs in Claude Design. Then they either:
- push the handoff bundle into Claude Code ("Send to local coding agent", per S1 §3), or
- drop the bundle into the repo.

The agent files the bundle into the round record **as-is**. Where the bundle carries HTML previews, the agent files them as numbered cards on the chosen replacement's surface; that is filing, not designing. The rest of the loop (operator view, read-back, signoff, regroup, memory) runs on the chosen replacement. This is the form Anthropic designed, and design-cowork already accepts the bundle as the record (S1 §3, point 4).

**Why not keep the current loop as an opt-in (main thread only, paid plan, `/design-login` under ocx):**
1. **It fails C2 and C3 by construction.** It needs a paid plan, and `DesignSync` is a built-in that background subagents drop. That contradicts the operator's stated preference for subagent-handled design.
2. **It is fragile.** Our read-back and regroup use `DesignSync` for something its own description excludes: *"Use this only with the /design-sync skill, which the user starts…"* (S1 §3). The flag-gated `ClaudeDesign` tool (`tengu_omelette_fouet`) shows the surface is still moving. A loop built on an off-label use of a moving tool can break without notice.
3. **It doubles the skill.** Two loops means two read-backs, two regroups and two sets of halts in `design-cowork`, for a path that works in neither the operator's ocx setup (without `/design-login`) nor background executors.
4. **What the operator would lose** is Claude Design's own canvas (chat, inline comments, sliders) as the *drafting* surface. The bundle-import path keeps exactly that, for the operator, on demand.

**Still unverified** (all need the operator's claude.ai account, which this phase may not touch):
- whether `/design-login` makes `DesignSync` work under `ocx claude` (S1: strongly indicated);
- whether Claude Design's "Send to local coding agent" handoff reaches an `ocx claude` session (it pushes into Claude Code; the ocx proxy's effect on it is untested);
- how a real bundle's files map onto the numbered card contract. Filing may need a numbering step at landing; if so, the operator should confirm it at the first real import.

---

## 7. Adoption notes (for the later adoption phase; none of this was done here)

1. **`design-cowork` SKILL.md:**
   - Rewrite §The loop, §The handoff (the drafter's brief), §The card set (the repo is the home), §The design record (reverse "do not copy the cards down"), §Read back (the replacement's check + screenshots), §Closing the round step 5 (the local regroup + `git diff`), and §Mechanics (drop "DesignSync is main-thread only"; the drafter is dispatched).
   - In §Never, lift the `frontend-design` ban for the drafter on new-direction rounds, and drop the `DesignSync` delegation line.
   - In the frontmatter, drop `DesignSync` from `allowed-tools`.
   - Keep a short "import a Claude Design bundle" subsection.
2. **`CLAUDE.md` contract:** change the co-work rules. "`DesignSync` work is never dispatched" and "the mockup build is its one dispatched span" become "the drafting span is dispatched too". "Never invent visual decisions in an executor" becomes "a drafter drafts; nothing is decided until the operator's literal signoff".
3. **Executors:** either a new `.claude/agents/design-drafter.md` or a drafting mode of `slice-executor-high`.
   - Its `tools:` gains `Skill` (for `frontend-design`).
   - MCP options add `mcp__<server>` to `tools:`, **or** define the server inline in the agent's `mcpServers:`, which keeps the schemas out of the main thread (this matters under ocx).
   - The frames board needs no MCP at all.
4. **Engine:** a `design-board` command (`build` / `check` / `regroup`) in `scripts/workflow.py`, or a shipped script, plus `python3 installer/build.py` in the same commit.
5. **`## Operator Runtime` fields:**
   - the design surface: board serve command + URL / Storybook command + port / Penpot URL;
   - for Penpot, also the agent's Penpot user, the MCP-key location (never in the repo), and the agent-tab sidecar command;
   - the agent's Aside account id (already a field) for visual read-back.
6. **Record layout:** the cards tree moves into the repo's design record (`docs/reference/design/cards/` or the product's `design/`). For Storybook, the explicit-meta-`id` rule. For Penpot, the round-accumulation convention (§3.3).

---

## 8. Teardown, dead ends, and what was not done

**Teardown:**
- **Penpot:** `docker compose -p p25s2-penpot down -v` removed 6 containers, 2 volumes (`p25s2-penpot_penpot_postgres_v15`, `…_penpot_assets`) and the network. `docker rmi` then removed all 8 pulled images: `penpotapp/{frontend,backend,exporter,mcp,admin-console}:2.18`, `postgres:15`, `valkey/valkey:8.1`, `sj26/mailcatcher:latest`. None was in the pre-probe image baseline (`scratch/docker_images_baseline.txt`). Afterwards, `grep`s for `p25s2` containers or volumes and for the probe images all came back empty.
- **Servers and browsers:** the board `http.server` (8765), Storybook (6006) and both headless Penpot tabs were stopped. `lsof` shows ports 8765, 6006, 9001, 1080, 4300 and 4400 all free, and `pgrep` finds no probe process.
- **One difference from the container baseline, not caused by this slice:** three of the operator's containers (`changple5-django_backend-1`, `-celery_worker-1`, `-celery_beat-1`) have new container IDs. Their images were **rebuilt at 20:20:36 KST** and the containers recreated two seconds later. That is a `compose up --build` in the `changple5` project, run concurrently by the operator or another session; this slice touched only project `p25s2-penpot`. The other six `changple5` containers and `kb-p28s2-pg` are unchanged. The Penpot caps kept every OOM inside my own containers (`OOMKilled=true` only on `p25s2-*`).

**Left outside scratch:**
- the npm/npx cache entry for `storybook@10.6.0` (`~/.npm/_npx`) and the npm cache for the scratch installs;
- no new Playwright browser download: the probes reused the cached `chromium_headless_shell-1223`.

**Dead ends:**
- The Storybook ESM/CommonJS clash (§3.2).
- The Penpot frontend OOM at 192 MiB, which I fixed.
- A Penpot login attempt against the dead frontend.
- `waitUntil: 'networkidle'` hung on Penpot; I switched to `load`.
- The Penpot menu-click script crashed and dropped the MCP connection. The plugin auto-connects, so no click is needed.
- `openPage` asynchrony and the active-page-only rule (§3.3).
- The board check's gap over-report (§3.1).

**Not done:**
- No Doop instance (§3.4).
- No Penpot PNG export at a larger exporter cap (§3.3).
- No second Penpot user for the separate-users remedy (§3.3).
- No React Storybook, so the docs toolset was not probed.
- No Aside: no agent account id is recorded here.
- No background-subagent run against any MCP server (§3.5).
- No claude.ai account use, no `/design-login`, no `ocx claude` launch.

## 9. Validation

- `python3 scripts/workflow.py validate`: exit 0, run after the `phase.md` edit.
- `git status --short`: only `works/`. That is this slice's `result.md` and `phase.md`, plus `slice.json`, `plan.md` and the generated `works/` files the orchestrator's `start-slice` had already modified.
- `docker ps -a`: no `p25s2` container. The container set differs from the baseline only by the three operator-rebuilt `changple5` containers described in §8.
