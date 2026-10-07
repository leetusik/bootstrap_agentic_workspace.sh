# Plan — P28.S2 Installer `--nested`: zero-footprint install, rewrite, clash map, update (implementation / high)

## Goal

`sh bootstrap_agentic_workspace.sh <host> --nested` installs the workspace privately into a host repo the operator doesn't own:
- the engine and its state go to `<host>/workflow/`, a nested git repo;
- skills and agents go to `<host>/.claude/` as untracked files;
- `<host>/.claude/settings.local.json` and `<host>/CLAUDE.local.md` are written;
- entries are appended to the host's `info/exclude`.

**After install, host `git status --porcelain` is empty, and host HEAD and git config are unchanged.** `--update --nested` refreshes the install with the same guarantees.

Read first:
- `phase.md`: `## Decisions` items 1–7, "Engine contract", the Claude Code verification, and every note tagged `for P28.S2`;
- `intent.md`;
- `installer/README.md` (the build loop).

At-root installs (fresh, `--into-existing` and `--update`) stay **byte-for-byte unchanged**. Tests 0–14 must pass untouched apart from the marker rename below.

## 0. Marker rename (operator answer, 2026-10-07)

- Rename the marker from `nested.json` to **`.agentic-nested.json`**: `NESTED_MARKER` in `scripts/workflow.py`, plus every comment, docstring and message that names the old file.
- Update Test 14 (fixture path, grep strings, title) and the "Engine contract" line in `phase.md` `## Decisions`.
- The schema is unchanged unless step 4 extends it.

## 1. Flag (`installer/wrapper.sh`)

- Add a usage line and `nested=0`.
- Add a `--nested) nested=1` case arm and `export NESTED`.
- **Combinations:**
  - `--nested` with `--into-existing` → error;
  - `--nested --update` and `--nested --update --dry-run` → allowed;
  - `--nested --force-empty-ok` → error, since there is nothing to force.
- `TARGET_DIR` is the **host**.

## 2. Two roots (`installer/main.py`)

- **When `NESTED`:**
  - `HOST = TARGET.resolve()`;
  - `ROOT = HOST / "workflow"` (the engine root; every existing `ROOT`-relative write lands there).
- **Preconditions:** the host must be a git work tree (`git -C HOST rev-parse --is-inside-work-tree`) with git on PATH. Otherwise refuse with one line.
- **Engine root (`workflow/`):**
  - `MANAGED_DIRS`/`MANAGED_FILES` drop `.claude*` and `CLAUDE.md`, which are host-side or renamed;
  - the contract is written as `workflow/CLAUDE.workspace.md`, rewritten (§3);
  - nothing under `workflow/` is named `CLAUDE.md`, and there is **no `workflow/.claude/`**.
- **Never written when `NESTED`:**
  - `emit_policy_files()` (guard the unconditional call at about L559): no CI file, no `.gitattributes` anywhere;
  - `_merge_settings_json`;
  - `_merge_contract`;
  - the host's `docs/` (docs are seeded only under `workflow/docs/`).
- **Templates:** `works/templates/*` are installed rewritten (§3), because agents at the host root read the phase files made from them.
- **Fresh-install guard:**
  - `workflow/` must be absent or empty, so `EMPTY_OK_ALLOWLIST` does not apply to the host;
  - a host where `workflow/` already holds an install (the marker is present) gets the message "already installed — use --update --nested" and exits 0 (idempotent, like retrofit);
  - a host where **`workflow` is a tracked path** (`git ls-files workflow` is non-empty) is refused.
- **Nested repo:** `git init -q` under `workflow/` when `workflow/.git` is absent. The installer still **never commits**; the banner tells the operator the first commit to make in `workflow/`.

## 3. Host-side writes and the install-time rewrite

- **One pure function: `nested_rewrite(text, renames) -> str`.** It is applied to the source payload, **never to an installed copy**, so a rerun or `--update` cannot double-prefix.
- **Engine paths:**
  - `python3 scripts/workflow.py` → `python3 workflow/scripts/workflow.py`, including inside `allowed-tools` frontmatter and the `Bash(python3 scripts/workflow.py:*)` allowlist;
  - bare `scripts/workflow.py` mentions get the same `workflow/` prefix.
- **Workspace paths** get the `workflow/` prefix: `works/`, `docs/current`, `docs/versions`, `docs/index.json`, `docs/reference/` (S1 leak 1: design cards), `docs/README.md`, `executors.toml`, `.env`.
- **Token boundaries:** use regex boundaries (e.g. `(?<![\w./-])works/`) so `workflow/works/`, URLs and words like `networks/` are never touched.
- **Contract references:** text naming the **contract** as `CLAUDE.md` (e.g. "the contract (`CLAUDE.md`)", "Read `CLAUDE.md`") is pointed at `workflow/CLAUDE.workspace.md`. Decide the exact token rule, keep it narrow, and list it in `result.md`.
- **Name renames** (S1's contract):
  - for each `renames.skills[X] = Y`: the directory, the `name:` frontmatter, `/X` slash references and prose of the form "the `X` skill";
  - for each `renames.agents[X] = Y`: the filename, the `name:` frontmatter and `subagent_type: X`, plus prose of the form "`X`" **only** in an agent context.
  - **Never** touch `workflow.py <subcommand>` lines.
- **Post-check:** after rendering everything host-side, plus `workflow/CLAUDE.workspace.md` and the templates, fail the install if any of these remain:
  - an unprefixed `python3 scripts/workflow.py`;
  - an unprefixed workspace path from the list;
  - a renamed name left in slash or `subagent_type` form.

  On failure, write nothing to the host: render in memory, check, then write.
- **Host writes:**
  - `.claude/skills/<installed>/SKILL.md` × 18 and `.claude/agents/<installed>.md` × 3, rewritten.
  - `.claude/settings.local.json`: an additive union of the rewritten shipped `permissions` (allow/deny). If the file exists and is the operator's own, merge without dropping their keys. Refuse if it is unparseable.
  - `CLAUDE.local.md`: a managed block between `<!-- BEGIN agentic-workspace (nested) -->` and `<!-- END … -->`. If the file exists, replace the block or append it, and keep the operator's own text. The block holds:
    1. one line saying this is a private, never-committed install;
    2. the import line `@workflow/CLAUDE.workspace.md`, outside backticks and fences;
    3. the nested rules, short:
       - start Claude at the host root;
       - two commits per slice: product to the host in the convention `nested-convention` prints (and the trailer rule), state to `workflow/` in the workspace convention;
       - confirm an UNCONFIRMED convention with the operator before the first product commit;
       - no parallel worktrees;
       - a PR carries no phase IDs, workflow paths or workspace files;
       - never `git add` `workflow/`, `CLAUDE.local.md` or our `.claude/` files to the host.

    S3 polishes the wording; S2 owns a working version.
- **Tracked-target refusal:** if any host-side target path is **tracked** in the host (`git ls-files --error-unmatch`), refuse before writing anything and name the path. `info/exclude` cannot hide a tracked file, and editing it would leak. This covers `CLAUDE.local.md`, `settings.local.json` and a skill or agent target after renaming.
- **`info/exclude`:**
  - resolve the path with `git -C HOST rev-parse --git-path info/exclude`;
  - maintain one managed block (`# BEGIN agentic-workspace (nested)` … `# END`) that is replaced on rerun or update, never duplicated;
  - anchored entries: `/workflow/`, `/CLAUDE.local.md`, `/.claude/settings.local.json`, `/.claude/skills/<installed>/` for each skill, `/.claude/agents/<installed>.md` for each agent.

## 4. Clash detection and the marker

- **Clash:** a host skill or agent counts as a clash when its directory or filename **or** its `name:` frontmatter equals one of ours and it is not our own installed copy. Read the host's `.claude/skills/*/SKILL.md` and `.claude/agents/*.md`.
- **Rename:** a clashing name is installed as `wf-<name>`. If `wf-<name>` also clashes, refuse with one line.
- **Recognising our own copies on `--update`:** the rename map alone cannot do this. Extend the marker with an `installed` record (`{"skills": [...], "agents": [...]}` holding the installed names) and teach S1's checker (`nested_marker_problems`) the new key, keeping it strict. Alternatively choose an equivalent mechanism, but state it in `## Decisions`.
- **Personal skills** (`~/.claude/skills/<name>`) silently shadow project skills. **Warn** (do not rename) when one of ours is shadowed there.
- **Marker:** write `workflow/.agentic-nested.json` exactly to the Engine contract:
  - `host_root: ".."`;
  - `commit_convention.inferred` = inferred text;
  - `confirmed: false`, `text: null`, `coauthor_trailers: "unknown"`;
  - `renames` from the clash detection.
- **`--update --nested`:** **merge** into the existing marker. Keep a confirmed convention and the existing renames; add renames only for newly shipped names that clash.
- **Post-check:** run `python3 workflow/scripts/workflow.py validate` from the host.

## 5. Inferring the host commit convention (non-interactive)

- **Sources:** the host's `git log -n 50 --format=%s` and the first ~4 KB of any `CONTRIBUTING*` or `.github/CONTRIBUTING*` (lines mentioning commit).
- **Classify:** Conventional Commits (≥60% of subjects match `^\w+(\([^)]*\))?!?: `); ticket-prefixed (`^[A-Z][A-Z0-9]+-\d+`); or free-form.
- **Inferred text:** one or two lines, e.g. `Conventional Commits "type(scope): summary" (42/50 recent subjects); CONTRIBUTING mentions: …`. An empty host history gives `null`.
- Also note whether existing bodies carry `Co-Authored-By:` lines, for the operator's information. `coauthor_trailers` stays `unknown` until the operator confirms.

## 6. Update path and stale flags

- **`--update --nested` detection:** `workflow/.agentic-nested.json` plus `workflow/scripts/workflow.py`.
- **Engine side:** the existing update policy under `ROOT = workflow/` (machinery overwritten, work preserved), with no policy files.
- **Host side:** re-render from source with the merged renames and replace the `CLAUDE.local.md` and `info/exclude` blocks.
- **`--dry-run`:** writes nothing anywhere, host included.
- **`flag_stale_skills`:** when nested, look in the host's `.claude/skills` and never flag our installed or renamed names.
- **Banners:** add nested variants for fresh and update. Include:
  - start Claude at the host root;
  - the first `git -C workflow` commit;
  - "confirm the commit convention: `python3 workflow/scripts/workflow.py nested-convention`";
  - "any remote for workflow/ stays inside your company's org".

## 7. Test 15 "nested install" (`tests/retrofit_smoke.sh`, before the summary)

**Fixture host** (git init and commit):
- a tracked `CLAUDE.md`, `.claude/settings.json`, `.gitattributes` and `.github/workflows/ci.yml`;
- a tracked `.claude/skills/commit/SKILL.md` with `name: commit` (a clash with our `commit` skill);
- about five Conventional-Commit subjects.

**Assert:**
1. Install `--nested`, exit 0.
2. Host `git status --porcelain` is empty, host HEAD is unchanged, and `git config --local --get core.hooksPath` is unset.
3. `workflow/.git` exists, and there is no `workflow/.claude` and no `workflow/CLAUDE.md`.
4. The marker records `renames.skills.commit == "wf-commit"`; `.claude/skills/wf-commit/SKILL.md` has `name: wf-commit`; the host's own `commit` skill is byte-identical.
5. No unprefixed `python3 scripts/workflow.py` remains anywhere in the host's untracked `.claude/` files, `CLAUDE.local.md` or `workflow/CLAUDE.workspace.md`.
6. `CLAUDE.local.md` carries the import line outside fences.
7. From the host, `python3 workflow/scripts/workflow.py validate` and `next` both work, and `next` shows `host_commit_convention=UNCONFIRMED` with the inferred Conventional-Commits text.
8. Right after install, `new-phase` and then `phase-scope` list nothing (S1 leak 2).
9. A rerun of `--nested` is an idempotent exit 0.
10. Run `nested-convention --confirm …`, then `--update --nested`: the confirmation and renames are kept, host status is still empty, there is no `workflow/workflow/`, and the exclude block appears once.
11. `--nested --into-existing` is rejected.
12. A second fixture with a tracked `CLAUDE.local.md` is refused with nothing written.

Keep each assertion one line, matching the file's style.

## 8. Live run (scratch host, outside the repo, in the session scratchpad)

- Install `--nested` into a scratch host.
- Try **once** to confirm loading in Claude Code: from the host root, `claude -p` asked to report whether the contract text (a unique phrase from `CLAUDE.workspace.md`) is in its context.
- **If that probe is denied or unavailable, do not retry and do not stop.** Record in `result.md` that the loading check is left to the operator's acceptance run in the real repo, and add a walkthrough item to `phase.md` `## Now`: `/context` shows `CLAUDE.local.md` plus the imported `workflow/CLAUDE.workspace.md`.
- If the probe runs and the import does **not** expand, take decision item 4's fallback (inline the rewritten contract in the `CLAUDE.local.md` block), re-run Test 15, and record it in `## Decisions`.

## Validation

- `bash tests/retrofit_smoke.sh`, as the only command in its own foreground Bash call. It must pass with zero failures (Tests 0–15).
- `python3 scripts/workflow.py validate` passes.
- `python3 installer/build.py`, then `--check`, passes. **Do not bump `WORKSPACE_VERSION`** (S3 does).

## Hand-off

- **`phase.md`:**
  - consume the S2 notes;
  - add a `## Decisions` entry pinning the rewrite token list, the contract-reference rule, the clash rule, the `installed` marker extension (or its alternative), the tracked-target refusal and the exclude block;
  - leave S3 notes: exact banner and CLAUDE.local.md texts to polish, and what `/update-workspace` and `/retrofit` must now call;
  - add `## Doc impact` lines (architecture: the nested installer; operations: the install and update commands; qa: Test 15);
  - rewrite `## Now`.
- **`result.md`:** verdict block first.
