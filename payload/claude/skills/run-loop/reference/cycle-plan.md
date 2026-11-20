# run-loop — a cycle's plan

On `action=plan`, write `works/phases/active/<P>/slices/<cycle>/plan.md` inline; the signed charter is the gate, so there is no plan pause. Read the current charter version (`charter=` on the tick) once per session and copy from it; never paraphrase its forbidden list. Keep it short: the executor reads only this file, the charter paths it names and the code the steps touch; add a ledger line it needs (a prior failure, the `screen` metrics a `confirm` re-checks), never the ledger.

```markdown
slice: <P>.C<k>

# <P>.C<k>: <stage> <item key>

## Item
- key: <key> · title: <title> · stage: <stage>
- payload: <the item's payload JSON, verbatim>

## One cycle
<the charter's `## One cycle` procedure for this stage>
Run each command plainly, one per Bash call: never chain with `;`, `&&`, `||`, `|` or `$(…)`; read a command's
exit status from the tool's result. A compound command can be denied where its plain form is allowed.

## Forbidden
<the charter's `## Forbidden` list, verbatim>

## Outputs
The only product paths this cycle may write (plus `result.md`): <the bounds' `outputs`, one per line>

## Budget
per_cycle_usd: <value>. Spend `spend_covered` does not name is `needs_operator` with `need_scope: spend`.

## Return
`result.md` opens with the verdict block, plus: item_verdict: pass|fail|survivor|parked|error · item_key ·
metrics: <one-line JSON> · need_scope: item|spend (with operator_need) when the cycle needs the operator.
No `phase.md` (bar `## Now`), no `loop-*` or state command, no commit.

## Dispatch
<the lines `executor-route <P>.C<k>` printed>
```

Only when the engine asks, before `## Dispatch`:

- `## Prior footprint`: the `footprint=` line (the cycle that closed `error` and the outputs it left). Reconcile first: read what is already filed for this item, never file it again.
- `## Retry (attempt 2)`: why attempt 1 left no verdict (the tick's `reason=`, an escalation's findings in a line or two) and the `dirty_outputs=` line. Reconcile first, finish or skip what it wrote and filed, never repeat a filing; then run the cycle.

**The route.** `executor-route <cycle>` routes by the engine's attempt: attempt 1 by the stage through the charter's `stages` (by default `screen` → the `screen` row, `confirm` → high), attempt 2 on high; no `--retry`. Pin its lines as `## Dispatch`; pass its `model`/`effort`.

**Authoring an item (`item=author`).** With an empty queue, author the next item from the charter's objective and the loop's memory (`loop-status <P>`, the ledger tail, `loop/dead.jsonl`), the key normalized as the charter defines; never a dead or tried key (the engine refuses one). `loop-cycle-start <P> --key <key> --title "…" [--payload '<json>']`, or queue several with `loop-queue <P> add --key … --title … [--stage …] [--payload …] [--priority …] --source orchestrator`.
