# run-loop — a checkpoint

A checkpoint `<P>.K<j>` (kind `review`) reviews one window of the loop: the cycles since the last checkpoint. It comes every `checkpoint_every` cycles (`action=checkpoint reason=every`) or on the operator's "checkpoint now" (`loop-checkpoint <P> --now`, then `reason=requested`). It is not the phase's REVIEW, which runs once, after the stop. Checkpoints never open the acceptance gate: the charter signature is the loop's operator gate.

## The sequence

1. `loop-checkpoint <P> --start`: creates `<P>.K<j>` and holds the lease. It prints the window and its `from_commit`.
2. Plan it (below). From here the tick's in-flight lines carry `kind=checkpoint`.
3. `loop-cycle-dispatch <P>.K<j>`, then the Agent call on the **high** row (`executor-route <P>.K<j>`: a review routes high by kind).
4. On its return, `record-dispatch`, then `loop-checkpoint <P> --verdict pass|changes_requested|blocked --summary "…"` (never `loop-cycle-close`).
5. Commit (at root `chore(<P>): checkpoint K<j> <verdict>`; nested, the host commit first, as for a cycle).
6. After a `pass`: `loop-checkpoint <P> --landed` (it records that commit as the merge point and refuses while the phase folder holds uncommitted changes), then commit again: the record rides in that commit. The default stream now sees `merge_ready=<P>:<sha7>`.

`overdue` on a checkpoint: `TaskStop` the span, then `loop-checkpoint <P> --verdict blocked --summary "overdue"`.

## The checkpoint's plan

`plan.md` starts with `slice: <P>.K<j>` and reviews **only its window**:

- the window's ledger lines (`loop/ledger.jsonl`), its spend against the budget, and its failures;
- every parked item (`loop/parked.jsonl`), each routed: into the digest as a question for the operator, or listed as a deferred job for you to file (the executor never runs `defer-job`);
- the survivors the window produced;
- the product diff since the printed `from_commit` (`git diff <from_commit>..HEAD`), checked against the charter's `outputs` (any path outside them is a finding) and its `## Forbidden` list (any forbidden act is a finding);
- charter fit: whether the cycles did what `## One cycle` says, and whether a bound needs a new charter version (that is a question for the operator, never a change).

The executor returns `review_verdict: pass|changes_requested|blocked`, a summary and the parked-item routing. It never edits source. It may append **at most one** `## Doc impact` line for the window (`phase-section <P> "Doc impact" --append`), which stamps the loop's consolidation debt; cycles leave none. Include the plan's `## Dispatch` from `executor-route <P>.K<j>`.

## After the verdict

- **`pass`**: the loop continues and goes `merge_ready` once landed (step 6). The default stream merges that commit: the `parallel-phase` skill, *A loop phase lands at its checkpoints*.
- **`changes_requested`**: the loop pauses (`paused_by: checkpoint`). The tick prints `fix`: cut one `fix` slice per finding class from the checkpoint's `result.md` (`new-slice --kind fix`, on the loop stream), commit; the tick then prints `setup slice=<F> reason=checkpoint` for each open one (run it the ordinary way, `do-next-slice`), then `resume reason=checkpoint` → `loop-control <P> resume` (no words needed once the fixes are done).
- **`blocked`**: the loop halts (`halted reason=checkpoint`); only the operator's words resume it.

Route the window's parked items into the digest: after a checkpoint, run `loop-status <P> --digest --write` when the digest is due, and show the operator every open parked question. A parked item the checkpoint routed to a deferred job: file it (`defer-job`), then `loop-unpark <P> <key> --to deferred --pointer <DID>`, which resolves it.
