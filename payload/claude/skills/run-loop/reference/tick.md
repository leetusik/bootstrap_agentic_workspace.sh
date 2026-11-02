# run-loop — one tick: every action and its commands

`python3 scripts/workflow.py loop-tick <P>` is read-only. It prints the loop's context lines (`loop=`, `status=`, `driver=`, `charter=`, `cycle=`, `inflight=`, `spend_today=`, `spend_total=`, `parked=`, `survivors=`, `queue=`), then exactly one `action=` and `wake_in=<s>`, then that action's own lines (`cycle=`, `attempt=`, `stage=`, `item=`, `reason=`, `detail=`, `kind=`, …). Act on the one action, then run the tick again (`wake_in=0`) or end the turn with `ScheduleWakeup` (SKILL.md, *Pacing*).

## The actions

| `action=` | What you run |
|---|---|
| `apply-control` | `loop-control <P> apply`: applies the requests other sessions queued in `loop/control.json`. |
| `claim` | `loop-claim <P>`: this session becomes the driver (it takes over a dead driver). |
| `not-driver` | Nothing: another live session drives this loop. Keep the heartbeat (`wake_in` 1,800 s) and relay the operator's words as control requests. |
| `start` (`stage=`, `item=<key\|author>`) | `loop-cycle-start <P>`: it creates `<P>.C<k>`, takes the queue head and holds the lease. On `item=author`: `loop-cycle-start <P> --key <key> --title "…" [--payload '<json>']`, an item you authored (`reference/cycle-plan.md`). Commit the start with the next close, never alone. |
| `plan` (`cycle=`) | Write the cycle's `plan.md` (`reference/cycle-plan.md`; the forbidden list verbatim), with its `## Dispatch` from `executor-route <cycle>`. |
| `dispatch` (`cycle=`, `attempt=`) | `loop-cycle-dispatch <cycle>` **immediately before** the Agent call (it refuses on a live span, and within 300 s of the last recorded dispatch). From attempt 2, `executor-route <cycle> --retry` (the high row) and re-pin `## Dispatch`; the command prints the line to use. Then dispatch `slice-executor` in the background with the pinned `model`/`effort`, the prompt starting `slice: <cycle>`. |
| `wait` (`reason=`) | `ScheduleWakeup` with `wake_in`. `reason=dispatching` (a span is starting), `budget-day` (`until=` the local midnight), `cadence` (the charter's `min_gap_minutes`), `phase-<status>` (the phase is pending, blocked or done). With a live span, its completion notification is the real wake. |
| `close` (`cycle=`) | The cycle's `result.md` holds a verdict: close it by SKILL.md's *Closing a cycle* (`loop-cycle-close <cycle> --verdict …`), `record-dispatch`, then commit. This also covers a restart after the executor finished. |
| `overdue` (`cycle=`, `span=`) | `TaskStop` the span (when this session owns it), then `loop-cycle-close <cycle> --verdict error --summary "overdue: …"`, then commit. |
| `resume-limit` (`until=`, `span=`) | After the reset: `SendMessage` the span when this session owns it; otherwise `loop-cycle-dispatch <cycle>` and re-dispatch from disk (the attempt is unchanged). Until then, `ScheduleWakeup` at `wake_in`. |
| `halt` (`reason=`, `detail=`) | `loop-control <P> halt --reason <reason> --detail "<detail>"` (the tick writes nothing), then report (SKILL.md, *Halts*). Pass the tick's `reason` verbatim (`charter`, `budget-total`, `max-cycles`, `limit`); `budget-total` and `max-cycles` lift only by signing a new charter version. |
| `halted` / `paused` (`reason=`, `on_words=`) | Report once and wait on the heartbeat. Only the operator's words move it (SKILL.md, *The operator's words*). |
| `sign` | The charter is unsigned: present it (`loop/charter/v<N>.md`) by the contract's stop rules and wait for the operator's literal words, then `loop-sign <P> --words "…"`. |
| `digest` | `loop-status <P> --digest --write`, show it, `PushNotification` one line when the tool exists, commit `loop/digest.md`. |
| `setup` (`slice=`) | Run that slice the ordinary way (`do-next-slice`), then tick again. `reason=checkpoint` marks a fix slice a checkpoint asked for. |
| `checkpoint` (`reason=every\|requested`, `j=`) | `loop-checkpoint <P> --start`, then run it like a cycle (`reference/checkpoint.md`). |
| `fix` (`slice=`) | A checkpoint requested changes: cut one `new-slice --phase <P> --slice <P>.F<n> --name "…" --kind fix --risk high --depends-on none` per finding class from its `result.md` (the next free `F<n>`; a fix of mid-row cycle work is high), on the loop stream, commit, tick again. |
| `resume` (`reason=checkpoint`) | The checkpoint's fix slices are done: `loop-control <P> resume` (no words needed). |
| `review` (`slice=<P>.REVIEW`) | The loop is stopped: run the REVIEW (SKILL.md, *The end*). |

**A checkpoint in flight.** Every in-flight line of a checkpoint carries `kind=checkpoint`. Its `plan` is the window review's plan, its `dispatch` is `loop-cycle-dispatch <P>.K<j>` on the high row, its `close` is `loop-checkpoint <P> --verdict pass|changes_requested|blocked --summary "…"` (never `loop-cycle-close`), and its `overdue` is `TaskStop`, then `loop-checkpoint <P> --verdict blocked --summary "overdue"` (blocked alone needs no `result.md`).

## The rule order (first wins)

apply-control (when this session drives, or no one does) → claim / not-driver → the in-flight cycle or checkpoint (a halted loop only closes or waits) → the loop's status (drafting → `sign`; halted; paused by a checkpoint → `setup` / `resume` / `fix`; paused; stopped → `review`) → the phase pending or blocked (`wait`) → the charter (changed since signing → `halt reason=charter`) → budget-total / max-cycles (`halt`) → budget-day (`wait`) → `digest` → `checkpoint` → cadence (`wait`) → `setup` → `start`.

## The in-flight cycle, in detail

The first rule that holds wins: a verdict in `result.md` → `close`; no `plan.md` → `plan`; a live span → `wait`, or `overdue` past the charter's `cycle_timeout_minutes`; the current attempt's last span ended on a usage limit → `resume-limit` (or `halt reason=limit` with no reset time); a dead span (finished with no verdict, or its session ended) → `dispatch` with the next attempt; no span yet → `dispatch` (or `wait reason=dispatching` within 300 s of `loop-cycle-dispatch`).
