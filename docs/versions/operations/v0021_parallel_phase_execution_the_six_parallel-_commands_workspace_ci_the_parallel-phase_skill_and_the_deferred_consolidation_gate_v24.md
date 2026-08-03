---
doc_id: operations
version: v0021
created_at: 2026-08-04T00:22:46+09:00
source: P12.REVIEW
summary: parallel phase execution: the six parallel-* commands, workspace CI, the parallel-phase skill and the deferred consolidation gate (v24)
previous: v0020_drop_the_low_executor_tier_two-tier_mid_high_routing_risk_low_high_defaulting_to_high_one-step_escalation_workspace_v23
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

Running the workflow: every slice — including the phase **review** — is executed by a `slice-executor` tier subagent (risk-routed by the orchestrator; see *Executor tiers* below). As of **v23** there are **two** tiers, not three: the `low` tier is retired, `slice-executor-mid` takes a one-line (or few-line) code edit or docs, and `slice-executor-high` takes everything else — essentially all code writing, and every cross-file change. Durable docs are versioned **once per phase, at the review slice** — the executor consolidates the phase's "Doc impact" notes (left in `phase.md` by earlier slices) into new versions on a passing review, rather than per slice; the read-only `phase-reviewer` is retired. As of **v21** that consolidation is explicitly **pass-only work**: a `changes_requested` or `blocked` verdict **stops** the review executor before it and hands the phase back with numbered findings and proposed fix slices, and the review **no longer writes a phase explainer at all** (this supersedes v16's auto-explain) — it reports the fixed pointer `explain: not written — run /explain for this phase`, and explaining is a separate operator-run step. See *The phase review — validate, then branch on the verdict* below. As of **v17**, the plugin-free **env-var/REST path is the documented default** for reaching a knowledge base — two exports in `~/.zshenv` let `/explain` save the explainer over plain REST — and a freshly bootstrapped workspace ships the same guidance in its own seed `operations.md`. See *Knowledge setup — the env-var/REST default* below. As of **v19**, the `do-whole-phase` loop is no longer strictly serial — the orchestrator **may** spend the executor's idle window preparing the *next* slice and then reconcile instead of re-researching; **v20** retired the bespoke `slice-planner` agent and recast that from a mandated procedure into an optional, mechanism-free judgment call — and every plan-persistence site **copies the operator-approved harness plan file** into `plan.md` instead of retyping it. See *Idle-window preparation* and *Persisting the approved plan by copy* below. As of **v24** a phase may optionally run on its **own branch and git worktree** instead of the shared default stream: six `parallel-*` commands cover the whole lifecycle, the workspace ships **CI** (`.github/workflows/workspace-ci.yml`), a new **`parallel-phase`** skill carries the runbook, and a parallel phase's passing review **defers** its doc consolidation to a serialized post-merge step on the default stream. Everything about the default single-stream flow is unchanged. See *Parallel phase execution* below.

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Executor tiers (risk routing, `executors.toml`, escalation) — since v7, two-tier since v23

Every slice is executed by one of two `slice-executor` tiers, picked by the orchestrator from the slice's `kind` + `risk`:

| Tier | Routes | Claude (`economy`, default) | Claude (`flex`) | Codex (both) | Behavior |
|---|---|---|---|---|---|
| `slice-executor-mid` | implementation/`fix` with `risk` exactly `low` — a one-line (or few-line) code edit, or docs | `sonnet` @ `high` | `sonnet` @ `xhigh` | `gpt-5.5` @ `high` | Judgment within the plan's intent; escalates the moment the slice turns out to be real code writing, spans more than one file, or breaks the plan's assumptions |
| `slice-executor-high` | decomposition, the phase review, and everything else (`high`/`medium`/unset/unknown) — essentially all code writing, and every cross-file change | `opus` @ `high` | `opus` @ `xhigh` | `gpt-5.5` @ `xhigh` | Full judgment; the escalation ceiling |

**The risk vocabulary is two values — `low` and `high` — and `--risk` defaults to `high`** on both `new-slice` and `promote-deferred` (it defaulted to `medium` through v22). Routing fails safe: only an exact `low` reaches `mid`, so an unset, legacy (`medium`), or misspelled risk lands on `high`. The engine still does **not** validate `--risk`; that non-validation is deliberate and unchanged. A phase's `DECOMP` and `REVIEW` slices are now created with `risk: high` to match the `kind` rule that already routed them to `slice-executor-high`.

Defaults come from a **mode preset** (`EXECUTOR_PRESETS` in `scripts/workflow.py`): `economy` is the shipped default (`sonnet` @ `high` / `opus` @ `high`) and `flex` raises every Claude tier one effort step (`sonnet` @ `xhigh` / `opus` @ `xhigh`); Codex tiers are identical in both. Pick one with a top-level `mode = "flex"` in `executors.toml`, then apply with `sync-agents`. The surviving `mid` tier kept its own v18 models and efforts when the `low` tier was dropped — it was **not** re-cut down to the old low values. (`effort = ""` remains the escape hatch for a model that rejects the effort parameter.)

- **Configure via `executors.toml` (since v8; seeded since v9):** the installer seeds `executors.toml` at the repo root with all defaults shown commented out — seed-once, never overwritten by updates, safe to delete (absent = defaults), committable (it holds no secrets). Uncomment/set `model` / `effort` under any of the `[claude.mid|high]` / `[codex.mid|high]` tables, then apply with `python3 scripts/workflow.py sync-agents`. A leftover `[claude.low]` / `[codex.low]` section is rejected by name with a migration message rather than a generic parse error. Values are written verbatim (aliases, full model IDs, `inherit`); an **empty** `effort = ""` omits the effort line (required for models that reject the effort parameter, e.g. haiku); an empty model errors, and so does any unrecognized line or section (line-numbered). `sync-agents --check` reports drift without writing; `validate` warns while the agent files drift from `executors.toml`/defaults. (Until v8 this was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read — `sync-agents` warns about it.)
- **Escalation (one step since v23):** a `mid` executor that can't safely complete a slice returns `escalate` with findings (a failed/empty `mid` return counts the same); the orchestrator appends an `## Escalation` section to the slice's `plan.md` and re-dispatches the slice to `slice-executor-high` — max **1** per slice (the ladder is a single step now), never past `slice-executor-high`, plan re-approved by the operator unless running `auto`. `needs_operator`/`blocked` keep their meanings and still stop the run.
- **Updating from a pre-v23 workspace:** `--update` never deletes, so it flags the now-stale `.claude/agents/slice-executor-low.md` and `.codex/agents/slice-executor-low.toml` for manual removal; delete both, drop any `[claude.low]`/`[codex.low]` block from `executors.toml`, and re-run `sync-agents`. Slices already carrying `risk: medium` or `risk: low` keep working — `medium` routes to `high`, `low` routes to `mid`.
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
- **Write policy:** (1) **overwrite** machinery — `scripts/workflow.py`, everything under `.claude/agents/` + `.codex/agents/` (the three tier subagents; `_is_machinery()` matches the whole `.claude/agents/` prefix, so a brand-new agent file arrives as `added: 1 file(s)` — and a *retired* one is never deleted, only flagged through `OBSOLETE_MACHINERY`, as `slice-planner.md` was in v20), every skill in `.claude/skills/` + `.agents/skills/`, `.codex/config.toml`, `works/templates/*`; (2) **additive merge** for `.claude/settings.json` (union permissions, never clobber); (3) **contract** — refresh the `*.workspace.md` sidecar if the repo was retrofitted, else overwrite `CLAUDE.md`/`AGENTS.md` in place; (4) **seed-once** — `executors.toml` is created when absent and never overwritten. Everything under `works/` except templates, and **all** of `docs/`, is **preserved** untouched.
- **Docs rebuild is gated:** the post-update `rebuild` runs only when the repo uses the workspace's *own* docs system (`docs/index.json` plus our versioned doc-type dirs); a repo adopted over its own docs runs `next` only, so the rebuild never crashes on a foreign or absent index.
- **No pruning, just flags:** skills or machinery upstream has dropped are never deleted; the change-list flags managed-looking skill dirs (those whose `SKILL.md` sets `disable-model-invocation: true`) absent from the new manifest **and** retired machinery files (`OBSOLETE_MACHINERY` — e.g. the untiered `slice-executor.md`/`.toml` replaced in v7, and `.claude/agents/slice-planner.md` retired in v20), so the operator removes them by hand.
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

## The phase review — validate, then branch on the verdict (v21 supersedes the v16 auto-explain)

The phase review is one `slice-executor-high` run that does two things in order:
**validate the phase's slices together, then judge them**. Only after the verdict is
settled does the run split — and as of **v21** the split is a real branch, not a
skipped step:

- **On `pass`:** consolidate the phase's "Doc impact" notes from `phase.md` into new
  doc versions (`doc-new-version` → edit the returned `edit_path` → `rebuild-docs`),
  one version per affected doc capturing the whole phase, then return.
- **On `changes_requested` or `blocked`: stop and hand back.** Doc consolidation is
  **pass-only work**; the executor runs none of it, and no other pass-only step
  either. It returns the verdict, numbered findings, and proposed fix slices
  (`<P>.F<n>`, one line of scope each) to the orchestrator, which decides what happens
  next. The docs stay unversioned until a later passing re-review consolidates the
  whole phase in one go.
- **On `pass` in a phase running in parallel mode (since v24): consolidate nothing.**
  A branch review instead **verifies** that `phase.md`'s "Doc impact" list covers every
  durable-truth change the phase made — an incomplete list is a review finding — and
  returns `doc_versions: none — deferred to post-merge consolidation (parallel mode)`.
  The versions are cut later, one phase at a time, on the default stream. The
  `docs/current` vs. `docs/index.json` parity check moves to that consolidation step
  too. This is engine-enforced, not merely documented: `doc-new-version` refuses to run
  on a parallel stream.

**"Stop" is scoped to the pass-only work, not to the review.** Validation and judgment
always complete first, across every slice — the executor never aborts at the first
failing check, or the orchestrator learns one finding per review cycle instead of all
of them at once. The distinction is stated in that order on every surface (both
`review-phase` copies, both `do-next-slice` copies, `do-whole-phase`, both
`slice-executor-high` files, and both contract bullets), and the clinching sentence is
*"This is a full stop, not a skipped step you carry on past."*

**The review writes no phase explainer (v21 reverses v16).** Between v16 and v20 a
passing review auto-produced an HTML phase explainer by locating and following the
external knowledge plugin's explain skill. That step is **gone from the review's
default behaviour**: the review locates no explain skill, runs no KB probe, has no
offline fallback, and commits nothing anywhere. Explaining is now a **separate
operator-run operation** (`/explain`). The review's whole remaining obligation is one
fixed pointer line, reported in `result.md` and in the structured return and
**identical on every verdict** — it costs the executor no work, so it does not collide
with the stop rule:

    explain: not written — run /explain for this phase

- **The KB-repo commit carve-out is deleted, not narrowed.** v16 had granted the review
  slice one narrow exception to "never commit" — the explain skill's offline fallback
  committing with `git -C <KB_ROOT>` in the *separate* knowledge-base repo. With
  auto-explain gone the exception has no purpose, so both `slice-executor-high` files
  now read "no exception anywhere: not in this workspace's repo and not in any other
  git root, on any slice kind", with read-only inspection (`git status` / `git diff`)
  explicitly still fine — the bright line is about *writes*. `slice-executor-low` /
  `-mid` never carried the carve-out.
- **`WebSearch` / `WebFetch` stay on the Claude high tier.** They were added in v16 for
  the explainer's cited research, but a reviewer occasionally needs to check an
  external fact, so they remain on `.claude/agents/slice-executor-high.md`'s `tools:`
  line by the operator's explicit call (cheap to remove later if they go unused).
  `sync-agents` patches only `model:` / `effort:`, so that line survives sync and
  `sync-agents --check` stays green. The Codex high executor still has no per-agent
  tools list (Codex governs tools via `sandbox_mode`).
- **Release + adopter impact.** Ships as workspace **v21** (`WORKSPACE_VERSION` 20 → 21
  + the `## v21` CHANGELOG entry, one commit with the rebuilt artifact). **Migration
  notes: nothing to delete or configure** — the review simply stops writing explainers;
  run `/explain` when you want one. Nine live machinery files carried the change; the
  fresh-install banner (`installer/main.py`) and the seeded
  `installer/payloads/doc_bodies/operations.md` knowledge section were part of it, since
  both had claimed a passing review auto-saves the explainer.
- **Lesson (v21):** the two surfaces above say "auto-**save**", not "auto-explain", so a
  grep for `auto-explain` missed them and a fresh-install probe is what caught them.
  When editing explainer/knowledge behaviour, grep `explain|explainer|auto-save|KB_API`
  across `installer/payloads/` **and** the banner prints, not just the skills.

## Parallel phase execution (opt-in, since v24)

A phase can be moved off the shared default stream onto its own branch + git worktree, with its
own orchestrator session, so two phases progress at once without fighting over one next-slice
pointer. It is **opt-in and suggested, never a default**: a workspace that ignores it sees no
behavioral change at all.

**Opting in is a creation-time decision.** `parallel-start` requires the phase to still be
`planned`, so once decomposition or execution has begun the phase stays on the default stream.

### The six commands

| Command | Runs on | Does |
|---|---|---|
| `parallel-start <P> [--worktree PATH] [--slug SLUG]` | default stream | Stamps the phase, cuts `phase/P<N>-<slug>` and adds a git worktree (default `../<repo-dirname>-<P>`) |
| `parallel-status` | any checkout | Read-only cross-stream view; the only workflow command that writes nothing |
| `parallel-gate <P> [--branch-ref REF] [--main-ref REF]` | any checkout / CI | Quiet-point gate: `GATE OPEN` (exit 0) or `GATE CLOSED` + numbered reasons (exit 1) |
| `parallel-merge-finish` | default stream | Right after the merge: regenerate every generated file and list the phases still owing doc consolidation |
| `parallel-consolidated <P>` | default stream | Records that the deferred consolidation is done |
| `parallel-teardown <P>` | not the phase's own branch | Retires the merged branch + worktree |

- **`parallel-start`** is the single, narrow exception to "the engine never commits": the stamp
  must exist on *both* the default branch (so its pointer skips the phase) and the phase branch
  (so the worktree claims the stream), and the branch has to be cut from a commit that already
  contains it. It makes one fixed-message commit — `chore(works): opt <P> into parallel
  execution`, no trailers — after a clean-tree guard, so it can contain nothing but the stamp plus
  the regenerated `works/` files. Every guard (phase `planned`, no existing block, inside a git
  work tree, on the default stream, clean tree, branch name free, worktree path free) runs before
  any mutation, so a refusal leaves zero partial state.
- **`parallel-status`** answers "what is happening on every stream right now?" from any checkout:
  this stream's pointer, then per parallel phase its branch / worktree / consolidation state and
  the **branch-side slice table** read with `git show` / `git ls-tree` — which the default
  stream's own `works/backlog.md` cannot show before the merge — plus a one-line verdict naming
  the next command to run. It deliberately skips the usual rebuild (it is meant to be run *from* a
  worktree, where a rebuild would rewrite that checkout's dashboards as a side effect), reports a
  `source=` line saying what it read, and falls back to the local folder copy with a note once the
  branch is torn down.
- **`parallel-gate`** reads the branch phase's `done` + review `pass` **from the branch**, never
  from the default stream's stale pre-merge copy, and requires the default stream to be quiet
  (every default-stream active phase `planned` or `done`; `in_progress` / `in_review` / `pending` /
  `blocked` close it — other parallel phases never make it busy). It refuses to use the working
  tree as a stand-in for main when the checkout *is* the phase branch.
- **`parallel-merge-finish`** refuses while a merge is in progress, then re-derives every generated
  file and lists each merged-but-unconsolidated phase with its `phase.md` "Doc impact" location and
  the exact follow-up sequence — explicitly **one phase at a time**. It makes no commit.
- Archiving is gated: a phase whose `execution.consolidation` is still `"pending"` cannot be
  archived (`archive-phase` refuses, `archive-all` lists it, `rotate-backlog` leaves it active).
  `parallel-teardown` only *warns* in that state — removing a worktree is reversible, archiving is
  not.

**Proactive suggestion (engine half).** `new-phase` prints a hint when another default-stream phase
is already `in_progress`, and `next` prints one when a planned phase is waiting behind an
in-progress one. Both name `parallel-start`, run nothing, touch no generated file, and are silent
otherwise. The skills carry the matching relays.

### The integration sequence (agent-run)

After the branch review passes, the orchestrator runs the whole integration itself — the
`parallel-phase` skill holds the runbook:

    parallel-gate <P> → push → gh pr create → gh pr checks --watch → gh pr merge --merge
      → parallel-merge-finish → commit → doc-new-version (one phase at a time, on the default
      stream) → parallel-consolidated <P> → parallel-teardown <P> → commit

If the gate is closed, the agent **stops and reports** instead of merging. The engine has no `gh`
wrapper: PR steps stay skill-guided so `gh` auth/output/error handling remains agent territory
and `workflow.py` stays offline-testable, with `parallel-gate` as the one shared check that both
CI and the agent run.

### Workspace CI

`.github/workflows/workspace-ci.yml` ships with the workspace:

- job **`validate`** — runs `python3 scripts/workflow.py validate` on every push and PR, and
  shell-guards the upstream-only checks (`installer/build.py --check`, `tests/retrofit_smoke.sh`)
  on the presence of those files, so an adopting workspace with no `installer/` or `tests/` skips
  them cleanly;
- job **`parallel-gate`** — runs only on a `pull_request` whose head ref starts with `phase/`. It
  checks out the **PR head sha** (`fetch-depth: 0`) rather than the default PR *merge* commit
  (whose `works/` is a blend of both sides), derives `<P>` from the branch name, and runs
  `parallel-gate <P> --branch-ref HEAD --main-ref origin/<base>`. A closed gate exits 1 → red
  check; whether that blocks the merge is branch protection's business.

No external actions beyond `actions/checkout@v4`, ASCII only, no secrets.

### Installer and adopter impact (workspace v24)

- `.github/workflows/workspace-ci.yml` is **seed-once** — created when absent, never overwritten,
  because an adopter's CI is theirs to own.
- `.gitattributes` is **line-merged** — `works/events.jsonl merge=union` is appended only when that
  exact line is absent, and existing content is never rewritten. Skipping the file entirely would
  silently drop the union rule exactly on the repos where a phase-branch merge conflicts.
- Both are emitted by one policy helper, so fresh install, `--into-existing` and `--update` behave
  identically, and neither trips the fresh-install conflict guard.
- **The shipped `.claude/settings.json` deny narrows from `Bash(git push:*)` to
  `Bash(git push --force:*)`.** Agent-driven integration has to push phase branches, and a blanket
  deny blocked that outright with no prompt; pushes now go through the normal interactive
  permission prompt (nothing is pre-allowed) while force-pushes stay denied. **Settings merges are
  additive and a deny can never be removed downstream, so existing adopters must delete the old
  `Bash(git push:*)` line by hand.**
- `.githooks/pre-commit` also matches `^\.github/` and `^\.gitattributes$`, since both are embedded
  payloads and editing either must force the artifact-parity check.

### The `parallel-phase` skill

`/parallel-phase` (Claude Code) and the Codex twin are the single source for the lifecycle: when to
suggest, opting in, stream-scoped work in the worktree, the branch review's deferral, and the
10-step integration sequence. Like every other command skill it is **explicit-invocation only**.
`create-phase`, `do-next-slice`, `do-whole-phase`, `review-phase` and `archive-phase` carry only the
matching relays and gates, and the contract lists the six command names — the contract routes, the
skill explains.

## Knowledge setup — the env-var/REST default (since v17)

`/explain` files its HTML phase explainer into a **knowledge base**; this is how a
workspace points at one. As of **v17** the plugin-free **env-var/REST path is the
documented default**, and a freshly bootstrapped workspace ships the same guidance in
its own seed `operations.md` (a `## Knowledge (phase explainers)` section between
Environment Variables and Deployment) plus a `Knowledge (optional)` line in the
fresh-install stdout. Since **v21** both of those seeds say plainly that explaining is
an **operator-run step and the phase review writes no explainer** — before v21 they
described a passing review auto-saving one, which would have shipped a false claim into
every freshly bootstrapped workspace's `operations` v0001.

- **Two exports in `~/.zshenv`, never a repo `.env`.** Sign up at the knowledge
  service, mint an API key, and export it where every zsh invocation inherits it:

      export KB_API_BASE_URL="https://knowledge.hi2vi.com"
      export KB_API_TOKEN="vk_..."

  `~/.zshenv` (not a repo `.env`) is deliberate: neither Claude Code nor Codex
  auto-loads a `.env` into the process environment, so the explain skill's resolver
  would never see it — and a secret in a repo file risks an accidental commit (this
  repo's own retired executor-tier `.env` taught the same lesson). One org-level key
  serves every repo; each document's project defaults to the repo's directory name.
- **Any agent saves via plain REST.** With the env vars set, `/explain` saves the
  explainer over plain REST (a Bearer-headed `POST`) — Claude Code and Codex equally,
  no plugin install required. The explain skill's resolver reads env vars first,
  overriding any config file. Cloudflare in front of the service is **not** a barrier —
  a plain `curl` reaches the app, and a `401` without a token is the app itself, not a
  challenge.
- **Codex caveat.** Codex's `workspace-write` sandbox blocks outbound network by
  default, so the save skips. To let a Codex `/explain` run post, opt in with
  `[sandbox_workspace_write] network_access = true` in `~/.codex/config.toml` — this
  loosens **all** Codex workspace-write runs (your call); Claude Code needs nothing.
- **Plugin as the alternative/richer path.** The Claude Code knowledge plugin
  (`/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge`
  → `/knowledge:setup`, `/knowledge:explain` on demand) stays available for a richer
  workflow; the env-var/REST default needs none of it.
- **The SaaS side is consumed, not built here.** Org-level keys and returned doc URLs
  are owned by the knowledge service (its sibling phases P18/P19/P20); this repo
  documents the contract it consumes and implements no SaaS-side behavior.

## Idle-window preparation — optional, `do-whole-phase` only (v19, recast in v20)

`do-whole-phase` used to idle for the whole executor run: plan N → dispatch N → wait
→ N returns → research + plan N+1 → gate → dispatch N+1. Research for N+1 never
depended on N *finishing*, only the final reconciliation did, so **v19** opened that
idle window for preparing the next slice. **v20 changed what kind of rule this is.**
v19 prescribed a mechanism — dispatch the bespoke read-only `slice-planner` agent
right after dispatching executor N, with five hard skip conditions. As of v20 the rule
is a **permission, not a procedure**: while executor N runs in the background the
orchestrator is idle on the main thread and **may** use that window to prepare slice
N+1 — by dispatching Claude Code's built-in read-only **`Explore`** agent, by reading
files inline itself, by thinking the slice through, or by simply waiting. Nothing is
mandatory, no mechanism is prescribed, and the call is the orchestrator's per slice.
The goal is efficient, high-quality work, not a procedure to follow.

- **The bespoke agent is retired.** `.claude/agents/slice-planner.md` is deleted, along
  with its three installer touchpoints (`build.py::FIXED_LIVE_FILES`, the explicit
  `write_text` in `main.py`, and `main.py::MANAGED_FILES`) and **plus a fourth edit that
  had to be added**: the file joins `OBSOLETE_MACHINERY`, the only channel that tells a
  v19 workspace to remove it by hand (`--update` never deletes). Deleting the agent also
  dissolves the v19 anomaly of an agent sitting outside `EXECUTOR_TIERS` — no
  `executors.toml` knob, no `sync-agents` coverage, no `validate` drift warning, and no
  in-file pinned model for `/update-workspace` to silently reset.
- **The enforcement changed, and the docs say so.** v19's read-only guarantee was
  structural — the planner's `Read, Glob, Grep` allowlist made a repo write impossible.
  With the bespoke agent gone that guarantee is weaker: `Explore` has `Bash`, and inline
  research is bounded only by the orchestrator's own discipline. **Read-only is now a
  rule to follow, not a structural property.** This is the accepted cost of not carrying
  a fourth managed agent surface.
- **Hard limits — they constrain the *how*, never the *whether*.** Whatever the
  orchestrator chooses stays strictly **read-only** (no repo writes, no `workflow.py`
  state commands, no commits, and never any part of slice N+1's actual work); dispatches
  **no second executor** (read-only research is not an executor and does not count
  against the one-at-a-time rule); **never blocks** — executor N's completion
  notification always wins, anything not ready by then is dropped, and
  `finish-slice` / `validate` / the commit are never delayed for it; is **discarded** on
  any verdict other than `done` (`escalate`, `blocked`, `needs_operator`, a failed or
  empty return — the world it assumed did not happen); and lives in the **session
  scratchpad, never in a slice folder** (a slice owns exactly two context files, and a
  stale draft must never be readable as an approved plan). Whatever is gathered is
  advisory input to the orchestrator's own plan, never an approved plan: **the
  operator's approval gate does not move**.
- **Judgment, not a checklist.** v19's five skip conditions survive in full but as
  *guidance*: preparing ahead usually does not pay off when the current slice is
  `DECOMP` (the middle slices do not exist yet), when the next is `REVIEW` (never
  pre-planned) or already `ready` (`[r]` — an approved `plan.md` exists), when the phase
  or any slice is `pending` (the loop stops there anyway), or when the next slice's
  files sit inside slice N's **blast radius** (the paths N's `plan.md` says it will
  touch — anything read there may be stale by the time N returns; `phase.md` is inside
  every running slice's blast radius by construction, so it is readable-but-stale).
  It tends to pay off when N+1's subject is separate from what N is touching, when it is
  decision-dense, or when it lands in a large unfamiliar area. **Weigh these; do not tick
  them off.**
- **If you delegate, keep the ask small.** The condensed contract of the retired agent's
  prompt now lives in the skill itself: hand the subagent everything by path (slice N+1's
  id and folder, the phase folder, and the paths N is mutating as explicit exclusions),
  ask a few sharp questions rather than "research this slice", and ask for a compact
  **advisory brief** — relevant files with one line each, patterns to reuse, constraints
  and risks, open questions, and an explicit "not read / possibly stale" list. Never a
  plan, never a file dump. A shallow brief that arrives in time beats an exhaustive one
  that does not.
- **After N returns**, plan N+1 by **reconciling** whatever was gathered against what N
  actually changed (`files_changed`, `result.md`, the new `phase.md` notes) instead of
  re-reading everything; do a full research pass when nothing was prepared, what there
  was got dropped, or the state visibly drifted.
- **Scope.** `do-whole-phase` only — `do-next-slice` never prefetches (it stops after one
  slice, so a tail prefetch speculates on work the operator may never run), and
  `plan only` runs no executor, so there is no idle window to fill. It applies in the
  default loop **and** in `auto`, where the reconciliation feeds the inline plan instead
  of a plan-mode pass.
- **Accepted trade-offs.** Some preparation tokens are spent and thrown away, and
  anything read while an executor mutates the tree may be stale — the blast-radius
  guidance is a mitigation, not a guarantee. `auto` gets the cleanest benefit; in manual
  mode the saving lands on the operator's side of the gate.

## Persisting the approved plan by copy (since v19)

Every plan-persistence site now **copies** the operator-approved plan instead of
re-emitting it. In Claude Code the harness already holds the exact approved plan on
disk (the plan-mode message names a file under `~/.claude/plans/`), so the
orchestrator `cp`s it into the slice's `plan.md` — byte-exact, removing the one step
where a paraphrase or a silent truncation could creep in.

- **The confirm-before-copy guard is load-bearing, not decorative.** The harness
  reuses **one plan file per session**, so before copying, confirm the file's opening
  lines match the plan just approved. Use the exact path the harness named for *this*
  planning session — never glob `~/.claude/plans/` and never pick by modification time.
- **Copy immediately after approval, before the next `EnterPlanMode`**, which
  overwrites the file.
- **Append after the copy, never rewrite it.** Slice-local additions — an
  `## Escalation <n>` section, for example — go *after* the copied body; the copied
  text itself is never edited.
- **`Write` remains the fallback wherever no plan file exists:** Codex (no plan mode)
  and `auto` (plan mode is never entered, so the harness writes no file). `auto` is the
  one persistence path that stays on `Write`.
- **Sites covered:** `do-next-slice` step 2 — its default branch *and* its `plan only`
  branch, in both the `.claude/skills/` and `.agents/skills/` copies (bodies stay
  byte-identical) — plus `do-whole-phase`'s default loop and its `plan only` branch
  (its `auto` branch keeps `Write` explicitly), and both contract clauses in
  `CLAUDE.md`/`AGENTS.md`. Unrelated and deliberately untouched: the "verbatim"
  language about the **operator's original request** in `intent.md`.
- **`.claude/settings.json` gains `Bash(cp:*)`** so the copy does not raise a
  permission prompt immediately after every approval gate. It is merged into an
  existing settings file on `--update` (`_merge_settings_json` unions permission
  entries), so adopting workspaces pick it up automatically.

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
- **Adding a *new* `.claude/agents/*.md` takes THREE edits, not one** (learned shipping
  `slice-planner` in v19 — with only the first, the payload ships but is never written,
  and every grep of the artifact still passes): (1) `installer/build.py` →
  `FIXED_LIVE_FILES`, because `.claude/agents/` is enumerated explicitly while skills are
  globbed from disk; (2) `installer/main.py` → an explicit
  `write_text(".claude/agents/<name>.md", …)`, because the existing agent write is a loop
  over `("low", "mid", "high")` that will never emit a fourth file; (3)
  `installer/main.py` → `MANAGED_FILES`, for the fresh-install conflict guard and
  managed-file bookkeeping. The `--update` path needs nothing (see the write policy
  above). **Verify with a real install probe, not a grep** — a fresh install into a
  scratch dir is the only check that catches dead payload.
- **Retiring one takes FOUR edits** (learned removing `slice-planner` in v20): the same
  three, reversed, **plus** an `OBSOLETE_MACHINERY` entry in `installer/main.py` with
  the house `# retired in vNN — <why>` comment. `--update` never deletes, and
  `flag_stale_skills()` walks only `.claude/skills/` + `.agents/skills/`, not
  `.claude/agents/` — so `OBSOLETE_MACHINERY` is the **only** channel that tells an
  already-installed workspace to remove the file by hand
  (`flag_obsolete_machinery()` pushes it into `UPDATE_SUMMARY["stale"]`). Without it
  every adopting workspace silently keeps a dead agent file. Consequence to expect:
  `grep -c '<retired-name>' bootstrap_agentic_workspace.sh` is **1, not 0** — the
  artifact embeds `installer/main.py`, so the retirement entry necessarily rides in it.
  The real check is that the single hit *is* that entry and that `grep -rl` over a fresh
  install probe returns nothing.
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

The workspace machinery reads **no environment variables**. Executor-tier config lives in the repo-root **`executors.toml`** (seeded by the installer with all defaults shown commented out; seed-once — updates never overwrite it; committable — it holds no secrets), read by `python3 scripts/workflow.py sync-agents`. All tables/keys optional — anything missing (or the whole file absent) keeps the built-in defaults. There are two tiers as of v23: a retired `[claude.low]` / `[codex.low]` section is an error naming the retirement, not a silent no-op. (Until v8 this config was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read and `sync-agents` warns about it.)

| Table | Key | Purpose | Default (`economy` preset) |
|---|---|---|---|
| _(top level)_ | `mode` | Preset the per-tier defaults come from — `economy` or `flex` | `economy` |
| `[claude.mid]` | `model` | Claude model for `slice-executor-mid` | `sonnet`; verbatim pass-through |
| `[claude.mid]` | `effort` | Effort for `slice-executor-mid` | `high` (`flex`: `xhigh`); empty = no effort line, for models that reject the param |
| `[claude.high]` | `model` | Claude model for `slice-executor-high` | `opus` (e.g. `fable`, or `claude-mythos-5` once available) |
| `[claude.high]` | `effort` | Effort for `slice-executor-high` | `high` (`flex`: `xhigh`) |
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
