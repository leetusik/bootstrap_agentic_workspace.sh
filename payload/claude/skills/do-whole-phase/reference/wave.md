# do-whole-phase — a wave: several slices at once

Read this when the phase's `DECOMP` **declared** its slices (`--depends-on <id>` or `--depends-on none`) and `next` prints `ready_slices=` with more than one id, or a slice becomes ready while others still run. Otherwise (nothing declared, one ready slice, a barrier) the loop in `SKILL.md` is unchanged and none of this applies. `/do-next-slice` never runs a wave, and an explain phase declares nothing, so it stays sequential.

## What the engine prints

A declared phase's `next` (and `run-phases`) adds, after `next_slice=` and in its WAITING branch:

- `ready_slices=<ids|none>`: the slices that may start now, by order. A declared slice is ready when it is `todo` or `ready` and every slice it depends on is `done`. A **barrier** (`DECOMP`, `DECOMP2`, `REVIEW`, a `co-work` slice, and every undeclared slice) is ready only alone: first open slice, nothing in progress. It also ends the walk, so nothing behind a barrier starts before it is done.
- `running_slices=<ids|none>`: the slices `in_progress`.
- With a stop on disk (a `pending` or `blocked` slice anywhere): `ready_slices=none -- stopped by <id> (<status>)…: nothing new starts while a stop is on disk`, and if slices run, `running_slices=<ids> -- already running beside the stop: wait for each, then finish and commit it`.
- `current_slice=` / `target_slice=` stay the plain pointer (the first open slice). In a wave they name the first open slice, which may already be running: the work is the whole `ready_slices=` list.
- The resume card adds `wave: running=<ids>; returned=<ids>; ready=<ids>; stops=<ids> -- …`, and a `stop: slice <id> …` line for a sibling's stop the pointer does not show. `returned` are the running slices whose `result.md` exists.

## Declaration and independence

`DECOMP` declares every non-barrier slice and writes each slice's **set** in its breakdown (`reference/decomposition.md`). What you rely on: any two slices with no dependency path between them (neither depends on the other, even transitively) have **disjoint sets**. A set is a slice's files; the generated files its edits regenerate; any numbered sequence it extends (migrations, doc versions); any shared runtime resource it mutates or holds (a local database, a fixed port, the agent's Aside profile).

**The join-rebuilt artifact is the one exception.** A build output regenerated from many slices' sources (a bundled single file, a compiled asset) is not counted as overlap: `DECOMP` names it, with its sources and the command that rebuilds it. A wave executor never rebuilds it; you rebuild it once at the join (*At each return*), so two slices that edit different sources of it may run together.

If two ready slices' sets overlap anyway, that is a defect in `DECOMP`: start only the lower-ordered one, say so in `## Now`, and start the other when it is done.

## Planning and dispatching a wave

- **Every ready slice starts: there is no cap.** Plan each one, then dispatch them together.
  - `auto` (the default): plan each inline and `Write` its `plan.md`. A slice that spends money still plans at the gate (`reference/modes.md`), so its approval comes before the wave's dispatch.
  - `gate`: approve each plan in turn (`EnterPlanMode` → `ExitPlanMode`), copying each approved plan to its slice's `plan.md` at once, as `reference/modes.md` says; then dispatch them together.
  - `plan only` is unchanged: plans are readied one at a time and nothing runs. A `ready` (`[r]`) slice dispatches from its approved plan, with its `## Wave` section added first.
- **Each wave slice's `plan.md` carries a `## Wave` section, placed before `## Dispatch`:** its declared set; the slices running or starting beside it, with their sets; the join-rebuilt artifact (the executor never rebuilds it) or `none`; and the checks scoped to its own set. That section is what puts the executor under the wave rules in `slice-executor.md`. A slice dispatched alone (one id in `ready_slices=`, nothing running) gets none: nothing can join it, because a slice becomes ready only when a running one finishes.
- Then, for each slice: `executor-route <slice>` and pin its `## Dispatch`; `start-slice <slice>`; and dispatch all of them in **one message**, as background tasks, each prompt starting `slice: <id>`, with its own `model` and `effort`.
- **Rolling starts.** After each return, recompute (`next`) and start every newly ready slice while the others still run. A slice whose dependencies are done never waits for the rest of the wave; it starts as a wave slice, its `## Wave` naming what runs beside it.
- **While executors run you write only what this protocol gives you:** the state commands of wave slices (`start-slice`, `finish-slice`, `record-dispatch`, a stop's `set-slice-status`), the `plan.md` of a slice about to start, and the notebook entries and commit of a slice that has returned. You never edit a running slice's files.

## The executor in a wave

When its `plan.md` carries `## Wave`, the executor (`slice-executor.md`):

- writes **no `phase.md`**: it returns its entries in a `notebook` field of its verdict, by section (Decisions, Notes for later slices, Doc impact, Operator Questions, Now). Long material goes in a new `topics/<slug>.md` of its own, and the entry is one line linking it;
- runs **no engine command that writes**; `validate` and `phase-section` reads are fine;
- edits **only its declared set**. A needed file that sits in no sibling's set may be edited, and is listed as a deviation. A file in a sibling's set means the declaration was wrong and a stronger row would hit the same wall, so on either row it returns `needs_operator` naming the file and the sibling (a stop like any other, below); once the operator has answered, re-dispatch that slice when the sibling is done;
- regenerates only the generated files in its own set, and **never a join-rebuilt artifact**;
- runs only the checks scoped to its own set, and lists every whole-tree check it left out (a full suite, a whole-project typecheck or build, a check the repo's rules say must run alone) as `deferred: whole-tree` in its `validation`. The review runs those with every other slice's commands. A failure that traces to a file outside its set is a sibling's work in flight: it reports it and never fixes it.

## At each return

Handle returns one at a time, in the order they come in.

1. `record-dispatch`. On `done`: `finish-slice <id> --outcome "<its summary>"`.
2. Write its `notebook` entries with `phase-section <P> <name>`, reading each section first and sending it back whole. Doc impact and Operator Questions are **appended**; number each question `OQ<n>` yourself, in finish order, because the executor cannot see its siblings' numbers. Decisions and Notes are merged: replace a superseded line, and remove the notes this slice consumed. Rewrite `## Now` **for the whole wave**: what landed, what is running, what is next.
3. `validate`.
4. **Commit the workflow state at once**, naming explicit paths: the slice folder, `phase.md`, its `topics/` file and the generated state. In a nested pair that is the nested repo's commit; in a single-repo install the paths ride in the slice's host commit and wait with it. Never `git add -A`, never `--no-verify`.
5. **Commit the slice's host paths**, one commit per slice, its `files_changed` only, attributed to its dispatch's model. Which way depends on the join-rebuilt artifact:
   - **Rolling (the default).** When no running or finished-uncommitted slice touches the artifact's sources (or the phase has none), commit at once, alone. A hook failure or a busy index lock while siblings run **holds** that commit, every later host commit and every new start until the running set drains; then commit the held ones in finish order. A worktree-wide hook can trip on a sibling's half-done edit, and a drained tree is the honest test.
   - **At the join.** When a running or finished-uncommitted slice touches the artifact's sources, **every host commit waits until the running set drains.** Then rebuild the artifact once, and commit each slice's own paths in finish order, **the rebuilt artifact with the last of them**. The earlier commits carry their sources without the rebuilt artifact, an exception to a same-commit rebuild rule that holds for a wave's commits only (the `DECOMP` gate approved the artifact's naming); the pre-commit hook still passes, because it reads the worktree, which is rebuilt by then. A barrier (`REVIEW`) starts only after the join's commits are in.
6. Recompute the ready set (`next`; `run-phases` in a run) and start what it lists, unless a stop is on disk or a held commit (*Rolling*) holds starts.

## Stops and retries

- **Every stop goes to disk the moment it returns**, so the ready set empties and a compaction cannot restart work:
  - `needs_operator` → `set-slice-status <id> pending --stop-kind decision|operator-action --on-words "<its operator_need>"`;
  - `blocked` → `set-slice-status <id> blocked`;
  - a failed or empty high-row return → `set-slice-status <id> pending --stop-kind other --on-words "re-dispatch <id> on the high row"`.
- The running siblings then **finish and are committed** as above, nothing new starts, and the run STOPS with every stop reported. If the stopped slice touches the artifact's sources, its half-done edits are in the tree: rebuild anyway so the hook passes, commit the siblings, and leave the artifact uncommitted for that slice's re-run, saying so in the report.
- A mid `escalate` (or a failed or empty mid-row return) re-dispatches on the high row at once, even while the run is stopping: it is that slice's own second attempt, not a new start, and the limit stays one per slice (`reference/verdicts.md`).

## After a compaction

The card's `wave:` line says it: **wait for every running span and never re-dispatch one**; finish each slice in `returned=` (its `result.md` exists), then commit it by *At each return*; start `ready=` only while no stop is on disk. The contract's kept facts already list each running executor's slice id.

## The idle window

While a wave runs, prepare only the **next frontier**: slices whose every open dependency is running now, never further ahead. The rest of `reference/prep.md` holds: read-only, never block, discard on any verdict other than `done`.

## Unchanged

`reference/dispatch.md`, the explain references, the `plan only` and spend gates, a design wave's spans inside one `co-work` slice, and `/do-next-slice`. The phase stays the unit of *worktree* parallelism (`reference/worktree.md`).
