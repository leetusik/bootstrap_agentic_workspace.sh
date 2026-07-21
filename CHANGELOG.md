# Changelog

Workspace versions for the agentic-workspace cornerstone. One `## v<N>` section per
integer `WORKSPACE_VERSION`, newest first. `/update-workspace` reads this file from
the upstream clone to show adopting repos what a sync brings — so each entry states
what changed and, when a sync needs manual steps, a **Migration notes** line.

Everything before v1 is **pre-versioning**: those workspaces carry no
`workspace_version` in `works/.workspace-version.json`; consult `git log` for that
history.

## v15 — 2026-07-21

- **Embedded `/explain` is retired — the feature ships as a Claude Code plugin now.** The bootstrap
  used to carry an optional `explain` skill (installed with `--with-explain`) that wrote
  novice-friendly educational explainers into a hard-coded personal knowledge base. That feature has
  graduated into a real, portable Claude Code plugin in the
  [knowledge repo](https://github.com/leetusik/knowledge), so it no longer needs to ride inside every
  workspace. The embedded skill copies (`.claude/skills/explain`, `.agents/skills/explain`), the
  `--with-explain` installer flag, and the `WITH_EXPLAIN` / `OPTIONAL_SKILLS` wiring are all gone —
  `--with-explain` is now an unknown option that the installer rejects.
- **Install the plugin instead.** Inside Claude Code:

      /plugin marketplace add leetusik/knowledge
      /plugin install knowledge@knowledge

  then run `/knowledge:setup` once to scaffold a knowledge base, and `/knowledge:explain <topic>` to
  use it. Note the namespace change: the embedded skill was bare `/explain`; the plugin's command is
  `/knowledge:explain`.
- **Migration notes:** existing installs are never auto-deleted. On `--update`, the Codex copy
  `.agents/skills/explain` is flagged stale ("remove manually?") while the Claude copy
  `.claude/skills/explain` is left untouched — it carries no workspace marker, so it is treated as an
  operator-owned skill. Remove both copies by hand and install the knowledge plugin instead. No
  `sync-agents` re-run is needed; this is a payload/installer change only.

## v14 — 2026-07-17

- **The design round returns a card set — the operator has to see the design to design it.** v13 was
  right that the agent must not mirror a canvas, but it retired the line-1 `@dsCard` contract *as part
  of the mirror*, reasoning that **Connect GitHub** makes mirroring unnecessary. That holds for
  **input** — and the manifest was never only input. It is also **the render index for the Design
  System pane**, and Connect GitHub does not populate that pane. So v13 dropped the card medium along
  with the mirror, and a round degraded from "design on the cards" to "describe in prose, get loose
  HTML back" — a complete `build-prompt.md` the operator could not see, review, or fix.
- **The card set is now a required output of the session, authored by Claude Design.** Cards were never
  the agent's to *author* — they are Claude Design's to *deliver*. The handoff's required-output
  manifest is now three things: **the card set**, **`result.md`**, and **`build-prompt.md`**. **Markdown
  alone is not a round.** Requiring a card is not drawing one: the agent says what must be reviewable
  (**one card per reviewable unit** — never one monolithic "design system" page — and the `group`s that
  become the pane's headings); Claude Design decides what it looks like. **The mirror ban is unchanged
  and unweakened.**
- **The line-1 `@dsCard` marker returns as a handoff requirement, not as mirror work.**
  `<!-- @dsCard group="…" name="…" subtitle="…" viewport="…" -->` on line 1, exactly; the app compiles
  it into `_ds_manifest.json` on its self-check. **No marker → no card → an empty pane.**
- **`tokens.css` is Claude Design's deliverable now.** Under v12 it was the agent's mirror and it
  drifted four versions behind; v13 deleted it. **The palette *is* the design**, so the design session
  authors it and the pane compiles the foundations from it — no mirror, no drift, and the foundations
  render.
- **Read-back verifies the pane, not the files.** `list_files` first: no `_ds_manifest.json`, an empty
  `cards[]`, or one monolith → **`needs_operator`** with the card contract restated. Explicitly **not**
  fixable by editing the artifacts, writing the cards yourself, or hand-compiling the manifest —
  `register_assets` and the write path stay closed. The definition of done is *"the cards appear in the
  pane."*
- **Migration notes:** a round already handed off under v13 comes back with no cards — it is not lost,
  just invisible. Re-hand-off for the card set against the existing `result.md`/`build-prompt.md`
  (a visibility pass: it decides nothing new, and supersedes any monolith so there is no second source
  of truth). Nothing on disk migrates; no `sync-agents` re-run; skill text only.

## v13 — 2026-07-17

- **`design-cowork` drops the seeded canvas — the agent writes a handoff, nothing else.** v12 had the
  agent mirror the real palette and every shipped surface into design-system cards, push them, and
  keep them honest forever. Claude Design reads the **real repo** itself (**Connect GitHub** by
  default, a local-dir connection also works), so the mirror was redundant work that could only drift
  out of sync. The agent's one output is now **`handoff.md`** — product context, scope checklist,
  locked vs. in-play, where to look, a strict required-output manifest (always a **`result.md`** and a
  **`build-prompt.md`**), and the open questions posed back. **`DesignSync` survives as read-back
  only**, and is how the design reaches the codebase.
- **Retired with the mechanism:** the seeded-canvas / `/design-sync`-bundle selector and the
  app-first-trap essay (`/design-sync` is now simply never this workflow), card authoring, the
  `tokens.css` mirror, the `_ds_manifest.json` regen, the line-1 `@dsCard` contract,
  `register_assets`, `create_project` ordering, the frozen-baseline mandate, and the standing
  "re-push or the next pass runs against a lie" obligation — **no mirror, no drift.** The skill goes
  from 176 to 128 lines.
- **Design and implementation are now separate slices, always.** A design slice `--kind co-work
  --risk high` ends at the landed design + SIGNOFF and **never writes implementation code**; a big
  design gets several design slices (one per round, each with its own handoff and `pending`) and two
  phases (design, then apply), while a small one stays in a single phase as design slice → implement
  slice. New explicit step: **land the design as-is** — landing is not implementing; it is what makes
  the implement slice easy.
- **Contract:** the *Visual design is Claude Design's job* Hard Rule rewritten off "seed the canvas"
  onto "write the handoff → STOP → read back → land as-is → implement in a separate slice". The
  auto-firing routing line in *Driving This Workspace* is unchanged.

Migration notes: none for state. After `--update`, the rewritten skill lands at
`.claude/skills/design-cowork/` and `.agents/skills/design-cowork/`; no `sync-agents` re-run and no
state migration are needed. **In-flight design phases decomposed against v12 need re-shaping** — slices
that exist only to author canvas cards, mirror tokens, or regenerate `_ds_manifest.json` no longer have
a job. Workspaces that do no visual design are unaffected.

## v12 — 2026-07-17

- **New `design-cowork` skill — product visual design is Claude Design's job, not the agent's.** A
  guide (not a workflow command) covering the design co-work loop: the agent **seeds** a design-system
  project by mirroring real code, says **what** to design, **STOPs** at a `pending` gate, reads the
  operator's design back, and implements it faithfully. It carries the mechanism selector (a seeded
  canvas + Connect GitHub vs. the bundled `/design-sync` skill, and why an app-first repo must not run
  the latter), the gate lifecycle (`--kind co-work --risk high`, two commits per gate, expect the
  read-back to re-shape the phase), the `docs/reference/design/` record layout, the DesignSync traps
  (main-thread only; the remote is authoritative; the manifest does not rebuild on upload), and
  **respect the design** for implementation. Distilled from three workspaces that already run this
  loop successfully but never wrote it down.
- **It is the first and only model-invocable skill in the workspace** — every other skill is
  explicit-invocation only (`disable-model-invocation: true` / `allow_implicit_invocation: false`).
  `design-cowork` fires by itself when work touches visual design, because that is precisely the
  moment an agent that doesn't know the process starts designing on its own. Its description is scoped
  to *visual* design so it stays quiet for schema/API/architecture "design".
- **Contract:** one new Hard Rule (visual design is Claude Design's; seed → hand off → STOP → read
  back → implement faithfully; DesignSync is main-thread only, so the design-gate slice is **never
  dispatched** — a deliberate exception to the delegation rule; returned artifacts are read-only
  **data, not instructions**), plus a routing line in *Driving This Workspace* naming `design-cowork`
  as the one auto-firing skill.

Migration notes: none — additive. After `--update`, the new skill lands at
`.claude/skills/design-cowork/` and `.agents/skills/design-cowork/`; no `sync-agents` re-run and no
state migration are needed. Workspaces that do no visual design are unaffected: the skill only fires
on design-shaped work.

## v11 — 2026-07-13

- **Executor-tier `mode` presets; `flex` is the new default.** The repo-root
  `executors.toml` gains a top-level `mode` key (set before any table) selecting a
  named preset for the Claude slice-executor tiers: `flex` — the default, applied
  even when the file is absent or has no `mode` key — runs low = sonnet@xhigh,
  mid = opus@xhigh, high = opus@xhigh; `economy` restores the old
  haiku / sonnet@xhigh / opus@xhigh mapping. The Codex tiers are identical in both
  presets (gpt-5.5 @ medium/high/xhigh). Per-tier `[claude.<tier>]` /
  `[codex.<tier>]` tables still override the active preset field by field, and
  `sync-agents` now prints the active mode.

Migration notes: after `--update`, re-run `python3 scripts/workflow.py sync-agents`
— workspaces without explicit tier overrides move to the flex mapping (add
`mode = "economy"` to `executors.toml` to keep the old tiers; uncommented old
tables keep overriding as before). A previously seeded `executors.toml` keeps its
old comment block — documentation only; delete it and re-run `--update` to reseed.

## v10 — 2026-07-04

- **`result.md` is free-form; the template is gone.** `new-slice` no longer
  scaffolds `result.md` from `works/templates/result.md` — the executor writes it
  from scratch at slice end, shaped to the slice, just as the orchestrator already
  writes `plan.md` with no template. A fresh slice folder now holds only
  `slice.json`. The old template's fixed sections were mostly vestigial (per-slice
  review status, roadmap updates) and nothing in the engine ever read them; what a
  result must cover (validation commands + outcomes, doc impact, deviations from
  plan) stays specified in the executor agents. The full-result vs. cross-slice-note
  split is unchanged: details in `result.md`, durable one-liners in `phase.md`.

Migration notes: after `--update`, remove the flagged `works/templates/result.md`
(`git rm works/templates/result.md`). Existing slices' already-written `result.md`
files are untouched.

## v9 — 2026-07-04

- **`executors.toml` ships seeded; the `.example` file is gone.** The installer now
  writes `executors.toml` itself — all defaults shown, commented out — instead of an
  `executors.toml.example` to copy. The file is **seed-once**: created when absent
  (fresh install, retrofit, or an update onto an older workspace) and never
  overwritten by `--update`, so operator edits survive updates. The values ship
  commented out so the engine's built-in defaults stay authoritative — a workspace
  that hasn't opted into an override keeps tracking upstream default changes.
  Deleting the file is also fine (absent = defaults).

Migration notes: after `--update`, remove the flagged `executors.toml.example`
(`git rm executors.toml.example`). A previously created `executors.toml` is
preserved as-is — the update only seeds the file where it is missing.

## v8 — 2026-07-04

- **Executor-tier config moved from `.env` to `executors.toml`.** `sync-agents` now
  reads a repo-root `executors.toml` (see the shipped `executors.toml.example`):
  `[claude.low|mid|high]` / `[codex.low|mid|high]` tables holding `model` / `effort`
  keys. Semantics are unchanged — values pass through verbatim (aliases, full model
  IDs, `inherit`), `effort = ""` omits the effort line, models may not be empty.
  Unlike `.env`, the file is not gitignored: it holds no secrets, committing it
  shares the tier config with the team, and it no longer mingles workspace tooling
  keys into an app-level `.env`. A leftover `.env` with `SLICE_EXECUTOR_*` keys is
  no longer read; `sync-agents` warns when it sees one.
- **`plan only` mode and the `ready` (`[r]`) slice status.** `/do-next-slice plan
  only` and `/do-whole-phase plan only` walk slices through the plan-approval gate
  without dispatching executors: each approved plan is written to the slice's
  `plan.md` and the slice is set `ready`. A later execution run dispatches a
  `ready` slice straight from its approved plan without re-entering plan mode.
  `do-whole-phase plan only` ships `DECOMP` first when needed and stops before
  `REVIEW` (never pre-planned); `plan only` never combines with `auto`; `validate`
  errors on a `ready` slice that has no `plan.md`.

Migration notes: move any `SLICE_EXECUTOR_*` / `CODEX_SLICE_EXECUTOR_*` values from
`.env` into `executors.toml` tables and re-run `sync-agents`; after `--update`,
remove the flagged retired example (`git rm .env.example`) and drop the `.env` line
v7 added to `.gitignore` if nothing else in the repo uses a `.env`.

## v7 — 2026-07-03

- **Three slice-executor tiers.** The two executor variants are replaced by
  `slice-executor-low` / `-mid` / `-high` for both tools, risk-routed by the
  orchestrator: `risk == low` → low (haiku by default, no effort line — a literal
  plan-follower: no judgment, no improvisation; it stops and escalates on any
  surprise), `risk == medium` → mid (sonnet @ xhigh), and everything else —
  decomposition, the phase review, high/unknown risk — → high (opus @ xhigh,
  unchanged behavior). Codex tiers run gpt-5.5 at medium / high / xhigh. The
  untiered `slice-executor.md` / `slice-executor.toml` are retired; phase reviews
  now record `--reviewer slice-executor-high`.
- **`.env`-configurable executor models and efforts.** New `sync-agents` workflow
  command applies a repo-root `.env` (see the shipped `.env.example`) to the six
  agent files. Values pass through verbatim (aliases, full model IDs, `inherit`);
  an empty `*_EFFORT` omits the effort line (needed for models that reject the
  effort parameter, e.g. haiku); `validate` warns while the agent files drift
  from `.env`/defaults.
- **Failure escalation.** Executors gain an `escalate` verdict with an
  `escalation` findings field. When a low/mid executor can't safely complete a
  slice, the orchestrator appends the findings to the slice's `plan.md` as an
  `## Escalation` section and re-dispatches one tier up (a failed/empty low/mid
  return is treated the same; at most 2 escalations per slice; the top tier never
  escalates — there, unresolvable means `blocked` or `needs_operator`).
  `needs_operator` / `blocked` semantics are unchanged, and in `auto` runs an
  escalation re-dispatches without a pause while the other safety halts still stop
  the loop.

Migration notes: after `--update`, remove the two retired files the updater flags
(`git rm .claude/agents/slice-executor.md .codex/agents/slice-executor.toml`) —
updates never delete files. If you tune tiers via `.env`, re-run
`python3 scripts/workflow.py sync-agents` after every update (updates reset the
agent files to upstream defaults), and add `.env` to your `.gitignore`.

## v6 — 2026-07-03

- **The workspace bootstraps with no phases.** The installer no longer seeds a
  placeholder `P1` ("Bootstrap Intake") — fresh installs and retrofits both start
  with an empty `works/phases/active/`, and `next` reports the empty-start state
  ("no active slice; create a phase or promote deferred work"). The first phase is
  created by the operator through the create-phase intake flow (`/create-phase` /
  `$create-phase` / `new-phase`), so intent is always captured and confirmed rather
  than pre-filled at install time.
- **`--phase-name` / `--phase-objective` removed.** With nothing to seed, the flags
  are gone from the installer; passing them now fails as unknown options.
- **`/retrofit` no longer synthesizes a first phase.** The skill installs, reconciles,
  and verifies — then points the operator at `/create-phase` for their first task.
  The `installer/payloads/p1_seed/` scaffolds are deleted.

Migration notes: already-installed workspaces are unaffected (`--update` never
touches your phases). Any script that passed `--phase-name` / `--phase-objective`
to the installer must drop those flags.

## v5 — 2026-07-03

- **Slice-executor dispatch pinned to a background task.** The `do-next-slice` /
  `do-whole-phase` orchestrator always launches the executor via the Agent tool as a
  background task (never `run_in_background: false`) and waits for its completion
  notification. (Shipped in machinery at `d1767f9`; versioned here — that commit
  skipped the release rule.)
- **Both slice-executors pinned to `model: opus`.** `.claude/agents/slice-executor.md`
  and `slice-executor-high.md` now carry `model: opus` instead of inheriting the
  session model. (Shipped in machinery at `1950902`; versioned here — that commit
  skipped the release rule.)
- **Upstream rebuild guard in the contract.** New Hard Rule, self-scoped to the
  upstream bootstrap repo (inert in adopting repos, which have no `installer/`):
  editing embedded machinery requires rebuilding and committing the distributable in
  the same commit; upstream, the tracked `.githooks/pre-commit` hook enforces the
  drift check. Prompted by a downstream report that `--update` at `d1767f9` emitted
  stale machinery (that commit edited machinery without rebuilding the artifact).

Migration notes: none.

## v4 — 2026-07-02

- **`/explain` saves through the KB document API.** The old steps 5–7 (manual file
  write, Recent bullet in `docs/index.md`, KB git commit) are replaced by one
  `POST http://localhost:8766/api/documents` — the API writes the convention file with
  frontmatter, inserts the Recent bullet, upserts the DB row, and makes the scoped
  commit in a single locked call.
- **The manual flow is now fallback-only.** It runs only when the API is unreachable
  (curl transport failure: connection refused / timeout). HTTP errors (409 duplicate,
  422 validation, 401 auth) are handled per the API contract and **never** trigger a
  file fallback.

Migration notes: the primary path needs the KB API compose service running
(`docker compose up -d` in `~/projects/personal/knowledge`); the skill still works via
the fallback when it is down. Applies to `--with-explain` installs; delivered by
`/update-workspace` force-refresh.

## v3 — 2026-07-02

- **A passing phase review now closes the `REVIEW` slice.** `review-phase` drives the
  phase's `REVIEW` slice from the verdict (`pass` → `done`, `changes_requested` →
  `changes_requested`, `blocked` → `blocked`), so a passing review no longer strands the
  review slice `in_progress` — previously `do-whole-phase` left it open, showing a `done`
  phase whose "Current Slice" still pointed at an unfinished `REVIEW` slice. Both
  `do-next-slice` and `do-whole-phase` now behave identically; no separate `finish-slice`
  for the review slice is needed.
- **`validate` catches the inconsistency.** It now flags a `done` phase that still has any
  unfinished slice, mirroring the archive guard, so a stranded slice is surfaced immediately
  instead of only at archive time.

Migration notes: if a pre-v3 phase was left `done` with an open `REVIEW` slice, run
`python3 scripts/workflow.py finish-slice <P>.REVIEW` once — the new `validate` guard will
name any such slice.

## v2 — 2026-07-02

- **`/explain` is now opt-in.** The `explain` skill is no longer installed by default. Pass
  `--with-explain` to include it on a fresh install or an `--into-existing` retrofit. The skill
  still ships inside the built artifact — it is only gated at install time.
- **Update preserves your choice.** `/update-workspace` keeps refreshing an already-installed
  `explain` (it is never dropped or flagged stale on update). A repo without it stays without it
  unless you re-run update with `--with-explain`.

Migration notes: none. Repos that installed `explain` under v1 keep it and keep receiving refreshes.

## v1 — 2026-07-02

First versioned release. Workspace versioning starts here.

- **Installer is now a build product.** The 3,025-line self-contained
  `bootstrap_agentic_workspace.sh` is dissolved into an `installer/` source tree
  (`build.py` + `wrapper.sh` + `main.py` + `payloads/`); `python3 installer/build.py`
  reassembles the single committed distributable deterministically. Source of truth
  for emitted machinery is now the live repo files — no more heredoc mirroring.
- **Drift check.** `python3 installer/build.py --check` (also `tests/retrofit_smoke.sh`
  Test 7) fails when the committed artifact no longer matches `installer/` source.
- **Model-flexible attribution.** The `slice-executor` agent defs use `model: inherit`
  (run the session's model) and commit-attribution wording is rule-based — "attribute
  each commit to the model that actually did the work" — with model names appearing
  only as examples. The Codex agent tomls keep an explicit `model = "gpt-5.5"` (Codex
  needs an explicit model).
- **Workspace versioning.** A `WORKSPACE_VERSION` integer is stamped as
  `workspace_version` into each target's `works/.workspace-version.json`, and this
  `CHANGELOG.md` records what each version brings. `/update-workspace` reports
  "you're on vN → upstream vM" and shows the changelog entries in between.

Migration notes: none.
