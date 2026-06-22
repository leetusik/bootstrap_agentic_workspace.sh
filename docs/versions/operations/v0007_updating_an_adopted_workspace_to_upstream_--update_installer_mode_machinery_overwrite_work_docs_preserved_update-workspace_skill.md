---
doc_id: operations
version: v0007
created_at: 2026-06-22T15:16:05+09:00
source: update-workspace
summary: Updating an adopted workspace to upstream: --update installer mode (machinery overwrite, work/docs preserved) + /update-workspace skill
previous: v0006_slice-level_operator_intent_lands_in_the_native_plan_plan.md_is_template-free
---

# Operations

## Status

Adoption is documented two ways: a **fresh** install into an empty dir (README
Quickstart) and a **non-destructive retrofit** into an existing repo
(`--into-existing` / the `/retrofit` skill). Once adopted, a workspace is kept
current with upstream via the **update** path (`--update` / the
`/update-workspace` skill). Full retrofit runbook:
[`docs/retrofit-guide.md`](../../retrofit-guide.md).

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Adopting into an existing repo (retrofit)

The plain bootstrap installs only into an empty directory. To add the workspace
to a repo that already has code/docs/history, use the retrofit path. It is
**non-destructive**: it adds the workspace's files, skips anything already
present, additively merges a small known set, and aborts before writing on an
unresolvable collision. See [`docs/retrofit-guide.md`](../../retrofit-guide.md)
for the full procedure; the operational essentials:

- **Invoke:** the `/retrofit` skill (`$retrofit` in Codex) — the agent runs the installer — or directly: `bootstrap_agentic_workspace.sh . --into-existing [--phase-name … --phase-objective …]`.
- **Four-tier collision policy:** (1) skip-if-exists for pure content (skills, templates, `.codex/config.toml`, `phase-reviewer`); (2) install the `docs/` and `works/` subsystems only if wholly absent (gate on `docs/index.json` / `works/state.json`), and gate the final rebuild to installed subsystems; (3) additive idempotent merge for `.claude/settings.json` (union permissions) and `CLAUDE.md`/`AGENTS.md` (marked section + `*.workspace.md` sidecar); (4) hard abort on a pre-existing `scripts/workflow.py`.
- **Two passes:** classify everything first (no writes), abort up front on a tier-4 collision, then apply — so a retrofit never half-installs.
- **Seed P1 from state:** pass `--phase-name`/`--phase-objective` (the skill synthesizes them from the README/manifest/language/HEAD); P1 stays `DECOMP`+`REVIEW`-only.
- **Git:** the installer runs no git; the operator reviews the diff (`git status` shows only additions plus the additive `.claude/settings.json` merge) and the agent commits the adoption on their approval. The agent adds `__pycache__/` to `.gitignore`.
- **Verify:** `python3 scripts/workflow.py validate` then `next`. Retrofit is idempotent — re-running is a clean no-op.

## Updating an adopted workspace to upstream

The machinery (engine, skills, subagents, contract, templates) evolves upstream;
the **update** path refreshes it in place without disturbing the downstream's own
work. Retrofit *adopts* (non-destructive, skips what exists); update *re-applies*
(overwrites machinery, preserves work). Drive it with the `/update-workspace`
skill (`$update-workspace` in Codex) — the agent clones the latest upstream, shows
the dry-run change-list, and applies on the operator's approval — or directly:

- **Invoke:** `bootstrap_agentic_workspace.sh . --update` (add `--dry-run` to preview the change-list and write nothing). `--update` and `--into-existing` are mutually exclusive; `--update` requires an already-installed workspace (`scripts/workflow.py` plus `works/state.json` or an active `phase.json`), else it errors toward fresh install / retrofit.
- **Three-way write policy:** (1) **overwrite** machinery — `scripts/workflow.py`, the `.claude/agents/` subagents, every skill in `.claude/skills/` + `.agents/skills/`, `.codex/config.toml`, `works/templates/*`; (2) **additive merge** for `.claude/settings.json` (union permissions, never clobber); (3) **contract** — refresh the `*.workspace.md` sidecar if the repo was retrofitted, else overwrite `CLAUDE.md`/`AGENTS.md` in place. Everything under `works/` except templates, and **all** of `docs/`, is **preserved** untouched.
- **Docs rebuild is gated:** the post-update `rebuild` runs only when the repo uses the workspace's *own* docs system (`docs/index.json` plus our versioned doc-type dirs); a repo adopted over its own docs runs `next` only, so the rebuild never crashes on a foreign or absent index.
- **No pruning, just flags:** skills upstream has dropped are never deleted; the change-list flags managed-looking skill dirs (those whose `SKILL.md` sets `disable-model-invocation: true`) that are absent from the new manifest, so the operator can remove them by hand.
- **Provenance:** each install/update records `works/.workspace-version.json` (`upstream_url`, `synced_commit`, `synced_at`). The `/update-workspace` skill passes the upstream commit via `SYNCED_COMMIT`; the diff itself is always file-based, so the marker is informational.
- **Git:** the installer makes no git changes — the operator reviews the diff and the agent commits on their approval. Idempotent: re-running `--update` with no upstream change is a clean no-op (machinery unchanged).

## Capturing operator intent (intake)

Operator requests can carry grammar slips, awkward phrasing, or genuine
ambiguity, and a misread of intent silently propagates into decomposition and
every downstream slice. So intent is **refined, clarified, and confirmed before
any work starts**, and preserved as durable, linked truth.

- **When:** wherever operator intent first enters a unit of work — always at phase creation, and at the slice level when an operator note is ambiguous.
- **Entry point:** the `/create-phase` skill drives phase creation (explicit invocation only) — it captures intent, creates the phase(s), then **stops** before decomposition. The same skill routes work the operator wants parked for later to `defer-job` instead of creating a phase.
- **Flow:** **refine** the request into clear language → **clarify** anything ambiguous by asking the operator → **confirm** the interpretation. Only after the operator confirms does the agent run `new-phase`; it never creates the phase on an unconfirmed guess.
- **Persist (phase level):** `new-phase` scaffolds `intent.md` in the phase folder (from `works/templates/intent.md`) and links it near the top of `phase.md`; the agent then fills it with the operator's **verbatim original** request (immutable) plus the **confirmed refined intent** and any resolved clarifications. The verbatim original is never edited; only the confirmed wording is the refined version.
- **Persist (slice level):** a slice's `plan.md` is the orchestrator's free-form native plan (no template) — it incorporates any operator note passed with `do-next-slice` / `do-whole-phase`, and when that note is ambiguous the agent clarifies it with the operator and reflects the confirmed reading in the plan. The operator's **verbatim** intent is captured at the phase level in `intent.md`, not duplicated under per-slice headings.
- **Reference:** when any later agent is unsure of intent, it consults the phase's `intent.md` (linked from `phase.md`) — the confirmed source of truth for what was asked.
- **Seeded phases:** the installer seeds P1 with a placeholder `intent.md` (Origin `bootstrap-placeholder`, or `synthesized-from-repo` on retrofit, which the `/retrofit` skill then enriches from the README/manifest/`git log`).
- **Always present:** because `new-phase` scaffolds `intent.md` for every phase, the file always exists for executors to read; `validate` emits a soft (non-failing) warning if an active phase is missing it.

## Local Development

- Install:
- Run:
- Test:
- Build:

## Environment Variables

| Name | Required | Purpose | Notes |
|---|---|---|---|
| <NAME> | yes/no | <purpose> | <notes> |

## Deployment

- Target:
- Process:
- Rollback:

## Scheduled Jobs / Workers

- <job>: <schedule/trigger>

## Observability

- Logs:
- Metrics:
- Alerts:

## Backup / Restore

- <policy>

## Open Questions

-
