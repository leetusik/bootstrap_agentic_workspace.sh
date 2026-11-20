# run-loop — a checkpoint

A checkpoint `<P>.K<j>` (kind `review`) reviews one window: the cycles since the last one. It comes every `checkpoint_every` cycles or on "checkpoint now". It is not the phase's REVIEW and never opens the acceptance gate: the charter signature is the loop's gate.

1. `loop-checkpoint <P> --start`: creates `<P>.K<j>`, holds the lease, prints the window and its `from_commit`.
2. **Plan it** (`slice: <P>.K<j>` first, `## Dispatch` from `executor-route <P>.K<j>`): the window's ledger lines, spend and failures; every parked item, each routed to the digest as a question or listed as a deferred job for you to file; the survivors; `git diff <from_commit>..HEAD` against the charter's `outputs` (a path outside them is a finding) and `## Forbidden` list; charter fit (a bound that needs a new version is a question, never a change). The executor returns `review_verdict`, a summary and the routing, and never edits source.
3. `loop-cycle-dispatch <P>.K<j>`, the Agent on the **high** row, then `record-dispatch` and `loop-checkpoint <P> --verdict pass|changes_requested|blocked --summary "…"`.
4. Commit (at root `chore(<P>): checkpoint K<j> <verdict>`; nested, the host commit first). In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`; run `mark-committed <slice>` after its product commit (with no product change, right after its finish).
5. After a `pass`: `loop-checkpoint <P> --landed` (it refuses while the phase folder is dirty), commit again; the default stream then sees `merge_ready=<P>:<sha7>`.

**`changes_requested`** pauses the loop: the tick prints `fix` (one fix slice per finding class), then `setup` per open fix, then `resume reason=checkpoint`. **`blocked`** halts it; only the operator's words resume. After a checkpoint, show the operator every open parked question in the digest; a parked item routed to a deferred job: `defer-job`, then `loop-unpark <P> <key> --to deferred --pointer <DID>`.
