# P12.S3 — Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation

_Auto-mode plan. Context: `phase.md` §Decomposition (S3 row), §Settled Decisions → S1 and S2
(binding: the `execution` block, `phase_execution`, `current_stream`, and the `parallel-start` /
`parallel-teardown` command family), §Findings & Notes, §Constraints. Also S2's `result.md`._

## Goal

The engine primitives that make integrating a parallel phase back into main safe and boring:
merge-safe generated files, the quiet-point gate, the post-merge rebuild, and the deferred-
consolidation state machine. Covers intent items 3, 4, and 6. The *orchestrated* integration
sequence (push → PR → merge, agent-run) is S5's; S3 builds what S5 and CI will call.

## Scope boundary (important)

The engine cannot write prose: the actual consolidated doc content is still produced by an agent
running `doc-new-version` on main (the S6 skill will direct that flow). S3's job is the **state
machine and the checks around it** — knowing when merge is allowed, what needs consolidating, and
recording when consolidation happened.

## Decisions S3 settles (record in `phase.md` §Settled Decisions)

1. **Command names stay in the `parallel-*` family** (S2 precedent). Recommended:
   `parallel-gate <P>`, `parallel-merge-finish`, `parallel-consolidated <P>` — adjust names for
   clarity if implementation suggests better, then record the final names; S5/S6 quote them.
2. **No custom git merge driver for generated files.** `merge=ours` needs per-clone git config
   (does not travel); instead the generated files are regenerated after merge by
   `parallel-merge-finish`. Only `works/events.jsonl` gets an attributes-level driver (`union` is
   built-in). Record this rationale.

## Implementation

- **`.gitattributes` (new file, repo root):**
  - `works/events.jsonl merge=union` (append-only log; union is a built-in driver).
  - Comment lines documenting that `works/state.json`, `works/index.json`, `works/backlog.md`,
    `works/deferred.md`, and `docs/current/*` are generated — on merge conflict take either side
    and run `python3 scripts/workflow.py parallel-merge-finish` (or `rebuild`) to regenerate.
  - Do NOT register it in the installer lists — that decision + implementation is S5's (phase.md
    §Open Questions). Repo-local file only in this slice.
- **`parallel-gate <P>` — the quiet-point check (CI-usable: clean exit 0 / nonzero + message):**
  - `<P>` is a parallel phase (stamped block).
  - **Branch side done:** read `works/phases/active/<P>/phase.json` **from the phase branch**
    (`git show <branch>:...` — never trust main's stale copy pre-merge): status `done`, review
    `pass`.
  - **Main side quiet:** on the default stream, no phase `in_progress` / `in_review` / `pending` /
    `blocked` (i.e., every non-parallel active phase is `planned` or `done`). Read from the
    current checkout when on main; in CI (checkout of the PR branch) accept `--main-ref origin/main`
    or similar to name where main's state is read from (`git show <ref>:works/...`). Keep the
    interface minimal but CI-workable — S5 will wire it.
  - Output: `GATE OPEN`/`GATE CLOSED` + numbered reasons. No state mutation.
- **`parallel-merge-finish` — run on main right after a `git merge` of a phase branch:**
  - Refuse mid-merge (`MERGE_HEAD` exists) with a message telling the operator/agent to resolve
    conflicts first (generated files: take either side; the rebuild below restores truth).
  - `rebuild_index_and_state()` + `rebuild_docs()` — regenerate every generated file from the
    merged folders.
  - Then scan for merged-but-unconsolidated parallel phases (block present, `consolidation:
    "pending"`, phase `done`, branch merged into HEAD or already deleted): print each with its
    `phase.md` §Doc Impact location and the instruction that consolidation (agent-run
    `doc-new-version` per note, then `parallel-consolidated <P>`) happens **one phase at a time,
    on main** — never in parallel. Also remind about `parallel-teardown <P>`.
  - No commit (the orchestrator commits the regenerated files as part of the merge flow).
- **`parallel-consolidated <P>` — mark the consolidation done:**
  - Guards: parallel block present, `consolidation == "pending"`, phase `done` + review `pass`,
    run on the default stream.
  - Sets `consolidation: "done"`, event (`phase_consolidated`), `rebuild_index_and_state()`.
- **Archive gating (`_phase_blockers`, workflow.py:912-area):** a parallel phase with
  `consolidation: "pending"` gains a blocker line ("docs not consolidated — run the post-merge
  consolidation, then parallel-consolidated <P>"). Teardown's existing pending-consolidation
  warning stays a warning (it only removes the worktree; archiving is the irreversible step).
- Backward compat: never-opted-in workspaces — generated files byte-identical, no stdout change
  (`parallel-merge-finish` on a plain tree just rebuilds and reports nothing to consolidate;
  `.gitattributes` only affects merges of `works/events.jsonl`, which single-stream flows never
  perform).

## Validation (lean; temp-git-repo smoke in the scratchpad — commits allowed inside it only)

1. End-to-end scenario using S2's real commands: init temp workspace (initial commit), P1
   in_progress on main, P2 planned → `parallel-start P2`; on the P2 worktree simulate slices
   (commit, append events, set P2 done + review pass via the engine); on main append a different
   event (diverge `events.jsonl`). Assert:
   - `parallel-gate P2` **closed** while P1 is `in_progress` (main not quiet) and closed earlier
     while P2 was not `done`; **open** once P1 is done and P2's branch shows done+pass;
   - `git merge` of the branch: `events.jsonl` unions cleanly (both events present), generated
     dashboards may conflict → resolve either side, `parallel-merge-finish` regenerates them
     correctly and lists P2 as needing consolidation;
   - `parallel-consolidated P2` flips the state (and refuses when repeated / when pending
     conditions unmet); archive of P2 is blocked before, allowed after; `parallel-teardown P2`
     completes the retirement; `validate` passes at every step.
2. Real tree: rebuild before/after diff (timestamps normalized) byte-identical; `validate` and
   `next` unchanged.
3. `python3 installer/build.py` + `--check` pass (workflow.py edits; `.gitattributes` deliberately
   not embedded yet).

## Boundaries

Executor: no commits in the REAL repo (temp repo commits fine), no status transitions, no
`doc-new-version`, no other slice's `plan.md`. Write `result.md`; append the settled names +
no-merge-driver rationale to `phase.md` §Settled Decisions and one-line notes to §Doc Impact
(likely `operations` — the gate/merge-finish/consolidated commands and the union attribute — and
`decisions` — regenerate-not-merge instead of a custom merge driver).
