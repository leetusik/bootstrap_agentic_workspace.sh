# run-loop — a cycle's plan

On `action=plan`, write `works/phases/active/<P>/slices/<cycle>/plan.md` inline. The signed charter is the gate: there is no plan pause, and no `gate` word applies to a cycle. Read the charter's current signed version (`loop/charter/v<N>.md`, `charter=` on the tick) once per session and copy from it; never paraphrase its forbidden list.

## The template

```markdown
slice: <P>.C<k>

# <P>.C<k>: <stage> <item key>

## Item
- key: <key>
- title: <title>
- stage: <stage>
- payload: <the item's payload JSON, verbatim>

## One cycle
<the charter's `## One cycle` procedure: what to run, in order, for this stage>

## Forbidden
<the charter's `## Forbidden` list, verbatim>

## Outputs
The only product paths this cycle may write (plus this slice's `result.md`):
<the bounds' `outputs`, one per line>

## Budget
per_cycle_usd: <the bounds' per_cycle_usd>. Spend the charter's `spend_covered` does not name is
`needs_operator` with `need_scope: spend`, never a workaround.

## Return
`result.md` opens with the verdict block (`status:` first), plus these lines:
- item_verdict: pass|fail|survivor|parked|error
- item_key: <key>
- metrics: <one-line JSON object, the product's own fields>
- need_scope: item|spend (with operator_need), only when the cycle needs the operator
The cycle writes no `phase.md` (bar `## Now`), runs no `loop-*` or other state command, and never commits.

## Dispatch
<the lines `executor-route <P>.C<k>` printed (the engine's attempt picks the row: no --retry)>
```

Two sections join the template only when the engine asks for them, each a few lines, placed before `## Dispatch`:

```markdown
## Prior footprint
<the `footprint=` line of loop-cycle-start or the tick's `plan`: the cycle that closed `error` and the outputs it
left, committed>. Reconcile first: read what is already filed there for this item, and never file it again.

## Retry (attempt 2)
Attempt 1 left no verdict: <the tick's `reason=`>. <its result.md, when it returned `escalate`: the escalation's
findings, one or two lines>. dirty_outputs: <the `dirty_outputs=` line, or none>. Reconcile first: read what
attempt 1 already wrote there and filed, finish or skip it, and never repeat a filing; then run the cycle.
```

Keep the plan short: one cycle is one item's run through the product's own steps, and the executor reads only this file, the charter's paths it names and the product code those steps touch. Add the ledger lines it needs (a prior attempt's failure, the `screen` metrics a `confirm` stage re-checks) as one line each, never the whole ledger.

## The route

`executor-route <cycle>` routes a cycle by the engine's attempt: attempt 1 by its stage through the signed charter's `stages` (by default `screen` → the `screen` row, `confirm` → `high`), attempt 2 (the retry) on `high`. It prints `attempt=`, `route=` and `stage_route=`, needs no `--retry` (it refuses one on attempt 1) and, after `loop-cycle-dispatch` recorded a retry, already prints the high row. Pin the printed lines as `## Dispatch` and pass its `model`/`effort` on the Agent call; on attempt 2, re-pin it and add `## Retry`.

## Authoring an item (`item=author`)

When the queue is empty, author the next item yourself from the charter's objective and the loop's memory: `loop-status <P>` (the parked list, the survivors, the queue), the ledger tail (`loop/ledger.jsonl`, its last lines only), and the dead list (`loop/dead.jsonl`). Never retry a dead or already tried key; `loop-cycle-start --key` refuses one anyway. The charter defines a key's normalization (how two items are the same item); the product owns it, so apply it before you choose a key. Start the cycle with `loop-cycle-start <P> --key <key> --title "…" [--payload '<json>']`. To queue several at once, `loop-queue <P> add --key … --title … [--stage …] [--payload …] [--priority …] --source orchestrator`.
