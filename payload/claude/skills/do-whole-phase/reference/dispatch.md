# Dispatch: resolve, pin, dispatch, record, limits, Explore

The route is the engine's, never yours: kind first (decomposition, `research` and review always go high, whatever their `risk`; a co-work mockup span too), then `risk` (`low` → the mid row, the default, real code included; anything else → high), then attempt (a second attempt → high).

1. **Resolve.** After `slice start`, run `python3 scripts/workflow.py executor-route <slice_id>` (`--retry` on a second attempt) and `executor-route --explore`. **Bump up, never down:** a plan that hits a named trigger (open design, a core invariant, an unlocated root cause, a wide blast radius) on a `low` slice sets `risk` to `high` in its `slice.json`, says why in `plan.md`, and resolves again.
2. **Pin.** Append `## Dispatch` to `plan.md`: the slice form's lines verbatim (`route=` … `attribution=`) plus the `--explore` form's `model=` / `effort=` as `explore_model=` / `explore_effort=`. A retry's lines go under `## Escalation: mid → high`.
3. **Dispatch** with the Agent tool, in the background (never pass `run_in_background: false`): `subagent_type=` from its line; `model` only when `pass_model=yes`, `effort` only when `pass_effort=yes`. Relay every `warning=` line. **The prompt's first line is `slice: <id>`**, then the slice folder and the repo root: the meter attributes the span by it.
4. **Record** after the completion notification, before `slice finish`: `python3 scripts/workflow.py record-dispatch <slice_id> --verdict <done|escalate|needs_operator|blocked|failed> [--attempt 2]`; a failed or empty return is `failed`. Time and cost are metered from the transcripts (`dispatch-summary`), never recorded by hand.
5. **Usage limits.** A span stopped by a usage or rate limit is no verdict: record nothing, then resume it with `SendMessage` or re-dispatch it from disk. A limit with no reset time is `pending --stop-kind limit --on-words "<their go-ahead resumes the span>"`.
6. **Explore** for your own lookups: `subagent_type: Explore` at the `--explore` model and effort, upgraded per call (`model: sonnet` or `opus`) for a lookup that needs judgment. Its brief is input to your plan, never a plan.

`executors.toml`'s `[claude.<row>]` blocks are the operator's knob; `/executor-route` shows the table.
