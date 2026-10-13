# P35.S5 — result: nested paired teardown, merge-finish and consolidation

- status: done
- tier: high
- model: opus
- effort: high
- summary: Nested `parallel-teardown` now retires the worktree pair. It runs every guard first, in one combined report that touches nothing: uncommitted nested and host work, ignored worktree-only files in both worktrees (refused unless `--discard-ignored`), and detached host commits no ref holds. Then it removes the nested worktree first, then the host worktree, keeps the host branch unless the engine created it and it is empty, and nulls `worktree` and `host_worktree`. `parallel-merge-finish` and `parallel-consolidated` run in nested without touching the host. The nested refusal helper and its constant are gone. Scratch-proven; smoke is 292/292, unchanged.
- files_changed: scripts/workflow.py, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P35/slices/P35.S5/result.md, works/phases/active/P35/phase.md
- validation: `python3 installer/build.py` + `--check` PASS; `python3 scripts/workflow.py validate` PASS; `bash tests/retrofit_smoke.sh` alone: 292 PASS / 0 FAIL (S4 left it at 292 / 0); scratch nested-install checks 1-5 all observed as planned, plus a resume and a stale-registration case (below)
- deviations: (1) No `--force` on either `worktree remove`, `--discard-ignored` included. git 2.45.2 deletes ignored files without `--force` (observed), so with no `--force`, git's own refusal of untracked or modified files stays as a second check. (2) The detached-host guard counts commits beyond `host_base_sha` **that no branch, tag or remote ref holds** (`rev-list HEAD --not <base> --branches --tags --remotes`). That is exactly the "would be orphaned" case: a worktree detached at a branch tip is not refused. (3) `--discard-ignored` is refused at root, writing nothing. At-root teardown without it is unchanged. (4) Two things the plan did not cover. A worktree already gone from disk but still registered is pruned **before** the branch steps, because a stale registration still holds its branch (found in scratch: `branch -D` failed). And a re-run resumes, since every step skips what is gone. (5) A host branch checked out in another host worktree is kept, and the reason is printed. (6) The ignored list drops a directory line when git also lists entries inside it, so each path is named once.
- doc_impact: one note appended to `phase.md` `## Doc impact` (operations)

## What changed (`scripts/workflow.py`)

- **Removed:** `NESTED_PARALLEL_OFF`, `_refuse_parallel_when_nested`, and its three calls (teardown, merge-finish, consolidated). `grep` finds neither name in `scripts/workflow.py` or the rebuilt artifact. No test or installer text referenced the old message.
- **`parallel_teardown`:** `--discard-ignored` at root is refused first. The shared preconditions are unchanged: an execution block with a branch; not on the phase branch; the branch merged into HEAD (`merge-base --is-ancestor`, in ROOT). Then a nested install branches to `_parallel_teardown_nested`. The at-root body below is byte-for-byte as before.
- **`_ignored_worktree_files(path, skip)`:** `ls-files -z --others --ignored --exclude-standard --directory`, minus `skip`, with a parent directory line dropped when its children are also listed.
- **`_parallel_teardown_nested`:**
  1. Guards, collected into one numbered refusal, with nothing touched. Each check runs only for a worktree still on disk.
     - (a) `status --porcelain --untracked-files=normal` in the nested worktree.
     - (b) the ignored list for both worktrees, the host's minus `CLAUDE.local.md` and `<relpath(ROOT, HOST_ROOT)>/`. It is refused with the full paths and both ways out, unless `--discard-ignored` is given.
     - (c) host status.
     - (d) a detached host HEAD with orphan commits (deviation 2).
  2. The host branch's fate is decided before any removal. It is deleted only when `host_branch_created`, `rev-list --count <host_base_sha>..<host_branch>` is 0, and no other host worktree has it checked out. Otherwise it is kept, with the reason and the "host's own custom, nothing pushed/opened/merged" line.
  3. The steps, in order: the nested `worktree remove` (or `worktree prune` in the nested repo if it is gone but registered); the host `worktree remove` (or prune); `branch -D <host_branch>` when step 2 chose deletion; nested `branch -d phase/…`. A failure prints git's message, what was already removed, `re-run … (it resumes)`, and the exact remaining commands, plus the phase.json nulling.
  4. A registration a successful remove still left is pruned. `execution.worktree` and `execution.host_worktree` are set to null, and the other host keys and `base_branch` are kept. The event `phase_parallel_torndown` now also carries `host_branch`, and the call is followed by a rebuild.
- **`parallel_merge_finish`, `parallel_consolidated`:** the refusal is lifted. The docstrings now say they run in the nested repo and never touch the host. No logic changed: every `_git` call there defaults to ROOT, the nested repo.
- **`parallel_gate`:** unchanged. Confirmed that `_json_at_ref`, `_phases_at_ref` and `_default_branch` all call `_git` with the default cwd (ROOT).
- **Argparse:** `parallel-teardown --discard-ignored`.

## Verification

Scratch: `scratchpad/p35s5.3TIW` (path also in `scratchpad/P35S5_SCRATCH`). It holds `seed/`, `origin.git`, and `host/`, a clone with `origin/HEAD → origin/main`, installed nested by the rebuilt `bootstrap_agentic_workspace.sh`. The scratch engine was later refreshed with two commits in the scratch nested repo, `engine: S5 dedupe` and `engine: S5 prune first`. The nested repo has phases P1-P6, and `temp/` is in its `info/exclude`. `$S` below is the scratch path.

Setup: `parallel-start P2 --host-branch feat/side` was cut from `origin/main` (`6723b4b`). In the host worktree I committed `src/side.txt` on `feat/side` and created the ignored `workflow/temp/note.txt`. I then hand-edited P2's `phase.json` to `done` with review `pass`, committed it in the nested worktree, ran `git -C workflow merge --no-ff phase/P2-phase_2` from the main checkout, and ran `parallel-merge-finish` (rc 0), then committed the cleanup.

1. **Ignored file refused:** `parallel-teardown P2` exited 1 with `refused -- nothing was removed: 1. ignored, worktree-only files … $S/host/.claude/worktrees/P2-phase_2/workflow/temp/ … re-run with --discard-ignored`. Both `git worktree list` outputs were unchanged (diffed against snapshots), and `temp/note.txt` was still there. `--directory` names the directory `temp/`, not the file inside it.
2. **The combined refusal:** I added an untracked `workflow/untracked.txt` in the nested worktree, an untracked `host-untracked.txt` in the host worktree, and an ignored `.claude/settings.local.json` in the host worktree. One report listed all three: the nested `?? untracked.txt`, the host `?? host-untracked.txt`, and the ignored `temp/` plus `.claude/settings.local.json`. Before the dedupe fix it also listed `.claude/`. Nothing was removed. With `--discard-ignored`, the two untracked items were still refused and the ignored item was dropped from the report.
   - **Detached host, in its own setup:** `parallel-start P3 --host-branch feat/empty`, then `git -C <host-wt> switch --detach` and a commit `src/det.txt`, then the merge. The teardown was refused: `1. the host worktree … is detached at bbfba31 with 1 commit(s) beyond the base that no branch, tag or remote ref holds; … put them on a branch first`. Both worktree lists were intact.
3. **`parallel-teardown P2 --discard-ignored`:** rc 0. The output order was `removed nested worktree …/P2-phase_2/workflow`, then `removed host worktree …/P2-phase_2`, then `removed branch phase/P2-phase_2`, then `deleted 2 ignored, worktree-only path(s)`, then `kept host branch feat/side: it has 1 commit(s) beyond its base origin/main (6723b4b6e688)` plus the host-custom line. `git worktree list --porcelain` had no `prunable` line in either repo, and each listed only its main checkout. In the execution block, `worktree` and `host_worktree` were null, and `host_branch`, `host_base`, `host_base_sha`, `host_branch_created` and `base_branch` were kept.
4. **The host branch rule:**
   - P3: after `switch feat/empty` (0 commits beyond the base), teardown printed `removed host branch feat/empty (created by parallel-start, no commits beyond its base)`.
   - P4: `git branch feat/reuse origin/main`, then `parallel-start P4 --host-branch feat/reuse` (it printed `reused`). Teardown printed `kept host branch feat/reuse: it existed before parallel-start, which reused it`.
   - Both repos had 0 `prunable` lines after each run.
5. **Merge-finish and consolidated in nested:** `parallel-merge-finish` (rc 0) regenerated the files and listed P2. `parallel-consolidated P2` (rc 0) printed `consolidation=done … archivable`. Host `for-each-ref` and `log --all --oneline` were identical to their snapshots from before the first teardown, and host `git status` was clean.
6. **Extra cases:**
   - **Resume:** P5 with the host worktree `git worktree lock`ed. Teardown removed the nested worktree, then failed on the host remove. It printed git's message, `removed nested worktree …`, `re-run … (it resumes)`, and the three remaining commands (host `worktree remove`, `branch -D feat/five`, nested `branch -d phase/P5-phase_5`) plus the nulling. After `unlock`, the re-run finished: `removed host worktree`, `removed host branch feat/five`, `removed branch phase/P5-phase_5`.
   - **Stale registration:** P6, with the whole host worktree `mv`ed away, left one `prunable` line in each repo. The first run hit `branch -D feat/six` → `cannot delete branch 'feat/six' used by worktree` (the bug behind deviation 4). After the fix, the re-run printed both `removed the stale registration … (git worktree prune in …)` lines, removed `feat/six` and `phase/P6-phase_6`, and left 0 `prunable` lines.
   - A re-run on the torn-down P2 printed `nothing to remove` and kept `feat/side`.
   - At root, `parallel-teardown P35 --discard-ignored` exited 1 before reading the phase.
7. **At root:** `bash tests/retrofit_smoke.sh`, alone in its call: 292 PASS / 0 FAIL, the same as S4's after-count (`scratchpad/p35s4-smoke-after.log`). Its Test 14 (h) covers the at-root teardown of a clean worktree. Log: `scratchpad/p35s5-smoke-after.log`.
8. `build.py --check` OK. `validate` passed.

In scratch, the nested `validate` reports P2's slices as unfinished, because I flipped the state by hand to reach `done`/`pass`. That comes from the test shortcut, not from the engine.

The scratch dirs stay on disk, because `rm -rf` is denied: `scratchpad/p35s5.3TIW` (including `moved-P6/`) and `scratchpad/P35S5_SCRATCH`.

## Notebook

Decision 23, the Doc impact line, the Notes for S8 and S9, and `## Now` are in `../../phase.md`. The consumed `(from P35.DECOMP2, for P35.S5)` note is removed.
