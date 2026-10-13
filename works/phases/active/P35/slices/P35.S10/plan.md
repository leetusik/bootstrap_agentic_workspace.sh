# P35.S10 — plan: convert this repo to the nested layout

## Context

The operator asked to convert this upstream repo to the nested layout ("Yes, as described"; `../../intent.md` item 4). How was settled in Decisions 15, 16 and 20 (`../../phase.md`):
- **Sources:** the shipped sources move to **`payload/`**, with undotted inner names.
- **State:** the workspace state (`works/`, the workspace `docs/`, the live `executors.toml`) moves into a private, git-excluded `workflow/` repo, **with its history**. The built installer creates that repo.
- **Who does what:** this slice's executor does the working-tree part. **The orchestrator runs the switch inline with the operator present.** This is a one-time exception to "every slice is delegated", for two reasons:
  - after the host commit there is no root engine until the install exists;
  - executors never commit.
- **Commit subjects:** host subjects **drop phase IDs** from the conversion commit on.

S3 proved the whole procedure twice on scratch clones (`../P35.S3/result.md`, (a)-(g)). This plan follows S3's runbook, with the post-S9 tree as input. **The smoke baseline is 297 PASS / 0 FAIL** (S9). The plan is approved **at the gate**.

## By approving this plan you confirm

1. **This repo's recorded custom.** It is what `nested-convention --confirm --trailers allowed` records at step 6. Edit it now if any of it is wrong.
   > Conventional Commits in English: `type(scope): summary`, imperative, no trailing period. Types: feat, fix, docs, chore, refactor, test, ci, build, perf, revert. The scope names the component (engine, installer, skills, agents, payload, readme, release …), never a phase or slice ID. Releases: `build(release): workspace vNN — <summary>`. Co-Authored-By trailers are allowed. Branches: work on `main`. A parallel phase's host branch is named by the operator (e.g. `feat/<slug>`) and based on `main`. Integration: the owner merges locally into `main`, with no PR. Push only when asked.
2. **The backup directory.** `B=~/.agentic-backups/bootstrap_agentic_workspace.sh/2026-10-13/`, outside the repo and durable. It holds:
   - the `--all` bundle;
   - `settings.local.json`;
   - the live `executors.toml`;
   - two copies of the moved state: `stash/` for the overlay and `moved/`, which stays untouched.
3. **No push.** `origin/main` stays at `8ea3b7b` until you say so after the gate. The host's past history keeps `works/` and is never rewritten.
4. **One restart at the end.** You restart Claude Code at the repo root. S11 and the REVIEW then run in the new session, from `workflow/`.

## Steps

**0. Preconditions and backup** (orchestrator, no commit)
- S1-S9 are committed. The tree is clean except the regenerated `works/index.json` and `works/state.json` timestamps, which ride in the start commit.
- `git worktree list` shows only `main`, and no `phase/*` branch exists (both checked).
- Context is far below the 500k auto-compact window.
- `git tag pre-nested-conversion` (at `bbbc73b`).
- Create `$B` and its contents:
  - `git bundle create $B/pre-nested.bundle --all`;
  - `cp .claude/settings.local.json $B/`;
  - `cp executors.toml $B/stash/executors.toml`;
  - save `executor-route` (no args), `next` and the `git log --follow` count of `works/events.jsonl` to `$B/before.txt`.

**1. Start** (orchestrator, at-root engine)
- `start-slice P35.S10`, `executor-route P35.S10`, `executor-route --explore`.
- Pin `## Dispatch` (preview: high, opus @ high, Claude Opus 5.5).
- Commit `chore(P35): start the nested conversion`, the last host commit that carries a phase ID.

**2. Executor** (`slice-executor-high`, background): the working tree only, S3 (f) step 2.
- **Move with `git mv`, per S3 (a)'s layout:**
  - `CLAUDE.md` → `payload/contract.md`;
  - `scripts/workflow.py` → `payload/scripts/workflow.py`;
  - `executors.toml` → `payload/executors.toml`;
  - `.claude/{settings.json,agents,skills}` → `payload/claude/…`;
  - `works/templates` → `payload/works/templates`;
  - `.github/workflows/workspace-ci.yml` → `payload/github/workflows/`;
  - `.gitattributes` → `payload/gitattributes`.

  No dotted name and no `CLAUDE.md` may exist under `payload/`.
- **Regenerate S3's patches against the post-S9 tree.** They are `scratchpad/p35s3.OEAp/patches/1-relocate.diff` and `2-smoke-root-reads.diff`; redo them from S3 (a) if they don't apply.
  - `build.py`: `SRC`, `src_rel`, the skills glob, `contract.md`, and the docstring.
  - The `.githooks/pre-commit` regex: `^(installer/|payload/|bootstrap_agentic_workspace\.sh$)`.
  - Every smoke source read: `SRC=$REPO_ROOT/payload`, the Python heredoc reads, and **S9's Test 14 fixture**, which reads `scripts/workflow.py` and `works/templates` and copies `.claude/agents/*`.
- **New root files:**
  - A dev `CLAUDE.md` of about 2 KB, from S3 (b)'s points:
    - this repo ships the workspace;
    - edit `payload/` and `installer/`, then `python3 installer/build.py`, and commit the artifact in the same commit (the hook enforces it);
    - **`.claude/skills`, `.claude/agents`, `CLAUDE.local.md` and `workflow/` are installed, untracked copies; never edit them**;
    - the release rule;
    - drive the workspace with `python3 workflow/scripts/workflow.py`, with workflow commits via `git -C workflow`;
    - host commits follow the recorded custom, with no phase IDs;
    - refresh with `sh bootstrap_agentic_workspace.sh --update .`;
    - run the smoke suite alone.
  - `.github/workflows/upstream-ci.yml`: the seed's `build.py --check` and smoke steps, unguarded, with the same runner and checkout. Add a git identity only if a smoke commit relies on a global one.
- **Text:**
  - the `.gitignore` comment (`payload/executors.toml` is only the seed's source; the live config is `workflow/executors.toml`);
  - `installer/README.md` (≈4-38, ≈90 superseded, ≈95-122);
  - `README.en.md` ≈708-710.
- **Validate:**
  - `python3 installer/build.py` leaves `bootstrap_agentic_workspace.sh` **byte-identical**, and `--check` passes;
  - `bash tests/retrofit_smoke.sh` **alone** gives **297 PASS / 0 FAIL**;
  - in a scratch clone, the hook passes the relocation commit and refuses a staged `payload/` edit made without a rebuild.

  Any engine check runs **before** the `git mv`, since no root engine exists after it.
- **Write** `result.md` (verdict block first) and `phase.md`'s Doc impact lines:
  - architecture: this repo's layout, `payload/` and nested-driven;
  - operations: the upstream dev loop `payload/` → build → `--update .`, and the runbook as history.

  It commits nothing, runs no installer, and writes nothing outside the repo except scratch.

**3. Stash and host commit** (orchestrator, inline). Usage numbers kept for step 7.
- `mkdir -p $B/stash/docs $B/moved/docs`.
- `cp -R works $B/stash/` and `cp -R docs/{current,versions,index.json,README.md} $B/stash/docs/`.
- `git rm -r -q --cached works docs/current docs/versions docs/index.json docs/README.md`.
- `mv` those paths into `$B/moved/`, and `mv scripts/__pycache__ $B/moved/`.
- `rmdir` any emptied dir (`scripts/`). **Never `rm -rf`.**
- `git status` shows only the intended changes.
- Host commit: `refactor: convert to the nested layout (sources to payload/, workspace state to workflow/)` + `Co-Authored-By: Claude Opus 5.5`. The hook runs `--check`.
- From here until step 6 no engine exists. The tracked hooks are `|| true`-guarded.

**4. Extract the history** (S3 (c)), in a clone at `$B/hist` reset to `HEAD~1` (the start commit):
- remove the origin and the tags;
- run `filter-branch --prune-empty --index-filter`, keeping `works/`, `docs/{current/,versions/,index.json,README.md}` and `executors.toml`. The TAB is written as `$(printf '\t')` inside the filter;
- `update-ref -d refs/original/refs/heads/main`;
- record the extracted count. Expected: the at-root count minus the pure-product commits, with P33's merge kept.

**5. Install:** `sh bootstrap_agentic_workspace.sh .`
- The banner shows no `wf-` renames and "hidden by .git/info/exclude, verified".
- `CLAUDE.local.md` is written.
- `settings.local.json` is merged: the deny list, `autoCompactWindow` and the `workflow/` hooks.

**6. Overlay and attach** (S3 (c)'s rules)
1. Make the overlay exact:
   - move the fresh install's `works/{backlog.md,deferred,deferred.md,events.jsonl,index.json,phases,state.json}` and `docs/{current,versions,index.json}` to `$B/fresh/`, if present;
   - `cp -R` the stash's copies in;
   - keep the installer's `works/templates/`, `works/.workspace-version.json`, `docs/README.md`, `.gitattributes`, marker, contract and engine.
2. `workflow/executors.toml` is the live `$B/stash` copy with `s#python3 scripts/workflow\.py#python3 workflow/scripts/workflow.py#` only. Diff it against the fresh seed.
3. Stamp `host_anchors.created = 8ea3b7bfe8f3d6b94a27bf2d1e70877eb91dfe79` in P35's `phase.json`, the same shape as the engine's `_with_host_anchors` (after `acceptance`, `indent=2`, `ensure_ascii=False`, trailing newline).
4. `git -C workflow fetch -q $B/hist main && git -C workflow reset -q --soft FETCH_HEAD`.
5. `python3 workflow/scripts/workflow.py rebuild`, then `validate`.
6. `nested-convention --confirm --text "<item 1>" --trailers allowed`.
7. `git -C workflow add -A && git -C workflow commit -m "chore(P35): install the agentic workspace (nested) over the extracted history"` + trailer.

**7. Finish and stop** (nested engine)
- `record-dispatch P35.S10` (step 2's pinned lines and usage).
- `finish-slice P35.S10 --outcome "…"`.
- Append `## The switch (orchestrator, inline)` to `result.md`: the shas, counts and checks below.
- Rewrite `## Now`.
- `set-phase-status P35 pending`, then `validate`.
- One nested commit, `chore(P35): finish the nested conversion and wait for the restart` + `Co-Authored-By: Claude Opus 5.5`.

**8. Report and STOP.**
- To resume: restart Claude Code at the repo root. Say go: `python3 workflow/scripts/workflow.py set-phase-status P35 in_progress`, then `/do-whole-phase` runs S11 and the REVIEW.

## Rollback (ready before step 3; S3 (g), proven twice, `mv` only)

- **If step 2 fails** (`needs_operator`, `blocked`, or an empty return):
  - `git reset --hard HEAD` (the start commit);
  - `mv` any untracked leftovers listed by `git status` into `$B/`;
  - set the slice `pending` and report.
- **From step 3 on:**
  1. `mv workflow $B/workflow.rolled-back`.
  2. `mv` the host install files (`CLAUDE.local.md`, the `/.claude/skills/<n>/` and `/.claude/agents/<f>` paths listed in the exclude block) into `$B/`.
  3. Restore `settings.local.json` from `$B`, and strip the managed exclude block.
  4. `git reset --hard pre-nested-conversion`. This is safe because nothing is pushed.
  5. Copy back any post-switch state, `rebuild`, and commit `chore(P35): roll back the nested conversion`.

## Verification

- **Step 2:**
  - the artifact is byte-identical, and `--check` passes;
  - smoke alone gives 297/0;
  - the hook refuses a stale `payload/` edit.
- **After step 6:**
  - **The host:** `git status` is clean, and the host tracks no `works/`, `scripts/`, `executors.toml`, `.gitattributes` or `.claude/`.
  - **The nested engine:**
    - `next` shows P35 at S10;
    - `validate` passes;
    - `docs` lists 11 docs;
    - `phase-scope P35` ranges from `8ea3b7b`, with the ≈976 state deletions as one class.
  - **History:** nested `rev-list --count` ≥ the extracted count + 1, and the `git log --follow works/events.jsonl` count in `workflow/` is ≥ the count saved in `before.txt`.
  - **Product history:** `git log --follow payload/claude/skills/commit/SKILL.md` crosses the move. The contract's pre-move history stays under `git log -- CLAUDE.md`, because that path is reused by the dev file.
  - **Routing:** `executor-route` (no args) matches `$B/before.txt` and reports the agent files in sync (otherwise `sync-agents`).
  - **Streams:** `backlog.md`'s Streams shows P35.

## Dispatch

```
route=high
reason=risk high (not low)
tier=high
subagent_type=slice-executor-high
model=opus
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Opus 5.5
explore_model=haiku
explore_effort=high
```
