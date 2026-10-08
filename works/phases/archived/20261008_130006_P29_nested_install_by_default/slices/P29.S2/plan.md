# Plan — P29.S2 Texts, /update-workspace and release v50

**Tier:** mid (`risk: low`). This is a text sweep plus a version bump, the same shape as P28.S3.

**Source of truth:** `works/phases/active/P29/phase.md` → `## Decisions` → **"Final flag shape (P29.S1)"**, together with the two S2 notes under `## Notes for later slices`.
- Write every flag name, behaviour and quoted message from that block. Never write them from memory or from the DECOMP plan.
- Read `works/phases/active/P29/intent.md` for the operator's accepted consequences.
- Read the new `installer/wrapper.sh` usage text and `installer/main.py`'s `resolve_layout()` / banners only to confirm wording.

## Edits

1. **`README.md` (Korean) and `README.en.md`**, kept parallel to each other.
   - **Install section** ("1. 설치" / its English twin):
     - The bare command `sh bootstrap_agentic_workspace.sh <dir>` now gives the **private nested layout**. A new or empty directory is `git init`ed as the host, and the commit convention is recorded as confirmed.
     - `--at-root` gives the committed, team-visible layout for a fresh directory.
     - `--into-existing` stays the at-root retrofit.
     - Update every fresh-install example that expects the at-root layout so it adds `--at-root`, or reword it.
   - **Update section:** a plain `--update` (and `--dry-run`) detects the layout. It no longer needs `--nested`.
   - **The `--nested` section** ("내 것이 아닌 저장소에서 혼자 쓰기" / "Private use in a repo you don't own"):
     - Reframe it: this is now the default. In a team repo you just run the bare command, and `--nested` is accepted but redundant.
     - Replace `--update --nested` with `--update`. Keep the rest of the section, which is still true: first run, the ticket flow, the known points.
     - Add a short line: a new personal project is also nested (`git init` + `workflow/`) and private by default. Use `--at-root` if collaborators should get the workspace in the repo. Parallel worktrees only work on an `--at-root` install.
     - Keep the anchors and links consistent, including the link from the retrofit paragraph near line 60.
2. **`docs/retrofit-guide.md`**
   - Reword its `--nested` section the same way.
   - The decision table row stays: retrofit = team-visible; private = the default bare command.
   - The staging command near line 303 (`sh bootstrap_agentic_workspace.sh /tmp/ws-stage …`) gets `--at-root`.
   - Change `--update --nested` to `--update`.
   - The line near 7 ("The plain bootstrap … intentionally …") must still be true. Fix it if it now describes the wrong layout.
3. **`installer/README.md`:** wherever it describes the install modes and flags, add `--at-root`, the nested default and update detection.
4. **`.claude/skills/update-workspace/SKILL.md`**
   - Collapse the `(nested)` command variants in steps 5 and 7 into the single plain command:
     - `sh "$tmp/bootstrap_agentic_workspace.sh" . --update --dry-run`
     - `SYNCED_COMMIT="$ref" sh "$tmp/bootstrap_agentic_workspace.sh" . --update`
   - Say that the installer detects the layout.
   - Delete the false sentence "A plain `--update` at such a host refuses and points to `--update --nested`."
   - Keep the nested differences that are still real: run from the host root; the dirty check uses `git -C workflow status`; the host status must be unchanged; it merges `settings.local.json` and `CLAUDE.local.md` and never `CLAUDE.md`.
   - Add one line covering a downstream on v49 skill text: `--update --nested` still works.
   - **Rewrite caution (P28):** this skill is rewritten at nested install time, so keep its paths root-relative (`scripts/workflow.py`, `works/…`). Never hand-write `workflow/…` engine paths. The text already prints `git -C workflow` and `workflow/.agentic-nested.json` literally; keep those as they are.
5. **`.claude/skills/retrofit/SKILL.md`:** its pointer to `--nested` for private use becomes "the default bare install (no flag)".
6. **`.claude/skills/commit/SKILL.md`:** check it, and change it only if it names `--nested` as an install step.
7. **`installer/wrapper.sh` usage text:** give it a final read against the docs, and fix any wording mismatch. Do not change behaviour.
8. **`CHANGELOG.md`:** a new top entry `## v50 — 2026-10-07`, in the same style as v49.
   - **The default is nested** everywhere: an existing git repo; a new or empty directory, which is `git init`ed with the workspace's own convention recorded as confirmed and trailers allowed; the init is undone on a refusal before the first write.
   - **`--at-root`** gives the committed layout. `--into-existing` is the at-root retrofit.
   - **`--update` detects** the layout. It refuses when the layout is ambiguous or a flag contradicts it.
   - **New refusals:**
     - a bare install over an at-root workspace (use `--update`);
     - any run on a nested install's `workflow/`;
     - a non-empty non-git target;
     - a new directory inside another repo's work tree.
   - **`/update-workspace`** runs plain `--update`.
   - **Migration notes:**
     - Existing installs are unaffected; there is no migration.
     - Scripts or habits that ran a bare install for the at-root layout must add `--at-root`.
     - `--nested` is now redundant.
     - `--force-empty-ok` needs `--at-root`, now on `--update` too, where v49 ignored it.
     - New personal projects are private by default, and parallel worktrees need `--at-root`.
9. **`installer/main.py`:** `WORKSPACE_VERSION = 50`. Then run `python3 installer/build.py` and `python3 installer/build.py --check`, which must pass.

## Validation

- Grep for stale text, and resolve each hit or justify it in `result.md`. The search covers `README*.md`, `docs/retrofit-guide.md`, `installer/README.md`, `.claude/skills` and `CHANGELOG.md`, but only the v50 entry: v49's history stays as written.
  - `--update --nested`
  - `--nested` presented as required or opt-in
  - a bare fresh install described as at-root
- Run `python3 installer/build.py --check`, which must pass.
- Run `python3 scripts/workflow.py validate`, which must pass.
- Do **not** run the smoke suite. The review runs it once.
- Write no tests.

## Notebook (`phase.md`, edited under budget)

- Remove the two consumed S2 notes from `## Notes for later slices`.
- Add one `## Doc impact` line: READMEs, retrofit guide and skills texts for the nested default, v50 (operations).
- Rewrite `## Now`: the next slice is `P29.REVIEW`. The gate is required. There is one operator question to route.

## Return

Write `result.md` with the verdict block first: `files_changed`, the grep results and the build check.

Do not commit and do not transition state.
