# P12.S2 result — Opt-in lifecycle: branch + worktree cut, teardown, proactive suggestion

**Status: done.** A planned phase can now be opted onto its own branch + worktree with one command,
retired with a second one after the merge, and the workspace *suggests* the option at both moments
amendment 1 named. Everything lands in `scripts/workflow.py` (plus the mandatory installer rebuild).

## What landed

**Two commands.**

- **`parallel-start <P> [--worktree <path>] [--slug <slug>]`** — guards, stamp, one engine commit,
  branch + worktree. Guard order (all before any mutation, so a refusal leaves zero partial state):
  phase exists → status is `planned` → no existing `execution` block → inside a git work tree →
  this checkout is on the default stream (not inside another phase's worktree) → `git status
  --porcelain` empty → computed branch free in `refs/heads/` and not stamped on another phase →
  worktree path free and its parent exists. Then it writes
  `execution = {mode: "parallel", branch, worktree: <abs path>, consolidation: "pending"}`,
  appends `phase_parallel_started`, `rebuild_index_and_state()`, `git add`s exactly the phase folder
  + the five regenerated `works/` files, commits
  `chore(works): opt <P> into parallel execution` (plain message, no trailers — the trailer
  convention is the orchestrator's), and finally `git worktree add -b <branch> <path> HEAD`, so the
  stamp exists on **both** sides by construction. It prints branch, worktree, the "open a session
  there and run /do-whole-phase" step, and a note that this stream's pointer now skips the phase.
- **`parallel-teardown <P>`** — guards: the phase has a parallel block with a branch; git repo; the
  current checkout is **not** the phase's own branch; and the branch is merged into HEAD
  (`git merge-base --is-ancestor`) — refused otherwise with "merge it first" (S5 owns the merge
  flow). Then `git worktree remove` (or `git worktree prune` when the path is already gone),
  `git branch -d` (whose merged-only rule is a free second check), `execution.worktree = null`
  (`mode`/`branch`/`consolidation` kept as history), `phase_parallel_torndown`,
  `rebuild_index_and_state()`. It **warns, does not block**, when `consolidation` is still
  `"pending"` (S3's gate), and reminds the operator that `phase.json` is now dirty — teardown makes
  no commit of its own.

**Helpers** (`_git`, `_require_git_repo`, `_branch_exists`, `_phase_branch`): one place for git
invocation and for the `phase/P<N>-<slug>` name. The block is still read only through
`phase_execution` (`data.get("execution")` is touched directly only in the two spots that must see
a *malformed or any* block: `parallel-start`'s "already opted in" guard, and the write itself).

**Two hint lines** (stdout only — no generated file changes):

- `new_phase`, after `created phase ...`: fires when another **default-stream** active phase is
  `in_progress` → `hint: <X> is in progress -- this phase can run in parallel on its own branch:
  python3 scripts/workflow.py parallel-start <P>`.
- `cmd_next`, after the pointer block, via `parallel_start_hint(state, index)`: fires on the default
  stream when the current phase is `in_progress` **and** a later default-stream phase is still
  `planned`, naming the first such phase. Silent on a parallel stream, silent when the current phase
  isn't running, silent for phases already opted in.

Both are ASCII (`--`, matching the file's existing print style), one line, run no commands, and are
suggestions only.

## Validation

| # | Command / check | Result |
|---|---|---|
| 1 | Temp-repo smoke, `scratchpad/smoke_s2.py` (45 checks) | **pass** — `SMOKE PASSED (45 checks)` |
| 2 | Real tree: `rebuild` before/after diff of `works/{state.json,index.json,backlog.md,deferred.md}` (timestamps normalized) **and** `next` output | **pass** — `IDENTICAL (generated files + next output)` |
| 3 | `python3 scripts/workflow.py validate` (real tree) | **pass** — `Workflow validation passed.` |
| 4 | `python3 scripts/workflow.py next` (real tree) | **pass** — unchanged, no hint (single active phase, nothing planned behind it) |
| 5 | `python3 installer/build.py` then `--check` | **pass** — `wrote bootstrap_agentic_workspace.sh (311199 bytes)`, then `OK: ... in sync` |
| 6 | `python3 -m py_compile scripts/workflow.py`, `--help` lists both new subcommands | **pass** |

The smoke builds a throwaway workspace in the session scratchpad (`workflow.py` + `works/templates`
+ `docs` copied, `git init -b main`, a real initial commit — **all commits are inside that temp repo
only**), with P1 `in_progress`, P2/P3 `planned`, and asserts:

- **hints**: silent while nothing is in progress; `new-phase P3` hints naming P1 + `parallel-start
  P3`; `next` hints naming P2 (first planned behind P1) while still printing the normal pointer;
  after P2 is opted in, `next` hints P3 instead and never re-suggests P2;
- **guards**: non-planned phase, dirty tree, taken branch name, already-stamped phase, and running
  from inside a phase worktree are each refused — and no `execution` block or dirty file is left
  behind by any of them;
- **`parallel-start P2`**: exactly one commit with the fixed message, containing exactly
  `works/phases/active/P2/phase.json` + the five regenerated `works/` files and nothing else; tree
  clean afterwards; identical stamp readable on main **and** in the worktree; main's pointer stays
  on P1 and prints `parallel_phases_elsewhere`; `next` run *in* the worktree selects only
  `P2.DECOMP` and prints `stream=phase/P2-second_phase`; `validate` passes on both sides;
- **teardown**: refused for a default-stream phase, refused from the phase's own worktree, refused
  while the branch is genuinely unmerged (a branch-only commit made in the worktree) — and the
  worktree survives that refusal; after `git merge --no-ff`, it removes the worktree, deletes the
  branch, warns about `consolidation: "pending"`, leaves
  `{mode, branch, worktree: null, consolidation: "pending"}`, and `validate` still passes;
- **events**: both `phase_parallel_started` and `phase_parallel_torndown` recorded.

## Deviations from `plan.md`

1. **One guard added: `parallel-start` refuses to run from a parallel stream.** The plan listed the
   guards without this one, but the command *commits*, and committing from inside another phase's
   worktree would put the stamp on the wrong branch. Same spirit as teardown's own stream guard, and
   covered by the smoke.
2. **Branch slug keeps `slugify`'s underscores and is capped at 40 characters.** The plan said
   `slug = slugify(phase name)` while S1's schema example showed `phase/P13-some-slug`; I kept the
   plan's literal function (so the slug is `second_phase`, not `second-phase`) and only added the
   length cap the plan's "keep it short" asked for. Cosmetic — nothing keys off the slug's shape,
   only off the whole branch string, and `--slug` overrides it (also passed through `slugify`, so an
   operator cannot inject an invalid ref name).
3. **Teardown makes no commit** (the plan didn't ask for one, and the narrow engine-commit exception
   is deliberately limited to `parallel-start`): it leaves `phase.json` dirty and says so, for the
   orchestrator to commit with the rest of the merge cleanup.
4. **`git worktree remove` failure is a hard, explanatory error** rather than a silent fallback to
   `prune`: the plan's "prune otherwise" applies to a worktree path that no longer exists, which is
   how it is implemented; a path that exists but is *dirty* must not be pruned away silently, so the
   operator is told to clean it or use `--force`.
5. **The `next` hint prints only on the normal pointer path** (not on the `WAITING ON OPERATOR`
   early return, nor on "no open slice in the current phase"). Suggesting a second stream while the
   operator is being asked for something would be noise.

Nothing else departed from the plan. No commits in the real repo, no status transitions, no
`doc-new-version`, no other slice's `plan.md` touched. The smoke script lives only in the session
scratchpad — nothing was added under `tests/`.

## Doc impact (recorded in `phase.md`, for the REVIEW slice)

- **`operations`** — two new operator commands: `parallel-start <P>` (opt a `planned` phase onto
  `phase/P<N>-<slug>` in its own worktree) and `parallel-teardown <P>` (retire the merged branch +
  worktree), plus the proactive `parallel-start` hints in `new-phase` and `next`.
- **`architecture`** — `parallel-start` is the one deliberate engine-made git commit: the opt-in
  stamp must exist on both the default branch and the phase branch, so the engine commits it (fixed
  message, clean-tree guard) and cuts the branch from that commit.

## Notes for S3+

- `execution.consolidation` is stamped `"pending"` at opt-in and nothing sets it `"done"` yet —
  that is S3's post-merge step. `parallel-teardown` only warns about it.
- Teardown is the cleanup half of the merge flow, not the merge itself; S3/S5 should call it (or
  tell the operator to) after the merge lands on the default stream.
- The temp-repo merge in the smoke was conflict-free only because main had not touched the
  generated `works/` files since the opt-in commit. A real phase-branch merge will collide on
  `works/{state.json,index.json,backlog.md,deferred.md}` — exactly the `.gitattributes` +
  regenerate-not-merge work S3 owns.
- `_git`, `_require_git_repo`, `_branch_exists` are reusable for S4's `git show <branch>:works/...`
  reads and S5's push/PR steps.
