# P12.S4 — Cross-stream status view

_Auto-mode plan. Context: `phase.md` §Decomposition (S4 row), §Settled Decisions → S1–S3 (binding:
`execution` block, `phase_execution`/`current_stream`/`git_current_branch` helpers, the
`parallel-start/-teardown/-gate/-merge-finish/-consolidated` family), §Constraints. Also S3's
`result.md` for the `git show <ref>:...` read patterns it already built._

## Goal

One read-only command that answers, from any checkout without switching: "what is happening on
every stream right now?" Today a parallel phase's slice progress exists only on its branch — the
main checkout's `works/backlog.md` stands still until merge. Covers intent item 8 (raised by the
operator asking how to check branch slices while main's backlog is unchanged).

## Decision S4 settles (record in `phase.md` §Settled Decisions)

**Name: `parallel-status`** — stays in the family (the intent's `status --all` was an illustrative
"e.g."; there is no existing `status` command to extend, and the family prefix is how the operator
discovers all of this). Adjust only with a recorded reason.

## Implementation (`scripts/workflow.py`; reuse, don't duplicate)

- **Current-stream header:** which stream this checkout is on (default or `<branch>`), then the
  pointer as `next` shows it (`current_phase` / `current_slice` / `next_slice` / waiting) — reuse
  the state already computed by `rebuild_index_and_state` / `resolve_current` rather than
  reimplementing. Read-only: do NOT rewrite dashboards from a parallel checkout as a side effect;
  compute in memory (call the pure helpers on `all_active_phases()` output, not the rebuild).
- **Per parallel phase (every active phase with a stamped block), one section:**
  - id, name, `branch`, `worktree` (or `—`), `consolidation` state;
  - branch-side truth via git plumbing — `git show <branch>:works/phases/active/<P>/phase.json`
    for status/review, `git ls-tree` + `git show` for each slice's `slice.json` (id, status, name)
    — presented compactly (the backlog's one-line-per-slice style with `[x]/[~]/[r]/[ ]` boxes,
    reuse `status_box`);
  - a one-line verdict of where the phase stands: e.g. in flight (`n/m slices done`), ready to
    merge (`done` + `pass` — suggest `parallel-gate <P>`), merged awaiting consolidation, or
    merged + torn down (branch deleted → fall back to the current checkout's merged copy, noted).
- **Edge cases:** branch ref missing (torn down or teammate's clone without the fetch) → fall back
  to the local folder copy with a `(local copy; branch not found)` note; git absent/non-repo →
  clear error (this command is inherently git-backed); no parallel phases → header plus
  `no parallel phases` (fine to run anywhere, never an error).
- Backward compat: purely additive subcommand; zero change to any existing command's output or any
  generated file. `rebuild` must NOT be triggered (read-only guarantee).

## Validation (lean)

1. Extend the temp-repo scenario (reuse the S2/S3 smoke harness pattern in the scratchpad; commits
   only inside the temp repo): with a parallel phase mid-flight on its branch (slices in mixed
   states, committed on the branch only), assert `parallel-status` from the MAIN checkout shows the
   branch-side slice statuses (which main's backlog does not), from the WORKTREE shows the same,
   and after merge + teardown falls back to the local copy with the note; assert it never modifies
   any file (hash the works/ tree before/after).
2. Real tree: `parallel-status` runs clean (no parallel phases message), `validate` + `next`
   unchanged, rebuild-diff byte-identity as in S1–S3.
3. `python3 installer/build.py` + `--check` pass (workflow.py is embedded machinery).

## Boundaries

Executor: no commits in the REAL repo (temp repo fine), no status transitions, no
`doc-new-version`, no other slice's `plan.md`. Write `result.md`; append the settled name to
`phase.md` §Settled Decisions and a one-line `operations` note to §Doc Impact.
