# P35.S4 — result: nested paired parallel-start, stream claim and host wiring

- status: done
- tier: high
- model: opus
- effort: high
- summary: Nested `parallel-start <P> --host-branch <name> [--host-base <ref>]` now cuts the worktree pair: guards first, the host's `/.claude/worktrees/` exclude, the execution block with six nested keys plus `host_anchors.created` re-stamped to the host base (or the merge-base for a reused branch), the nested stamp commit, the host worktree, the nested worktree at `<host-wt>/workflow`, and a byte-copied `CLAUDE.local.md`. `current_stream`, `parallel-status`, `parallel-gate` and the start hints run in nested, and `CLAUDE_AGENTS` resolves to the main host checkout. Proven on a scratch nested install; at root the smoke suite is 292/292 before and after.
- files_changed: scripts/workflow.py, tests/retrofit_smoke.sh, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P35/slices/P35.S4/result.md, works/phases/active/P35/phase.md
- validation: `python3 installer/build.py` + `--check` PASS; `python3 scripts/workflow.py validate` PASS; `bash tests/retrofit_smoke.sh` alone: 292 PASS / 0 FAIL (it was 292 / 0 before the slice); scratch nested-install checks 1-6 all observed as planned (below)
- deviations: (1) `parallel-skip` lost its nested refusal too: it is a no-op reporter, and its "parallel worktrees are disabled" line would now be false; its hint carries `--host-branch <name>`. (2) `validate` treats `base_branch` apart from the five `host_*` keys: those five must appear together and only in nested, while `base_branch` comes with them in nested but is only type-checked at root, so S7's optional root stamp needs no validate change. (3) In nested, `--worktree` overrides the **host** worktree's path, and the nested half goes at `<that>/workflow`. The plan was silent on this. (4) The host exclude line is written anchored (`/.claude/worktrees/`, as the installer's block does), and either form counts as present. At root the unanchored line and the check are unchanged. (5) `CLAUDE_AGENTS` uses the common dir's parent only when that dir is named `.git`. A submodule host or a separate GIT_DIR falls back to HOST_ROOT. (6) `_git_operation_in_progress` checks cherry-pick and bisect only when given a `cwd` (the host), so the root check is unchanged.
- doc_impact: two notes appended to `phase.md` `## Doc impact` (architecture, operations)

## What changed (`scripts/workflow.py`)

- **Constants:** `NESTED_HOST_BRANCH_REQUIRED` (the refusal text) and `NESTED_HOST_BRANCH_ARG` (`" --host-branch <name>"` in nested, `""` at root, appended to every printed `parallel-start` hint). `NESTED_PARALLEL_OFF` stays: teardown, merge-finish and consolidated still refuse with it until S5.
- **`CLAUDE_AGENTS`:** `_main_host_checkout_agents(HOST_ROOT)` in nested. It returns the parent of `git rev-parse --path-format=absolute --git-common-dir` plus `/.claude/agents`, and falls back to HOST_ROOT. At root it is the same expression as before.
- **`current_stream`:** the nested early return is gone. The key is the nested repo's branch.
- **`new_phase` hint, `parallel_start_hint`, `parallel_skip`, `parallel_status`, `parallel_gate`:** nested allowed. `parallel-status` adds `host_branch=` (created/reused), `host_base=<ref> (<sha>)` and `host_worktree=` per phase in nested.
- **Git helpers:** `_git_dir(common, cwd=None)`, `_git_operation_in_progress(cwd=None)` and `_ensure_worktrees_excluded(cwd=None)`. Every call without `cwd` behaves exactly as before.
- **New helpers:**
  - `_worktree_entries(cwd)` parses `worktree list --porcelain`;
  - `_resolve_host_base(host, explicit)` follows Decision 19's order and never fetches;
  - `_parallel_start_nested(...)` does the pair;
  - `_nested_execution_problems(pid, execution)` holds validate's checks.
- **`parallel_start`:** a missing `--host-branch` in nested is refused first, before the phase is read. At root, `--host-branch` and `--host-base` are refused. After the shared guards, a nested start branches to `_parallel_start_nested`.
- **Argparse:** `--host-branch` and `--host-base` on `parallel-start`.
- **`validate`:** extends the parallel branch with `_nested_execution_problems`. It checks the types, all-or-none plus nested-only for the five host keys, `base_branch` with them in nested, and `worktree == <host_worktree>/<relpath(ROOT, HOST_ROOT)>` while both are set. A legacy block, or a torn-down one (both null), passes.
- **Smoke Test 14:** the one assertion now expects `parallel-start in a nested install needs --host-branch <name>…`, a non-zero exit and no `"execution"` in P1's `phase.json`.

## Verification

Scratch: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/1f05045c-d99c-4193-ad79-5557ad4128a8/scratchpad/p35s4.hBGB`. It holds:
- `seed/`, `origin.git` (bare), and `host/`, a clone with `origin/HEAD → origin/main`, installed by `sh bootstrap_agentic_workspace.sh host`, which went nested;
- the phases P1 (default stream, `P1.DECOMP` started), P2, P3 and P4;
- `r_trunk`, `r_master`, `r_dev` and `r_both`, for the base-order check.

Before the start, host `main` pushed one commit (`origin/main = b37d4c6`) and made one local commit (`HEAD = 29c12fe`), so the anchor shows which one was picked. Results by plan item:

1. **No `--host-branch`:** refused with the new message, rc=1. Nested and host `git status` both clean.
2. **`parallel-start P2 --host-branch feat/side`:** rc=0.
   - Host `worktree list`: `.claude/worktrees/P2-side_feature b37d4c6 [feat/side]`. Nested `worktree list`: `…/P2-side_feature/workflow cfe6858 [phase/P2-side_feature]`.
   - Host and nested status are clean. The host exclude has `/.claude/worktrees/`. `cmp` shows `CLAUDE.local.md` identical.
   - `<host-wt>/.claude` does not exist.
   - `host_anchors.created = b37d4c6…`: the `origin/main` sha, not the local HEAD.
   - The execution block holds all the keys, with `worktree = <host-wt>/workflow`, `host_base = origin/main`, `host_branch_created = true` and `base_branch = master`.
3. **The worktree and the main checkout:**
   - In `<host-wt>`, `next` printed `stream=phase/P2-side_feature (parallel phase checkout…)` and `current_phase=P2`.
   - `validate` there passed with no missing-agent warning. `CLAUDE_AGENTS` imported there is `<host>/.claude/agents` (exists).
   - The main checkout's `next` printed `parallel_phases_elsewhere=P2:phase/P2-side_feature` and `current_phase=P1`.
4. **Status and gate:** `parallel-status` printed the P2 section with the `host_branch`, `host_base` and `host_worktree` lines. `parallel-gate P2` ran from the main checkout (`main_state_source=working tree`) and from the worktree (`main_state_source=master (local default branch…)`). Both said GATE CLOSED, for the right reasons.
5. **Reuse and refusals:**
   - `--host-branch feat/side` (checked out in P2's worktree) and `--host-branch main` were refused. So were `--host-base origin/nope` and `--host-branch bad..name`. Each run wrote nothing: nested HEAD, nested dirt, host branches and `.claude/worktrees/` were all unchanged, and P3 had no execution block.
   - `parallel-start P3 --host-branch feat/free` reused a free branch (cut from `11f5f89`, plus one commit): `host_branch_created=false`, `created = 11f5f89` = `git merge-base origin/main feat/free`, and the host worktree is at the branch tip `09fcb53`.
   - Base order, via `_resolve_host_base`: `host` → `origin/main`; `r_trunk` (local `init.defaultBranch=trunk`) → `trunk`; `r_master` → `master`; `r_both` → `main`; `r_dev` → refused with "pass --host-base <ref>"; explicit `HEAD` → `HEAD`.
   - The failure path: P4 on `feat/clash`, whose tree tracks a file named `workflow`, made the nested `worktree add` fail after the stamp commit. The engine printed the remaining nested `worktree add` and `cp` commands, plus the give-up route, and exited 1. (The give-up wording was improved after this run, to say how to un-stamp.)
   - At root, `parallel-start P99 --host-branch x` and `--host-base main` were refused, writing nothing.
6. **phase-scope:** after the start, host `main` advanced (`src/m.txt`) and the worktree committed `src/t.txt`. `phase-scope P2` from the worktree showed `range=b37d4c6..26f7e8e commits=1` and `A src/t.txt` only. P3, the reused branch, showed `range=11f5f89..09fcb53` and `A src/f.txt`.
7. **At root:** `bash tests/retrofit_smoke.sh` alone gave 292 PASS / 0 FAIL before the slice and 292 PASS / 0 FAIL after. Logs: `scratchpad/p35s4-smoke-before.log`, `scratchpad/p35s4-smoke-after.log`.
8. `build.py --check` OK. `validate` passed.

`validate`'s new checks were also run directly: a sound nested block gives `[]`. A block missing `host_base`, with `host_branch_created="yes"` and a wrong `worktree`, gives three errors. A legacy block and a torn-down block give `[]`. At root, a host key gives an error, and `base_branch` alone passes.

The scratch directory stays on disk, because `rm -rf` is denied. Delete `scratchpad/p35s4.hBGB` and `scratchpad/P35S4_SCRATCH` when convenient.

## Observations (not changed)

- `phase-scope` still labels the base "the host HEAD when the phase was created". After a nested `parallel-start` re-stamps it, it is the host worktree's base (or the merge-base). The value is right; only the wording is stale (Note for S8).
- `consolidation_owed` and `validate` warn about P2 the moment it is stamped, because `execution.consolidation` is `pending`. This is today's at-root behavior too, so it is the same in-flight question S7 handles for `next` (Note for S7).
