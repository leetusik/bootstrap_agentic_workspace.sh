# A wave: several slices at once (the orchestrator's side)

Read this when `DECOMP` declared the phase's slices (`next` prints `ready_slices=`). *Resume* runs at every session start, after every compaction and before every start or commit; the rest applies when `ready_slices=` lists more than one id, or a slice becomes ready while others run. The executor's side is `playbooks/wave.md`. `/do-next-slice` never runs a wave; an explain phase declares nothing.

## What the engine prints

- `ready_slices=<ids|none>`: the slices that may start now. A declared slice is ready when every slice it depends on is `done`. A **barrier** (`DECOMP`, `DECOMP2`, `REVIEW`, a co-work slice, every undeclared slice) is ready only alone and ends the walk.
- `running_slices=<ids|none>`: the wave's slices `in_progress`. With a stop on disk, `ready_slices=none -- stopped by <id>…`: nothing new starts.
- The resume card's `wave:` line: running, returned (a `result.md` exists), ready, stops. `start-slice` warns, never refuses, on a start the ready set would not make.

## Sets

Each slice's **set** is in its `## <slice id>` block of `topics/breakdown.md`: its files, the generated files it regenerates, any numbered sequence it extends, any shared runtime resource it holds. Two slices with no dependency path between them have disjoint sets. **The join-rebuilt artifact is the one exception.** A build output regenerated from many slices' sources is in no set; you rebuild it once at the join. Two ready slices whose sets overlap anyway: start the lower-ordered one, say so in `## Now`.

## Start

- **Every ready slice starts; there is no cap.** Plan each (a spending slice still plans at the gate), then for each: `executor-route`, pin `## Dispatch`, `start-slice`, and dispatch them all in one message, in the background, each prompt starting `slice: <id>`.
- **Each wave slice's `plan.md` carries `## Wave`, before `## Dispatch`:** its set (plus any path an answer added), the slices beside it with their sets, each `done` slice whose commit still waits with its set, the join-rebuilt artifact or `none`, and its set-scoped checks. Write it afresh at every dispatch. A slice dispatched while nothing else runs, starts, is stopped or waits to commit gets none and commits all its changes.
- **Rolling starts.** After each return, start every newly ready slice. **A shared file waits for its commit:** a slice whose set overlaps a waiting commit's set starts once that commit is in. A stopped slice's re-dispatch is not a start.
- While executors run you write only the wave's state commands, a starting slice's `plan.md`, an answered set change, and a returned slice's notebook entries and commit.

## At each return

1. `record-dispatch`. On `done`, **check its edits against the sets:** every product path in its `files_changed`, and every dirty product path in the tree (`git status --porcelain --untracked-files=all`, both sides of a rename; the workflow state and the artifact aside), must be in the set of a slice in flight or named by a check stop on disk. A path that fails is a **check stop** naming every such path: `set-slice-status <id> pending --stop-kind decision --on-words "check stop on <path>, …: revert each, or add it to a slice's set"`; nothing of the slice is finished or committed, and any commit whose set holds that path waits. On the answer, revert the path or write it into a `## Wave` set line, then `set-slice-status <id> in_progress && finish-slice <id> --outcome "…"` in one command. Otherwise `finish-slice <id> --outcome "<summary>"`.
2. Write its `notebook` entries one entry at a time, through `phase-section` only: Operator Questions `--append`ed and numbered `OQ<n>` by you in finish order; Decisions and Notes merged entry by entry (`--append`, `--entry K --replace`, a consumed note `--entry K --remove`); `## Now` rewritten for the whole wave. Run any `notebook_move=` lines here.
3. `validate`.
4. **One commit per slice: its host paths first, then its workflow state.** Its host paths are every dirty path of its set, read from the tree with `git status --porcelain --untracked-files=all -- <set>` (never without a path); `git add --` only the new ones, then `git commit -- <paths>`; never `git add -A`, never `--no-verify`. A slice that ran alone takes every dirty product path. **A `done` slice whose `slice.json` is uncommitted is a commit that waits.** In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions are the workflow's history. Product commits are unchanged. In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`; run `mark-committed <slice>` after its product commit (with no product change, right after its finish).
5. **When it commits.** **Rolling (the default).** With no in-flight slice touching the artifact's sources, commit at once; a hook failure or busy index lock while siblings run holds every commit and start until the set drains, then commit in finish order. **At the join.** When an in-flight slice touches the artifact's sources, every commit waits for the drain; then rebuild the artifact once and commit in finish order, the artifact with the last host commit.
6. `next`, and start what it lists, unless a stop is on disk or a held commit holds starts; a barrier starts only once no commit waits.

## Stops

Every stop goes to disk the moment it returns: `needs_operator` → `pending --stop-kind decision|operator-action`; `blocked` → `blocked`; a failed high return → `pending --stop-kind other --on-words "re-dispatch <id> on the high row"`. The running siblings finish and are committed, nothing new starts, and the run STOPS with every stop reported. A mid `escalate` re-dispatches on the high row at once: it is that slice's second attempt, not a start.

## Resume

1. **The commits that still wait:** `git status --porcelain --untracked-files=all` on the phase's `slices/` folder (the workflow repo), reading only `slice.json` lines. A `done` slice whose `slice.json` is uncommitted waits (unless its committed copy already says `done`); then read each `pending` slice's `on_words`. Finish each waiting slice in finish order from step 2 (its `result.md` holds its `notebook`), unless a check stop names a path in its set.
2. **Then each slice `in_progress`:** wait for every running span and never re-dispatch one (after a compaction, the card's running spans). At a fresh session's start none is running: a slice whose `result.md` verdict says `done` is finished by *At each return*; any other is re-dispatched from disk.

While a wave runs, prepare only the next frontier (slices whose every open dependency is running now), read-only.
