---
name: do-whole-phase
description: Finish the active phase end-to-end, including the review and any fix slices.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent, EnterPlanMode, ExitPlanMode
disable-model-invocation: true
---

# do-whole-phase

A playbook: how a phase usually runs. Leave a step when the work needs it and say why in your report; the contract's four invariants never move.

**Read just in time.** `python3 scripts/workflow.py next` for the pointer (never `works/state.json` or `works/backlog.md`: `next` prints the pointer), `CLAUDE.md`, then the phase's `phase.md`, the **bounded phase notebook**, only through `section` (`section <P>` lists it, `<P> Now` first), never with `Read`, `Edit` or `Write`; `intent.md` when unsure what was asked; `docs/current/` sections only as the work needs them. `next` sees this stream only (`parallel-status` shows every stream).

**You are the orchestrator.** You plan, dispatch, finish, commit, move state and talk to the operator; every slice runs on `slice-executor`. **One exception, `kind: co-work`:** a design slice runs inline: the round's lifecycle and the operator's words stay inline, the drafting is dispatched to `design-drafter`, the critique to `design-critic` when the job asks, and the mockup build is the one span dispatched to a slice executor, only when the operator asked for one (`reference/co-work.md`, with the `design-cowork` skill). A co-work slice stops `pending` once per round.

## The loop, slice by slice

1. **Plan** the slice into its own `plan.md`, free-form: the goal, what to read, the claims to prove, how to validate. Pull context through `section`; never pre-fill another slice's `plan.md`. An `implementation` or `fix` plan carries `## Claims and contracts`: each behaviour claim a check can fail, each external contract with its source (URL and date, or the file read), `unread` if nobody has read it, or `none — <why>`.
2. **Dispatch** one executor in the background: `slice start`, `executor-route <slice>`, pin `## Dispatch`, dispatch, `record-dispatch` (`reference/dispatch.md`).
3. **Read the verdict** and the head of `result.md`, then act on it (`reference/verdicts.md`): `done` → `slice finish <slice_id> --outcome "<its summary>"`, `check`, commit; `needs_operator` → a typed `pending` stop; `blocked` → STOP; a mid `escalate` or a failed mid return → once more on the high row; a failed high return → STOP.
4. Then `section <P> Now` and only the sections the next plan needs.

While an executor runs you may prepare the **next** slice only, read-only (an `Explore` lookup, inline reads, notes in the session scratchpad), and drop it on any verdict but `done`; never write to the repo or move state meanwhile. Declared slices (`next` prints `ready_slices=` with more than one id) run together by `reference/wave.md`, whose *Resume* runs first at every session start and after every compaction in a declared phase.

## Modes

- **`auto`, the default:** plan inline and `Write` the full `plan.md`; no plan mode, no approval pause. A decomposition slice and a slice that spends money (vendor models, paid APIs, per-use cloud; never this workspace's dispatches) still plan at the gate unless the operator said `auto` explicitly.
- **`gate`:** `EnterPlanMode`, read-only research, `ExitPlanMode` for the operator's approval, then copy the harness plan file the harness named for this session (never glob `~/.claude/plans/`, never pick by time) to the slice's `plan.md` after checking its opening lines are the plan just approved; copy before the next `EnterPlanMode`.
- **`plan only`:** ready each plan at the gate, `slice status <slice> ready`, commit; dispatch nothing. Stop before a plan that depends on work not landed yet: the `REVIEW`, a `DECOMP2`, a `paired` apply slice. A `ready` slice later dispatches from its approved plan.

## Stops

- **`WAITING ON OPERATOR`** (`next`; a `pending` item shows `[~]`): STOP; start, finish or advance nothing until the operator clears it. An open acceptance gate (`acceptance_gate=open`): relay the walkthrough as is; it clears with `accept-gate <P> --clear`, never `phase status`.
- Set every stop typed: `slice status <slice> pending --stop-kind wave|mockup|decision|operator-action|limit|other --on-words "<what their words will do>"`.
- **The stop rules**, for every stop and report you make: at most about 5 decisions, and only those that change a contract, contradict the operator's own words, or are costly to undo; the rest in one "decided as drawn" list; about 2k characters plus links; one word ("accept", "moveon") signs everything presented. Anything else you have a recommendation for, take it and list it.

## Special slices

- decomposition → `reference/decomposition.md` (the gate, the PR branches); the review → `reference/review.md` and the `review-phase` skill; co-work → `reference/co-work.md`.
- an explain phase (`## Explain` in `intent.md`): `reference/explain-decomposition.md`, `reference/explain-chapter.md`, `reference/explain-review.md`.
- a worktree: only on the operator's word (an explain: its confirmation asked), or when the phase already runs in one or `next` prints `merge_ready=`: `reference/worktree.md`.

**After a compaction** continue from the resume card's next action (`next --card`); an executor dispatched before it is still running: wait for it, never re-dispatch. The mode word and any open gate are kept facts; `intent.md` and `next` are the record.

**Stop what you start**, the main thread included: a server, container or browser you started is stopped before the slice is committed.

Do not continue into the next phase: **one session per phase.** Report and end; the next phase starts fresh from disk.
