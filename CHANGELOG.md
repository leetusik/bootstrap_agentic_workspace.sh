# Changelog

Workspace versions for the agentic-workspace cornerstone. One `## v<N>` section per
integer `WORKSPACE_VERSION`, newest first. `/update-workspace` reads this file from
the upstream clone to show adopting repos what a sync brings — so each entry states
what changed and, when a sync needs manual steps, a **Migration notes** line.

Everything before v1 is **pre-versioning**: those workspaces carry no
`workspace_version` in `works/.workspace-version.json`; consult `git log` for that
history.

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
