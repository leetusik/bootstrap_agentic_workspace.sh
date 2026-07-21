---
doc_id: operations
version: v0016
created_at: 2026-07-22T00:37:34+09:00
source: P8.REVIEW
summary: Phase review now also produces a phase explainer on a passing review (review = validate + consolidate docs + explain) via the knowledge plugin's explain skill; gracefully skipped when absent; workspace v16
previous: v0015_embedded_explain_retired_no_longer_ships_--with-explain_removed_workspace_v15_install_the_knowledge_plugin_plugin_marketplace_add_leetusik_knowledge_-_plugin_install_knowledge_knowledge_knowledge_setup_knowledge_explain
---

# Operations

## Status

Adoption is documented two ways: a **fresh** install into an empty dir (README
Quickstart) and a **non-destructive retrofit** into an existing repo
(`--into-existing` / the `/retrofit` skill). Once adopted, a workspace is kept
current with upstream via the **update** path (`--update` / the
`/update-workspace` skill). Full retrofit runbook:
[`docs/retrofit-guide.md`](../../retrofit-guide.md).

The distributable `bootstrap_agentic_workspace.sh` is now a **build product**
assembled from an `installer/` source tree — maintainers edit live repo files (or
`installer/payloads/` for fresh-install-only seeds) and run `python3
installer/build.py`, never editing the artifact by hand. Workspaces are now
**versioned**: an integer `WORKSPACE_VERSION` is stamped into each target's marker
and a root `CHANGELOG.md` records what each version brings, which `/update-workspace`
surfaces as "you're on vN → upstream vM". See *Building and releasing the installer*
below. As of **v15**, the `/explain` educational-explainer no longer ships in the
bootstrap at all — it graduated into a standalone Claude Code plugin in the
[knowledge repo](https://github.com/leetusik/knowledge); the `--with-explain`
install flag is retired. See *The explain feature ships as a plugin now* below.

Running the workflow: every slice — including the phase **review** — is executed by a `slice-executor` tier subagent (`slice-executor-low` / `-mid` / `-high` since v7, risk-routed by the orchestrator; see *Executor tiers* below). Durable docs are versioned **once per phase, at the review slice** — the executor consolidates the phase's "Doc impact" notes (left in `phase.md` by earlier slices) into new versions on a passing review, rather than per slice; the read-only `phase-reviewer` is retired. As of **v16**, a **passing** review also **auto-produces a phase explainer** via the knowledge plugin's explain skill — the review is now *validate + consolidate docs + **explain*** — best-effort and gracefully skipped wherever the plugin/KB is absent or unreachable. See *Auto-explain at the phase review* below.

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Executor tiers (risk routing, `executors.toml`, escalation) — since v7

Every slice is executed by one of three `slice-executor` tiers, picked by the orchestrator from the slice's `kind` + `risk`:

| Tier | Routes | Claude default | Codex default | Behavior |
|---|---|---|---|---|
| `slice-executor-low` | implementation/`fix` with `risk` exactly `low` | `haiku` (no effort line) | `gpt-5.5` @ `medium` | Literal plan execution — no judgment, no improvisation; stops and escalates on any surprise |
| `slice-executor-mid` | `risk` exactly `medium` (the `new-slice` default) | `sonnet` @ `xhigh` | `gpt-5.5` @ `high` | Judgment within the plan's intent; escalates beyond its depth |
| `slice-executor-high` | decomposition, the phase review, and everything else (`high`/unset/unknown) | `opus` @ `xhigh` | `gpt-5.5` @ `xhigh` | Full judgment; the escalation ceiling |

- **Configure via `executors.toml` (since v8; seeded since v9):** the installer seeds `executors.toml` at the repo root with all defaults shown commented out — seed-once, never overwritten by updates, safe to delete (absent = defaults), committable (it holds no secrets). Uncomment/set `model` / `effort` under any of the `[claude.low|mid|high]` / `[codex.low|mid|high]` tables, then apply with `python3 scripts/workflow.py sync-agents`. Values are written verbatim (aliases, full model IDs, `inherit`); an **empty** `effort = ""` omits the effort line (required for models that reject the effort parameter, e.g. haiku); an empty model errors, and so does any unrecognized line or section (line-numbered). `sync-agents --check` reports drift without writing; `validate` warns while the agent files drift from `executors.toml`/defaults. (Until v8 this was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read — `sync-agents` warns about it.)
- **Escalation:** a low/mid executor that can't safely complete a slice returns `escalate` with findings (a failed/empty low/mid return counts the same); the orchestrator appends an `## Escalation` section to the slice's `plan.md` and re-dispatches one tier up — max 2 per slice, never past `slice-executor-high`, plan re-approved by the operator unless running `auto`. `needs_operator`/`blocked` keep their meanings and still stop the run.
- **Upstream caution:** in the bootstrap repo itself, keep the tracked `executors.toml` at its commented defaults — a non-default `sync-agents` run there mutates the committed agent files and the pre-commit drift check will block the commit.

## Adopting into an existing repo (retrofit)

The plain bootstrap installs only into an empty directory. To add the workspace
to a repo that already has code/docs/history, use the retrofit path. It is
**non-destructive**: it adds the workspace's files, skips anything already
present, additively merges a small known set, and aborts before writing on an
unresolvable collision. See [`docs/retrofit-guide.md`](../../retrofit-guide.md)
for the full procedure; the operational essentials:

- **Invoke:** the `/retrofit` skill (`$retrofit` in Codex) — the agent runs the installer — or directly: `bootstrap_agentic_workspace.sh . --into-existing` (the `--phase-name`/`--phase-objective` seeding flags were removed in v6 — nothing is seeded).
- **Four-tier collision policy:** (1) skip-if-exists for pure content (skills, templates, `.codex/config.toml`, the `slice-executor` tier subagents, `executors.toml`); (2) install the `docs/` and `works/` subsystems only if wholly absent (gate on `docs/index.json` / `works/state.json`), and gate the final rebuild to installed subsystems; (3) additive idempotent merge for `.claude/settings.json` (union permissions) and `CLAUDE.md`/`AGENTS.md` (marked section + `*.workspace.md` sidecar); (4) hard abort on a pre-existing `scripts/workflow.py`.
- **Two passes:** classify everything first (no writes), abort up front on a tier-4 collision, then apply — so a retrofit never half-installs.
- **No seeded phase (since v6):** the workspace starts with no phases; the operator's first phase comes from the `/create-phase` intake flow.
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
- **Write policy:** (1) **overwrite** machinery — `scripts/workflow.py`, the `.claude/agents/` + `.codex/agents/` tier subagents, every skill in `.claude/skills/` + `.agents/skills/`, `.codex/config.toml`, `works/templates/*`; (2) **additive merge** for `.claude/settings.json` (union permissions, never clobber); (3) **contract** — refresh the `*.workspace.md` sidecar if the repo was retrofitted, else overwrite `CLAUDE.md`/`AGENTS.md` in place; (4) **seed-once** — `executors.toml` is created when absent and never overwritten. Everything under `works/` except templates, and **all** of `docs/`, is **preserved** untouched.
- **Docs rebuild is gated:** the post-update `rebuild` runs only when the repo uses the workspace's *own* docs system (`docs/index.json` plus our versioned doc-type dirs); a repo adopted over its own docs runs `next` only, so the rebuild never crashes on a foreign or absent index.
- **No pruning, just flags:** skills or machinery upstream has dropped are never deleted; the change-list flags managed-looking skill dirs (those whose `SKILL.md` sets `disable-model-invocation: true`) absent from the new manifest **and** retired machinery files (`OBSOLETE_MACHINERY` — e.g. the untiered `slice-executor.md`/`.toml` replaced in v7), so the operator removes them by hand.
- **Post-update tier config:** updates reset the six agent files to upstream defaults — a repo that tunes executor tiers via `executors.toml` re-runs `python3 scripts/workflow.py sync-agents` after every update (`validate` warns while the files drift). An update onto an older workspace seeds a missing `executors.toml` and flags the retired examples (`.env.example` from pre-v8, `executors.toml.example` from v8) as obsolete machinery (flagged, never deleted — remove them with `git rm`).
- **Provenance + version:** each install/update records `works/.workspace-version.json` (`upstream_url`, `workspace_version`, `synced_commit`, `synced_at`). `workspace_version` is the integer `WORKSPACE_VERSION` baked into the artifact (see *Building and releasing the installer*); a marker missing that key was adopted **pre-versioning**. The `/update-workspace` skill passes the upstream commit via `SYNCED_COMMIT`; the file diff is always byte-based, so the marker is informational.
- **Version-aware preview:** before applying, `/update-workspace` reports the sync as "you're on vN → upstream vM". It reads local **N** from `works/.workspace-version.json` (absent ⇒ pre-versioning) and upstream **M** from the top `## v<M>` heading in the fresh clone's root `CHANGELOG.md` (the clone is a full checkout, so the file is there — the installed target never carries `CHANGELOG.md`). It then prints every `## v` entry newer than N (their "what changed" bullets and any **Migration notes**), alongside the existing `--dry-run` file change-list. Equal versions ⇒ "already on vM; any diff below is unreleased upstream drift". Applying stamps the upstream `workspace_version` M into the marker.
- **Git:** the installer makes no git changes — the operator reviews the diff and the agent commits on their approval. Idempotent: re-running `--update` with no upstream change is a clean no-op (machinery unchanged).

## The explain feature ships as a plugin now (retired from the bootstrap, since v15)

The `/explain` educational-explainer used to ride inside the bootstrap as an
optional skill (opt-in via `--with-explain` from v2, and from v4 wired to a KB
document API on the operator's personal Mac). As of **v15** it is **retired from
the distribution entirely** — the feature graduated into a real, portable Claude
Code plugin in the [knowledge repo](https://github.com/leetusik/knowledge), so it
no longer needs to ride inside every workspace. What was removed: the embedded
skill copies (`.claude/skills/explain`, `.agents/skills/explain`), the
`--with-explain` installer flag, and the `WITH_EXPLAIN` / `OPTIONAL_SKILLS`
install-time wiring in `installer/main.py` + `installer/wrapper.sh`. Because
`build.py` discovers skills from disk, deleting the two dirs drops them from the
embedded `PAYLOADS` on rebuild; no build-code change was needed. `--with-explain`
is now an **unknown option** the installer rejects (the wrapper's generic
`-*) die "unknown option $1"` arm).

- **Install the feature as a plugin instead.** Inside Claude Code:

      /plugin marketplace add leetusik/knowledge
      /plugin install knowledge@knowledge

  then run `/knowledge:setup` once to scaffold a knowledge base, and
  `/knowledge:explain <topic>` to use it. Note the namespace change: the embedded
  skill was bare `/explain`; the plugin's command is `/knowledge:explain`.
- **`--update` never auto-deletes an old copy — remove it by hand.** A downstream
  that had `explain` installed keeps its on-disk copies across `--update`: they are
  no longer in `PAYLOADS`, so they are never re-written and never deleted. The
  generic `flag_stale_skills` then flags them **asymmetrically**: the Codex copy
  `.agents/skills/explain` carries the `agents/openai.yaml` marker → flagged stale
  ("remove manually?"), while the Claude copy `.claude/skills/explain` carries no
  `disable-model-invocation: true` marker → treated as an operator-owned skill and
  left untouched, not flagged. This asymmetry is accepted; the v15 CHANGELOG
  **Migration notes** tell existing installs to remove **both** old copies by hand
  and install the knowledge plugin. Nothing is ever auto-deleted. `flag_stale_skills`
  and `OBSOLETE_MACHINERY` needed no edit — the former is generic and already
  produces this behavior; the latter is for retired individual *files*, not skill
  dirs.
- **Release note (v15):** the retirement shipped as workspace **v15**
  (`WORKSPACE_VERSION` 14 → 15 in `installer/main.py` + the `## v15 — 2026-07-21`
  `CHANGELOG.md` entry with **Migration notes**, per the release rule below), all in
  one commit with the rebuilt artifact. This is a payload/installer change only — no
  `sync-agents` re-run is needed. Resolves deferred **D1** (make `/explain` portable
  for public users) by deletion: the plugin makes it portable for real.
- **Verify:** `tests/retrofit_smoke.sh` asserts the default install still omits both
  explain dirs (Test 5, now a permanent invariant) and that `--with-explain` is
  rejected as an unknown option with no explain dir created (rewritten Test 8).

## Auto-explain at the phase review (since v16)

A **passing** phase review now also produces a **phase explainer** — a
self-contained interactive HTML document (change mode: what the phase changed and
why, with a citation-backed "Best practices & next steps" section) filed into the
operator's knowledge base. The review is now **validate + consolidate docs +
explain**. Explain is invoked from the external knowledge plugin retired from the
distribution in v15 (see *The explain feature ships as a plugin now* above) — the
bootstrap no longer *ships* explain, but the review now *invokes* it.

- **Where it runs.** The `slice-executor-high` review executor runs it, on a
  **pass only** (exactly like doc consolidation — never on `changes_requested` /
  `blocked`), after validation and doc consolidation. The step is defined once, in
  the `review-phase` skill checklist (`.claude/skills/review-phase/SKILL.md` + its
  `.agents` mirror); the executor agent files carry only a short pointer, so the
  procedure has a single source of truth and can't drift from the plugin.
- **Skill detection, first hit wins.** The executor locates the installed explain
  skill in order: project `.claude/skills/explain/SKILL.md` → user
  `~/.claude/skills/explain/SKILL.md` → plugin installs under `~/.claude/plugins`
  (`cache/` and `marketplaces/`). None found → skip and report `explain: skipped
  (skill not installed)`. Found → read that `SKILL.md` and follow it as written (the
  checklist never duplicates the skill's procedure), in **change mode with the phase
  as change-ref**.
- **Best-effort, verdict-neutral.** The explain outcome is reported as a one-line
  `explain:` field in `result.md` and the executor's structured return — `saved
  <url-or-path>` / `skipped (skill not installed)` / `skipped (KB unconfigured)` /
  `skipped-offline` / `failed (<reason>)` — and it **never** changes the
  `review_verdict`. The skill's own steps govern its KB config probe
  (`KB_STATUS=unconfigured` / `error` → skip), its research judgment gate (degrades
  to `skipped-offline` when web tools are unavailable), its API save, and its
  API-unreachable local fallback.
- **Research tools (Claude high only).** `.claude/agents/slice-executor-high.md`
  gains `WebSearch, WebFetch` in its `tools:` line so the explain skill's cited
  "Best practices & next steps" section can run at review — read-only research tools
  that fit the review executor's read-heavy job. `sync-agents` patches only `model:`
  / `effort:`, so the new `tools:` line survives sync and `sync-agents --check`
  stays green; no re-run is needed after `--update`. Only the high tier gets them
  (reviews always run there); mid/low and the Codex executors are unchanged. The
  Codex high executor has no per-agent tools list (Codex governs tools via
  `sandbox_mode`), so its review degrades the research section to `skipped-offline`
  by design.
- **Scoped KB-repo commit carve-out.** The explain skill's API-unreachable offline
  fallback commits the explainer with `git -C <KB_ROOT>` in the **separate**
  knowledge-base repo. The review executor's "never commit" invariant gains one
  narrow exception for exactly this: the review slice's auto-explain fallback may
  commit **only** in that KB repo — never in this workspace's repo, and never any
  `git push`. Under a Codex `workspace-write` sandbox (which cannot write outside the
  workspace) the fallback is an automatic skip. The API-reachable path needs no
  carve-out — the KB API makes its own server-side commit, so the executor runs no
  git at all.
- **Adopter setup + release.** Ships as workspace **v16** (`WORKSPACE_VERSION` 15 →
  16 + the `## v16` CHANGELOG entry, one commit with the rebuilt artifact). **No
  adopter action is required** — the step self-skips wherever the plugin or a KB is
  absent, and the verdict is unaffected. Adopters who want auto-explain at their own
  KB install the knowledge plugin (`/plugin marketplace add leetusik/knowledge` →
  `/plugin install knowledge@knowledge`) and run `/knowledge:setup` once. On
  `--update` the `slice-executor-high` agent payload changed (new review step,
  `explain` verdict field, and — Claude only — the `WebSearch` / `WebFetch` `tools:`
  line), but no `sync-agents` re-run is required (the update ships the new agent-file
  bodies directly).

## Building and releasing the installer

The distributable `bootstrap_agentic_workspace.sh` at repo root is **generated** —
never hand-edit it. It is assembled by `python3 installer/build.py` from the
`installer/` source tree, with the **live repo files as the source of truth** for
emitted machinery.

- **Where things live:** `installer/build.py` (deterministic assembler + `--check`),
  `installer/wrapper.sh` (the POSIX-sh wrapper), `installer/main.py` (the Python
  driver: config, write engine, retrofit/update policies, guards, seeding,
  finalizers), and `installer/payloads/` (fresh-install-only seeds with no live
  counterpart: the 11 `doc_bodies/<doc>.md` — the `p1_seed/` scaffolds were deleted in v6).
- **The edit → build → commit loop:** to change what the installer emits, edit the
  **live file** — a skill (`.claude/skills/*` / `.agents/skills/*`), an agent def
  (`.claude/agents/*.md`, `.codex/agents/*.toml`), `scripts/workflow.py`,
  `.claude/settings.json`, `.codex/config.toml`, `works/templates/*`, or the contract
  (`CLAUDE.md`; keep `AGENTS.md` byte-equal — `build.py` asserts it) — or, for a
  fresh-only seed, edit `installer/payloads/`. Then run `python3 installer/build.py`
  and commit the rebuilt artifact **with** your edit. No more heredoc mirroring.
- **Drift guard:** `python3 installer/build.py --check` fails (non-zero) when the
  committed artifact no longer matches `installer/` source; `tests/retrofit_smoke.sh`
  Test 7 runs the same check, so CI/the smoke test flags a stale artifact. The build
  is deterministic — same inputs produce a byte-identical artifact.
- **Release rule (version + changelog):** when an edit ships a machinery change to
  targets, bump `WORKSPACE_VERSION` in `installer/main.py` **and** add the matching
  `## v<N> — <date>` entry to the root `CHANGELOG.md`, in the **same commit** as the
  rebuilt artifact. `/update-workspace` reads that changelog from the upstream clone
  to tell adopters what a sync brings, so a bump without an entry (or vice versa)
  leaves them blind. Repo-only edits that never reach a target (`installer/README.md`,
  `tests/`, `LICENSE`, this `CHANGELOG.md` itself) need no bump. `CHANGELOG.md` is
  **repo-only** — deliberately not emitted to targets.

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
- **No seeded phases (since v6):** the installer seeds nothing — every phase, and therefore every `intent.md`, comes from the create-phase intake flow.
- **Always present:** because `new-phase` scaffolds `intent.md` for every phase, the file always exists for executors to read; `validate` emits a soft (non-failing) warning if an active phase is missing it.

## Local Development

- Install:
- Run:
- Test:
- Build:

## Environment Variables

The workspace machinery reads **no environment variables**. Executor-tier config lives in the repo-root **`executors.toml`** (seeded by the installer with all defaults shown commented out; seed-once — updates never overwrite it; committable — it holds no secrets), read by `python3 scripts/workflow.py sync-agents`. All tables/keys optional — anything missing (or the whole file absent) keeps the built-in defaults. (Until v8 this config was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read and `sync-agents` warns about it.)

| Table | Key | Purpose | Default |
|---|---|---|---|
| `[claude.low]` | `model` | Claude model for `slice-executor-low` | `haiku`; verbatim pass-through |
| `[claude.low]` | `effort` | Effort for `slice-executor-low` | empty = no effort line (haiku rejects the effort param) |
| `[claude.mid]` | `model` | Claude model for `slice-executor-mid` | `sonnet` |
| `[claude.mid]` | `effort` | Effort for `slice-executor-mid` | `xhigh` |
| `[claude.high]` | `model` | Claude model for `slice-executor-high` | `opus` (e.g. `fable`, or `claude-mythos-5` once available) |
| `[claude.high]` | `effort` | Effort for `slice-executor-high` | `xhigh` |
| `[codex.low]` | `model` | Codex model for `slice-executor-low` | `gpt-5.5` |
| `[codex.low]` | `effort` | Codex reasoning effort, low tier | `medium` |
| `[codex.mid]` | `model` | Codex model for `slice-executor-mid` | `gpt-5.5` |
| `[codex.mid]` | `effort` | Codex reasoning effort, mid tier | `high` |
| `[codex.high]` | `model` | Codex model for `slice-executor-high` | `gpt-5.5` |
| `[codex.high]` | `effort` | Codex reasoning effort, high tier | `xhigh` |

Values are double-quoted TOML strings; the parser is a strict subset — an unrecognized line, unknown section, duplicate key, or unquoted value errors with its line number. Empty `model` values are an error; `effort = ""` omits the effort line entirely.

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
