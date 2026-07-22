# Result — P9.S1 (Installer/product knowledge-setup wiring)

Executor: `slice-executor-mid` (risk `medium`). Status: **done**.

## What changed

Made a freshly bootstrapped workspace ship with operator-facing knowledge setup —
docs + onboarding wiring only, no engine logic. All source edits are under `installer/`
(machinery), so the artifact was rebuilt and the version bumped in the same change.

1. **`installer/payloads/doc_bodies/operations.md`** — added a `## Knowledge (phase
   explainers)` section between `## Environment Variables` and `## Deployment`. It
   describes the default, plugin-free path (sign up → mint key → export
   `KB_API_BASE_URL` + `KB_API_TOKEN` in **`~/.zshenv`**, never a repo `.env`), one
   org-level key serving every repo with project = repo directory name, the auto-save
   of the phase explainer on a passing review via plain REST (Claude Code and Codex
   equally, no plugin install), the Codex `[sandbox_workspace_write] network_access = true`
   opt-in with its tradeoff, and the Claude Code knowledge plugin as the alternative/richer
   path. Lean and template-toned, agent-first framing ("REST is the substrate").
2. **`installer/main.py`** fresh-install stdout block (final `else:`) — added a
   `Knowledge (optional): ...` line pointing at the `~/.zshenv` exports and
   `docs/current/operations.md`.
3. **`installer/main.py:38`** — `WORKSPACE_VERSION` bumped `16` → `17` (comment intact).
4. **`CHANGELOG.md`** — new `## v17 — 2026-07-22` entry (newest-first, v15/v16 style):
   knowledge-by-default wiring, Codex sandbox opt-in, the new stdout line, plus a
   **Migration notes** line (doc seeds are fresh-install-only → existing workspaces
   won't gain the section on `--update`; add the exports to `~/.zshenv` directly, and
   enable Codex `network_access` if reviews should post online).
5. **`bootstrap_agentic_workspace.sh`** — rebuilt via `python3 installer/build.py` so the
   new seed section, stdout line, and version bump ride inside the artifact.

## Validation

| Command | Outcome |
|---|---|
| `python3 installer/build.py` | wrote `bootstrap_agentic_workspace.sh` (286069 bytes) from `installer/` source |
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **passed** (see run below) |

Artifact spot-checks (all as expected):
- `grep -c KB_API_TOKEN bootstrap_agentic_workspace.sh` → 2 (seed export + stdout line)
- `grep -c "WORKSPACE_VERSION = 17" bootstrap_agentic_workspace.sh` → 1
- `grep -c "Knowledge (optional)" bootstrap_agentic_workspace.sh` → 1
- `grep -c "Knowledge (phase explainers)" bootstrap_agentic_workspace.sh` → 1

## Doc impact (appended to phase.md — REVIEW consolidates, no `doc-new-version` here)

- `operations.md` — fresh workspaces now ship a `## Knowledge (phase explainers)` seed
  section; this repo's own `docs/current/operations.md` should gain the same knowledge-setup
  stance at REVIEW.

## Cross-slice note for S2

The canonical knowledge-setup wording landed in the seed body (recorded in phase.md
Findings & Notes with the full framing): S2 should mirror it in `README.en.md`, leading
with the env-var/REST default and demoting the plugin to the alternative path.

## Deviations

None. Followed `plan.md` exactly.
