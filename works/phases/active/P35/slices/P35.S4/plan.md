# P35.S4 — plan: nested paired parallel-start, stream claim and host wiring

## Context

P35 makes parallel worktrees work in a nested personal install (`../../intent.md`; `../../phase.md` Decisions 2, 3, 10-14, 17-19 and the `(from P35.DECOMP2, for P35.S4)` Note). S2 proved the design on a scratch install (`../P35.S2/result.md` (a), (b), (d), (f)). This slice builds the **start** half in the engine. Teardown, merge-finish and consolidation are S5's; the hooks S6's; the Streams view S7's; the skill/installer text S8's; the smoke tests S9's.

**At-root behavior stays byte-for-byte unchanged.** Every new path is gated on `NESTED is not None`, the same way the existing nested branches are (`scripts/workflow.py` ≈19-26, 151-181).

## Changes (all in `scripts/workflow.py`; then `python3 installer/build.py`)

1. **Lift the nested refusal** where this slice needs it.
   - `parallel_start` (≈2544), `parallel_gate` (≈2697) and `parallel_status`'s early return (≈2992): these now run in nested.
   - `current_stream`'s nested early return (≈1479): the stream key in nested is the **nested repo's** branch, read by `git_current_branch()` (cwd ROOT, unchanged).
   - `parallel_start_hint` (≈3083) and `new_phase`'s hint (≈2081): allowed in nested; the printed command carries `--host-branch <name>`.
   - Keep `_refuse_parallel_when_nested` on `parallel_teardown`, `parallel_merge_finish` and `parallel_consolidated` (S5 lifts those). Keep `NESTED_PARALLEL_OFF` only if something still uses it.
2. **`parallel-start` flags** (parser ≈5073):
   - `--host-branch <name>`: **required in nested**. The refusal names the reason: the host's branch for this phase's product commits, named by the host's convention, with no workspace IDs. Refused at root (meaningless there).
   - `--host-base <ref>`: optional, nested only.
3. **Host base resolution** (nested, when `--host-base` is absent), in this order, all inside the host repo, with no fetch:
   1. `git symbolic-ref --short refs/remotes/origin/HEAD` → e.g. `origin/main`;
   2. else `git config init.defaultBranch`, if that branch exists locally;
   3. else `main`, then `master`, if it exists;
   4. else refuse with "pass --host-base <ref>".

   Resolve the chosen ref to a sha (`rev-parse --verify <ref>^{commit}`).
4. **Guards, before anything is written** (S2 (a) step 1, plus):
   - the host is a git work tree and not mid-merge, rebase, cherry-pick or bisect (reuse `_git_operation_in_progress` with a `cwd`);
   - the host branch is either absent, or exists and is **not checked out** in any host worktree (`git -C <host> worktree list --porcelain`);
   - the host worktree path is free;
   - the base resolves;
   - the nested `phase/…` branch is free.
5. **Write and commit, in S2's order:**
   - ensure `/.claude/worktrees/` in the **host's** common `info/exclude` (generalize `_ensure_worktrees_excluded` / `_git_dir` to take a `cwd`; the at-root call is unchanged);
   - write the execution block;
   - re-stamp `host_anchors.created`:
     - a new branch: the base sha;
     - a reused branch: `git merge-base <base-sha> <host-branch>`;
   - rebuild, then the nested stamp commit (the existing `--only` path);
   - the host worktree:
     - a new branch: `git -C <host> worktree add -b <host-branch> <host-wt> <base-sha>`;
     - a reused branch: `git -C <host> worktree add <host-wt> <host-branch>`;
   - `git -C <ROOT> worktree add -b <phase-branch> <host-wt>/workflow HEAD`;
   - copy `<host>/CLAUDE.local.md` byte for byte to `<host-wt>/CLAUDE.local.md` (when it exists).

   **Create nothing under `<host-wt>/.claude/`.** Each later failure prints the exact remaining commands (S2's failure table).
6. **The execution block in nested.** Keep today's keys and add six, nested only:
   - `{"mode": "parallel", "branch": <phase-branch>, "worktree": <host-wt>/workflow, "consolidation": "pending", …}`;
   - **`worktree` is the nested worktree**, the worktree of the repo that owns the state, so the existing remove-in-ROOT logic fits the nested half (S5 relies on this; S2 saw `git worktree remove <host-wt>` fail from the nested repo);
   - `host_worktree`: `<host-wt>`, where the session enters;
   - `host_branch`;
   - `host_base`: the ref as resolved, e.g. `origin/main`;
   - `host_base_sha`;
   - `host_branch_created` (bool);
   - `base_branch`: the nested repo's branch at start (the default stream's branch; S7 reads it for the default row on a parallel stream).

   `validate` (≈1720-1745) checks the new keys' types, that they appear together and only in nested, and that `host_worktree`'s `workflow/` equals `worktree`. A legacy at-root block without them stays valid.
7. **`CLAUDE_AGENTS`** (≈273), in nested: the parent of `git -C HOST_ROOT rev-parse --path-format=absolute --git-common-dir`, then `/.claude/agents` (the main host checkout's). Fall back to `HOST_ROOT / ".claude/agents"` when git is unavailable. At root it is unchanged.
8. **`parallel-status` in nested** prints `host_branch=`, `host_base=` and `host_worktree=` per phase (`worktree=` stays the nested worktree), beside today's lines. Branch reads stay in the nested repo (`_phase_json_at_ref` / `_slices_at_ref`).
9. **The printed next steps** after a nested start: `EnterWorktree` with `path=<host-wt>` (the `host_worktree`; or open a session there); `next` there shows `stream=phase/…`; product commits go to `<host-branch>` in the host worktree, and workflow commits to `git -C workflow` there.

10. **Smoke Test 14** (`tests/retrofit_smoke.sh` ≈1846-1847) asserts the exact refusal `parallel worktrees are disabled in a nested personal install`, which this slice removes. Update that one assertion to the new behavior: `parallel-start` without `--host-branch` refuses with the new message and writes nothing. S9 replaces it with the lifecycle check.

## Doc impact (append to phase.md)

- `architecture.md`: nested installs support parallel worktrees as a pair (a host worktree under `<host>/.claude/worktrees/`, with the nested worktree inside); the stream key is the nested branch; new nested execution fields `host_worktree`, `host_branch`, `host_base`, `host_base_sha`, `host_branch_created`, `base_branch`; `worktree` is the nested worktree (P35.S4)
- `operations.md`: in nested, `parallel-start <P> --host-branch <name> [--host-base <ref>]`, the base resolution order, the re-stamped host anchor and the copied `CLAUDE.local.md` (P35.S4)

## Verification (a scratch nested install; never this checkout's state, never glide-ilab)

Build first (`python3 installer/build.py`, then `--check`). Then:

```
SCRATCH=$(mktemp -d <session scratchpad>/p35s4.XXXX)
```

Make a host repo with commits on `main` and a bare "origin" clone, so `origin/HEAD` exists. Install with `sh <repo>/bootstrap_agentic_workspace.sh "$SCRATCH/host"`, then `new-phase P2 …`. Show:

1. `parallel-start P2` without `--host-branch` is refused, and writes nothing (`git -C workflow status` clean).
2. `parallel-start P2 --host-branch feat/side` succeeds:
   - the two worktrees exist (`git worktree list` in both repos);
   - the host status is clean;
   - `<host-wt>/CLAUDE.local.md` equals the main one;
   - no `<host-wt>/.claude/`;
   - `host_anchors.created` = the `origin/main` sha;
   - the execution block carries all the new keys, with `worktree` = `<host-wt>/workflow`.
3. In `<host-wt>`, `python3 workflow/scripts/workflow.py next` prints `stream=phase/P2-…`. `validate` there shows no missing-agent warning. In the main checkout, `next` skips P2.
4. `parallel-status` and `parallel-gate P2` run in nested.
5. A second start reusing a branch that is checked out elsewhere is refused; reusing a free one works and stamps the merge-base. An unresolvable `--host-base` refuses and writes nothing.
6. **`phase-scope`:**
   - advance host `main` in the main checkout after the start;
   - commit one file in `<host-wt>`;
   - `phase-scope P2` from the worktree lists only the worktree's commit (S2 (f)).
7. At root, nothing changes: run **`bash tests/retrofit_smoke.sh` as the only command in its Bash call**; it reports the same PASS count as before the slice (record both counts).
8. `python3 installer/build.py --check` and `python3 scripts/workflow.py validate` pass.

Leave `$SCRATCH` in the scratchpad (`rm -rf` is denied) and list it in `result.md`. **No `claude -p` probes.**

## Must not

- Touch teardown, merge-finish, consolidated, the hooks, the backlog or any skill/README/installer text (S5-S8).
- Fetch in the engine.
- Create files under `<host-wt>/.claude/`.
- Change at-root behavior.
- Bump the version, commit, or move workflow state.

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
