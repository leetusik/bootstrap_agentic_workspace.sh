# Result — P9.S2 (Repo docs alignment: env-var/REST knowledge default)

Executor: `slice-executor-mid` (risk `medium`). Status: **done**.

## What I did

Aligned this repo's own operator-facing README with the env-var/REST knowledge default
that S1 shipped to fresh workspaces, mirroring S1's canonical `operations.md` seed wording.

### 1. `README.en.md` knowledge callout reframed

Rewrote the blockquote callout that follows the Agent Skills table (was ~lines 274–279).
It previously **led with the plugin-install path** (`/plugin marketplace add …`) and only
mentioned auto-explain in passing. It now:

- **Leads with the plugin-free env-var/REST default**: sign up at the
  [knowledge service](https://knowledge.hi2vi.com), mint an org-level API key, add two
  exports to `~/.zshenv` (shown inline as backticked code:
  `export KB_API_BASE_URL="https://knowledge.hi2vi.com"` /
  `export KB_API_TOKEN="vk_..."`).
- **Warns against a repo `.env`**: neither Claude Code nor Codex auto-loads it, and a
  secret in a repo file risks being committed.
- States one org-level key serves every repo, each document's project defaults to the repo
  basename, and a passing review then auto-saves the explainer via plain REST — Claude Code
  and Codex equally, no plugin install required (gracefully skipped when the KB is absent).
- **Codex caveat**: `workspace-write` sandbox blocks outbound network by default (save
  skipped) → opt in via `[sandbox_workspace_write] network_access = true` in
  `~/.codex/config.toml`, with the tradeoff (loosens all Codex workspace-write runs; Claude
  Code needs nothing).
- **Demotes the plugin to the alternative/richer path**: `explain` graduated out of the
  bootstrap into the [knowledge repo](https://github.com/leetusik/knowledge) plugin —
  `/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge` →
  `/knowledge:setup`, then `/knowledge:explain <topic>` on demand.

The callout grew from 6 lines to a 3-paragraph blockquote. Scope was kept to the blockquote
only — the surrounding executor-tier prose was not rewritten. `CLAUDE.md`/`AGENTS.md`
(contract = machinery) and the Korean `README.md` were left untouched per plan.

### 2. `phase.md` Doc impact — S2 placeholder replaced

Replaced the `_(S2 will append …)_` placeholder in the Doc impact list with two concrete
consolidation notes for REVIEW:
- `operations.md` (v0016 → next): this repo's own operations doc should adopt the env-var/REST
  default knowledge stance (`~/.zshenv` exports + retired-`.env` lesson, org-level key /
  repo-basename project, plain-REST auto-save, Codex `network_access` opt-in, plugin as
  alternative) — matching the v17 seed section fresh workspaces already ship.
- `decisions.md` (v0022 → next): the P9 decision — knowledge-by-default via the plugin-free
  env-var/REST path; why `~/.zshenv` over a repo `.env`; Cloudflare verified a non-barrier;
  the real Codex blocker is its own sandbox (opt-in documented); SaaS side consumed from
  knowledge-repo P18/P19, never implemented here.

### 3. `phase.md` Findings & Notes — cross-slice note appended

Added an `(S2 done)` note recording the reframe, the inline-code choice for the exports, what
was deliberately left untouched, and a "REVIEW to double-check" pointer that the README now
matches the seed stance.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **passed** — "Workflow validation passed." |
| `python3 installer/build.py --check` | **passed** — "OK: bootstrap_agentic_workspace.sh is in sync with installer/ source" |

`README.en.md` is not embedded machinery, so the artifact `bootstrap_agentic_workspace.sh`
is unchanged (confirmed via `git status` — it is not in the change list), and `--check`
stays green. No version bump / rebuild needed.

## Deviations from plan

None. The plan noted the Korean `README.md` extension was optional / the S2 plan's call — the
plan itself directed not to extend it, so it was left untouched.

## Doc impact (appended to phase.md for REVIEW to consolidate)

- `operations.md` (v0016 → next): env-var/REST default knowledge stance for this repo's own
  operations doc.
- `decisions.md` (v0022 → next): the P9 knowledge-by-default decision + rationale.
