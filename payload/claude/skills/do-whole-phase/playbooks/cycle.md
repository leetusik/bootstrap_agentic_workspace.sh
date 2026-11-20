# Playbook: cycle (kind `cycle`, `<P>.C<k>`) and a loop's checkpoint (`<P>.K<j>`)

**A cycle** runs one item through the product's own steps, exactly as `plan.md`'s `## One cycle` says.
- Its `## Forbidden` list is the signed charter's, verbatim, and binds **absolutely**: no reading of the plan's intent overrides it.
- Write only the `## Outputs` paths plus `result.md`, and no `phase.md` section (bar `## Now` when the plan asks).
- Spend the plan does not cover is `needs_operator` with `need_scope: spend`, never a workaround, a cheaper substitute or a skipped step. An item that needs an operator decision is `needs_operator` with `need_scope: item`: the loop parks it and goes on.
- An item that fails the product's scorer is a `done` cycle with `item_verdict: fail`, never `blocked`.
- **A retry or a prior footprint** (`## Retry` or `## Prior footprint` in the plan): reconcile first. Read what the earlier attempt left on the outputs and what it already filed, finish or skip that work, and never repeat a filing.
- The `screen` row follows the mid row's rules: `escalate` on the card's reasons; the retry runs on the high row, which never escalates.

**Cycle fields.** `item_verdict`: `pass|fail|survivor|parked|error`; `item_key`; `metrics`: a one-line JSON object; `need_scope`: `item|spend` with `operator_need`, when the cycle needs the operator.

**A checkpoint** (a `review` slice on a loop phase) reviews only the window its plan names: the ledger lines, spend and failures, every parked item (route each: a question for the digest or a deferred job for the orchestrator to file), the survivors, and the product diff since the plan's `from_commit` against the charter's `outputs` and `## Forbidden` list. It is not the phase review: no gate stages, no doc versions, no walkthrough, and it never edits source. Fields: `review_verdict`: `pass|changes_requested|blocked`, and the parked-item routing.
