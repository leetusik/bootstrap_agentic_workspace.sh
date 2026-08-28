# P12.S2 — Opt-in lifecycle: branch + worktree cut, teardown, proactive suggestion

_Auto-mode plan. Context: `phase.md` §Decomposition (S2 row), §Settled Decisions → S1 (binding —
quote the `execution` block fields and helpers verbatim), §Findings & Notes, §Constraints, and
S1's `result.md` §"Notes for S2+"._

## Goal

The commands that actually create and retire a parallel phase, plus the proactive suggestion from
intent amendment 1. After S2, an operator can opt a planned phase onto its own branch + worktree
with one command, and the workspace *suggests* that option at the two moments it becomes relevant.
Covers intent items 2 and 7 and amendment 1's engine half (skill text is S6's).

## Decisions S2 settles (record in `phase.md` §Settled Decisions for S3–S7)

1. **Command names: `parallel-start <P>` and `parallel-teardown <P>`** (workflow.py subcommands).
   Symmetric, self-describing; every hint and skill quotes these names.
2. **`parallel-start` commits its own stamp.** The stamp must exist on BOTH main and the branch
   (S1's Notes for S2+), and the branch must be cut from a commit containing it. One atomic
   engine-made commit achieves that by construction; a stamp-then-ask-the-operator-to-commit
   two-step cannot. This is a deliberate, narrow exception to "the engine never commits": one
   deterministic, fixed-message commit (`chore(works): opt <P> into parallel execution`, plus the
   standard trailer convention is the orchestrator's problem, not the engine's — keep the engine
   message plain, no trailers), made only after a clean-tree guard so it can contain nothing but
   the stamp + regenerated dashboards.

## Implementation (all in `scripts/workflow.py`; read the block only via `phase_execution`)

- **`parallel-start <P> [--worktree <path>] [--slug <slug>]`:**
  1. Guards (fail loudly, no partial state): phase exists and status is `planned`; phase has no
     `execution` block; `git status --porcelain` empty (clean tree); git available and inside a
     repo; computed branch name not already taken (`git rev-parse --verify --quiet`), worktree
     path free.
  2. Branch `phase/P<N>-<slug>` (slug = `slugify(phase name)`, `--slug` overrides; keep it short).
     Default worktree path: a sibling of the repo root, `../<repo-dirname>-<P>` (absolute in the
     stamp); `--worktree` overrides.
  3. Stamp `phase.json`: `execution = {mode: "parallel", branch, worktree: <abs path>,
     consolidation: "pending"}`; `rebuild_index_and_state()`; append event `phase_parallel_started`.
  4. `git add` the phase folder + regenerated works files, commit the fixed message on the current
     branch (main), then `git worktree add <path> <new-branch-created-at-HEAD>` (e.g. `-b`), so
     both sides carry the stamp.
  5. Print operator guidance: worktree path, branch, "open a session there and run /do-whole-phase";
     note that main's pointer now skips this phase (S1 behavior).
- **`parallel-teardown <P>`:**
  1. Guards: phase has a parallel `execution` block; branch fully merged into the current HEAD
     (`git merge-base --is-ancestor <branch> HEAD`) — refuse otherwise (message says merge first;
     S5 owns the merge flow); run from the default stream (not inside the phase's own worktree).
  2. `git worktree remove` (if the stamped worktree exists and is clean; `git worktree prune`
     otherwise), `git branch -d <branch>` (the `-d` merged-only guard is a free second check),
     set `execution.worktree` to `null` (keep `mode`/`branch`/`consolidation` as history),
     `rebuild_index_and_state()`, append event `phase_parallel_torndown`.
  3. Do NOT gate on `consolidation` here — S3 owns consolidation and may tighten this guard later;
     note that in the output when `consolidation` is still `"pending"` (warn, don't block).
- **Proactive suggestion (amendment 1), engine half — a hint line naming `parallel-start`:**
  - `new_phase` (:665): after `created phase ...`, if any OTHER active default-stream phase is
    `in_progress`, print e.g.
    `hint: P<X> is in progress — this phase can run in parallel: python3 scripts/workflow.py parallel-start <P>`.
  - `cmd_next` (:796): on the default stream, when the current phase is `in_progress` AND at least
    one later default-stream phase is `planned`, print one hint line naming the first such phase
    and `parallel-start`. (S1's `parallel_phases_elsewhere` line is unrelated — leave it.)
  - Suggestion only, never a default; one line each, no new commands run.
- **Backward-compat boundary (refined for S2):** generated FILES stay byte-identical for
  never-opted-in workspaces (re-run S1's rebuild-diff proof). Stdout is allowed to gain exactly the
  two hint lines above in their trigger conditions — that is amendment 1's explicit ask — and must
  stay unchanged when the conditions don't hold (e.g. this repo today: single active phase → no
  hints; verify on the real tree).

## Validation (lean; temp-repo smoke in the scratchpad, commits allowed INSIDE the temp repo only)

1. Temp git repo (this time with an initial commit, since parallel-start commits): two phases
   P1 (in_progress) + P2 (planned). Assert: `new-phase` for a P3 prints the hint; `next` prints the
   waiting-phase hint; `parallel-start P2` → stamp committed on main, branch + worktree exist, the
   worktree's phase.json carries the stamp, main's `next` skips P2, `next` run in the worktree
   selects only P2; guards fire (dirty tree, already-stamped, non-planned phase, taken branch);
   `parallel-teardown P2` refuses unmerged, then after `git merge` succeeds: worktree gone, branch
   deleted, `worktree: null`, `validate` passes throughout.
2. Real tree: `rebuild` before/after diff (timestamp-normalized) byte-identical; `next` output
   unchanged (single phase → no hint); `validate` passes.
3. `python3 installer/build.py` + `--check` pass (workflow.py is embedded machinery).

## Boundaries

Executor: no commits in the REAL repo (the temp smoke repo is fine; `parallel-start`'s own commit
code runs only there), no status transitions, no `doc-new-version`, no other slice's `plan.md`.
Write `result.md`; append to `phase.md`: the settled command names + the engine-commits-its-stamp
decision under §Settled Decisions, and a one-line Doc impact note (likely `operations` — new
operator commands — and the `architecture` stamp-on-both-sides mechanics if you judge it durable).
