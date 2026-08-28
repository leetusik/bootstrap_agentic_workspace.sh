# Intent — P12

- Captured at: 2026-08-03T22:12:44+09:00
- Origin: operator

## Original Input (verbatim)

> current workspace quite comforable and I'm satisfied. but one thing. parallel works.
> 1. currently, the repo only aims for the solo dev. no branch, no parallel work, no PR related stuff.
> 2. I'm fine but I want it to able to work as a team, or parallely work even if a repo run by one maintainer.
> 3. so I think we should drop consolidate point to the next job.
> 4. and Idk how to do next.
> you suggest me a best way to accomplish parallel jobs.

Follow-up (after phase creation):

> But i think it better be based on main thread by default, make it possible to parallel work option.

Follow-up (merge gate):

> and for pr, merge, I wolud like it to be able to happen when no phase is inprogress for both main and branch.

Follow-up (at DECOMP planning — proactive suggestion):

> it's opt-in but when a user try to start new phase while inprogressing phase exists, then suggest the parallel workflow.(what p12 building)

Follow-up (at DECOMP planning — agent-driven PR/merge):

> and pr, merge basically done with coding agent. after branch's review slice.

## Confirmed Intent (refined + clarified)

Add an **opt-in parallel mode** to the workspace while keeping the default flow unchanged: by default, work stays exactly as today — one stream, phases executed one at a time directly on main (or the current branch), no branches, no PRs, doc consolidation at the phase review. Parallel execution is a per-phase **option** the operator explicitly chooses, making the workspace usable by a team — or by one maintainer running multiple work streams — without changing the solo experience.

When a phase is opted into parallel mode, **the phase is the unit of parallelism**: it runs on its own branch (`phase/P<N>-<slug>`) in its own git worktree, driven by its own orchestrator session. Slices within a phase stay sequential. Concretely, for parallel-mode phases:

1. **No single global next-job pointer contention.** Today `/do-next-slice` and `/do-whole-phase` consult one consolidated selection point (`works/state.json` `current_phase`/`current_slice`, computed by `resolve_current`, which walks phases in order and can only represent one phase in flight; a `pending` anywhere halts everything). Selection must become phase-scopable: `next` scoped to a phase, `pending` halting only its own phase, and main-thread selection skipping phases that are out running in parallel mode (and vice versa). This is the operator's point 3 — the "consolidate point to the next job" is that global pointer; it stays as the default single-stream behavior but must no longer be a hard assumption.
2. **Branch-per-phase in a worktree.** Phase creation (`/create-phase`) stays on main so phase numbering stays serialized; opting a phase into parallel execution cuts its branch in its own worktree; slice commits land on the phase branch; a passing review leads to a merge (PR) to main.
3. **Durable-doc consolidation defers to a serialized post-merge step on main.** A parallel-mode phase's review still verifies the "Doc impact" list and gives its verdict, but stops before `doc-new-version`. Consolidation runs only on main, after the phase branch merges, one phase at a time — so `vNNNN` allocation and `docs/index.json` / `docs/current/*` can never collide between parallel phases. Default-mode phases keep consolidating at the review, as today.
4. **Merge-safe generated files.** `works/state.json`, `backlog.md`, `index.json`, `deferred.md`, `docs/current/*` are regenerated, never hand-merged (a merge-finish step / post-merge rebuild plus `.gitattributes`; `works/events.jsonl` gets `merge=union`).
5. **Full PR + CI layer.** Parallel-mode phases push their branch and open a PR (phase = the reviewable unit; review verdict maps onto PR approval); CI runs `validate` (and, in this upstream repo, `installer/build.py --check`). CI may run on all pushes/PRs regardless of mode. The model must be identical for "one maintainer, two sessions" and a real team.
6. **Quiet-point merge gate.** A parallel phase's PR/merge is allowed only when no phase is in progress on either side: the branch's phase is `done` (review passed, consolidation still pending), and the main stream has no phase in progress (main is between phases). Enforced by the merge/post-merge tooling and checkable in CI. This serializes integration — and therefore consolidation — on main by construction.
7. **Worktree, not clone.** On one machine, opting a phase into parallel creates a git worktree (`git worktree add`) sharing the same repository — never a second clone; the operator opens a second session in that worktree directory, and it is removed after merge. A teammate on another machine uses a normal clone + the phase branch; the workflow is identical from there.
8. **Cross-stream visibility.** Because slice folders and dashboards are versioned files, a parallel phase's slices exist only on its branch — the main checkout's `works/backlog.md` stands still until merge. P12 must give the operator a cross-stream status view from the main checkout: a `workflow.py` command (e.g. `status --all`) listing the main-thread pointer plus each parallel phase's branch, worktree path, and slice statuses, read via git from the branch (`git show <branch>:works/...`) without switching checkouts. (Raised by the operator asking how to check branch slices while main's backlog is unchanged.)

**Backward compatibility is a hard requirement:** a workspace (or operator) that never opts in sees no behavioral change — same commands, same single-stream flow on main, same review-time consolidation.

Out of scope (deliberately): slice-level parallelism inside one phase (concurrent executors, real `depends_on`) — phase-level only.

## Clarifications Resolved

- Q: Does "drop consolidate point to the next job" mean moving doc consolidation out of the phase review to a post-merge job on main? — A: No — the operator meant the point `/do-next-slice` and `/do-whole-phase` look at to decide what to do next, i.e. the single global next-job pointer; drop that in favor of per-phase selection. (The post-merge doc-consolidation move was the assistant's addition and remains in scope as item 3 — the operator confirmed the overall proposal containing it.)
- Q: What grain of parallelism? — A: Phase-level only.
- Q: How far should the team/PR layer go in the first pass? — A: Full PR + CI flow now.
- Q: Create the phase now? — A: Yes.
- Amendment (operator, after creation): parallel work must be **opt-in**, not the new default — "based on main thread by default, make it possible to parallel work option." Default flow stays exactly as today; parallel mode is a per-phase option the operator explicitly engages. Assumption recorded (correctable): the opt-in is chosen per phase when the operator starts it in parallel (exact mechanism — flag, command, or phase field — is a DECOMP design decision).
- Amendment (operator, merge gate): PR/merge of a parallel phase branch may happen only when no phase is in progress on **both** main and the branch — the branch's phase done (review passed), and the main stream between phases. Reading confirmed with the operator as a quiet-point merge gate; a softer variant (merge at a clean *slice* boundary while a main phase is mid-flight) was noted but not chosen.
- Amendment (operator, at DECOMP planning, 2026-08-03): parallel stays opt-in, but the workspace **proactively suggests** the parallel workflow at **both** moments where it becomes relevant (operator chose "both" when asked): (a) when a new phase is created while an existing phase is `in_progress` (`/create-phase` / `new-phase`), and (b) when the operator tries to start executing a second phase while the current one is mid-flight (`do-next-slice` / `do-whole-phase` / `next`). A suggestion only, never a default — the operator still opts in explicitly.
- Amendment (operator, at DECOMP planning, 2026-08-03): the PR and merge are **basically done by the coding agent**, after the branch's review slice — once a parallel phase's review passes on its branch, the orchestrator itself runs the integration (push the branch, open the PR, check the quiet-point gate + CI, merge, then the post-merge step on main: rebuild + serialized doc consolidation + worktree teardown), not manual operator clicks. The quiet-point gate still rules: if main has a phase in progress, the agent stops and reports instead of merging.

## Notes

- Single-writer assumptions located in the engine: `resolve_current` (scripts/workflow.py:449) — global pointer; `next_doc_version_id` (scripts/workflow.py:278) — max+1 version allocation that collides across parallel branches; global dashboard rebuild on every transition; the "work on the current branch, including main" commit convention.
- The works/ layout is already parallel-ready: each phase's state, notebook, and slices live in a disjoint folder. Phase-branch merges become nearly conflict-free once a parallel phase defers consolidation to post-merge.
- Mixed operation must work: a parallel-mode phase on its branch alongside the default main-thread stream. A phase-branch checkout also contains the main-thread phases (forked from main), and main contains the parallel phase's folder — so selection needs a way to know which phases belong to which stream (e.g. a mode/branch field in `phase.json`), rather than relying on order alone.
