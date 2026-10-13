# P35.S5 — plan: nested paired teardown, merge-finish and consolidation

## Context

S4 built the nested paired `parallel-start` (`../P35.S4/result.md`). Its execution block has `worktree` = the nested worktree `<host-wt>/workflow`, plus `host_worktree`, `host_branch`, `host_base`, `host_base_sha`, `host_branch_created` and `base_branch`. This slice builds the **end** of the lifecycle in nested: teardown, merge-finish and consolidated (`../../phase.md` Decisions 11 and 19, the `(from P35.DECOMP2, for P35.S5)` Note; S2's evidence in `../P35.S2/result.md` (d), (e)). **At-root teardown, merge-finish and consolidated stay byte-for-byte unchanged.** Re-check every line ref against the post-S4 tree first.

**From S4's notes (`../../phase.md`, `(from P35.S4)` under S5):**
- The git helpers already take `cwd=` (`_git_dir`, `_git_operation_in_progress`, `_ensure_worktrees_excluded`, `_worktree_entries`); use them on the host instead of writing new ones.
- `validate` checks `worktree == <host_worktree>/workflow` only while both are set, so nulling both at teardown is valid.
- `NESTED_PARALLEL_OFF` and `_refuse_parallel_when_nested` now remain only for the three commands this slice lifts: drop both.

## Changes (`scripts/workflow.py`; then `python3 installer/build.py`)

1. **Lift `_refuse_parallel_when_nested`** from `parallel_teardown`, `parallel_merge_finish` and `parallel_consolidated`. Then delete the helper and `NESTED_PARALLEL_OFF`, since S4 already made `parallel_skip` nested-aware. `grep` confirms no use remains.

2. **`parallel-teardown` in nested.** Keep today's precondition: the phase branch is merged into the nested HEAD (`merge-base --is-ancestor`, in ROOT). Then, in **this order**:

   1. **Every guard first, before anything is removed.** One combined report, one refusal, nothing touched.
      - **(a) Uncommitted work in the nested worktree:** `git -C <worktree> status --porcelain`, refused if non-empty. Git would refuse too, but say why in our own words.
      - **(b) Ignored, worktree-only files in both worktrees:**
        - `git -C <worktree> ls-files --others --ignored --exclude-standard --directory`;
        - `git -C <host_worktree> ls-files --others --ignored --exclude-standard --directory`, minus `CLAUDE.local.md` (the engine's copy) and `workflow/` (the nested worktree, handled in step 2).

        If anything remains, refuse, list the files, and name both ways out: move them, or rerun with `--discard-ignored`.

        **This must run before step 2.** S2 observed that `git worktree remove` on the nested worktree exits 0 and deletes its ignored files, e.g. an operator-excluded `temp/`. A guard placed after the removal would protect nothing.
      - **(c) Uncommitted work in the host worktree** (tracked changes or untracked files), refused.
      - **(d) Detached host commits:** the host worktree is detached with commits beyond `host_base_sha`, refused. They would be orphaned. S4 always checks out a branch, so this covers a worktree someone detached by hand.
   2. `git -C ROOT worktree remove <worktree>`: the nested half, **always first**. Removing the host worktree first exits 0 and silently deletes the nested worktree inside it, untracked `works/` included (S2 (e)).
   3. `git -C HOST worktree remove <host_worktree>`. With `--discard-ignored`, pass `--force` only for the ignored files the guard listed, and only after that guard.
   4. **The host branch rule:**
      - delete it with `git -C HOST branch -D <host_branch>` only when `host_branch_created` is true **and** `git -C HOST rev-list --count <host_base_sha>..<host_branch>` is 0 (`-D` because `-d` measures against HEAD);
      - otherwise keep it, and print that the host side follows the host's recorded custom (Decision 18): the branch is the operator's for the PR, and nothing was pushed, opened or merged.
   5. Delete the nested `phase/…` branch as at-root teardown does today. `git worktree prune` both repos if a registration is left. Set `execution.worktree` and `execution.host_worktree` to null, and keep `host_branch`, `host_base`, `host_base_sha`, `host_branch_created` and `base_branch` as history.

   Each step that fails after step 2 prints the exact remaining commands.

3. **`parallel-merge-finish` in nested:** it runs in ROOT (the nested repo), where the merge of `phase/…` into the nested default branch happened, and does what it does at root (`rebuild_docs`, `rebuild_index_and_state`, list the merged phases). It never touches the host repo.
4. **`parallel-consolidated` in nested:** the same state flip as at root, run on the default stream of the nested repo.
5. **`parallel-gate` (S4 lifted it):** no change, unless S4's result says otherwise. Confirm it reads the branch in ROOT.

## Doc impact (append to phase.md)

- `operations.md`: nested teardown checks first, then removes the nested half first; ignored worktree-only files are listed and refused unless `--discard-ignored`; the host branch is kept unless engine-created and empty; merge-finish and consolidated run in `git -C workflow` with no host merge (P35.S5)

## Verification (a scratch nested install, S2's recipe, in the session scratchpad; no `claude -p`; `rm -rf` is denied, so leave scratch)

Set up: build, install into a scratch host with an origin, `new-phase P2`, then `parallel-start P2 --host-branch feat/side`. In the worktree:
- commit a host file on `feat/side`;
- create an **ignored** `workflow/temp/note.txt` (add `temp/` to the nested repo's `info/exclude`);
- run the phase's state to `done` with a `pass` review by hand (`set-phase-status` or the engine's own commands);
- merge `phase/P2-…` into the nested default branch from the main checkout (`git -C workflow merge --no-ff`).

Then show:
1. `parallel-teardown P2` **refuses**, listing `temp/note.txt`, and nothing is removed (both `git worktree list`s unchanged; the file still there).
2. An untracked file in the nested worktree is refused, and so is a detached host worktree with a commit (each in its own setup).
3. `parallel-teardown P2 --discard-ignored` succeeds:
   - the nested worktree is removed first, then the host worktree;
   - `feat/side` is **kept** (it has a commit);
   - no `prunable` registration in either repo;
   - `execution.worktree` and `host_worktree` are null.
4. With a second phase P3, started with `--host-branch feat/empty` and with no host commits, teardown deletes `feat/empty`. With P4 **reusing** an existing branch with no new commits, teardown keeps it.
5. `parallel-merge-finish` and `parallel-consolidated P2` run in nested; the host repo is untouched (`git -C host log` unchanged).
6. At root, nothing changes: **`bash tests/retrofit_smoke.sh` as the only command in its Bash call**, with the same PASS count as after S4 (record both).
7. `python3 installer/build.py --check` and `python3 scripts/workflow.py validate` pass.

## Must not

Touch the hooks, the backlog, the skills, the installer or the READMEs (S6-S8); change at-root behavior; ever merge or push the host repo; bump the version; commit; or move workflow state.

## Dispatch

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
