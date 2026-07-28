# Result — P9.REVIEW (phase review: Knowledge-by-default in bootstrapped workspaces)

Executor: `slice-executor-high`. Verdict: **pass**.

## Verdict justification

P9's objective shipped in full. A freshly bootstrapped workspace now receives the
plugin-free env-var/REST knowledge default: S1 added a `## Knowledge (phase explainers)`
seed section to `installer/payloads/doc_bodies/operations.md` plus a `Knowledge (optional)`
fresh-install stdout line, bumped `WORKSPACE_VERSION` 16→17, added the `## v17` CHANGELOG
entry with Migration notes, and rebuilt the artifact — all atomic in one commit per the
machinery hard rule. S2 reframed the `README.en.md` callout to lead with the env-var/REST
default and demote the plugin to the alternative, touching no machinery, no contract, and
not the Korean README. Both slices match `intent.md`: `~/.zshenv` over a repo `.env` (with
the retired executor-tier `.env` lesson), one org-level key / project = repo basename, the
Codex `[sandbox_workspace_write] network_access = true` opt-in with its tradeoff, Cloudflare
documented as a non-barrier, and the SaaS side (org keys, doc URLs) described as consumed
from the knowledge repo's P18/P19 — never implemented here. No engine/machinery logic changed
(`scripts/workflow.py` untouched). Both slices' `result.md` report "no deviations". Nothing
warranted a fix slice.

## Validation (all slices re-run together)

| Command | Outcome |
|---|---|
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **passed** (before consolidation and after rebuild) |
| Artifact grep `KB_API_TOKEN` | 2 (seed export + stdout line) |
| Artifact grep `WORKSPACE_VERSION = 17` | 1 |
| Artifact grep `Knowledge (optional)` | 1 |
| Artifact grep `Knowledge (phase explainers)` | 1 |

S1 consistency checks (all confirmed):
- `installer/main.py:38` → `WORKSPACE_VERSION = 17`.
- `CHANGELOG.md` → `## v17 — 2026-07-22` present, with a **Migration notes** line (doc seeds
  are fresh-install-only; existing workspaces add the exports to `~/.zshenv` directly).
- Seed `installer/payloads/doc_bodies/operations.md` knowledge section matches the canonical
  framing in `phase.md` (env-var/REST default via `~/.zshenv`, one org-level key, project =
  repo basename, Codex `network_access` opt-in + tradeoff, plugin as alternative).

S2 consistency checks (all confirmed):
- `README.en.md` knowledge callout (lines ~274–291) leads with the env-var/REST default
  (`~/.zshenv` exports, never a repo `.env`), then the Codex `network_access` caveat, then the
  plugin as the alternative/richer path.
- Korean `README.md` untouched (0 knowledge mentions); `CLAUDE.md`/`AGENTS.md` not in the S2
  commit (`abf3671` touched only `README.en.md` + `works/` state).

Commit-scope check: S1 (`5f49654`) touched only `installer/` machinery + rebuilt artifact +
CHANGELOG + `works/` state; S2 (`abf3671`) touched only `README.en.md` + `works/` state.
Boundaries clean.

## Doc versions created (consolidation, pass only)

Consolidated the two `phase.md` "Doc impact" notes into one version per doc, `--source P9.REVIEW`:

- **`operations` v0016 → v0017** — `docs/versions/operations/v0017_knowledge_setup_ships_by_default_in_fresh_workspaces_env-var_rest_via_.zshenv_org-level_key_codex_network_access_opt-in_plugin_as_alternative_workspace_v17.md`. Added a `## Knowledge setup — the env-var/REST default (since v17)` section and a v17 note in Status.
- **`decisions` v0022 → v0023** — `docs/versions/decisions/v0023_knowledge-by-default_in_bootstrapped_workspaces_via_the_plugin-free_env-var_rest_path_plugin_demoted_to_alternative_.zshenv_over_a_repo_.env_codex_sandbox_the_real_blocker_workspace_v17.md`. Added the P9 decision entry at the top of the Decision Log, extended the Status summary, count 19→20.

`python3 scripts/workflow.py rebuild-docs` regenerated `docs/current/operations.md` and
`docs/current/decisions.md`; `validate` confirms `docs/current/*` match the latest versions.

## Auto-explain (best-effort, verdict-neutral)

- **explain: saved** `/Users/sugang/projects/personal/knowledge/docs/bootstrap_agentic_workspace.sh/2026-07-22-knowledge-by-default-p9.html`
- Skill located at `~/.claude/skills/explain/SKILL.md` (user-level; project had none). Followed
  in change mode with P9 as change-ref. KB config resolved `KB_STATUS=configured` (legacy local
  checkout; API `http://localhost:8766`, no token, `KB_LOCAL_FALLBACK=yes`).
- The document API was unreachable (curl exit 7, connection refused), so the skill's local
  fallback wrote the HTML explainer with the `<!--kb …-->` comment-frontmatter, inserted the
  Recent bullet in the KB `docs/index.md`, and committed **in the KB repo only** (`806930a`,
  the scoped carve-out — never this workspace's repo, never a push). A later
  `POST /api/reindex` or `docker compose up -d` in the KB reconciles the DB.
- Research section: **included** — grounded in 12factor.net/config and gitguardian.com (env
  vars vs committed config files; keeping the token out of the repo tree entirely; the
  proportional divergence from full secret managers).
- The explain outcome does not affect the verdict.

## Deviations from plan.md

None substantive. The two `doc-new-version` `--summary` strings were shortened from the fuller
phrasing (the initial long summary overran the OS filename limit, since the version filename is
derived from the summary); the full stance is captured in the version bodies. Auto-explain took
the documented offline-fallback path because the local API was down — expected behavior, not a
deviation.
