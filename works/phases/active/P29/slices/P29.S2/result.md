# Result: P29.S2 Texts, /update-workspace and release v50

- **status:** done
- **tier:** mid
- **summary:** Both READMEs, the retrofit guide, `installer/README.md` and the `update-workspace` / `retrofit` skills now present the nested install as the default (`--at-root` for the committed layout, `--nested` redundant, `--update` detecting the layout). CHANGELOG v50 carries the migration notes, `WORKSPACE_VERSION` is 50, and the artifact is rebuilt. `build.py --check` and `validate` pass.
- **files_changed:**
  - `README.md`
  - `README.en.md`
  - `docs/retrofit-guide.md`
  - `installer/README.md`
  - `.claude/skills/update-workspace/SKILL.md`
  - `.claude/skills/retrofit/SKILL.md`
  - `CHANGELOG.md`
  - `installer/main.py` (`WORKSPACE_VERSION = 50` only)
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `works/phases/active/P29/phase.md`
  - `works/phases/active/P29/slices/P29.S2/result.md`
- **validation:**
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: PASS (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`).
  - `python3 scripts/workflow.py validate`: PASS (`Workflow validation passed.`; the only warnings are the pre-existing P26-P28 consolidation debt, stale docs and oversized doc sections).
  - Stale-text grep over `README*.md`, `docs/retrofit-guide.md`, `installer/README.md`, `.claude/skills` and the v50 entry only: clean (below).
  - Quick live probe with the rebuilt artifact in a scratch dir (not the smoke suite): a bare install into a new dir nests it; a bare `--update --dry-run` and `--update --nested --dry-run` both print `(nested, detected)`; `--update --force-empty-ok` exits 1 with `--force-empty-ok applies to the at-root install; add --at-root`; the installed `update-workspace` skill reads correctly after the nested rewrite (`workflow/scripts/workflow.py`, `workflow/works/…`).
  - The smoke suite was **not** run, as instructed. No installer code changed beyond `WORKSPACE_VERSION`; its release-version and "Migration notes" asserts are dynamic and the v50 entry satisfies both by inspection.
- **deviations:**
  1. **Retitled the README private-use section** (`(--nested)` became `(the default install)`; Korean `(기본 설치)`), and so changed its anchor. The plan said to keep anchors and links consistent, so every link was updated (both READMEs, the retrofit guide, the `retrofit` skill). A heading that still said `(--nested)` would have misdescribed the default.
  2. **Worded the `workflow/`-target refusal as "a bare install or an `--update`"** on a nested install's own `workflow/` (the Decisions block's resolution), not the plan's "any run". `--at-root` / `--into-existing` are not covered by that refusal in `resolve_layout()`.
  3. **Small additions beyond the plan's list, all from the intent's accepted consequences or the S1 behaviours:** the worktree section of each README notes that `parallel-*` needs an `--at-root` install; the READMEs' prerequisites say the default install needs `git`; each README's step 2 points a nested user at the first-run order; the README first-run text says an initialised host starts confirmed and has no commits.
- **doc_impact:** `- operations.md (install modes, release v50): the READMEs, docs/retrofit-guide.md and the update-workspace / retrofit skill texts present the nested install as the default … WORKSPACE_VERSION 49 → 50 with CHANGELOG v50 migration notes … (P29.S2)` (full line in `phase.md` `## Doc impact`).

## What changed

**`README.md` (Korean) and `README.en.md`**, kept parallel
- **Install:**
  - The bare command is described as the private nested install: a new or empty directory is `git init`ed as the host, with this workspace's convention recorded as confirmed and trailers allowed.
  - A second `--at-root` example gives the committed layout; the `curl | sh` line mentions `sh -s -- . --at-root`.
  - `--force-empty-ok` is stated to need `--at-root` or `--into-existing`.
  - Prerequisites now list `git` for the default install.
- **Existing project:** the bare command also works there (nested, no tracked file changes); `--into-existing` stays the team-visible at-root retrofit. The retrofit paragraph's link goes to the default install section.
- **Update:** plain `--update` / `--dry-run` detects the layout; no `--nested` / `--at-root`; ambiguity or a contradicting flag refuses; at-root installs update at-root with no migration.
- **Private-use section:**
  - Reframed as the default.
  - `--nested` is described as the v49 spelling, accepted and redundant.
  - New line: a new personal project is also nested (`git init` + `workflow/`) and private by default; use `--at-root` if collaborators should get the workspace; parallel worktrees need `--at-root`.
  - Install command is bare.
  - The refusals are listed: non-empty non-git target, a new dir inside another repo's work tree, a bare install over an at-root workspace, and a bare install or `--update` on a nested install's `workflow/`.
  - `--update --nested` became `--update` in the gitignore-check and Updating paragraphs; the update paragraph says the v49 form still works.
  - First run: initialised-host notes (no commits yet, convention already confirmed).
  - The sections on the ticket flow and the known points are kept.
  - The caveat on parallel worktrees now says they are off by default.
- **English only:** the options table gains `--at-root` and a default row, and its `--force-empty-ok`, `--update` and `--nested` rows are rewritten; "What gets created" is labelled as the `--at-root` layout; the **Safety** paragraph covers both layouts.
- **Worktree sections (both):** a one-line note that `parallel-*` needs an `--at-root` install.

**`docs/retrofit-guide.md`**
- Line-7 paragraph: the plain bootstrap is the nested default and `--at-root` is its committed form that refuses non-empty repos; retrofit is the non-destructive team-visible route.
- Decision table: the retrofit row says "team-visible", and the private row points at the default bare command.
- Private-use section: retitled, bare command, `--update` instead of `--update --nested`, a pointer to the retitled README anchor.
- The Manual-fallback staging command now reads `sh bootstrap_agentic_workspace.sh /tmp/ws-stage --at-root --name … --summary …`.

**`installer/README.md`:** a new *Install modes and flags* section (default nested, `--at-root`, `--into-existing`, `--update` detection, `--nested`, the refusals), plus the `wrapper.sh` and `main.py` bullets updated.

**`.claude/skills/update-workspace/SKILL.md`**
- The nested paragraph now says nested is the default since v50 and that the installer detects the layout, so steps 5 and 7 run the same plain `--update`.
- It carries the v49-text line: `--update --nested` still works on a nested install.
- The two `(nested)` command blocks are gone; each keeps a one-line `(nested)` note (run from the host root; the dry-run banner says `(nested, detected)`).
- The false sentence "A plain `--update` at such a host refuses and points to `--update --nested`" is deleted.
- Kept as they were: the host-root rule, the `git -C workflow status` dirty check, the unchanged host status, and the `settings.local.json` / `CLAUDE.local.md` merge that never touches `CLAUDE.md`.
- Paths stay root-relative; the new text adds no `workflow/…` engine path. I checked the installed, rewritten copy.

**`.claude/skills/retrofit/SKILL.md`:** the private-use pointer now names the default bare install and the retitled README section.

**`.claude/skills/commit/SKILL.md`:** read, no change. It names the nested layout only through `workflow/.agentic-nested.json`, never `--nested` as an install step.

**`installer/wrapper.sh`:** final read of the usage text against the docs found no mismatch, and nothing changed. The text already says nested by default, `--at-root`, `--force-empty-ok` "With --at-root", `--into-existing` "At-root retrofit", `--update` detecting the layout, `--nested` "Accepted and redundant", and the closing git / `--update` line.

**`CHANGELOG.md`:** new `## v50 — 2026-10-07` entry in v49's style:
- the default is nested, including `git init` for a new or empty dir with the confirmed convention and the init undone on a pre-write refusal;
- `--at-root` and the `--into-existing` at-root retrofit;
- `--update` detecting the layout, refusing when ambiguous or contradicted;
- the new refusals (listed above);
- `/update-workspace` running a plain `--update`;
- a Docs line;
- **Migration notes:** existing installs are unaffected, no migration; scripts that ran a bare install for the at-root layout must add `--at-root`; `--nested` is redundant; `--force-empty-ok` needs `--at-root`, now on `--update` too where v49 ignored it; new personal projects are private by default; parallel worktrees need `--at-root`.

**`installer/main.py`:** `WORKSPACE_VERSION = 50`; `build.py` and `--check` pass.

## Stale-text grep

Scope: `README.md`, `README.en.md`, `docs/retrofit-guide.md`, `installer/README.md`, `.claude/skills/*/SKILL.md`, and the v50 CHANGELOG entry only (v49's history stays as written). Patterns: `--update --nested`, `--nested` as required or opt-in, a bare fresh install described as at-root, and the old anchors.

- **`--update --nested`:** 3 hits, all justified.
  - `README.md:205` and `README.en.md:322` say the v49 form still works.
  - The `update-workspace` skill line 14 says the same for a downstream on v49 text.
  - The v50 CHANGELOG entry has the same two statements (lines 21, 38).
- **`--nested` presented as required or opt-in:** none. Every other hit says it is redundant or accepted:
  - `installer/README.md:87-88`;
  - `README.en.md:161`, `:201`, `:241`, `:321`;
  - `README.md:98`, `:122`, `:204`;
  - `docs/retrofit-guide.md:35`, `:46`, `:48`;
  - `.claude/skills/retrofit/SKILL.md:12`, where `--nested --into-existing` is refused;
  - the v50 entry's refusal and migration lines.
- **A bare fresh install described as at-root:** none left. I fixed the "plain bootstrap is for an empty directory" / "refuses non-empty" paragraphs, the Safety paragraph, "scaffold a fresh workspace into an empty directory", and the retrofit guide's staging command (now `--at-root`).
- **Old anchors** (`…dont-own---nested`, `…혼자-쓰기---nested`): none remain.
- **Outside the grep scope:** `scripts/workflow.py` line 32 is an engine comment that mentions `--update --nested` (still true, since it works). It is left untouched. `tests/retrofit_smoke.sh` keeps its own `--nested` probes as S1 left them.

## Notes

- **Operator question:** this slice raised no new one. The README, CHANGELOG and installer README now state S1's behaviour for a new directory inside another repo's work tree (refused). If the operator chooses auto-init instead, those three lines change with it (recorded in `phase.md` `## Decisions`, `## Operator Questions` still holds the question).
- `phase.md` is 20.8 KB, well under the budget.
