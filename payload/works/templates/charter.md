# Charter: __NAME__ (__PHASE_ID__)

_The loop's contract. The operator signs a version on their literal words (`python3 scripts/workflow.py loop-sign __PHASE_ID__ --words "..."`), which pins this file's sha256: a signed file that later changes halts the loop, so a change of charter is a new version (`loop/charter/v<N+1>.md`) and a new signature. Every cycle plan carries the forbidden list below verbatim. Replace each placeholder line before signing; `loop-sign` refuses while one is left._

## Objective

UNFILLED: what this loop is for, in one or two sentences, and what a good result looks like.

## One cycle

UNFILLED: what one cycle does, step by step. Name the product's own commands it runs (a backtest, a scorer, a filing step); how an item is specified (its `key`, its one-line `title`, and the `payload` the product reads); and how the product's scorer maps to a verdict:

- `pass`: the item clears this stage (a pass at the last stage makes a survivor; otherwise the next stage is queued);
- `fail`: the item fails the scorer and is never retried;
- `survivor`: the item is kept as a result at once;
- `parked`: the item needs an operator decision (the question goes on the parked list; the loop goes on);
- `error`: the cycle produced no item verdict (it goes back in the queue once, then dead).

## Forbidden

UNFILLED: keep, edit or extend the list below (each cycle plan carries it verbatim), then delete this line.

- trade or place orders
- spend money
- touch live systems or production credentials

## Bounds

The engine reads the first `json` fence below (`loop-sign` validates it). `budget` is in metered list-price USD and its three caps are required; `stages` maps each stage, in pass order, to the row it runs on (`screen`, `mid`, `high` or `research`); `outputs` are the product paths cycles may write, relative to the product root.

```json
{
  "cadence": {"min_gap_minutes": 0},
  "budget": {"per_cycle_usd": 5.0, "per_day_usd": 50.0, "total_usd": 500.0, "max_cycles": null},
  "stops": {"max_consecutive_failures": 3},
  "spend_covered": [],
  "stages": {"screen": "screen", "confirm": "high"},
  "checkpoint_every": 25,
  "digest_every_hours": 24,
  "keep_cycles": 10,
  "outputs": []
}
```
