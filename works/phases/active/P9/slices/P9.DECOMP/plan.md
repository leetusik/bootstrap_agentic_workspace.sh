# Plan — P9.DECOMP (decompose phase P9: Knowledge-by-default in bootstrapped workspaces)

Operator-approved orchestrator plan (2026-07-22). Executor: `slice-executor-high`.

## Job

Decompose P9 into middle slices: create them with `new-slice` (bare folders — never pre-fill their `plan.md`), set each `--risk` deliberately (it selects the executor tier), and seed `phase.md` (Decomposition breakdown + rationale, Findings & Notes, Constraints). Write `result.md` when done. Do not commit; do not transition slice/phase status.

## Phase intent (see ../../intent.md for the confirmed source of truth)

Make the knowledge SaaS (knowledge.hi2vi.com) the default, low-friction knowledge path for bootstrapped workspaces:

- The plugin-free **env-var/REST flow is the intended default**: sign up → mint key → `export KB_API_BASE_URL` + `KB_API_TOKEN` in **`~/.zshenv`** (never a repo `.env` — neither Claude Code nor Codex auto-loads `.env`; this repo's retired executor-tier `.env` taught that lesson) → any coding agent saves via plain REST through the explain skill's resolver (env vars are read first). Claude Code and Codex get equal access; no plugin install required.
- Document the **Codex blocker + alternative**: Cloudflare is NOT a barrier (verified empirically); the real blocker is Codex's `workspace-write` sandbox blocking outbound network — document the `[sandbox_workspace_write] network_access = true` opt-in in `~/.codex/config.toml` with its tradeoff (loosens all Codex workspace-write runs; Claude Code needs nothing).
- **One org-level key serves all repos** — each document's project comes from the repo's directory name (knowledge repo P18/P19 own the SaaS side; this repo only consumes that contract).
- Align workspace docs with the agent-first skill flow (recommend driving knowledge via the skill/agent, REST is the substrate).

## Research findings (orchestrator survey — trust these, spot-check only what you build on)

- **Nothing operator-facing documents the env-var setup anywhere yet.** `KB_API_BASE_URL` / `KB_API_TOKEN` / `~/.zshenv` / `network_access` appear only in P9's intent/objective. The resolver, REST save, skill-detection order, and Codex-sandbox degradation are already implemented in the external skill and already described in machinery (`.claude/skills/review-phase/SKILL.md` + `.agents` mirror, the `slice-executor-high` agent files) — **no engine/machinery logic change expected**.
- **Current knowledge stance** lives in `docs/current/operations.md` (v0016: explain-as-plugin + auto-explain-at-review) and `docs/current/decisions.md` (v0022). Durable-doc changes are "Doc impact" notes in `phase.md`, consolidated at REVIEW — never direct edits by middle slices.
- **Fresh workspaces get no knowledge guidance at all**: the 11 seed doc bodies (`installer/payloads/doc_bodies/*.md`) have zero knowledge mentions; the fresh-install stdout onboarding block in `installer/main.py` (final `else:`) has no KB line. This is the gap between today and "by default".
- **Human onboarding for the bootstrap product**: `README.en.md` has a knowledge-plugin callout (~lines 274–279) still leading with the plugin-install path; Korean `README.md` has no knowledge content.
- **Hard rule**: any edit under `installer/`, `.claude/`, `.agents/`, `.codex/`, `works/templates/`, or the contract requires a same-commit `python3 installer/build.py` rebuild of `bootstrap_agentic_workspace.sh` (pre-commit hook enforces `--check`), plus by precedent a `WORKSPACE_VERSION` bump and CHANGELOG entry.

## Recommended decomposition shape (validate and refine; record your rationale in phase.md)

Installer wiring is **in scope** — docs-only would leave fresh workspaces exactly as knowledge-less as today, defeating "by default". Suggested middle slices (you make the final call on count/boundaries/risks):

1. **Installer/product wiring** — add operator-facing knowledge setup to what a fresh workspace receives: a knowledge-setup section in the seed `installer/payloads/doc_bodies/operations.md` (env-var exports in `~/.zshenv`, one org-level key / repo-basename project, Codex `network_access` opt-in + tradeoff, plugin as alternative) and a short KB line in the fresh-install stdout onboarding block of `installer/main.py`. Machinery edit → rebuild + version bump + CHANGELOG. Risk: `medium`.
2. **This repo's docs alignment** — update `README.en.md` to lead with the env-var/REST default (plugin as alternative), and append "Doc impact" notes to `phase.md` for `operations.md`/`decisions.md` (new default stance, `~/.zshenv` recommendation + retired-`.env` lesson, Codex sandbox opt-in) for REVIEW to consolidate. Risk: `low` or `medium` per your judgment (`low` only if the plan will be fully mechanical).

## Constraints (record in phase.md)

- This repo consumes the knowledge repo's contract (P18 org-level keys, P19 doc URLs); it never implements SaaS-side behavior.
- Durable docs version only at REVIEW; middle slices append Doc-impact notes.
- Secrets never in repo files; `~/.zshenv` is the recommended home for the exports.

## Verification

`python3 scripts/workflow.py validate` passes; middle slices exist as bare folders (only `slice.json`) with deliberate risks and sensible `--order`; `phase.md` seeded with breakdown, findings, constraints.
