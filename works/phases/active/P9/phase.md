# Phase P9: Knowledge-by-default in bootstrapped workspaces

_Intent: see [intent.md](intent.md)._

## Objective

Make the knowledge SaaS the default low-friction knowledge path for bootstrapped workspaces: document/wire the env-var setup (KB_API_BASE_URL + KB_API_TOKEN via ~/.zshenv, not a repo .env), address the Codex workspace-write network-sandbox blocker, and align the workspace docs with the agent-first skill flow.

## Context

This phase is docs + installer-wiring only. It makes the plugin-free **env-var/REST knowledge flow** the documented default a fresh workspace receives, and aligns this repo's own operator docs with that stance. It implements **no engine/machinery logic**: the env-var resolver, REST save, skill-detection order, and Codex-sandbox degradation already exist in the external explain skill and are already described in machinery (`.claude/skills/review-phase/SKILL.md` + `.agents` mirror, the `slice-executor-high` agent files). The SaaS side (org-level keys, returned doc URLs) is owned by the knowledge repo's sibling phases P18/P19/P20 — this repo only consumes that contract.

## Decomposition

Two middle slices, both `implementation`. Rationale for the split: the two touch different file classes with different commit/validation profiles — S1 edits embedded machinery under `installer/` (so it must rebuild `bootstrap_agentic_workspace.sh`, bump `WORKSPACE_VERSION`, add a CHANGELOG entry), while S2 edits only a human-facing repo doc (`README.en.md`, not machinery → no rebuild) plus `phase.md` Doc-impact notes. Keeping them separate keeps the machinery-rebuild atomic (one version bump, one build) and lets the review validate each cleanly. Merging S1's two edits (seed doc + stdout) into one slice is deliberate — they are the same "what a fresh workspace receives" concern and share the single rebuild/version-bump/CHANGELOG obligation, so splitting them would force two version bumps.

- **P9.S1 — Installer/product knowledge-setup wiring** (`implementation`, risk `medium`, order 1). Add operator-facing knowledge setup to what a fresh workspace receives:
  - Add a knowledge-setup section to the seed doc body `installer/payloads/doc_bodies/operations.md` (currently a generic template with zero knowledge mentions): the `~/.zshenv` exports of `KB_API_BASE_URL` + `KB_API_TOKEN` (never a repo `.env`), one org-level key / repo-basename project, the Codex `[sandbox_workspace_write] network_access = true` opt-in in `~/.codex/config.toml` with its tradeoff (loosens all Codex workspace-write runs; Claude Code needs nothing), and the plugin as an alternative path.
  - Add a short KB onboarding line to the fresh-install stdout block in `installer/main.py` (the final `else:` at ~lines 623–633, which today has no KB line).
  - Machinery edit → same-commit obligations: run `python3 installer/build.py` to rebuild `bootstrap_agentic_workspace.sh` (pre-commit hook enforces `--check`), bump `WORKSPACE_VERSION` (currently `16` → `17` in `installer/main.py:38`), and add a `CHANGELOG.md` entry (by precedent). The executor may run `build.py` (a build step, not a commit/state transition); the orchestrator owns the commit.
  - **Risk `medium`** (not `low`): the content is substantive judgment (setup narrative, Codex tradeoff, plugin-vs-default framing) and it touches the build machinery — not fully mechanical. Not `high`: well-specified in intent, no engine-logic design.

- **P9.S2 — Repo docs alignment: env-var/REST knowledge default** (`implementation`, risk `medium`, order 2, depends_on P9.S1). Align this repo's own operator-facing docs with the new default:
  - Rewrite the `README.en.md` knowledge callout (~lines 274–279) to **lead with the env-var/REST default** (sign up → mint key → `export` in `~/.zshenv` → any agent saves via REST), with the plugin install path demoted to an alternative. (Korean `README.md` has no knowledge content today — extending it is optional, the S2 plan's call.)
  - Append **Doc impact** notes to `phase.md` (below) for `operations.md` (v0016) and `decisions.md` (v0022): the new default knowledge stance, the `~/.zshenv` recommendation + retired-`.env` lesson, and the Codex sandbox `network_access` opt-in. **Do not version docs here** — REVIEW consolidates.
  - **Risk `medium`**: reframing the callout's emphasis and writing the Doc-impact wording is prose judgment, not a mechanical line-swap. depends_on P9.S1 so S1's canonical setup text lands first and S2 mirrors its wording; advisory only.

REVIEW (order 9999) then validates both slices together and, on a pass, consolidates the `operations.md` and `decisions.md` Doc-impact notes into new versions.

## Findings & Notes

- **No engine/machinery logic change is expected** (verified against the plan's orchestrator survey and spot-checked): the resolver / REST save / skill-detection / Codex degradation are already implemented externally and described in machinery. This phase adds documentation + fresh-workspace onboarding, nothing more.
- **Today's knowledge gap in a fresh workspace, confirmed by inspection:**
  - `installer/payloads/doc_bodies/operations.md` is a generic template (Status / Purpose / Env-Vars table / Deployment / …) with **zero knowledge mentions** — this is where the knowledge-setup section goes (S1).
  - `installer/main.py` fresh-install stdout block (final `else:`, ~lines 623–633) lists contracts/skills/executor-tiers/docs but has **no KB line** (S1 adds one).
  - `WORKSPACE_VERSION = 16` at `installer/main.py:38` — S1 bumps to 17.
  - `README.en.md` knowledge callout (~lines 274–279) still **leads with the plugin-install path** (`/plugin marketplace add …`); S2 reframes to env-var/REST-first.
- **Current durable knowledge stance** lives in `docs/current/operations.md` (v0016) and `docs/current/decisions.md` (v0022). These are the two docs S2 flags for REVIEW consolidation. Durable docs are versioned only at REVIEW — middle slices append Doc-impact notes, never run `doc-new-version`.
- `CHANGELOG.md` exists at repo root — S1 adds an entry alongside the version bump (by precedent for machinery edits).

## Constraints

- **Consume, don't implement the SaaS contract**: this repo never implements SaaS-side behavior (P18 org-level keys, P19 returned doc URLs live in the knowledge repo). Docs describe the contract as consumed.
- **Durable docs version only at REVIEW**: S1/S2 append Doc-impact notes to `phase.md`; they never run `doc-new-version` and never hand-edit `docs/current/*.md`.
- **Secrets never in repo files**: `~/.zshenv` is the recommended home for `KB_API_BASE_URL` / `KB_API_TOKEN` — never a repo `.env` (neither Claude Code nor Codex auto-loads it; this repo's own retired executor-tier `.env` taught that lesson).
- **Upstream machinery hard rule (S1)**: any edit under `installer/` requires a same-commit `python3 installer/build.py` rebuild of `bootstrap_agentic_workspace.sh` (pre-commit hook enforces `--check`), plus `WORKSPACE_VERSION` bump and a CHANGELOG entry by precedent. `README.en.md` (S2) is **not** machinery — editing it needs no rebuild.

## Doc impact

_Running list of durable-truth changes; the REVIEW slice consolidates these into new doc versions. Middle slices append here — no `doc-new-version` before REVIEW._

- _(S2 will append: `operations.md` + `decisions.md` — new env-var/REST knowledge default, `~/.zshenv` recommendation, Codex `network_access` opt-in.)_

## Open Questions

-
