# Plan — P4.S3 (CHANGELOG + integer workspace versioning in /update-workspace)

Orchestrator's native plan. Slice kind: `implementation`, risk `medium`. Executor: `slice-executor` (xhigh). Read `phase.md` first — S1's note tells you where everything lives now (`installer/main.py` holds `write_version_marker()`; edit live files / installer source, then `python3 installer/build.py`); S2's note says the remaining `GPT-5.5` strings are intentional examples — leave them.

## Goal

Intent Job 3: adopting repos (and this one) can see *what* a workspace update brings, not just a byte-diff. Integer workspace versions (v1, v2, …) + a root `CHANGELOG.md`, stamped into `works/.workspace-version.json`, surfaced by `/update-workspace` as "you're on vN → upstream vM" plus the changelog entries in between.

## Changes

1. **`WORKSPACE_VERSION = 1`** (int) in `installer/main.py` near the config/constants. `write_version_marker()` adds `"workspace_version": WORKSPACE_VERSION` to `works/.workspace-version.json` (alongside `upstream_url`/`synced_commit`/`synced_at`). Every consumer of the single-file artifact gets it — adopting repos don't have `installer/`, the constant rides inside the built artifact.
2. **Root `CHANGELOG.md`** (repo-only — NOT emitted to targets; keep it out of the payload manifest). Newest-first, one `## v<N> — <YYYY-MM-DD>` section per version, each with short "what changed" bullets + a "Migration notes" line when manual steps exist (v1: none). Seed **v1** as this first versioned release: installer split into `installer/` + build/drift check, model-flexible attribution (`model: inherit`, rule-based trailers), workspace versioning itself; note that earlier history is pre-versioning (git log).
3. **Release rule documented where maintainers look**: add to `installer/README.md`'s edit→build→commit loop — shipping a machinery change to targets ⇒ bump `WORKSPACE_VERSION` + add the matching `CHANGELOG.md` entry in the same commit.
4. **`/update-workspace` skill** — both mirrors (`.claude/skills/update-workspace/SKILL.md`, `.agents/skills/update-workspace/SKILL.md`; bodies must stay identical, the `.claude` copy keeps its 2 extra frontmatter lines), then rebuild:
   - Preflight (existing step 3): also read `workspace_version` from local `works/.workspace-version.json` — absent ⇒ report "pre-versioning".
   - After clone: read upstream version + entries from the clone's `CHANGELOG.md` (top `## v<N>` = upstream version M; the clone is a full repo so the file is right there).
   - Preview step: report "workspace vN → upstream vM" and print the changelog entries newer than vN (pre-versioning ⇒ note it and show the v-entries with a pointer to the full file), alongside the existing `--dry-run` change-list. Versions equal ⇒ say "already on vM; any diff below is unreleased upstream drift".
   - Apply step unchanged (`SYNCED_COMMIT="$ref" sh … --update` now stamps `workspace_version` M).
5. **This repo's own marker**: hand-add `"workspace_version": 1` to `works/.workspace-version.json` (it's workspace state, only rewritten by install/update runs).
6. Optional, keep-tests-small: a one-line assert in the smoke test's fresh block that the fresh marker contains `"workspace_version"` — only if it stays a single grep.

## Validation

1. `python3 installer/build.py --check` green; `bash tests/retrofit_smoke.sh` all blocks green.
2. Fresh-mode: fresh-install the new artifact into a temp dir → `works/.workspace-version.json` has `"workspace_version": 1`.
3. Update-mode end-to-end: fresh-install the PREVIOUS artifact (`git show HEAD:bootstrap_agentic_workspace.sh`) into a temp git repo (its marker has no `workspace_version` — pre-versioning), commit it there, then run the NEW artifact `--update --dry-run` (unchanged behavior) and real `--update` → exit 0 and the marker now has `"workspace_version": 1`; target `python3 scripts/workflow.py validate` passes.
4. This repo's `works/.workspace-version.json` shows `workspace_version: 1`; `python3 scripts/workflow.py validate` passes here.

## Wrap-up

`result.md` with validation outcomes; `phase.md` gets the S3 cross-slice note + Doc impact lines (`operations`: version-aware update flow + release rule (bump version / add changelog entry); the review consolidates). Never commit; never transition state.
