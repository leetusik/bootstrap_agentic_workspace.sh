---
name: run-loop
description: "Drive a signed loop phase one tick at a time: claim it, start, plan, dispatch, close and commit each cycle, run its checkpoints and digests, park items and halt only on the charter's stops; paced by /loop's ScheduleWakeup."
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent, ScheduleWakeup, TaskStop, SendMessage, PushNotification
disable-model-invocation: true
---

# run-loop

`/run-loop <P>` drives a **loop phase**: a stream of bounded cycles under a signed charter (`loop/charter/v<N>.md`), each cycle one slice `<P>.C<k>` of kind `cycle`. You run the engine's tick, plan each cycle, dispatch it, close it and commit; the executor runs the cycle; the engine decides what comes next. The loop's DECOMP (charter draft, setup slices) and its final REVIEW run by `do-whole-phase`.

**Invariants:**

- **One tick = `loop-tick <P>`, then its one `action=`.** The tick is read-only and always right: never skip ahead of it or run two actions from one output (bar `wake_in=0`: run the next tick now).
- **Never re-dispatch a live span.** `wait` means one runs; its completion notification is the real wake.
- **Park, don't halt.** Only the charter's stops halt, and the tick names them. An item that needs the operator is parked and asked through the digest, never dropped.
- **You commit after every close**; executors never commit or run a `loop-*` or state command.
- **Money stays behind the operator's words:** spend the charter's `spend_covered` does not name halts the loop (`reason=spend`).
- **The forbidden list rides in every plan**, verbatim. The charter changes only by a new version the operator signs (`loop-sign`).

**Resume (after a compaction or a restart):** run `loop-tick <P>` and act on it; `wait` means a live span, never re-dispatch it. After a restart run `/loop /run-loop <P>` again: `loop-claim` takes over a dead driver and refuses while another live session drives.

## Starting

The phase prints a `loop=` line in `next`; until the charter is signed the tick prints `sign`, until the setup slices are done `setup`. Start in the loop's own session (its worktree when the operator asked for one): `/loop /run-loop <P>` for paced ticks, or `/run-loop <P>` to run ticks back to back until a wait or a halt. If the Skill tool refuses an invocation `/loop` fired, read this file and follow it.

**The driver's environment.** Drive a loop from one Claude Code session only: the claim, span liveness and the dispatch hold-off read Claude Code's internal session registry (`${CLAUDE_CONFIG_DIR:-~/.claude}/sessions/<pid>.json`, undocumented); without it a claim prints `driver=none` and the guards weaken to transcript times and a 300 s window. A **headless driver** (`claude -p "/run-loop <P>"`) in an untrusted directory ignores the install's allow list: trust it once interactively, or pass `--allowedTools` covering the engine, `git` and the cycle's own command, never `--dangerously-skip-permissions`. A denied call closes the cycle `error`; never widen the bounds to absorb repeats.

## One tick

`loop-tick` → `loop-claim` | `loop-control apply` → `loop-cycle-start` → `plan.md` → `loop-cycle-dispatch` → `executor-route` → Agent (background) → on return `record-dispatch` → `loop-cycle-close` → commit → next tick. Every action and its commands: `reference/tick.md`, **read before a session's first tick**. A cycle's plan: `reference/cycle-plan.md`, **read before a session's first plan**. A checkpoint: `reference/checkpoint.md`.

**Pacing.** Under `/loop`, end a tick with nothing left this turn with `ScheduleWakeup` (`delaySeconds` the tick's `wake_in` clamped to [60, 3600], `prompt` the same `/loop` input, `reason` one line); while an executor runs, only the long fallback, never a poll. A halted or paused loop keeps the heartbeat.

## Closing a cycle: verdict → command

- `done` with `item_verdict` → `loop-cycle-close <cycle> --verdict <item_verdict> --metrics '<json>' --summary "…"`.
- `needs_operator`, `need_scope: item` → `--verdict parked --question "…" --on-words "…"`; the loop goes on.
- `needs_operator`, `need_scope: spend` → `--verdict error --summary "uncovered spend: …"`, `loop-control <P> halt --reason spend --detail "…"`, report, stop.
- `blocked` → `--verdict error`.
- Attempt 1 escalated, failed or came back empty → the tick prints `dispatch attempt=2 route=high` (`## Retry` in the plan); attempt 2 likewise → `close verdict=error`. At most two attempts.
- `overdue` → `TaskStop` this session's span, then `--verdict error`.
- **An `error` close with dirty outputs** prints `dirty_outputs=`: commit that diff with the close, never revert it; the re-queued item's next plan reconciles it (`## Prior footprint`), so it cannot file twice.

`record-dispatch` each dispatch. **The commit**, at root one commit of outputs and state, `chore(<P>): cycle C<k> <verdict> <key>`; nested, the host commit first in its recorded conventions (no IDs, no `workflow/` paths), then `git -C workflow …`. In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions are the workflow's history. Product commits are unchanged. In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`; run `mark-committed <slice>` after its product commit (with no product change, right after its finish). Attribute each commit to the dispatch's `attribution=`; `rolled …` folders ride in the same commit.

## Halts, digests, checkpoints

**Halts:** only the charter's stops (budget spent, `max_consecutive_failures` in a row, a usage limit with no reset, uncovered spend, the stop word, a blocked checkpoint). Report in about 2k chars with the stop and its `on_words`, then keep the heartbeat. A failed cycle has no item verdict; an item failing the product's scorer is a successful cycle.

**Digest** (`action=digest`): `loop-status <P> --digest --write`, show it, one-line `PushNotification` when the tool exists, commit `loop/digest.md`.

**Checkpoint** (`action=checkpoint`): `reference/checkpoint.md`.

**Coexistence** (a loop in its own worktree): `parallel-phase`, *A loop phase lands at its checkpoints* (the default branch merged back at each cycle boundary when `git merge-base --is-ancestor <default> HEAD` fails).

## The operator's words

Pause, resume, stop and "checkpoint now" work from any session: elsewhere the engine queues them in the live loop's `loop/control.json` and the driver applies them at its next tick. Every other loop command runs only on the loop's own stream and refuses elsewhere; `loop-status <P>` reads the live loop from anywhere.

- "pause" → `loop-control <P> pause`; "stop" → `loop-control <P> stop --words "<their words>"`.
- "resume" → `loop-control <P> resume --words "<their words>"`; it never resumes past a charter-level stop (`not resumed`): relay its `on_words`, usually a new charter version.
- "sign" → `loop-sign <P> --words "<their words>"` (`--version N` for a new one), only on their literal words.
- "checkpoint now" → `loop-checkpoint <P> --now --words "<their words>"`.
- An answer to a parked item → `loop-unpark <P> <key> --to queue|survivor|dead --words "<their words>"`; one routed to a deferred job: `defer-job`, then `loop-unpark <P> <key> --to deferred --pointer <DID>`.

**Usage limits** (`resume-limit`, `until=`): after the reset, `SendMessage` the span this session owns, else `loop-cycle-dispatch <cycle>` and re-dispatch from disk (same attempt); wake with `ScheduleWakeup`. No reset time is a halt.

**The end:** `loop-control <P> stop --words "…"` → the in-flight cycle closes → the tick prints `review` → the REVIEW by `.claude/skills/do-whole-phase/reference/review.md` (*A loop phase's final review*) → `ScheduleWakeup` with `stop: true`.
