# run-loop — one tick

`python3 scripts/workflow.py loop-tick <P>` is read-only. It prints the loop's context lines, exactly one `action=` with `wake_in=<s>`, then that action's lines (`cycle=`, `attempt=`, `stage=`, `item=`, `reason=`, `detail=`, `kind=`, …). Act on the one action, then tick again (`wake_in=0`) or end the turn with `ScheduleWakeup`.

| `action=` | What you run |
|---|---|
| `apply-control` | `loop-control <P> apply`: the requests other sessions queued. |
| `claim` | `loop-claim <P>`: this session drives (it takes over a dead driver). |
| `not-driver` | Nothing: another live session drives. Keep the heartbeat; relay the operator's words as control requests. |
| `start` (`item=<key\|author>`) | `loop-cycle-start <P>` (creates `<P>.C<k>`, takes the queue head, holds the lease); on `item=author`, `--key <key> --title "…" [--payload '<json>']` (`cycle-plan.md`). A `footprint=` line puts `## Prior footprint` in the plan. Commit the start with the next close. |
| `plan` | Write `plan.md` (`cycle-plan.md`) with `## Dispatch` from `executor-route <cycle>`. |
| `dispatch` (`attempt=`, `route=`, `dirty_outputs=`) | `loop-cycle-dispatch <cycle>` **immediately before** the Agent call (it refuses on a live span, a recent dispatch, or queued requests). Attempt 1 on the stage's row, attempt 2 on high (re-pin `## Dispatch`, add `## Retry`). Then `slice-executor` in the background with the pinned `model`/`effort`, the prompt starting `slice: <cycle>`. |
| `wait` (`reason=`) | `ScheduleWakeup` at `wake_in`. |
| `close` (`verdict=`, `dirty_outputs=`) | Close by SKILL.md's *Closing a cycle*, `record-dispatch`, commit. `verdict=error` (attempt 2 left none): `--verdict error --summary "<reason>"`, settle `dirty_outputs`. |
| `overdue` (`span=`) | `TaskStop` the span you own, `loop-cycle-close <cycle> --verdict error --summary "overdue: …"`, settle `dirty_outputs`, commit. |
| `resume-limit` (`until=`) | After the reset: `SendMessage` your span, else `loop-cycle-dispatch <cycle>` and re-dispatch from disk. |
| `halt` (`reason=`, `detail=`) | `loop-control <P> halt --reason <reason> --detail "<detail>"`, then report. `budget-total` and `max-cycles` lift only by a new signed charter version. |
| `halted` / `paused` | Report once and wait on the heartbeat; only the operator's words move it. |
| `sign` | Present the unsigned charter (`loop/charter/v<N>.md`) by the stop rules (`.claude/skills/do-whole-phase/SKILL.md` § Stops), wait for their literal words, `loop-sign <P> --words "…"`. |
| `digest` | `loop-status <P> --digest --write`, show it, `PushNotification` one line when the tool exists, commit `loop/digest.md`. |
| `setup` (`slice=`) | Run that slice the ordinary way (`do-next-slice`), tick again; `reason=checkpoint` marks a checkpoint's fix. |
| `checkpoint` (`reason=every\|requested`) | `loop-checkpoint <P> --start`, then `checkpoint.md`. |
| `fix` (`slice=`) | One `new-slice --phase <P> --slice <P>.F<n> --name "…" --kind fix --risk high --depends-on none` per finding class from the checkpoint's `result.md`, on the loop stream; commit; tick again. |
| `resume` (`reason=checkpoint`) | The fixes are done: `loop-control <P> resume`. |
| `review` | The loop is stopped: run the REVIEW (SKILL.md, *The end*). |

**A checkpoint in flight** carries `kind=checkpoint`: its `dispatch` is `loop-cycle-dispatch <P>.K<j>` on the high row, its `close` is `loop-checkpoint <P> --verdict pass|changes_requested|blocked --summary "…"` (never `loop-cycle-close`), its `overdue` is `TaskStop` then `--verdict blocked --summary "overdue"`.

**The rule order (first wins):** apply-control → claim / not-driver → the in-flight cycle or checkpoint → the loop's status (drafting → `sign`; halted; paused by a checkpoint → `setup` / `resume` / `fix`; paused; stopped → `review`) → phase pending or blocked (`wait`) → charter changed since signing (`halt reason=charter`) → budget-total / max-cycles (`halt`) → budget-day (`wait`) → `digest` → `checkpoint` → cadence (`wait`) → `setup` → `start`.

**The in-flight cycle (first wins):** a verdict in `result.md` → `close`; no `plan.md` → `plan`; a live span → `wait`, or `overdue` past `cycle_timeout_minutes`; an `escalate`, a dead span (no verdict, or its session ended) → the next attempt; a usage limit → `resume-limit` (no reset time: `halt reason=limit`); no span yet → `dispatch` at the same attempt (or `wait reason=dispatching` within 300 s). The next attempt from 1 is `dispatch attempt=2` on high; from 2 it is `close verdict=error` (a checkpoint: `blocked`). A `result.md` the last dispatch already saw (attempt 1's `escalate`) is no verdict for attempt 2.
