# Result — P28.S2 Installer `--nested`: zero-footprint install, rewrite, clash map, update

- `status`: done
- `tier`: high
- `summary`: `sh bootstrap_agentic_workspace.sh <host-root> --nested` now installs the workspace privately. The engine and state go to a nested git repo `workflow/` (contract `CLAUDE.workspace.md`). Rewritten skills and agents go to the host's `.claude/` as untracked files (a clashing name installs as `wf-<name>`). The installer writes `settings.local.json`, a `CLAUDE.local.md` that imports the contract, and one `info/exclude` block. The host's `git status`, HEAD and config stay untouched, and `--update --nested` refreshes it the same way. The marker is renamed `.agentic-nested.json` and gains a strict `installed` record. Smoke Test 15 pins the behaviour, an old/new differential shows at-root installs unchanged, and a live `claude -p` probe confirmed the import expands.
- `files_changed`:
  - `installer/main.py`
  - `installer/wrapper.sh`
  - `scripts/workflow.py`
  - `tests/retrofit_smoke.sh`
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `works/phases/active/P28/phase.md`
  - `works/phases/active/P28/slices/P28.S2/result.md`
- `validation`:
  - `bash tests/retrofit_smoke.sh` (alone, foreground): PASS, 223 checks, `ALL RETROFIT SMOKE TESTS PASSED`. That is Tests 0–14 unchanged apart from Test 14's marker rename, plus the 12 checks of the new Test 15.
  - `python3 scripts/workflow.py validate`: PASS. The only warnings are the existing P26/P27 debt, stale-doc and oversized-section ones.
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: PASS. `WORKSPACE_VERSION` stays 48.
  - At-root differential (scratch, not shipped): the committed HEAD artifact against the new one, on a fresh install, `--into-existing` (plus its rerun), `--update --dry-run`, `--update`, `--update` on a bare dir, and `--help`. With timestamps and paths normalised, every installed file tree and every output is identical, with two expected exceptions:
    - the update change-list now names `scripts/workflow.py` as updated, because the engine itself changed;
    - `--help` gains the `--nested` lines.
  - Live run (§8), scratch host in the session scratchpad: install `--nested`, then one `claude -p` probe from the host root. It ran: Claude Code listed `CLAUDE.md`, `CLAUDE.local.md` and the imported `workflow/CLAUDE.workspace.md` as loaded, and quoted the rewritten Read Order item 1 (`python3 workflow/scripts/workflow.py next`). The import expands, so no fallback was needed.
- `deviations`: all within the plan's intent; none removes anything it asked for.
  1. **`SLICES_GUIDANCE` follows `WORKFLOW_CMD`** (`scripts/workflow.py`). The plan rewrites the templates. Without this change, the engine's regenerated `## Slices` guidance line would print an unprefixed `python3 scripts/workflow.py rebuild` into every nested `phase.md`. At root, `WORKFLOW_CMD` is that same literal, so output there is byte-identical (Test 9 and the template==fallback check pass).
  2. **Clash detection also reads the host's `.claude/commands/**/*.md`.** A skill of the same name would shadow the team's command for the operator.
  3. **Convention inference uses `git log --no-merges`**, so GitHub merge subjects do not dilute the ratio. With no commits but a CONTRIBUTING commit line, it records `"no commits yet; CONTRIBUTING mentions: …"` instead of `null`; with neither, it stays `null`. The inferred text is one line: classification, an example subject, CONTRIBUTING lines and the Co-Authored-By count.
  4. **Extra refusals, all with nothing written:**
     - a TARGET that is a subdirectory of the host work tree, not its root, because `info/exclude` entries are root-anchored;
     - a missing TARGET;
     - a stray or unterminated managed-block marker in `CLAUDE.local.md` or `info/exclude`.
  5. **The nested stale check** (`flag_stale_skills` when nested) reports only our own previously `installed` names that this version no longer ships. The plan said to look in the host's `.claude/skills` and never flag our names. A `disable-model-invocation` heuristic there could mislabel the team's own skills, so it is not used.
  6. **`git init` in `workflow/` happens on a fresh install only.** On `--update`, a missing `workflow/.git` is the operator's choice.
  7. **Small extras:**
     - an at-root `--update` on a nested host adds one line pointing to `--update --nested`; it prints only when the nested marker exists, so at-root output is unchanged;
     - a replaced pre-existing host file (`CLAUDE.local.md`, `settings.local.json`, `info/exclude`) keeps its file mode;
     - `--nested --force-empty-ok` is refused in the wrapper, as the plan asked.
  8. **The live probe's first attempt never reached `claude`.** It was wrapped in `timeout`, which macOS lacks (`command not found: timeout`). The single real probe ran right after without the wrapper.
- `doc_impact`: three lines appended to `phase.md` `## Doc impact`:
  - architecture.md: the nested installer's two roots, the host-side files, what it never writes, and the marker rename plus `installed`;
  - operations.md: the `--nested` / `--update --nested` runbook and its refusals;
  - qa.md: smoke Test 15.

## What landed, by plan section

0. **Marker rename.**
   - `NESTED_MARKER = ".agentic-nested.json"`. Every comment and docstring that named `nested.json` is updated, and the "not a JSON object" problem now uses the constant.
   - Test 14 changed its fixture path, its two grep strings (now `grep -F`), the title and the header comment.
   - In `phase.md` `## Decisions`, the Engine contract line, design item 1, item 6 and invariant (a) were updated in place.
1. **Flag** (`installer/wrapper.sh`):
   - usage lines and `nested=0`, the `--nested) nested=1` arm and `export NESTED`;
   - `--nested` is refused with `--into-existing` and with `--force-empty-ok`;
   - `--dry-run` still needs `--update`, so `--nested --update --dry-run` works.
2. **Two roots** (`installer/main.py`):
   - With `NESTED`, `HOST = TARGET.resolve()` and `ROOT = HOST/workflow`.
   - `MANAGED_DIRS` and `MANAGED_FILES` drop `.claude*` and `CLAUDE.md`.
   - `nested_preflight()` runs before any write. It checks for git on PATH, that HOST is the root of a git work tree, and that the host does not track `workflow`. It also checks `workflow/`:
     - an update needs the marker and the engine;
     - a fresh install over an existing marker prints "already installed -- use --update --nested" and exits 0;
     - otherwise `workflow/` must be absent or empty, `.git` allowed.
   - The contract is written as `workflow/CLAUDE.workspace.md` (`_is_machinery` treats it as machinery on update).
   - Never reached when nested: `emit_policy_files()`, the skill and agent loops, and the `.claude/settings.json` write; nothing calls `_merge_settings_json` or `_merge_contract`.
   - `git init -q` runs on a fresh install. `run_workflow` runs from the host root.
3. **Rewrite and host writes:**
   - `nested_rewrite(text, renames)`: the token list, the contract-reference rule and the rename forms are pinned in `phase.md` `## Decisions` → Nested installer.
   - `nested_plan()` renders everything in memory, then post-checks it:
     - no `python3 scripts/workflow.py` (a literal match) and no bare `scripts/workflow.py`;
     - no unprefixed workspace path;
     - no renamed skill left as `/X` outside a `workflow.py` span, and no renamed agent left as `subagent_type: X`.
   - It refuses on a tracked target. Only after all of that does `nested_apply()` write.
   - `settings.local.json` is an additive union with the operator's file: their keys are kept, and an unparseable file is refused.
   - `CLAUDE.local.md` and the exclude file each get one managed block.
4. **Clash map and marker:** `_host_taken()` and `wf-` renames; a double clash refuses, and a personal skill shadow warns. The marker carries `installed`, and the checker (`nested_marker_problems`) now knows it (`NESTED_OPTIONAL_KEYS`): it is strict, it requires renames ⊆ installed, and `validate`'s unknown-key warning skips it. `--update` merges as described in `## Decisions`. After the install, validate runs from the host.
5. **Convention inference:** `nested_infer_convention()` reads 50 recent non-merge subjects and the `CONTRIBUTING*` / `.github/CONTRIBUTING*` lines that mention commit. Conventional means ≥ 60% of subjects match `^\w+(\([^)]*\))?!?: `, ticket-prefixed ≥ 60% match `^\[?[A-Z][A-Z0-9]+-\d+`, and anything else is free-form.
6. **Update path and banners:**
   - On the engine side, the existing update policy runs under `workflow/`, with no policy files.
   - On the host side, everything is re-rendered from source with the merged map.
   - `--dry-run` writes nothing anywhere; a snapshot of host and `workflow/` before and after confirmed it.
   - The change-list prints `workflow/`-prefixed engine paths plus a host-side section.
   - The fresh and update banners cover: start at the host root, the first `git -C workflow` commit, the convention confirmation, and the remote staying inside the company's org.
7. **Test 15:** 12 checks, all listed in the plan; one line each in the file's style.
8. **Live run:** see `validation`.

## Verified by hand in scratch hosts (not shipped)

Fixture hosts like Test 15's (`scratchpad/mkhost.sh`) and an edge script (`scratchpad/edge.sh`) covered these cases:

- A tracked `CLAUDE.local.md` is refused, the host snapshot is identical, and no `workflow/` is created.
- `--nested` with `--into-existing`, with `--force-empty-ok`, or with `--dry-run` but no `--update` is refused.
- Refused hosts: not a git repo, a subdirectory of one, a missing dir (not created), a tracked `workflow/`, a non-empty `workflow/`.
- A double clash (`commit` plus another skill named `wf-commit`) is refused with nothing written.
- **Empty host (no commits):**
  - the inferred convention is `null` and `host_anchors.created` is `null`;
  - a `.claude/commands/do-next-slice.md` command renames `do-next-slice` to `wf-do-next-slice`;
  - an agent `drafter.md` whose `name:` is `design-drafter` renames ours to `wf-design-drafter`, and `subagent_type:` follows;
  - `validate` and `sync-agents --check` resolve the renamed agent;
  - the operator's own `CLAUDE.local.md` text and its 0644 mode are kept, and their `settings.local.json` `env` key is kept with ours unioned in;
  - after `--update --nested` there is still one block in each file.
- An unparseable `settings.local.json` is refused with nothing written.
- An at-root `--update` on a nested host prints the `--update --nested` hint.
- **On `--update`:**
  - our `installed` copy that is no longer shipped is reported stale, stays excluded, and the host stays clean;
  - a name that is newly shipped and clashes with a host skill added since (a tracked `name: create-phase`) is renamed `wf-create-phase`, and every installed text is re-rendered with `/wf-create-phase`.
- `HOME=<fake>` with `~/.claude/skills/explain` prints the shadow warning.
- The strict `installed` checker reports:
  - a renamed name missing from `installed`;
  - a non-list kind;
  - extra keys.
- A full-rename prototype (every skill and agent renamed) leaves no slash form and nothing inside a protected `workflow.py` span, and the rewrite is idempotent on all 25 texts.

## Observations

- With the workspace not yet trusted, Claude Code ignored the host's `.claude/settings.json` allow entry. It printed "Ignoring 1 permissions.allow entry … not trusted", and the first interactive run in a real repo accepts the trust dialog. Its warning named only the host's `settings.json`.
- Not rewritten by design (noted for S3 in `phase.md`):
  - the comments in `workflow/executors.toml` and the text of `workflow/docs/README.md` and the doc seeds;
  - the engine's own messages that name a skill (only relevant when that skill was renamed).

The notebook carries the decisions (`## Decisions` → Nested installer), the S3/REVIEW notes and `## Now`: `works/phases/active/P28/phase.md`.
