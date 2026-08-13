---
doc_id: operations
version: v0026
created_at: 2026-08-14T06:46:18+09:00
source: P15.REVIEW
summary: Operate the single-harness workspace: Claude-only executor config, the v31 install/retrofit/update contract, and a uniform pending gate
previous: v0025_operate_the_v30_codex_visual-design_gate_explicit_resume_decomp2_and_browser-fidelity_lifecycle
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
below. As of **v26**, the `/explain` educational-explainer **ships with the workspace
again**, reversing v15's retirement — it is operator-invoked only and sets a knowledge
base up on first use, on the hosted service at `knowledge.hi2vi.com`. The
`--with-explain` flag stays retired; `explain` is unconditional now. See *`/explain`
ships with the workspace again* below.

As of **v31 the workspace ships Claude Code only** — Codex support is removed. One
contract (`CLAUDE.md`, no `AGENTS.md` twin), one set of entry points (`.claude/`), one
set of **17 workflow skill packages**, and the two `.claude/agents/slice-executor-{mid,high}.md`
tiers. The `.agents/` skill mirror, `.codex/config.toml`, and the `.codex/agents/*.toml`
executors are gone from the repository and from the installer payload; the v29 dual-harness
inventory, Codex's automatic-only execution skills, and the harness-specific preset halves
described below in earlier form all went with them. Claude Code keeps default `auto` plus
opt-in `gate` and `plan only`. Commits and saved explainers still identify the model that
actually performed the work rather than a hard-coded default. **Adopters:** see
*Updating an adopted workspace to upstream* — an update flags the retired trees instead of
deleting them, and never touches an `AGENTS.md` your repo maintains for other tools.

Running the workflow: every slice — including the phase **review** — is executed by a `slice-executor` tier subagent (risk-routed by the orchestrator; see *Executor tiers* below). As of **v23** there are **two** tiers, not three: the `low` tier is retired, `slice-executor-mid` takes a one-line (or few-line) code edit or docs, and `slice-executor-high` takes everything else — essentially all code writing, and every cross-file change. Durable docs are versioned **once per phase, at the review slice** — the executor consolidates the phase's "Doc impact" notes (left in `phase.md` by earlier slices) into new versions on a passing review, rather than per slice; the read-only `phase-reviewer` is retired. As of **v21** that consolidation is explicitly **pass-only work**: a `changes_requested` or `blocked` verdict **stops** the review executor before it and hands the phase back with numbered findings and proposed fix slices, and the review **no longer writes a phase explainer at all** (this supersedes v16's auto-explain) — it reports the fixed pointer `explain: not written — run /explain for this phase`, and explaining is a separate operator-run step. See *The phase review — validate, then branch on the verdict* below. As of **v17**, the plugin-free **env-var/REST path is the documented default** for reaching a knowledge base — two exports in `~/.zshenv` let `/explain` save the explainer over plain REST — and a freshly bootstrapped workspace ships the same guidance in its own seed `operations.md`. **v26 supersedes this**: the shipped `explain` skill sets a knowledge base up on first run, and the env vars became the override for an existing base, hosted or self-hosted. See *Knowledge setup* below. As of **v19**, the `do-whole-phase` loop may spend an executor's idle window preparing the *next* slice and then reconcile instead of re-researching; **v20** retired the bespoke `slice-planner` agent and recast that from a mandated procedure into an optional, mechanism-free judgment call. In the default automatic path the orchestrator writes its inline plan directly to `plan.md`; only the gated modes copy the operator-approved harness plan file. See *Idle-window preparation* and *Persisting plans* below. As of **v24** a phase may optionally run on its **own branch and git worktree** instead of the shared default stream: six `parallel-*` commands cover the whole lifecycle, the workspace ships **CI** (`.github/workflows/workspace-ci.yml`), a new **`parallel-phase`** skill carries the runbook, and a parallel phase's passing review **defers** its doc consolidation to a serialized post-merge step on the default stream. Everything about the default single-stream flow is unchanged. See *Parallel phase execution* below. As of **v25**, the no-mode execution default is **`auto`** — plan inline → write `plan.md` → dispatch the executor — while `gate` and `plan only` remain opt-in approval paths (**v31**: these are simply *the* modes; there is no second harness to narrow them to).

Product visual work automatically invokes the `design-cowork` guide: Claude Design (claude.ai/design)
plus the operator make every visual decision, the orchestrator writes one `handoff.md`, stops
`pending`, reads the result back with main-thread-only `DesignSync`, and lands it as-is. Design
remains a main-thread-only `co-work` boundary; later slices implement the signed contract and prove
fidelity in a real browser. **v31 removed the Codex half of this** (ImageGen generation, the
`record.json` / `SIGNOFF.md` round record, the inline-resume carve-out) along with Codex itself; see
*Visual-design runbook* below.

## Purpose

Use this doc for local development, environment variables, deployment, infra, jobs, observability, backups, and recovery.

## Visual-design runbook (Claude Design + DesignSync; single-harness since v31)

`design-cowork` is the one workspace guide that may invoke itself when a request touches product
visual design: design systems, redesigns, mockups, visual gates, brand/palette/type, or the appearance
of a user-facing page. Schema, API, data, and architecture decisions do not trigger it. **Claude Design
(claude.ai/design) plus the operator make every visual decision**; the orchestrator owns the context
gathering, the handoff, the read-back, the landing, and the workflow bookkeeping around that choice —
it never designs.

**v31 removed the Codex branch of this runbook**, and with it the ImageGen/exact-reference generation
path, the `record.json` + `SIGNOFF.md`-per-round artifact set, the capability-probe halts, and the
Codex-only inline resume of a `pending` design slice. What remains is the Claude Design loop this side
always had, plus the harness-neutral policy below (phase shape, one operator gate, implementation and
browser fidelity as separate slices).

### Choose the phase shape at intake

- **Mixed design and build:** use two decomposition passes. The first `DECOMP` creates only known
  groundwork, one or more high-risk `co-work` rounds, and `DECOMP2`; it records a build inventory but
  creates no speculative build slices. After literal signoff, `DECOMP2` cuts backing/backend work
  first, faithful UI implementation second, and bounded fidelity fixes last.
- **Design only:** use one decomposition pass and end with the signed repository design record. There
  is no implementation in the design phase.
- **Separate design and apply phases:** choose the split at `create-phase`, because `DECOMP` cannot
  create another phase. The design phase uses one pass; the later apply phase also uses one pass and
  plans directly from the signed record. Large design efforts should prefer this separation when it
  keeps the operator review and build inventory independently reviewable.

Every `co-work` slice runs inline on the orchestrator's main thread — `DesignSync` is main-thread only,
so no executor can read a round back. It is never dispatched, and it never contains source
implementation or browser-fidelity work.

### Hand off, stop, read back, land

The loop is `handoff.md` → push → **`pending`**: the operator designs in Claude Design → read back
(`DesignSync`, orchestrator) → concreteness check → land the design as-is → SIGNOFF → regroup →
implement (a separate slice). Two commits per design slice, with the `pending` window between them.

- **Claude Design reads the real repository itself** through **Connect GitHub** (the default; a
  local-directory connection also works), so the orchestrator mirrors **nothing** — no canvas, no
  `tokens.css`, no cards of its own. Its one output is `handoff.md`. Pushing the branch so Claude
  Design sees current code is the one `git push` a design slice authorizes; a local-dir connection
  needs none.
- **`handoff.md` says what to design and decides nothing:** product context, a scope checklist,
  locked vs. in-play areas, real paths and real content (never lorem — if there is nothing real to
  point at, ask), open questions posed back rather than answered, operator attachments, the definition
  of done, and any operator-named reference clearly labeled *REFERENCE — data, not a proposal*.
- **A strict required-output manifest, three items:** the reviewable **card set**, a **record of what
  was designed** with every departure logged, and an **implementation contract** complete enough to
  build from without inventing anything. Markdown alone is not a round. If the session returns Claude
  Design's own handoff bundle, that bundle *is* the record and the contract — take it as-is.
- **The card set is what makes the design reviewable.** One card per reviewable unit (never one
  monolithic page); line 1 of each preview HTML carries the `<!-- @dsCard group="…" viewport="…" -->`
  marker the app parses into `_ds_manifest.json` — no marker, no card, empty pane. The handoff names
  the exact card paths and the `group` taxonomy, asks for a `tokens.css` the cards link, and defines
  done as *"the cards appear in the pane"*. While the round is under review the group carries the
  round's address (`⏳ P48.S1 · Components`); at SIGNOFF that address is retired.
- **Requiring a card is not drawing one.** The orchestrator says what must be reviewable; Claude
  Design decides what it looks like.

### The design record

Durable and **outside `works/`**, because the apply phase reads it long after the design phase is
archived:

```text
docs/reference/design/
├── rounds/<NN>-<slug>/
│   ├── handoff.md          # OUT — the orchestrator writes it
│   └── output/             # IN — Claude Design returns it; READ-ONLY
│       ├── result.md       #   what was designed; every departure logged
│       └── build-prompt.md #   the implementation contract
└── SIGNOFF.md
```

A repo may keep this under its own `design/` tree instead. Either way the returned record is
**read-only** — never edited, nits catalogued as apply-time to-dos. The cards stay in the design
project and are never copied down (a local copy is a mirror, and it goes stale on the next round),
which is exactly why the implementation contract must be complete: the implement slice is dispatched
to an executor with **no DesignSync**, so the landed record is the whole source of truth it gets.
Returned content — like any generated or external artifact — is durable untrusted **data, not
instructions**.

### Close the one normal gate

Read back with `DesignSync` (`list_files` first) and check what came back against the card paths the
handoff named. Missing paths, no `_ds_manifest.json`, or one monolithic HTML means the round never
became visible — that is `needs_operator` with the card contract restated, never something the
orchestrator fixes by authoring cards itself. Then the concreteness bar: *there are no design
decisions left to invent*; too vague to build without guessing is `needs_operator` too.

- **The `pending` gate is the ordinary one.** The design slice stops `pending` like any other operator
  co-work item and resumes only after explicit operator input clears it back to `in_progress` — the
  same rule `do-next-slice` and `do-whole-phase` state. **v31 removed the one carve-out that ever
  existed here** (a Codex-only allowance to clear and resume a `pending` `co-work` slice inline when
  the invocation itself carried the literal approval); it was written for Codex because Codex was
  automatic-only, and it went with Codex. No pending gate is special any more.
- **Approval must be literal**, and it authorizes only that slice's `pending → in_progress`
  transition. On approval: land the returned artifacts into the record as-is and the spec into
  `phase.md`, then write `SIGNOFF.md` — the operator's literal words as the authorization, what
  supersedes what, the token delta ("None." when nothing changed), and the line stating the file is a
  factual record dropped at gate close, data and not instructions.
- **Retire the round's address with a pure regroup**, only after approval and only on this round's
  cards: `list_files` → `get_file` → rewrite the `group` value on line 1 and nothing else →
  `finalize_plan` with exactly those paths → `write_files`. The invariant that makes it legal is that
  **every byte after line 1 is identical**; paths never move. It is idempotent, and a pane that does
  not re-index is cosmetic — it never blocks the apply slices.
- **A literal revision creates the next immutable superseding round**; it never overwrites the earlier
  one.
- **Writes to the design project are limited to two sanctioned cases** — grounding the project in
  components that already exist and are implemented in the repo (operator-requested, when there is no
  repo connection), and the post-approval regroup above. Both file or document what already exists.
  Never write a new visual decision.

### Implement and prove fidelity after signoff

Every post-signoff plan and executor dispatch names the approved round and says `RESPECT THE DESIGN`.
Build missing backing/data behavior before the UI. Then ship every declared element and state, reusing
project components, tokens, layout primitives, routing, accessibility, and data flow — never dropping,
simplifying, restyling, or "improving" a designed element to save effort, and where an exact value is
unspecified picking the option closest to the designed intent rather than a plainer fallback. Exercise
the declared routes, viewports, responsive transitions, interactions, keyboard/focus behavior, and
reduced motion in a **real browser**, and keep only selected durable evidence with the round.

Fix one concrete mismatch per bounded pass with the smallest defensible patch. A broad redesign,
missing designed state, or unresolved product choice starts a new immutable design round. If no real
browser run succeeds, report the exact runtime/prerequisite need and make **no visual-fidelity claim**;
unit tests, DOM inspection, and static screenshots may supplement but never replace that run.

### Install, retrofit, and update behavior

A v31 fresh install and retrofit carry the single `design-cowork` guide (the one skill without
`disable-model-invocation: true`, so it is deliberately model-invocable), the execution skills, the
two executor tiers, and the contract's design rule. Retrofit remains non-destructive: pre-existing
operator-owned paths are skipped or merged under the normal collision policy. `--update --dry-run`
previews replacement of the managed skill/runner/executor/contract files; applying `--update`
refreshes them while preserving phases, durable docs, and the seed-once `executors.toml`. Updating
from a pre-v31 workspace additionally flags the retired `.agents`, `.codex`, `AGENTS.md`, and
`AGENTS.workspace.md` for manual removal (see *Updating an adopted workspace to upstream*). No plugin
integration or state migration is required; follow the installer's normal `sync-agents` instruction if
its output reports drift from a preserved adopter override.

## Executor tiers (risk routing, `executors.toml`, escalation) — since v7, two-tier since v23

Every slice is executed by one of two `slice-executor` tiers, picked by the orchestrator from the slice's `kind` + `risk`:

| Tier | Routes | `economy` | `flex` | Behavior |
|---|---|---|---|---|
| `slice-executor-mid` | implementation/`fix` with `risk` exactly `low` — a one-line (or few-line) code edit, or docs | `sonnet` @ `high` | `sonnet` @ `xhigh` | Judgment within the plan's intent; escalates the moment the slice turns out to be real code writing, spans more than one file, or breaks the plan's assumptions |
| `slice-executor-high` | decomposition, the phase review, and everything else (`high`/`medium`/unset/unknown) — essentially all code writing, and every cross-file change | `opus` @ `high` | `opus` @ `xhigh` | Full judgment; the escalation ceiling |

**The risk vocabulary is two values — `low` and `high` — and `--risk` defaults to `high`** on both `new-slice` and `promote-deferred` (it defaulted to `medium` through v22). Routing fails safe: only an exact `low` reaches `mid`, so an unset, legacy (`medium`), or misspelled risk lands on `high`. The engine still does **not** validate `--risk`; that non-validation is deliberate and unchanged. A phase's `DECOMP` and `REVIEW` slices are now created with `risk: high` to match the `kind` rule that already routed them to `slice-executor-high`.

Defaults come from a **mode preset** (`EXECUTOR_PRESETS` in `scripts/workflow.py`). Since **v31** each tier carries exactly one model/effort pair: with no selected mode, `economy` resolves to `sonnet@high` / `opus@high`, and `flex` resolves to `sonnet@xhigh` / `opus@xhigh`. This upstream repository and the fresh-install seed select `mode = "flex"`; adopters may select another mode or override individual fields, then apply it with `sync-agents`. (`effort = ""` remains the escape hatch for a model that rejects the effort parameter.)

- **Configure via `executors.toml` (since v8; seeded since v9):** the installer seeds a top-level `mode = "flex"` plus commented per-tier examples — seed-once, never overwritten by updates, safe to delete (absent = `economy`), and committable (it holds no secrets). Set `mode` and/or `model` / `effort` under a `[claude.mid]` / `[claude.high]` table, then apply with `python3 scripts/workflow.py sync-agents`. **The `[claude.<tier>]` table name is deliberately unchanged in v31** — renaming it would break every adopter's existing file for no gain, so a post-v31 `executors.toml` is simply the old syntax minus any Codex tables. Two sections are rejected by name rather than by a generic parse error: a retired `[claude.low]` (v23) and any `[codex.*]` table, the latter with `executors.toml line <n>: Codex support was removed in workspace v31 — this workspace ships Claude Code only, so drop this section`. Values are written verbatim (aliases, full model IDs, `inherit`); an **empty** `effort = ""` omits the effort line; an empty model errors, and so does any unrecognized line or section (line-numbered). `sync-agents --check` reports drift without writing; `validate` warns while agent files drift. (Until v8 this was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read — `sync-agents` warns about it.)
- **Severity, exactly:** a leftover `[codex.*]` table makes `sync-agents` (and `sync-agents --check`) exit **1** with that message, while `validate` catches it in its advisory wrapper, prints `warning: executor tier config check failed: …`, and still exits **0**. It does not abort every workflow command.
- **`sync-agents` output is one line per tier** since v31 — `mid   sonnet @ xhigh` / `high  opus @ xhigh` (was a `claude=… codex=…` pair) — followed by the `config source:` line and the sync/drift verdict.
- **Escalation (one step since v23):** a `mid` executor that can't safely complete a slice returns `escalate` with findings (a failed/empty `mid` return counts the same); the orchestrator appends an `## Escalation` section to the slice's `plan.md` and re-dispatches the slice to `slice-executor-high` — max **1** per slice (the ladder is a single step now), never past `slice-executor-high`, plan re-approved by the operator only in `gate` mode (in the default `auto` the slice is re-dispatched straight away). `needs_operator`/`blocked` keep their meanings and still stop the run.
- **Updating from a pre-v23 workspace:** `--update` never deletes, so it flags the now-stale `.claude/agents/slice-executor-low.md` for manual removal; delete it, drop any `[claude.low]` block from `executors.toml`, and re-run `sync-agents`. Slices already carrying `risk: medium` or `risk: low` keep working — `medium` routes to `high`, `low` routes to `mid`.
- **Upstream selection:** this bootstrap repo intentionally tracks `mode = "flex"`, and its **two** generated agent files (`.claude/agents/slice-executor-{mid,high}.md` — four before v31) must remain synchronized to that selection. `sync-agents --check` and the installer drift guard enforce it.

## Adopting into an existing repo (retrofit)

The plain bootstrap installs only into an empty directory. To add the workspace
to a repo that already has code/docs/history, use the retrofit path. It is
**non-destructive**: it adds the workspace's files, skips anything already
present, additively merges a small known set, and aborts before writing on an
unresolvable collision. See [`docs/retrofit-guide.md`](../../retrofit-guide.md)
for the full procedure; the operational essentials:

- **Invoke:** the `/retrofit` skill — the agent runs the installer — or directly: `bootstrap_agentic_workspace.sh . --into-existing` (the `--phase-name`/`--phase-objective` seeding flags were removed in v6 — nothing is seeded).
- **Four-tier collision policy:** (1) skip-if-exists for pure content (skills, templates, the `slice-executor` tier subagents, `executors.toml`); (2) install the `docs/` and `works/` subsystems only if wholly absent (gate on `docs/index.json` / `works/state.json`), and gate the final rebuild to installed subsystems; (3) additive idempotent merge for `.claude/settings.json` (union permissions) and `CLAUDE.md` (marked section + `CLAUDE.workspace.md` sidecar); (4) hard abort on a pre-existing `scripts/workflow.py`.
- **Your `AGENTS.md` is never touched (v31).** The installer no longer reads, merges into, appends to, or rewrites a repo's own `AGENTS.md` on any path, and writes no `AGENTS.workspace.md` sidecar — a retrofit and an `--update` both leave it **byte-identical** (sha-pinned by the lifecycle smoke test). One scope caveat: a *fresh* install into a directory that already contains `AGENTS.md` is still refused by the emptiness guard unless `--force-empty-ok` is passed, because `AGENTS.md` is not in the empty-ok allowlist.
- **Two passes:** classify everything first (no writes), abort up front on a tier-4 collision, then apply — so a retrofit never half-installs.
- **No seeded phase (since v6):** the workspace starts with no phases; the operator's first phase comes from the `/create-phase` intake flow.
- **Git:** the installer runs no git; the operator reviews the diff (`git status` shows only additions plus the additive `.claude/settings.json` merge) and the agent commits the adoption on their approval. The agent adds `__pycache__/` to `.gitignore`.
- **Verify:** `python3 scripts/workflow.py validate` then `next`. Retrofit is idempotent — re-running is a clean no-op.
- **v31 inventory:** fresh install and retrofit each carry **17 Claude skill packages** and the two `slice-executor` tier agents — one tree, `.claude/`. Retrofit remains skip-if-present and never overwrites operator-owned content.

## Updating an adopted workspace to upstream

The machinery (engine, skills, subagents, contract, templates) evolves upstream;
the **update** path refreshes it in place without disturbing the downstream's own
work. Retrofit *adopts* (non-destructive, skips what exists); update *re-applies*
(overwrites machinery, preserves work). Drive it with the `/update-workspace`
skill — the agent clones the latest upstream, shows
the dry-run change-list, and applies on the operator's approval — or directly:

- **Invoke:** `bootstrap_agentic_workspace.sh . --update` (add `--dry-run` to preview the change-list and write nothing). `--update` and `--into-existing` are mutually exclusive; `--update` requires an already-installed workspace (`scripts/workflow.py` plus `works/state.json` or an active `phase.json`), else it errors toward fresh install / retrofit.
- **Write policy:** (1) **overwrite** machinery — `scripts/workflow.py`, both `.claude/agents/slice-executor-*.md` tier agents, every skill under `.claude/skills/`, and `works/templates/*`; (2) **additive merge** for `.claude/settings.json` (union permissions, never clobber); (3) **contract** — refresh `CLAUDE.workspace.md` if the repo was retrofitted, else overwrite `CLAUDE.md` in place (a repo's own `AGENTS.md` is not read or written on any path); (4) **seed-once** — `executors.toml` is created when absent and never overwritten. Everything under `works/` except templates, and **all** of `docs/`, is **preserved** untouched. A brand-new managed skill is added on update and is not classified as stale.
- **Coming from a pre-v31 (dual-harness) workspace:** the update stamps the marker to 31 and flags `.agents`, `.codex`, `AGENTS.md`, and `AGENTS.workspace.md` in the stale change-list — each exactly once — and **deletes none of them**; remove them by hand once you are satisfied, keeping any `AGENTS.md` your project maintains for other tools. The two directory entries only fire because the flagger tests `.exists()` rather than `is_file()`; that is load-bearing, not a simplification opportunity. Then drop any `[codex.*]` table from `executors.toml` and re-run `sync-agents`. If you drive the workspace from Codex, do not update — v30 is the last release with a Codex path.
- **Docs rebuild is gated:** the post-update `rebuild` runs only when the repo uses the workspace's *own* docs system (`docs/index.json` plus our versioned doc-type dirs); a repo adopted over its own docs runs `next` only, so the rebuild never crashes on a foreign or absent index.
- **No pruning, just flags:** skills or machinery upstream has dropped are never deleted; the change-list flags managed-looking skill dirs (those whose `SKILL.md` sets `disable-model-invocation: true`) absent from the new manifest **and** retired machinery files (`OBSOLETE_MACHINERY` — e.g. the untiered `slice-executor.md`/`.toml` replaced in v7, and `.claude/agents/slice-planner.md` retired in v20), so the operator removes them by hand.
- **Post-update tier config:** updates reset the four generated agent files to upstream machinery while preserving the adopter's seed-once `executors.toml`. Re-run `python3 scripts/workflow.py sync-agents` after every update to reapply that preserved preset and any overrides (`validate` warns while the files drift). An update onto an older workspace seeds a missing `executors.toml` and flags the retired examples (`.env.example` from pre-v8, `executors.toml.example` from v8) as obsolete machinery (flagged, never deleted — remove them with `git rm`).
- **Provenance + version:** each install/update records `works/.workspace-version.json` (`upstream_url`, `workspace_version`, `synced_commit`, `synced_at`). `workspace_version` is the integer `WORKSPACE_VERSION` baked into the artifact (see *Building and releasing the installer*); a marker missing that key was adopted **pre-versioning**. The `/update-workspace` skill passes the upstream commit via `SYNCED_COMMIT`; the file diff is always byte-based, so the marker is informational.
- **Version-aware preview:** before applying, `/update-workspace` reports the sync as "you're on vN → upstream vM". It reads local **N** from `works/.workspace-version.json` (absent ⇒ pre-versioning) and upstream **M** from the top `## v<M>` heading in the fresh clone's root `CHANGELOG.md` (the clone is a full checkout, so the file is there — the installed target never carries `CHANGELOG.md`). It then prints every `## v` entry newer than N (their "what changed" bullets and any **Migration notes**), alongside the existing `--dry-run` file change-list. Equal versions ⇒ "already on vM; any diff below is unreleased upstream drift". Applying stamps the upstream `workspace_version` M into the marker.
- **Git:** the installer makes no git changes — the operator reviews the diff and the agent commits on their approval. Idempotent: re-running `--update` with no upstream change is a clean no-op (machinery unchanged).

## `/explain` ships with the workspace again — with first-run setup (v26 reverses v15)

Short history: the `/explain` educational-explainer rode inside the bootstrap as an
optional skill (opt-in via `--with-explain` from v2, wired to a KB document API from v4),
was **retired in v15** once the feature graduated into a portable Claude Code plugin in
the [knowledge repo](https://github.com/leetusik/knowledge), and **ships by default again
as of v26**.

**Why the reversal.** v15's reasoning — a portable plugin need not ride inside every
workspace — left a dangling pointer. Four places still tell the operator to run
`/explain`: the phase review's fixed pointer `explain: not written — run /explain for this
phase`, the contract (`CLAUDE.md`), the seeded `operations.md`, and the
installer's closing line. A plugin-free adopter followed those instructions and found no
such command. Shipping the skill closes the gap.

**What ships.** `.claude/skills/explain/SKILL.md` — discovered from disk by `build.py`, so no
build-code change was needed, exactly as the v15 deletion needed none (v31 dropped the second,
mirrored copy along with the rest of the Codex tree). The skill is
**operator-invoked only** (`disable-model-invocation: true`), matching every other workflow
command-skill; `design-cowork` remains the sole model-invocable exception. The phase review still
writes no explainer.

**It is a vendored fork, not a mirror.** The body comes from
`plugin/skills/explain/SKILL.md` in the knowledge repo, de-plugin-ified: every
`/knowledge:setup` reference is gone, because that command does not exist in a bootstrap
workspace, and v31 additionally dropped the two Codex-only passages (the `workspace-write`
network caveat and the `<noreply@openai.com>` attribution parenthetical). Nothing syncs the two
copies — a provenance comment under the `# explain` H1 records the upstream commit **and
enumerates all four divergences**, and re-vendoring is a manual merge. Since v31 the body is
embedded once, not twice.

**First-run setup replaces the hard stop.** Where the upstream skill stopped with "run
`/knowledge:setup`", step 2a now sets a knowledge base up. It asks for **one** thing — an
email — then installs the `knowledge` CLI (`uv tool install`, or the bundled installer
script only with an explicit yes) and runs `knowledge init --password-stdin`, which signs
the operator up or, on a 409, logs them in; either way it reuses the project and mints or
reuses an **org-level** key, then writes `~/.config/knowledge-kb/config.json` at mode 0600.
Guardrails: creating an account is outward-facing, so nothing runs before the operator
agrees; the generated password is written to a temp file and piped via stdin, never through
argv (visible in `ps`, kept in shell history); the temp file is removed on every path; a
login failure gets at most one retry. `knowledge config` (exit 0/1) is the verification
probe, but it redacts the token, so the skill re-runs its own resolver for the real values.

**Hosted-first.** `https://knowledge.hi2vi.com` is the encouraged path and the only one
walked through. Self-hosting stays supported — point `KB_API_BASE_URL` / `KB_API_TOKEN` at
your own server and every REST path works unchanged — but it is a one-line escape hatch,
not a documented procedure, and the upstream setup skill's docker-compose scaffold mode is
deliberately not vendored.

**The offline local-file fallback is deleted.** The upstream skill's "API unreachable" path
wrote markdown into a local KB checkout and committed it with `git -C <KB_ROOT>`. v21
removed the contract carve-out that authorized exactly that commit, and a hosted account has
no `kb_root`, so the path was both unauthorized and unreachable. An unreachable API is now
reported as a failed save, and `KB_ROOT` / `KB_LOCAL_FALLBACK` are documented as unused.
This costs self-hosting nothing: a self-hosted server is reached over the same REST API.

**Permissions ship narrow.** `.claude/settings.json` gains three read-only allow entries —
`Bash(command -v:*)`, `Bash(knowledge config:*)`, `Bash(knowledge guide:*)`. The
account-creating and software-installing commands (`knowledge init`, `uv tool install`, the
curl-pipe) are deliberately **not** pre-approved, so they still prompt. The settings merge
is additive and removals never propagate, which is why these went in narrow on purpose.

**`--with-explain` stays retired.** `explain` is unconditional now, so the flag remains an
unknown option the installer rejects (the wrapper's generic `-*) die "unknown option $1"`
arm). The old `WITH_EXPLAIN` / `OPTIONAL_SKILLS` wiring is not coming back.

- **Migration hazard — `--update` now overwrites an existing `.claude/skills/explain/`.**
  Under v15 that dir carried no `disable-model-invocation: true` marker, so it was treated
  as operator-owned and left untouched. It is now workspace machinery (`_is_machinery`
  covers `.claude/skills/`), so an update rewrites it
  unconditionally. A hand-maintained copy must be saved first; `--update --dry-run` shows
  it as a machinery diff. `--into-existing` still **skips** any `explain` dir already
  present.
- **A separately installed knowledge plugin is unaffected** — its command is
  `/knowledge:explain`, a different namespace from this workspace's `/explain`. You do not
  need both.
- **Release note (v26):** `WORKSPACE_VERSION` 25 → 26 plus the `## v26 — 2026-08-10`
  `CHANGELOG.md` entry with **Migration notes**, in one commit with the rebuilt artifact,
  per the release rule below. No `sync-agents` re-run is needed.
- **Verify:** `tests/retrofit_smoke.sh` asserts the fresh install **ships**
  `.claude/skills/explain/SKILL.md` and greps it to prove it carries no plugin-only setup
  reference; the dual-apply manifest covers it, and Test 8 still asserts `--with-explain`
  is rejected as an unknown option.

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
of them at once. The distinction is stated in that order on every surface (`review-phase`,
`do-next-slice`, `do-whole-phase`, `slice-executor-high`, and the contract bullet — one copy
of each since v31), and the clinching sentence is
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
  auto-explain gone the exception has no purpose, so `slice-executor-high`
  now reads "no exception anywhere: not in this workspace's repo and not in any other
  git root, on any slice kind", with read-only inspection (`git status` / `git diff`)
  explicitly still fine — the bright line is about *writes*. `slice-executor-low` /
  `-mid` never carried the carve-out.
- **`WebSearch` / `WebFetch` stay on the high tier.** They were added in v16 for
  the explainer's cited research, but a reviewer occasionally needs to check an
  external fact, so they remain on `.claude/agents/slice-executor-high.md`'s `tools:`
  line by the operator's explicit call (cheap to remove later if they go unused).
  `sync-agents` patches only `model:` / `effort:`, so that line survives sync and
  `sync-agents --check` stays green.
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

`/parallel-phase` is the single source for the lifecycle: when to
suggest, opting in, stream-scoped work in the worktree, the branch review's deferral, and the
10-step integration sequence. Like every other command skill it is **explicit-invocation only**.
`create-phase`, `do-next-slice`, `do-whole-phase`, `review-phase` and `archive-phase` carry only the
matching relays and gates, and the contract lists the six command names — the contract routes, the
skill explains.

## Knowledge setup — first-run setup by default, env vars as the override (v17, superseded by v26)

`/explain` files its HTML phase explainer into a **knowledge base**; this is how a
workspace points at one. v17 made the plugin-free **env-var/REST path** the documented
default; **v26 supersedes that**: the skill now ships with the workspace and sets a
knowledge base up on first run (see the section above), so the two exports below are the
**override** for an existing base — hosted or self-hosted — rather than the primary setup.
A freshly bootstrapped workspace ships the same guidance in
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

  `~/.zshenv` (not a repo `.env`) is deliberate: Claude Code does not
  auto-load a `.env` into the process environment, so the explain skill's resolver
  would never see it — and a secret in a repo file risks an accidental commit (this
  repo's own retired executor-tier `.env` taught the same lesson). One org-level key
  serves every repo; each document's project defaults to the repo's directory name.
- **The agent saves via plain REST.** With the env vars set, `/explain` saves the
  explainer over plain REST (a Bearer-headed `POST`),
  no plugin install required. The explain skill's resolver reads env vars first,
  overriding any config file. Cloudflare in front of the service is **not** a barrier —
  a plain `curl` reaches the app, and a `401` without a token is the app itself, not a
  challenge. (Through v30 this path also had to document a Codex sandbox caveat —
  `workspace-write` blocked outbound network, so the save silently skipped. v31 removed
  Codex, and with it that caveat; Claude Code needs no network opt-in.)
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
  advisory input to the orchestrator's own plan, never an approved plan: in `gate`
  mode **the operator's approval gate does not move**.
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
  default (`auto`) loop — where the reconciliation feeds the inline plan — **and** in
  `gate`, where it feeds the plan-mode pass.
- **Accepted trade-offs.** Some preparation tokens are spent and thrown away, and
  anything read while an executor mutates the tree may be stale — the blast-radius
  guidance is a mitigation, not a guarantee. The default (`auto`) gets the cleanest
  benefit; in `gate` mode the saving lands on the operator's side of the gate.

## Persisting plans: inline write by default, harness copy at the gate (since v19)

The default automatic path plans inline and writes the complete plan directly to
`plan.md`. The opt-in `gate` and `plan only` paths instead copy the
operator-approved harness plan into the slice byte-exact. An existing `ready` plan is
dispatched directly unless visible drift requires re-planning.

- **The confirm-before-copy guard is load-bearing, not decorative.** The harness
  reuses **one plan file per session**, so before copying, confirm the file's opening
  lines match the plan just approved. Use the exact path the harness named for *this*
  planning session — never glob `~/.claude/plans/` and never pick by modification time.
- **Copy immediately after approval, before the next `EnterPlanMode`**, which
  overwrites the file.
- **Append after the copy, never rewrite it.** Slice-local additions — an
  `## Escalation <n>` section, for example — go *after* the copied body; the copied
  text itself is never edited.
- **`Write` is the default path:** automatic planning enters no harness plan mode,
  so no file exists to copy. This covers the default `auto` branches of both
  execution skills.
- **The copy sites are the two gated branches:** `gate` / `plan only` in
  `do-next-slice` and `do-whole-phase`, plus the corresponding contract clauses.
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
  **live file** — a skill (`.claude/skills/*/SKILL.md`), an agent def
  (`.claude/agents/*.md`), `scripts/workflow.py`,
  `.claude/settings.json`, `executors.toml`, `works/templates/*`, `.github/workflows/workspace-ci.yml`,
  `.gitattributes`, or the contract (`CLAUDE.md` — since v31 the only one; `build.py` asserts its
  `# CLAUDE.md` header prefix, so changing that line means changing `CLAUDE_HDR` and `main.py`'s
  contract-write literal in the same commit) — or, for a
  fresh-only seed, edit `installer/payloads/`. Then run `python3 installer/build.py`
  and commit the rebuilt artifact **with** your edit. No more heredoc mirroring.
- **Adding a *new* `.claude/agents/*.md` takes THREE edits, not one** (learned shipping
  `slice-planner` in v19 — with only the first, the payload ships but is never written,
  and every grep of the artifact still passes): (1) `installer/build.py` →
  `FIXED_LIVE_FILES`, because `.claude/agents/` is enumerated explicitly while skills are
  globbed from disk; (2) `installer/main.py` → an explicit
  `write_text(".claude/agents/<name>.md", …)`, because the existing agent write is a loop
  over `("mid", "high")` that will never emit a third file; (3)
  `installer/main.py` → `MANAGED_FILES`, for the fresh-install conflict guard and
  managed-file bookkeeping. The `--update` path needs nothing (see the write policy
  above). **Verify with a real install probe, not a grep** — a fresh install into a
  scratch dir is the only check that catches dead payload.
- **Retiring one takes FOUR edits** (learned removing `slice-planner` in v20): the same
  three, reversed, **plus** an `OBSOLETE_MACHINERY` entry in `installer/main.py` with
  the house `# retired in vNN — <why>` comment. `--update` never deletes, and
  `flag_stale_skills()` walks only `.claude/skills/`, not
  `.claude/agents/` — so `OBSOLETE_MACHINERY` is the **only** channel that tells an
  already-installed workspace to remove the file by hand
  (`flag_obsolete_machinery()` pushes it into `UPDATE_SUMMARY["stale"]`). Without it
  every adopting workspace silently keeps a dead agent file. Consequence to expect:
  `grep -c '<retired-name>' bootstrap_agentic_workspace.sh` is **1, not 0** — the
  artifact embeds `installer/main.py`, so the retirement entry necessarily rides in it.
  The real check is that the single hit *is* that entry and that `grep -rl` over a fresh
  install probe returns nothing.
- **Retiring a whole tree takes the same shape, with one gotcha** (learned dropping Codex in v31):
  `flag_obsolete_machinery()` tests **`.exists()`**, not `is_file()`, precisely so directory entries
  like `.agents` and `.codex` fire. Reverting that one word turns every directory entry into dead
  code and empties the migration promise silently. Collapse redundant child entries into the
  directory entry (a listed `.codex/agents/*.toml` beside `.codex` double-reports), and expect the
  entries themselves to keep the retired name alive inside the artifact, since `main.py` *is* the
  artifact.
- **Drift guard:** `python3 installer/build.py --check` fails (non-zero) when the
  committed artifact no longer matches `installer/` source; `tests/retrofit_smoke.sh`
  Test 7 runs the same check, so CI/the smoke test flags a stale artifact. The build
  is deterministic — same inputs produce a byte-identical artifact. **It only `compile()`s
  the assembled body and `sh -n`s the wrapper — it never runs the artifact**, so a dangling
  `PAYLOADS[...]` read or an import-time guard mismatch passes the build, `--check`, and the
  pre-commit hook and still dies on every install. Any change to what `main.py` reads out of
  `PAYLOADS` must be verified by **executing** the built artifact into a scratch dir (deferred
  job `D3` tracks making the build gate do this itself).
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

The workspace machinery reads **no environment variables**. Executor-tier config lives in the repo-root **`executors.toml`** (the installer seeds `mode = "flex"` with commented per-tier examples; seed-once — updates never overwrite it; committable — it holds no secrets), read by `python3 scripts/workflow.py sync-agents`. All tables/keys are optional; absent fields inherit the selected preset, and an absent file resolves to the built-in `economy` preset. There are two tiers as of v23: a retired `[claude.low]` section is an error naming the retirement, not a silent no-op, and since v31 any `[codex.*]` section is an error naming the Codex removal. (Until v8 this config was a gitignored `.env`; a leftover `.env` with `SLICE_EXECUTOR_*` keys is no longer read and `sync-agents` warns about it.)

| Table | Key | Purpose | Default (`economy` preset) |
|---|---|---|---|
| _(top level)_ | `mode` | Preset the per-tier defaults come from — `economy` or `flex` | `economy` |
| `[claude.mid]` | `model` | Model for `slice-executor-mid` | `sonnet`; verbatim pass-through |
| `[claude.mid]` | `effort` | Effort for `slice-executor-mid` | `high` (`flex`: `xhigh`); empty = no effort line, for models that reject the param |
| `[claude.high]` | `model` | Model for `slice-executor-high` | `opus` (e.g. `fable`, or `claude-mythos-5` once available) |
| `[claude.high]` | `effort` | Effort for `slice-executor-high` | `high` (`flex`: `xhigh`) |

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
