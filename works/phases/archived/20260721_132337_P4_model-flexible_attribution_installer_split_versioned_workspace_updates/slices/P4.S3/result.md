# Result

- Phase ID: P4
- Slice ID: P4.S3
- Slice: CHANGELOG + integer workspace versioning in /update-workspace
- Review status: pending
- Next action: orchestrator runs `validate`, then `finish-slice P4.S3` + commit; P4.REVIEW consolidates docs.

## Outcome

Job 3 done: integer workspace versioning + a root `CHANGELOG.md`, surfaced by
`/update-workspace` as "you're on vN → upstream vM" plus the changelog entries in
between.

- **`WORKSPACE_VERSION = 1`** (int) added in `installer/main.py` near the config
  constants (after `UPSTREAM_URL`). `write_version_marker()` now writes
  `"workspace_version": WORKSPACE_VERSION` into `works/.workspace-version.json`
  (order: `upstream_url`, `workspace_version`, `synced_commit`, `synced_at`). The
  constant rides inside the built artifact, so adopting repos (no `installer/`) get
  it stamped on install/update.
- **Root `CHANGELOG.md`** seeded (repo-only, NOT emitted to targets — `build.py`
  never embeds it, verified). Newest-first, one `## v<N> — <date>` section; v1
  documents the installer split + drift check, model-flexible attribution, and
  workspace versioning itself, with a "Migration notes: none" line and a note that
  earlier history is pre-versioning (git log).
- **Release rule** documented in `installer/README.md`'s edit→build→commit loop:
  shipping a machinery change to targets ⇒ bump `WORKSPACE_VERSION` + add the
  matching `CHANGELOG.md` entry in the same commit; repo-only edits need no bump.
- **`/update-workspace` skill** — both mirrors updated (bodies kept byte-identical;
  the `.claude` copy keeps its 2 extra frontmatter lines): preflight reads local
  `workspace_version` (absent ⇒ pre-versioning); after clone, read upstream version
  M from the clone's `CHANGELOG.md`; preview step reports the vN→vM gap + prints the
  changelog entries newer than vN (pre-versioning and equal-version cases handled),
  alongside the existing `--dry-run` change-list; apply step notes it stamps
  `workspace_version` M.
- **This repo's own marker** `works/.workspace-version.json` hand-updated to include
  `"workspace_version": 1`.
- **Smoke test**: one-line grep assert added to Test 5 (fresh block) that the fresh
  marker carries `workspace_version`.
- Distributable rebuilt via `python3 installer/build.py` (212202 bytes).

## Deviations from Plan

None. The optional smoke-test assert (plan item 6) was added as a single grep, as
permitted. Kept the `/update-workspace` step numbering intact by folding the
version-aware preview into the existing step 5 rather than adding a numbered step.

## Validation Run

1. `python3 installer/build.py` — rebuilt artifact (212202 bytes). PASS.
2. `python3 installer/build.py --check` — "OK: ... in sync with installer/ source". PASS.
3. `bash tests/retrofit_smoke.sh` — ALL RETROFIT SMOKE TESTS PASSED (all 7 blocks,
   including the new "fresh marker carries workspace_version"). PASS.
4. Fresh-mode: fresh-install NEW artifact into a temp dir → marker has
   `"workspace_version": 1`. PASS.
5. Update-mode end-to-end: fresh-installed the PREVIOUS artifact
   (`git show HEAD:bootstrap_agentic_workspace.sh`) into a temp git repo (marker had
   NO `workspace_version` — pre-versioning), committed it, then ran the NEW artifact
   `--update --dry-run` (unchanged behavior; reported only the 2 update-workspace
   SKILL.md files updated) and real `--update` → exit 0, marker now has
   `"workspace_version": 1`; target `python3 scripts/workflow.py validate` passes. PASS.
6. This repo: `works/.workspace-version.json` shows `workspace_version: 1`;
   `python3 scripts/workflow.py validate` passes. PASS.
7. Confirmed `CHANGELOG.md` text is NOT embedded in the built artifact (repo-only). PASS.
8. `/update-workspace` bodies verified byte-identical across both mirrors (below
   frontmatter). PASS.

## Files Changed

- `installer/main.py` — `WORKSPACE_VERSION = 1` constant + `workspace_version` in `write_version_marker()`
- `CHANGELOG.md` — new root file, seeded v1
- `installer/README.md` — release rule (bump version + changelog entry)
- `.claude/skills/update-workspace/SKILL.md` — version-aware preflight/clone/preview/apply
- `.agents/skills/update-workspace/SKILL.md` — same body edits
- `works/.workspace-version.json` — added `"workspace_version": 1`
- `tests/retrofit_smoke.sh` — one-line fresh-marker assert
- `bootstrap_agentic_workspace.sh` — rebuilt distributable

## Doc Versions Created

- None (non-review slice). Doc-impact note appended to `phase.md` for P4.REVIEW to
  consolidate (`operations` doc).

## Roadmap Updates

-

## Retrospective

The S1 build workflow held: edit live files/installer source + `installer/build.py`,
no heredoc mirroring. `CHANGELOG.md` being repo-only means it is NOT in the target
payload — `/update-workspace` reads it from the fresh upstream clone (a full
checkout), not from the installed target, which is why the skill points at
`$tmp/CHANGELOG.md`. Update-mode diff between prev and new artifact was exactly the
two SKILL.md mirrors, confirming `main.py`/`CHANGELOG.md` changes don't reach targets
as files while the version constant still rides the artifact and gets stamped.
