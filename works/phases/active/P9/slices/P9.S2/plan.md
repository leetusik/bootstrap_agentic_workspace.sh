# Plan — P9.S2 (Repo docs alignment: env-var/REST knowledge default)

Operator-approved orchestrator plan (2026-07-22). Executor: `slice-executor-mid` (risk `medium`, depends_on P9.S1 — done).

## Job

Align this repo's own operator-facing docs with the env-var/REST knowledge default that S1 shipped to fresh workspaces. `README.en.md` is **not** machinery: no artifact rebuild, no version bump. Read `works/phases/active/P9/phase.md` (especially the "(S1 done)" canonical-wording note in Findings & Notes) and `works/phases/active/P9/intent.md` first.

## Changes

1. **`README.en.md` knowledge callout (lines 274–279)** — reframe the blockquote to lead with the env-var/REST default, mirroring S1's canonical wording:
   - Lead: knowledge setup is two exports in `~/.zshenv` (`export KB_API_BASE_URL="https://knowledge.hi2vi.com"`, `export KB_API_TOKEN="vk_..."`) — one org-level key serves every repo, each document's project defaults to the repo basename, and a passing phase review then auto-saves the phase explainer via plain REST — Claude Code and Codex equally, no plugin install required.
   - Warn: never a repo `.env` (neither Claude Code nor Codex auto-loads it; risks committing the secret).
   - Codex caveat: `workspace-write` sandbox blocks outbound network by default (save skips) → opt in via `[sandbox_workspace_write] network_access = true` in `~/.codex/config.toml`; tradeoff: loosens all Codex workspace-write runs; Claude Code needs nothing.
   - Keep the plugin as the alternative/richer path: explain graduated to the [knowledge repo](https://github.com/leetusik/knowledge) plugin — `/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge` → `/knowledge:setup`, `/knowledge:explain` on demand.
   - Scope: the blockquote callout only (it may grow a few lines). Do NOT rewrite the surrounding executor-tier prose, do NOT touch `CLAUDE.md`/`AGENTS.md` (contract = machinery), do NOT extend the Korean `README.md`.
2. **`works/phases/active/P9/phase.md` Doc impact** — replace the S2 placeholder line with concrete notes for REVIEW to consolidate:
   - `operations.md` (v0016 → next): the env-var/REST default knowledge stance — `~/.zshenv` exports (with the retired-executor-`.env` lesson), org-level key / repo-basename project, Codex `network_access` opt-in, plugin as alternative; fresh workspaces ship the same stance via the v17 seed section.
   - `decisions.md` (v0022 → next): the P9 decision — knowledge-by-default via the plugin-free env-var/REST path; why `~/.zshenv` over a repo `.env`; Cloudflare verified a non-barrier, the real Codex blocker is its own sandbox (opt-in documented); SaaS side (org keys, doc URLs) consumed from knowledge-repo P18/P19, never implemented here.

## Wrap-up (executor)

- Append any durable cross-slice notes to `phase.md` Findings & Notes (e.g. confirmation the README now matches the seed wording, anything REVIEW should double-check).
- Write `works/phases/active/P9/slices/P9.S2/result.md` (free-form, from scratch).
- Run `python3 scripts/workflow.py validate` and `python3 installer/build.py --check` (README is not embedded, so the artifact must be unchanged — if `--check` fails, you touched something you shouldn't have); confirm both pass.

## Never

Commit; transition slice/phase status; run `doc-new-version`; hand-edit `docs/current/*.md`; touch machinery (`installer/`, `.claude/`, `.agents/`, `.codex/`, contract files) or the Korean `README.md`. If the reframe turns out deeper than this plan, return `escalate` with findings instead of improvising.

## Verification

- `python3 scripts/workflow.py validate` passes; `python3 installer/build.py --check` still green.
- README callout reads env-var-first with the plugin as alternative; `phase.md` Doc impact holds both consolidation notes for REVIEW.
