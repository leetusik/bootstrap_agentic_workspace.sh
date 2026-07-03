# Changelog

Workspace versions for the agentic-workspace cornerstone. One `## v<N>` section per
integer `WORKSPACE_VERSION`, newest first. `/update-workspace` reads this file from
the upstream clone to show adopting repos what a sync brings — so each entry states
what changed and, when a sync needs manual steps, a **Migration notes** line.

Everything before v1 is **pre-versioning**: those workspaces carry no
`workspace_version` in `works/.workspace-version.json`; consult `git log` for that
history.

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
