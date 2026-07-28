# Plan — P9.S1 (Installer/product knowledge-setup wiring)

Operator-approved orchestrator plan (2026-07-22). Executor: `slice-executor-mid` (risk `medium`).

## Job

Make a freshly bootstrapped workspace ship with operator-facing knowledge setup — today fresh workspaces receive zero knowledge guidance. Docs + onboarding wiring only, no engine logic. Read `works/phases/active/P9/phase.md` (context, findings, constraints) and `works/phases/active/P9/intent.md` first.

## Changes (all under `installer/` — the machinery hard rule applies)

1. **`installer/payloads/doc_bodies/operations.md`** — the seed body every fresh workspace's `docs/current/operations.md` is generated from; currently a fully generic template with zero knowledge mentions. Add a `## Knowledge (phase explainers)` section between `## Environment Variables` and `## Deployment` covering:
   - The default, plugin-free path: sign up at the knowledge SaaS → mint an API key → export in **`~/.zshenv`**:
     `export KB_API_BASE_URL="https://knowledge.hi2vi.com"` and `export KB_API_TOKEN="vk_..."` — never a repo `.env` (neither Claude Code nor Codex auto-loads `.env`, and a repo file risks committing the secret).
   - One org-level key serves all repos; each document's project defaults to the repo's directory name (consumed from the knowledge service's contract).
   - With the env vars set, a passing phase review auto-saves the phase explainer via plain REST — Claude Code and Codex equally, no plugin install required.
   - Codex caveat: its `workspace-write` sandbox blocks outbound network by default → opt in via `[sandbox_workspace_write] network_access = true` in `~/.codex/config.toml`, noting the tradeoff (loosens ALL Codex workspace-write runs; Claude Code needs nothing).
   - The Claude Code knowledge plugin (`/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge` → `/knowledge:setup`) as the alternative/richer path (`/knowledge:explain` on demand).
   - Keep it lean and template-toned like the rest of the seed body; agent-first framing (drive it via the skill/agents — REST is the substrate).
2. **`installer/main.py`** fresh-install stdout block (final `else:`, lines 623–633) — add one `Knowledge (optional): ...` line pointing at the env-var exports in `~/.zshenv` and `docs/current/operations.md` for details.
3. **`installer/main.py:38`** — `WORKSPACE_VERSION = 16` → `17` (keep the comment intact).
4. **`CHANGELOG.md`** — new `## v17 — 2026-07-22` entry, newest-first, matching v15/v16 style: knowledge-by-default wiring (what changed and why). Include a **Migration notes** line: no action required; doc seeds are fresh-install-only, so existing workspaces won't gain the section on `--update` — they can add the exports to `~/.zshenv` directly, which works regardless; mention the Codex `network_access` opt-in.
5. **Rebuild**: run `python3 installer/build.py`, then confirm `python3 installer/build.py --check` passes (pre-commit hook enforces it). The rebuilt `bootstrap_agentic_workspace.sh` must land in the orchestrator's same commit — running the build is your job; committing is not.

## Wrap-up (executor)

- Append to `works/phases/active/P9/phase.md`: a one-line **Doc impact** note (this repo's `operations.md` gains the same knowledge-setup stance — REVIEW consolidates) and a short cross-slice note under Findings & Notes giving S2 the canonical setup wording to mirror in `README.en.md`.
- Write `works/phases/active/P9/slices/P9.S1/result.md` (free-form, from scratch).
- Run `python3 scripts/workflow.py validate`; confirm it passes.

## Never

Commit; transition slice/phase status; run `doc-new-version`; hand-edit `docs/current/*.md`; touch files outside the listed ones plus the phase folder. If anything here turns out deeper than this plan (unexpected installer structure, build failures you can't resolve mechanically), return `escalate` with findings instead of improvising.

## Verification

- `python3 installer/build.py --check` passes; `python3 scripts/workflow.py validate` passes.
- The rebuilt `bootstrap_agentic_workspace.sh` contains the new seed section and stdout line (grep `KB_API_TOKEN`), and `WORKSPACE_VERSION = 17` appears in both `installer/main.py` and the artifact.
