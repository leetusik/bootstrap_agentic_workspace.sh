# P12.S3 result — Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation

**Status: done.** Integrating a parallel phase back into the default stream is now a state machine
with three checkable steps — `parallel-gate <P>` (may I merge?), `parallel-merge-finish` (the merge
landed, regenerate and tell me what is left), `parallel-consolidated <P>` (the deferred docs are
done) — plus the archive gate that refuses to bury a phase whose docs were never consolidated, and
a repo-root `.gitattributes` that makes `works/events.jsonl` merge itself.

## What landed

### `.gitattributes` (new, repo root — repo-local only)

One live rule, `works/events.jsonl merge=union`, plus a comment block documenting the
regenerate-not-merge policy for the five generated artifacts. Deliberately **not** registered in
`installer/build.py:FIXED_LIVE_FILES` / `installer/main.py:MANAGED_FILES` — whether it ships
embedded to adopting workspaces is S5's open question, and registering it here would pre-empt that
decision.

### `parallel-gate <P> [--branch-ref REF] [--main-ref REF]`

Read-only, CI-shaped (`GATE OPEN` + exit 0, or `GATE CLOSED` + numbered reasons + exit 1), no state
mutation. Two independent questions:

- **branch side** — `git show <branch-ref>:works/phases/active/<P>/phase.json` must read `status:
  done` + `review.status: pass`. Never main's copy: pre-merge, main's copy of the phase is stale by
  construction (the smoke asserts main still says `planned` while the gate correctly reads
  `done`/`pass`). `--branch-ref` defaults to the stamped `execution.branch` and accepts any ref
  (`HEAD`, `origin/phase/...`) so CI can name what it has.
- **main side** — every *default-stream* active phase must be `planned` or `done`; anything
  `in_progress` / `in_review` / `pending` / `blocked` closes the gate (`BUSY_PHASE_STATUSES`).
  Other *parallel* phases never make main busy. Source is the working tree by default, or
  `--main-ref origin/main` in a PR checkout, and the chosen source is always echoed
  (`main_state_source=...`) so a CI log shows what was actually read.

One guard worth naming: the working tree may not stand in for main when the checkout **is** the
phase branch — by name (its worktree) or detached at its tip (how CI checks out a PR). Sharing a tip
with main, which is the normal state immediately after `parallel-start`, does *not* count; the first
version of this check used tip equality alone and the smoke caught the false positive.

A second merged-but-unconsolidated phase produces a `note:` line (consolidation is serialized) but
does not close the gate — the plan's definition of quiet is about the default stream's phases.

### `parallel-merge-finish`

Run on the default stream right after `git merge` of a phase branch.

1. **Refuses mid-merge** (`git rev-parse -q --verify MERGE_HEAD`) with the resolution rule spelled
   out: generated files may be resolved by taking *either* side, because step 2 rewrites them.
2. `rebuild_docs()` + `rebuild_index_and_state()` — every generated file back to truth from the
   merged folders.
3. Lists merged-but-unconsolidated phases (parallel block, `consolidation: "pending"`, phase `done`,
   branch merged into HEAD *or already deleted*), each with its `phase.md` §Doc Impact location, the
   per-note `doc-new-version → edit edit_path → rebuild-docs` sequence, the closing
   `parallel-consolidated <P>`, and the `parallel-teardown <P>` reminder — under an explicit
   "ONE AT A TIME" heading, since doc versions come from a single index.
4. Makes **no commit**, and says so.

On a never-opted-in workspace it degrades to "rebuild, print nothing to consolidate" (asserted).

### `parallel-consolidated <P>`

Guards in order: parallel block present → not on a parallel stream → phase `done` → review `pass` →
`consolidation == "pending"` (a repeat and a malformed value get distinct messages). Then
`consolidation: "done"`, a `phase_consolidated` event, `rebuild_index_and_state()`, and a reminder
that `phase.json` is dirty for the orchestrator to commit alongside the new doc versions.

### Archive gating

`_phase_blockers` gains one reason when `phase_execution(phase).consolidation == "pending"`, so
`archive-phase` refuses, `archive-all` reports it as a blocker, and `rotate-backlog` quietly leaves
the phase active. `parallel-teardown`'s existing pending-consolidation **warning** stays a warning:
teardown removes a worktree (reversible), archiving is not.

## Settled decisions (also appended to `phase.md` §Settled Decisions)

1. **Final names: `parallel-gate <P>`, `parallel-merge-finish`, `parallel-consolidated <P>`** — the
   plan's recommendations, kept verbatim; S5/S6 quote these.
2. **No custom git merge driver**, with the rationale recorded: a driver needs
   `git config merge.<driver>.driver` per clone, so it does not travel with the repo and would
   silently fall back to a normal merge exactly where it mattered. Generated files are regenerated
   after the merge instead; only `works/events.jsonl` gets an attributes-level driver, and only
   because `union` is built into git.

## Validation

| # | Command / check | Result |
|---|---|---|
| 1 | End-to-end temp-git-repo smoke, `scratchpad/smoke_s3.py` (49 checks) | **pass** — `SMOKE PASSED (49 checks)` |
| 2 | Regression: S2's smoke, `scratchpad/smoke_s2.py` (45 checks) | **pass** — `SMOKE PASSED (45 checks)` |
| 3 | Real tree: `rebuild` before/after, 15 generated files + `next` + `validate` output, timestamps normalized | **pass** — `IDENTICAL` |
| 4 | Real tree `python3 scripts/workflow.py validate` / `next` | **pass** — `Workflow validation passed.`, pointer unchanged (`P12.S3`) |
| 5 | `python3 installer/build.py` then `--check` | **pass** — `wrote bootstrap_agentic_workspace.sh (326073 bytes)`, then `OK: ... in sync` |
| 6 | `python3 -m py_compile scripts/workflow.py`, `--help` lists the three new subcommands | **pass** |

The smoke (all commits **inside the temp repo only**) builds a workspace with `workflow.py` +
`.gitattributes` + `works/templates` + `docs`, P1 `in_progress` on main and P2 `planned`, opts P2 in
with the real `parallel-start`, runs P2 to `done`/`pass` **in its worktree**, then genuinely diverges
both sides (branch: a finished phase + its own events; main: its own transition + events) and
asserts:

- **gate** — closed before P2 is done *and* while P1 is in progress (all three reasons numbered);
  closed with exactly one reason once the branch is ready but main is still busy, while
  `branch_phase_status=done`/`branch_review=pass` are read from the branch and main's copy still
  says `planned`; **open** once P1 is parked; open with explicit `--branch-ref`/`--main-ref`;
  refused from the branch checkout without `--main-ref`, open from it *with* `--main-ref main`;
  closed on an unreadable ref; refuses a non-parallel phase; mutates nothing (`git status` clean).
- **merge** — `works/events.jsonl` does **not** conflict and both sides' events survive
  (`merge=union` from the in-repo `.gitattributes`, no per-clone config); only the four generated
  dashboards conflict; `parallel-merge-finish` **refuses** while `MERGE_HEAD` exists; after
  resolving by taking either side, it regenerates them into a truthful state (`[x] P2` reappears),
  lists P2 with its `phase.md` Doc Impact location, the serialized `doc-new-version` flow and the
  teardown reminder, and makes no commit (`git log -1` still the merge).
- **consolidation** — `archive-phase P2` blocked with "docs not consolidated" and `rotate-backlog`
  leaves P2 active; `parallel-consolidated` refused for a default-stream phase and from the phase's
  own stream, succeeds on main, flips the state, records `phase_consolidated`, refuses a repeat;
  `parallel-merge-finish` then reports nothing to consolidate.
- **retirement** — `parallel-teardown P2` completes with no pending-consolidation warning, and
  `archive-phase P2` is now allowed. `validate` passes at every step.
- **backward compatibility** — with no parallel phase left, `parallel-merge-finish` only rebuilds
  and prints "nothing awaiting doc consolidation" (no warning line), and a following `rebuild` is a
  no-op.

## Deviations from `plan.md`

1. **`parallel-gate` gained `--branch-ref` alongside `--main-ref`.** The plan named only
   `--main-ref`. CI checks out the PR branch, where the *local* ref name may not exist (detached
   HEAD, or `origin/phase/...`), so the branch side needs the same escape hatch; it defaults to the
   stamped `execution.branch`, so the interactive call is still `parallel-gate <P>`.
2. **The working-tree-is-not-main guard** (described above) is not in the plan — without it the
   default `--main-ref`-less invocation from a PR checkout would silently grade the branch against
   itself, which is exactly the failure the gate exists to prevent.
3. **A second unconsolidated phase is a `note:`, not a closing reason** — kept the plan's definition
   of "main quiet" intact while still surfacing the serialization constraint.
4. **`parallel-merge-finish` warns (does not refuse) when run on a parallel stream.** It is
   idempotent and harmless there; refusing would only strand someone mid-cleanup.
5. **`parallel-gate` requires the phase folder to exist in the current checkout** (via
   `require_phase`) even when `--branch-ref` is given. True at every real gate time — `parallel-start`
   commits the stamp to both sides — and keeping it avoids a second, ref-only phase-lookup path.

No commits in the real repo, no status transitions, no `doc-new-version`, no other slice's `plan.md`
touched. Smoke scripts live only in the session scratchpad; nothing was added under `tests/`.

## Doc impact (recorded in `phase.md`, for the REVIEW slice)

- **`operations`** — three post-review commands and the archive gate.
- **`decisions`** — regenerate-not-merge instead of a custom git merge driver.

## Notes for S4–S6

- **S5 (PR + CI):** `parallel-gate` is the CI-callable piece — `python3 scripts/workflow.py
  parallel-gate <P> --branch-ref HEAD --main-ref origin/main` in a PR checkout, exit code is the
  verdict, stdout is the report. The full agent-run sequence is: gate → `git merge` → resolve
  generated-file conflicts by taking either side → `parallel-merge-finish` → commit → consolidate
  docs one phase at a time → `parallel-consolidated <P>` → `parallel-teardown <P>` → commit.
  `.gitattributes` is still **repo-local**; embedding it (plus the CI workflow) in
  `FIXED_LIVE_FILES` + `MANAGED_FILES` remains S5's open question.
- **S4 (cross-stream view):** `_phases_at_ref(ref)` / `_phase_json_at_ref(ref, P)` /
  `_json_at_ref(ref, rel)` already read another stream's state via `git show`/`git ls-tree`, and
  handle a workspace nested below the repo root through `_repo_prefix()`. `_git_available()` is the
  soft "is there git here" probe (never raises), as opposed to `_require_git_repo()`.
- **S6 (contract + skills):** the parallel review slice must **stop before** `doc-new-version` and
  leave its "Doc Impact" notes in `phase.md`; `parallel-merge-finish` is what tells the operator
  which phases still owe that consolidation, and it is deliberately serialized on the default stream.
