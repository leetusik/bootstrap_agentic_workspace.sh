# P12.S4 result — Cross-stream status view (`parallel-status`)

**Status: done.** From any checkout, `parallel-status` now answers "what is happening on every
stream right now?" — this stream's pointer, then one section per parallel phase whose slice
progress is read straight off that phase's branch with git plumbing, each closed by a one-line
verdict naming the next command. It is the only command in `scripts/workflow.py` that writes
nothing at all.

## What landed (`scripts/workflow.py`, +148 lines, additive only)

### `parallel-status` (new subcommand, no arguments)

**Header** — the stream this checkout is on (`stream=default` or `stream=phase/P13-…`) and the
pointer as `next` computes it (`current_phase` / `current_slice` / `next_slice` /
`waiting_on_operator`). Reuses the exact chain `rebuild_index_and_state()` uses —
`current_stream` → `stream_phases` → `resolve_current` / `operator_wait_target` — but **in memory**:
no `rebuild`, no dashboard rewrite. That matters because the command's whole point is to be run from
a parallel worktree, where a rebuild would silently rewrite that checkout's generated files.

**One section per stamped parallel phase** (`phase_execution(p)` is the only membership test):

```
== P2: second phase ==
  branch=phase/P2-second_phase
  worktree=/…/repo-P2
  consolidation=pending
  source=branch phase/P2-second_phase
  status=in_progress review=pending merged_into_HEAD=false
  slices (1/3 done):
    [x] P2.DECOMP  done              decompose phase
    [~] P2.S1      pending           build it
    [ ] P2.REVIEW  todo              phase review
  verdict: in flight on its branch -- 1/3 slices done; current slice P2.S1
```

The slice boxes come from the shared `status_box` (`[x]` / `[~]` / `[r]` / `[ ]`), so they read
exactly like `works/backlog.md`.

**Where truth is read from** (always printed as `source=`):

1. the phase's branch *is* this checkout's stream → the **working tree** (fresher than its own last
   commit, and what a worktree session actually wants to see);
2. else `git show <branch>:works/phases/active/<P>/phase.json` + `git ls-tree`/`git show` per
   `slice.json`, falling back to `origin/<branch>` — a teammate who fetched but has no local branch;
3. else the **local folder copy**, with `note: (local copy; branch not found: <branch>) -- merged and
   torn down, or never fetched in this clone`.

**Verdict ladder**, each step naming the next command: in flight `n/m slices done` (+ current
slice) → `pending`/`blocked` on its own stream → slices done but review not `pass` → **ready to
merge** (`parallel-gate <P>`) → **merged, docs awaiting consolidation** (`parallel-merge-finish`,
then `parallel-consolidated <P>`) → **merged + consolidated** (`parallel-teardown <P>`) → **merged,
consolidated and torn down** (archivable). "Merged" is `git merge-base --is-ancestor <branch> HEAD`,
computed only when the checkout is not the phase's own stream (there HEAD trivially contains the
branch, so the answer would always be a misleading "yes"); a deleted branch counts as merged because
`parallel-teardown` refuses an unmerged one.

**Edge cases.** No parallel phases → header + `no parallel phases` + the `parallel-start <P>`
pointer, exit 0, and git is never consulted (an untouched workspace behaves exactly as before). A
stamped parallel phase with no usable git work tree → a clear `not inside a git work tree` error,
since the command is inherently git-backed. A parallel stamp with no `branch` degrades to the local
copy instead of crashing (`validate` is what flags that stamp).

### `_slices_at_ref(ref, phase_id)` (new helper)

The slice-level twin of S3's `_phases_at_ref`: `git ls-tree` the phase's `slices/` at a ref, `git
show` each `slice.json`, sort by `order`, `None` when the ref is unreadable. Goes through S3's
`_repo_prefix()`, so a workspace nested below the repo root works. S5 can reuse it.

## Validation

| # | Command / check | Result |
|---|---|---|
| 1 | Temp-git-repo smoke, `scratchpad/smoke_s4.py` (44 checks) | **pass** — `SMOKE PASSED (44 checks)` |
| 2 | Real tree: `parallel-status` | **pass** — `stream=default` + pointer + `no parallel phases`, exit 0, `git status` unchanged |
| 3 | Real tree: `validate`, `next` | **pass** — `Workflow validation passed.`, pointer still `P12.S4` |
| 4 | Byte-identity: HEAD's vs. this workflow.py generating from the real `works/`+`docs/` (`scratchpad/rebuild_diff_s4.py`) | **pass** — 17 artifacts (4 dashboards + 11 `docs/current/*.md` + `next` + `validate`), `IDENTICAL` |
| 5 | `python3 installer/build.py` then `--check` | **pass** — `wrote bootstrap_agentic_workspace.sh (334412 bytes)`, then `OK: … in sync` |
| 6 | Regression: S3's smoke (49 checks) | **pass** |
| 7 | Regression: S2's smoke (45 checks) | pass on re-run; one **pre-existing** flake, see below |
| 8 | `python3 -m py_compile scripts/workflow.py`; `--help` lists `parallel-status` in the family | **pass** |

**The S2 flake is not mine.** `smoke_s2.py`'s "commit contains only the stamp + regenerated works
files" check occasionally sees 4 files instead of 6: `now_iso()` has second resolution, so when two
consecutive rebuilds land in the same wall-clock second, `works/state.json` and `works/deferred.md`
come out byte-identical and never enter the commit. Reproduced 3× out of 6 runs against **HEAD's**
`workflow.py` (`scratchpad/smoke_s2_head.py`, an unmodified copy pointed at a pristine HEAD build),
so it predates S4. Worth tightening in that smoke, not in the engine.

`smoke_s4.py` (all commits **inside its temp repo only**) seeds P1 `in_progress` on main and P2
`planned` with three slices, opts P2 in with the real `parallel-start`, and asserts:

- **before opt-in** — header + `no parallel phases` + the `parallel-start` pointer, exit 0;
- **right after opt-in** — main's pointer stays on P1, the P2 section carries branch/worktree/
  `consolidation=pending`, `source=branch …`, all three slices with boxes, `verdict: in flight …
  0/3 slices done`;
- **mid-flight, from MAIN** — after P2.DECOMP is finished and P2.S1 set `pending` **on the branch
  only**, `parallel-status` shows `[x] P2.DECOMP done`, `[~] P2.S1 pending`, `1/3 slices done`,
  while main's own `slice.json` still says `todo` and `works/backlog.md` has no `[x] P2.DECOMP` —
  the exact gap this command closes — and P2's `pending` slice does **not** hijack main's pointer;
- **mid-flight, from the WORKTREE** — `stream=phase/P2-…` with its own scoped pointer,
  `source=working tree`, the same slice statuses main saw, verdict "in flight on this checkout's
  own stream";
- **branch finished** — reads `status=done review=pass` off the branch while main's copy still says
  `planned`, `merged_into_HEAD=false`, verdict routes to `parallel-gate P2`;
- **after merge / after `parallel-consolidated` / after `parallel-teardown`** — `merged_into_HEAD=
  true` → "merged, docs still awaiting consolidation"; `consolidation=done` → "merged + consolidated
  … parallel-teardown P2"; branch gone → `source=local copy` + the `(local copy; branch not found:
  …)` note, `worktree=-`, "merged, consolidated and torn down";
- **read-only** — `works/` + `docs/` are content-hashed around **every one** of the 8 invocations and
  never change; `next` and `validate` produce identical output before and after;
- **non-repo** — a copy of the workspace without `.git`, with P2 still stamped, exits non-zero with
  `not inside a git work tree`.

## Deviations from `plan.md`

1. **Own-stream sections read the working tree, not `git show`.** In the phase's own worktree the
   uncommitted working tree is the freshest truth and is what that session is actually editing;
   reading its own last commit would show stale data at exactly the moment work is in progress. The
   `source=` line always says which was used, and the smoke asserts both checkouts agree once the
   branch is committed (the plan's requirement).
2. **Added an `origin/<branch>` fallback** before falling back to the local copy — the plan's
   "teammate's clone without the fetch" case is much better served by the remote-tracking ref when
   it exists, and it costs one `git show`.
3. **`worktree` renders as `- (plain clone, or already torn down)`** rather than the plan's `—`:
   `scripts/workflow.py` is ASCII-only throughout, and the em dash would be the sole exception.

No commits in the real repo, no status transitions, no `doc-new-version`, no other slice's
`plan.md` touched. Smoke scripts live only in the session scratchpad; nothing was added under
`tests/`.

## Doc impact (recorded in `phase.md`, for the REVIEW slice)

- **`operations`** — `parallel-status`: the read-only cross-stream view (pointer + per-phase
  branch-side slice state + next-command verdict), the only workflow command that writes nothing.

## Notes for S5–S7

- **S5** can reuse `_slices_at_ref(ref, P)` for anything PR-side that needs a branch's slice detail,
  and should keep the "read-only means no rebuild" rule for any further reporting command.
- **S6/S7** quote the name **`parallel-status`** verbatim; the natural operator loop to document is
  `parallel-status` (where is everything?) → `parallel-gate <P>` → merge → `parallel-merge-finish` →
  consolidate → `parallel-consolidated <P>` → `parallel-teardown <P>`, and `parallel-status` is the
  one safe command to run from *inside* a phase worktree without disturbing its generated files.
