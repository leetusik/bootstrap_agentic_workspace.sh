---
name: run-loop
description: "Drive a signed loop phase one tick at a time: claim it, start, plan, dispatch, close and commit each cycle, run its checkpoints and digests, park items and halt only on the charter's stops; paced by /loop's ScheduleWakeup."
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent, ScheduleWakeup, TaskStop, SendMessage, PushNotification
disable-model-invocation: true
---

# run-loop

`/run-loop <P>` drives a **loop phase**: a phase whose work is a stream of bounded cycles under a signed charter (`loop/charter/v<N>.md`), each cycle one slice `<P>.C<k>` of kind `cycle`. You are the ORCHESTRATOR: you run the engine's tick, plan each cycle, dispatch it, close it and commit. The executor runs the cycle; the engine decides what comes next.

**Invariants (they hold on every tick):**

- **One tick = `loop-tick <P>`, then its one `action=`.** The tick is read-only and always right: never second-guess it, never skip ahead of it, never run two actions from one tick's output without running the tick again (bar `wake_in=0`, which means *run the next tick now*).
- **Never re-dispatch a live span.** `wait` means a span is running; its completion notification is the real wake.
- **Park, don't halt.** Only the charter's stops halt the loop, and the tick names them. Every item that needs the operator is parked, asked through the digest and `loop-status`, and never dropped.
- **Executors never commit** and never run `loop-*` or any other state command. You commit after every close.
- **Money and live actions stay behind the operator's words.** Spend the charter's `spend_covered` does not name halts the loop (`reason=spend`).
- **The forbidden list rides in every plan**, verbatim from the signed charter. The charter changes only through a new version the operator signs (`loop-sign`).
- **Cycle slices never write `phase.md`** (bar `## Now`). The loop's memory is `loop/` (queue, ledger, dead, survivors, parked).

**Resume (after a compaction or a restart):** the resume card's loop line and `loop-tick <P>` say what to do; run the tick and act on it. The tick prints `wait` for a live span: never re-dispatch it. After a restart, run `/loop /run-loop <P>` again: `loop-claim` takes over a dead driver and refuses while another live session drives the loop.

## When it applies

A loop phase (`next` prints a `loop=` line) whose charter is signed (until it is, the tick prints `sign`) and whose setup slices are done (until they are, `setup`). Start it in the loop's own session, and in its worktree when the operator asked for one: `/loop /run-loop <P>` for dynamic pacing, or `/run-loop <P>` to run ticks back to back until a wait or a halt. If the Skill tool refuses an invocation that `/loop` fired, read this SKILL.md and follow it: the operator's `/loop` is the invocation.

The loop's DECOMP (the charter draft, the setup slices) and its final REVIEW run by `do-whole-phase` / `do-next-slice`; this skill runs everything in between.

## One tick

The order, end to end: `loop-tick` → `loop-claim` | `loop-control apply` → `loop-cycle-start` → write `plan.md` → `loop-cycle-dispatch` → `executor-route` → Agent (background) → on its return `record-dispatch` → `loop-cycle-close` → commit → next tick.

Every action and the commands it runs, with the tick's rule order, are in `reference/tick.md`: **read it before the first tick of a session.**

## Pacing

Under `/loop`, end every tick that has nothing left to do in this turn with `ScheduleWakeup`:

- `delaySeconds`: the tick's `wake_in`, clamped to [60, 3600];
- `prompt`: the same `/loop` input, verbatim (e.g. `/run-loop <P>`);
- `reason`: one specific line (`cycle P7.C12 running; fallback wake`, `budget-day until 00:00`).

`wake_in=0` means run the next tick now, in the same turn. While an executor runs, schedule only the long fallback, never a poll: its completion notification is the real wake. A halted or paused loop keeps the heartbeat the tick gives, so control requests queued from other sessions are seen. A stopped loop that has handed off to its REVIEW ends `/loop` with `ScheduleWakeup` `stop: true`. Without `/loop`, run ticks back to back and stop at the first `wait` with `wake_in` > 0, or at a halt.

## A cycle's plan

`plan.md` starts with a `slice: <cycle id>` line and holds the item (key, title, payload), the charter's `## One cycle` procedure, its `## Forbidden` list **verbatim**, the `outputs` paths (the only product paths the cycle may write), the per-cycle budget, the `result.md` verdict lines the executor must return, and `## Dispatch` from `executor-route <cycle>`. The template and the authoring rule for an empty queue are in `reference/cycle-plan.md`: **read it before the first plan of a session.**

When the queue is empty (`item=author`), you author the next item from the charter's objective and the loop's memory (`loop-status`, the ledger tail, the dead list) and never retry a dead or tried key; the engine refuses one anyway. The charter defines a key's normalization; the product owns it.

## Closing a cycle: verdict → command

- Executor `done` with `item_verdict` → `loop-cycle-close <cycle> --verdict <item_verdict> --metrics '<json>' --summary "…"`.
- `needs_operator` with `need_scope: item` → `loop-cycle-close <cycle> --verdict parked --question "…" --on-words "…"`. The loop goes on.
- `needs_operator` with `need_scope: spend` → `loop-cycle-close <cycle> --verdict error --summary "uncovered spend: …"`, then `loop-control <P> halt --reason spend --detail "…"`, then report and stop.
- `blocked` → `--verdict error`.
- On attempt 1 (the stage's row: `screen`, `mid`, …), an `escalate`, or a failed or empty return → the tick prints `dispatch attempt=2 route=high`: `loop-cycle-dispatch <cycle>`, `executor-route <cycle>` (it prints the high row by itself), `## Retry` in the plan (`reference/cycle-plan.md`), re-dispatch.
- On attempt 2 (high), any of those → the tick prints `close verdict=error`: `--verdict error`. A cycle runs at most two attempts.
- `overdue` → `TaskStop` this session's span, then `--verdict error`.
- **An `error` close with dirty outputs** prints `dirty_outputs=`: read that diff, then commit it with the close (never revert it: the dead attempt may have acted outside the repo). The engine carries the paths onto the re-queued item, and its next cycle's plan reconciles them first (`## Prior footprint`), so it cannot file twice.

Record each dispatch with `record-dispatch`, as for every slice. **The commit**, at root: one commit holding the product outputs and the state, `chore(<P>): cycle C<k> <verdict> <key>`. In a nested install the host commit comes first, in the host's recorded conventions (`nested-convention`: no phase or slice IDs, no `workflow/` paths), then the nested state commit (`git -C workflow …`). Attribute each commit to the dispatch's `attribution=`. A close may print `rolled …` lines: the old cycle folders it removed ride in this same commit.

## Halts

Only the charter's stops halt: the budget spent, `max_consecutive_failures` failed cycles in a row, a usage limit with no reset time, uncovered spend, the operator's stop word, a blocked checkpoint. On a halt, report it in about 2k chars with the `next` stop and its `on_words`, then keep the heartbeat. A failed cycle is one with no item verdict; an item that fails the product's scorer is a successful cycle.

## Digest

On `action=digest`: run `loop-status <P> --digest --write`, show the digest to the operator, send a one-line `PushNotification` when the tool exists, and commit `loop/digest.md`.

## Checkpoint

On `action=checkpoint`: `loop-checkpoint <P> --start` → plan → `loop-cycle-dispatch <P>.K<j>` → Agent on the **high** row → `loop-checkpoint <P> --verdict pass|changes_requested|blocked --summary "…"` → commit → `loop-checkpoint <P> --landed` → commit. Its plan reviews only its window. **Read `reference/checkpoint.md` before you plan one**: the plan, `changes_requested`'s fix slices, and the landing.

## Coexistence (a loop in its own worktree)

At each cycle boundary, when the default branch has moved (`git merge-base --is-ancestor <default> HEAD` fails), run `git merge <default>` in the loop worktree (take either side of a `works/` conflict, then regenerate), then `parallel-merge-finish`. The default stream merges the loop's passing checkpoint commit: the `parallel-phase` skill, *A loop phase lands at its checkpoints*.

## The operator's words

Pause, resume, stop and "checkpoint now" work from any session: from another stream the engine queues them in the loop worktree's `loop/control.json`, writes nothing in the calling checkout, and the driver applies them at its next tick. Every other loop command (sign, unpark, queue, claim, the cycle commands) runs only on the loop's own stream and refuses elsewhere.

- "pause" → `loop-control <P> pause`.
- "resume" → `loop-control <P> resume --words "<their words>"`. It never resumes past a charter-level stop (a changed signed charter, `total_usd` spent, `max_cycles` run): it prints `not resumed`, the loop halts on that stop, and you relay its `on_words` (usually a new charter version). A new version that clears one cap but not the other likewise halts on the other.
- "stop" → `loop-control <P> stop --words "<their words>"`.
- "sign" on a charter → `loop-sign <P> --words "<their words>"`, only on the operator's literal words (a new version: `--version N`).
- "checkpoint now" → `loop-checkpoint <P> --now --words "<their words>"`.
- An answer to a parked item → `loop-unpark <P> <key> --to queue|survivor|dead --words "<their words>"`. A parked item a review or checkpoint routes to a deferred job: `defer-job`, then `loop-unpark <P> <key> --to deferred --pointer <DID>`. The final review cannot pass while one is open.
- "status" → `loop-status <P>`.

## Usage limits

On `resume-limit` (`until=`): if this session owns the span, `SendMessage` it after the reset; otherwise `loop-cycle-dispatch <cycle>` and re-dispatch from disk (the attempt does not change). Wake at the reset with `ScheduleWakeup`. A limit with no reset time is a halt (`stop_kind=limit`).

## The end

`loop-control <P> stop --words "…"` → the in-flight cycle closes → the tick prints `review` → run the phase's REVIEW by `.claude/skills/do-whole-phase/reference/review.md` (*A loop phase's final review*) → `ScheduleWakeup` with `stop: true`.
