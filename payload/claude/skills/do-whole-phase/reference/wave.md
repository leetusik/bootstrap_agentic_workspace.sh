# do-whole-phase — a wave: several slices at once

Read this when the phase's `DECOMP` **declared** its slices (`--depends-on <id>` or `--depends-on none`) and `next` prints `ready_slices=` with more than one id, or a slice becomes ready while others still run, and after every compaction in a declared phase (*After a compaction*). Otherwise (nothing declared, one ready slice, a barrier) the loop in `SKILL.md` is unchanged and none of this applies. `/do-next-slice` never runs a wave, and an explain phase declares nothing, so it stays sequential.

## What the engine prints

A declared phase's `next` (and `run-phases`) adds, after `next_slice=` and in its WAITING branch, the lines below. While a barrier runs alone it adds none and the card has no `wave:` line: the phase then reads as an undeclared one.

- `ready_slices=<ids|none>`: the slices that may start now, by order. A declared slice is ready when it is `todo` or `ready` and every slice it depends on is `done`. A **barrier** (`DECOMP`, `DECOMP2`, `REVIEW`, a `co-work` slice, and every undeclared slice) is ready only alone: first open slice, nothing in progress. It also ends the walk, so nothing behind a barrier starts before it is done.
- `running_slices=<ids|none>`: the wave's slices `in_progress`, never a barrier.
- With a stop on disk (a `pending` or `blocked` slice anywhere): `ready_slices=none -- stopped by <id> (<status>)…: nothing new starts while a stop is on disk`, and if slices run, `running_slices=<ids> -- already running beside the stop: wait for each, then finish and commit it`.
- `current_slice=` / `target_slice=` stay the plain pointer (the first open slice). In a wave they name the first open slice, which may already be running: the work is the whole `ready_slices=` list.
- The resume card adds `wave: running=<ids>; returned=<ids>; ready=<ids>; stops=<ids> -- …`, and a `stop: slice <id> …` line for a sibling's stop the pointer does not show. `returned` are the running slices whose `result.md` exists.
- `start-slice` warns, never refuses: it prints one `warning:` line, and still starts the slice, for a start the ready set would not make (a declared slice whose dependency is not `done`, or a barrier beside a running slice).

## Declaration and independence

`DECOMP` declares every non-barrier slice and writes each slice's **set** in its breakdown (`reference/decomposition.md`). What you rely on: any two slices with no dependency path between them (neither depends on the other, even transitively) have **disjoint sets**. A set is a slice's files; the generated files its edits regenerate; any numbered sequence it extends (migrations, doc versions); any shared runtime resource it mutates or holds (a local database, a fixed port, the agent's Aside profile).

**The join-rebuilt artifact is the one exception.** A build output regenerated from many slices' sources (a bundled single file, a compiled asset) is not counted as overlap: `DECOMP` names it, with its sources and the command that rebuilds it. A wave executor never rebuilds it; you rebuild it once at the join (*At each return*), so two slices that edit different sources of it may run together.

If two ready slices' sets overlap anyway, that is a defect in `DECOMP`: start only the lower-ordered one, say so in `## Now`, and start the other when it is done.

## Planning and dispatching a wave

- **Every ready slice starts: there is no cap.** Plan each one, then dispatch them together.
  - `auto` (the default): plan each inline and `Write` its `plan.md`. A slice that spends money still plans at the gate (`reference/modes.md`), so its approval comes before the wave's dispatch.
  - `gate`: approve each plan in turn (`EnterPlanMode` → `ExitPlanMode`), copying each approved plan to its slice's `plan.md` at once, as `reference/modes.md` says; then dispatch them together.
  - `plan only` is unchanged: plans are readied one at a time and nothing runs. A `ready` (`[r]`) slice dispatches from its approved plan, with its `## Wave` section added first.
- **Each wave slice's `plan.md` carries a `## Wave` section, placed before `## Dispatch`:** its declared set; the slices running or starting beside it, with their sets; each `done` slice whose commit still waits (*At each return* step 4), with its `files_changed`; the join-rebuilt artifact (the executor never rebuilds it) or `none`; and the checks scoped to its own set. That section is what puts the executor under the wave rules in `slice-executor.md`. Write it afresh at every dispatch, a re-dispatch after a stop or an escalation included. A slice dispatched alone (one id in `ready_slices=`, nothing running) gets none: nothing can join it, because a slice becomes ready only when a running one finishes, and no commit waits then (the drain commits them before any start).
- Then, for each slice: `executor-route <slice>` and pin its `## Dispatch`; `start-slice <slice>`; and dispatch all of them in **one message**, as background tasks, each prompt starting `slice: <id>`, with its own `model` and `effort`.
- **Rolling starts.** After each return, recompute (`next`) and start every newly ready slice while the others still run. A slice whose dependencies are done never waits for the rest of the wave; it starts as a wave slice, its `## Wave` naming what runs beside it. **A shared file waits for its commit:** a slice whose set shares a file with a `done` slice's `files_changed` while that slice's commit still waits (its folder uncommitted, *At each return* step 4) starts only once that commit is in (at the join, after the drain), so each commit holds only its own slice's edits. `next` cannot see commits, so this check is yours; the join-rebuilt artifact is in no set and never counts.
- **While executors run you write only what this protocol gives you:** the state commands of wave slices (`start-slice`, `finish-slice`, `record-dispatch`, a stop's `set-slice-status`), the `plan.md` of a slice about to start, and the notebook entries and commit of a slice that has returned. You never edit a running slice's files.

## The executor in a wave

When its `plan.md` carries `## Wave`, the executor (`slice-executor.md`):

- writes **no `phase.md`**: it returns its entries in a `notebook` field of its verdict (so its `result.md` verdict block holds them too), by section (Decisions, Notes for later slices, Doc impact, Operator Questions, Now). Long material goes in a new `topics/<slug>.md` of its own, and the entry is one line linking it;
- runs **no engine command that writes**; `validate` and `phase-section` reads are fine;
- edits **only its declared set**. Any other file it needs, whether in a sibling's set, in a waiting commit's files or in no set at all, means the declaration was wrong, and a stronger row would hit the same wall, so on either row it returns `needs_operator` naming the file and the slice whose set or commit holds it, if any (a stop like any other, below). Once the operator has answered, re-dispatch it (the file added to its set, if that is the answer) as soon as no running slice's set and no waiting commit holds the file. No out-of-set edit is allowed, because one could land in another slice's commit: a sibling started after this slice, or another out-of-set edit, may hold the same file;
- regenerates only the generated files in its own set, and **never a join-rebuilt artifact**;
- runs only the checks scoped to its own set, and lists every whole-tree check it left out (a full suite, a whole-project typecheck or build, a check the repo's rules say must run alone) as `deferred: whole-tree` in its `validation`. The review runs those with every other slice's commands. A failure that traces to a file outside its set is a sibling's work in flight: it reports it and never fixes it.

## At each return

Handle returns one at a time, in the order they come in.

1. `record-dispatch`. On `done`: `finish-slice <id> --outcome "<its summary>"`.
2. Write its `notebook` entries with `phase-section <P> <name>`, reading each section first and sending it back whole. Doc impact and Operator Questions are **appended**; number each question `OQ<n>` yourself, in finish order, because the executor cannot see its siblings' numbers. Decisions and Notes are merged: replace a superseded line, and remove the notes this slice consumed. Rewrite `## Now` **for the whole wave**: what landed, what is running, what is next.
3. `validate`.
4. **The slice's commit, one per slice: its host paths first, then its workflow state**, at the time step 5 gives. The host commit stages its `files_changed` only (the join-rebuilt artifact rides only with the last, step 5), attributed to its dispatch's model. The workflow state is its slice folder and its `topics/` file: in a single-repo install they ride in that same commit; in a nested pair they go to the nested repo right after it. A rolling commit, or the last of several that waited (held, or at the join), also carries `phase.md` and the generated state, which hold every entry so far. Explicit paths only: never `git add -A`, never `--no-verify`. **So a `done` slice whose folder is still uncommitted is exactly a commit that waits**: no other record is kept, and the start rules and *After a compaction* read this one.
5. **When it commits** depends on the join-rebuilt artifact:
   - **Rolling (the default).** When no running or finished-uncommitted slice touches the artifact's sources (or the phase has none), commit at once, alone. A hook failure or a busy index lock while siblings run **holds** that commit, every later commit and every new start until the running set drains; then commit the held ones in finish order. A worktree-wide hook can trip on a sibling's half-done edit, and a drained tree is the honest test; a commit that still fails there is fixed like any slice's failed commit, and nothing starts until it is in.
   - **At the join.** When a running or finished-uncommitted slice touches the artifact's sources, **every commit waits until the running set drains.** Then rebuild the artifact once, and commit each slice in finish order, **the rebuilt artifact with the last host commit** (that slice's workflow state also carries `phase.md` and the generated state, step 4). The earlier commits carry their sources without the rebuilt artifact, an exception to a same-commit rebuild rule that holds for a wave's commits only (the `DECOMP` gate approved the artifact's naming); the pre-commit hook still passes, because it reads the worktree, which is rebuilt by then.
6. Recompute the ready set (`next`; `run-phases` in a run) and start what it lists, unless a stop is on disk or a held commit (*Rolling*) holds starts. A listed slice that shares a file with a waiting commit starts once that commit is in (*Rolling starts*), and a barrier (`REVIEW` included) only once no commit waits.

## Stops and retries

- **Every stop goes to disk the moment it returns**, so the ready set empties and a compaction cannot restart work:
  - `needs_operator` → `set-slice-status <id> pending --stop-kind decision|operator-action --on-words "<its operator_need>"`;
  - `blocked` → `set-slice-status <id> blocked`;
  - a failed or empty high-row return → `set-slice-status <id> pending --stop-kind other --on-words "re-dispatch <id> on the high row"`.
- The running siblings then **finish and are committed** as above, nothing new starts, and the run STOPS with every stop reported. If the stopped slice touches the artifact's sources, its half-done edits are in the tree: rebuild anyway so the hook passes, commit the siblings, and leave the artifact uncommitted for that slice's re-run, saying so in the report.
- A mid `escalate` (or a failed or empty mid-row return) re-dispatches on the high row at once, even while the run is stopping: it is that slice's own second attempt, not a new start, and the limit stays one per slice (`reference/verdicts.md`).

## After a compaction

This runs after every compaction in a declared phase, before you start anything (`SKILL.md` and `do-whole-phases` give the same trigger).

1. **First, the commits that still wait.** The card shows no waiting commit, and once the running set drains it points at the barrier. So run `git status --porcelain` on the phase's `slices/` folder, in the repo that holds the workflow state (the nested repo in a nested pair). **A `done` slice with uncommitted changes in its folder has a commit that waits** (*At each return* step 4), held, at the join, failed, or cut off by the compaction; a slice whose folder is committed never waits, even while a later slice edits its files, and nothing else is read: no ownership, no clock. Take each waiting slice in finish order (`completed_at`) and finish *At each return* where it stopped: write the `notebook` entries `phase.md` still lacks (its `result.md` verdict block holds them), `validate`, then commit it by step 4 when step 5 says. Its dirty `files_changed` paths are its own: while its commit waits no other slice may edit them (a wave slice edits only its set, *Rolling starts* keeps a sharer out, and a lone slice had nothing beside it). When none is dirty, its host commit is already in and only its workflow state is left. Step 6's holds stand until they are in: no barrier, and no slice that shares a file with a waiting one. While a barrier runs alone this finds nothing, because a barrier starts only once no commit waits.
2. Then the card's `wave:` line says it: **wait for every running span and never re-dispatch one**; finish each slice in `returned=` (its `result.md` exists), then commit it by *At each return*; start `ready=` only while no stop is on disk. The contract's kept facts already list each running executor's slice id.

## The idle window

While a wave runs, prepare only the **next frontier**: slices whose every open dependency is running now, never further ahead. The rest of `reference/prep.md` holds: read-only, never block, discard on any verdict other than `done`.

## Unchanged

`reference/dispatch.md`, the explain references, the `plan only` and spend gates, a design wave's spans inside one `co-work` slice, and `/do-next-slice`. The phase stays the unit of *worktree* parallelism (`reference/worktree.md`).
