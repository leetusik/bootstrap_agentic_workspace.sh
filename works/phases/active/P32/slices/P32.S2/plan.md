# Plan — P32.S2: Engine — `record-dispatch` and `dispatch-summary`

Kind `implementation`, risk `low` (mid tier). Read `phase.md` first: D5 (the instrument), D4 (what `executor-route` prints — the record copies those values), D7 (attribution), D12, and the two `## Notes for later slices` entries tagged for S2 (row names and helpers from S1; the `events.jsonl` facts). `intent.md` *The instrument* paragraph is the why.

## Goal

Every executor dispatch can leave one machine-readable record in `works/events.jsonl`, and a read-only summary reads them back by route. After this slice the orchestrator runs `record-dispatch` after each executor return (S4 writes that into the skills); nothing else in the workflow changes.

## Files

- `scripts/workflow.py` — two commands and their parsers, placed right after `cmd_executor_route` (~639) and its parser (~4516). Reuse `require_slice` (1765), `read_json`, `append_event` (362), `EXECUTOR_ROUTES`, `EXECUTOR_TIERS`, `ROUTE_TIER`, `MODEL_ATTRIBUTION`, `WORKS`, `now_iso`. Do not touch `slice_route`, `resolve_routes` or `executor-route`.
- `tests/retrofit_smoke.sh` — assertions appended right after the route matrix block (~999–1077, inside the same throwaway workspace `$F`).
- `bootstrap_agentic_workspace.sh` — rebuilt (`python3 installer/build.py`); the pre-commit hook needs it.

Do **not** touch: agent files, skills, `CLAUDE.md`, installer source, `WORKSPACE_VERSION`, CHANGELOG, READMEs, `docs/`.

## `record-dispatch` (exactly this)

```
record-dispatch <slice_id> --route <row> --model <m> --effort <e> --verdict <v>
                [--attempt N] [--tier mid|high] [--agent <name>]
                [--duration-ms N] [--tokens N] [--tool-uses N] [--note "<text>"]
```

- `slice_id` → `require_slice` (exit 1 with the engine's usual message when unknown); read `slice.json` for `phase_id`, `kind`, `risk`.
- `--route` must be in `EXECUTOR_ROUTES` (argparse `choices`). `--verdict` choices: `done`, `escalate`, `needs_operator`, `blocked`, `failed`. `--tier` choices `mid`, `high`; default `ROUTE_TIER[route]` (for `explore` it is `None` → record `null`). `--attempt` int, default 1. `--effort` accepts `""` (recorded as `""`). `--model` any non-empty string. `--agent` default: the tier's installed agent name (`installed_agent_name(f"slice-executor-{tier}")`), or the given name. `--duration-ms`, `--tokens`, `--tool-uses` ints, default `null` when omitted. `--note` optional free text (e.g. "back-filled from the completion notification").
- Appends via `append_event("executor_dispatched", slice=…, phase=…, kind=…, risk=…, route=…, tier=…, agent=…, model=…, effort=…, attribution=MODEL_ATTRIBUTION.get(model, model), attempt=…, verdict=…, duration_ms=…, tokens=…, tool_uses=…, note=…)`. Nothing else is written; no rebuild, no state change.
- Prints one key=value per line echoing the stored record (`recorded=executor_dispatched`, then `slice=`, `route=`, `tier=`, `model=`, `effort=`, `attempt=`, `verdict=`, `duration_ms=`, `tokens=`, `tool_uses=`), the `next` convention.

## `dispatch-summary` (exactly this)

```
dispatch-summary [--phase P] [--slice <slice_id>] [--json]
```

- Reads `works/events.jsonl` line by line; keeps `type == "executor_dispatched"`; skips blank or malformed lines silently (counts them, reports `skipped_lines=N` only when > 0). `--phase` keeps records whose `phase` matches; `--slice` keeps one slice's records (its attempts, in order).
- Default output (text), in this order:
  1. `records=N` `phases=…` (comma list) `since=<first ts>` `until=<last ts>`; with no records: `records=0` and a one-line hint `hint=record a dispatch with: <WORKFLOW_CMD> record-dispatch <slice_id> --route … --model … --effort … --verdict …`, exit 0.
  2. **By route** — an aligned table, rows in `EXECUTOR_ROUTES` order (only rows that appear), columns: `route`, `n`, `done`, `escalate`, `needs_op`, `blocked`, `failed`, `retries` (records with `attempt >= 2`), `mean_min` (mean duration in minutes, 1 decimal, `-` when no durations), `total_min`, `tokens` (sum, `-` when none).
  3. **By model @ effort** — same columns keyed by `model @ effort` (effort `""` shown as `(none)`), ordered by `n` desc.
  4. **By kind** — `kind`, `n`, `done`, `escalate`, `retries`, `tokens`, same ordering rule.
  5. With `--slice`: instead of the tables, one line per record: `attempt=1 route=cheap model=haiku effort=high verdict=escalate duration_ms=… tokens=… ts=…`.
- `--json` prints the same aggregates as one JSON object (`{"records": N, "by_route": {...}, "by_model_effort": {...}, "by_kind": {...}}`) for later tooling. Read-only: writes nothing, exit 0 always unless `--phase`/`--slice` name something that does not exist (then exit 1 with a one-line error).

## Smoke assertions (append after the route matrix, same `$F` workspace, same `ok`/`bad` style)

1. `record-dispatch P1.DECOMP --route high --model opus --effort high --verdict done --duration-ms 60000 --tokens 1000 --tool-uses 5` → prints `recorded=executor_dispatched` and `tail -1 "$F/works/events.jsonl"` contains `"type": "executor_dispatched"`, `"route": "high"`, `"attribution": "Claude Opus 5.5"`.
2. the `docs low` probe slice (`P1.S9`): `record-dispatch P1.S9 --route cheap --model haiku --effort high --verdict escalate --attempt 1` then `record-dispatch P1.S9 --route high --model opus --effort high --verdict done --attempt 2 --tier high` → `dispatch-summary` shows `cheap` with `escalate` 1 and `high` with `retries` 1; `dispatch-summary --slice P1.S9` prints two lines, `attempt=1` then `attempt=2`.
3. `record-dispatch P1.S9 --route bogus …` → exit non-zero (argparse); `record-dispatch P9.S1 …` (no such slice) → exit non-zero.
4. `dispatch-summary --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["records"]==3'` → ok.
5. `dispatch-summary --phase P7` (no such phase in the fixture) → exit 1; `dispatch-summary --phase P1` → `records=3`.
6. a malformed line appended to `works/events.jsonl` (`printf 'not json\n' >>`) → `dispatch-summary` still exits 0 and prints `skipped_lines=1`.
7. `--effort ""` is accepted: `record-dispatch P1.DECOMP --route high --model opus --effort "" --verdict done` → the summary's model@effort table shows `opus @ (none)`.

## Validation (run all; record each in the verdict block)

1. `python3 -m py_compile scripts/workflow.py`.
2. Live repo, real records — **back-fill the two dispatches that already happened** (D12; numbers from the orchestrator):
   - `python3 scripts/workflow.py record-dispatch P32.DECOMP --route high --tier high --model opus --effort xhigh --verdict done --attempt 1 --agent slice-executor-high --duration-ms 471434 --tokens 145242 --tool-uses 56 --note "back-filled from the completion notification; dispatched by frontmatter before the table existed"`
   - `python3 scripts/workflow.py record-dispatch P32.S1 --route high --tier high --model opus --effort xhigh --verdict done --attempt 1 --agent slice-executor-high --duration-ms 721125 --tokens 213658 --tool-uses 67 --note "back-filled from the completion notification; dispatched by frontmatter before the table existed"`
   - `python3 scripts/workflow.py dispatch-summary` and `dispatch-summary --phase P32` → `records=2`, route `high` n=2, done 2, tokens 358900; `dispatch-summary --slice P32.S1` → one line. Paste the summary into `result.md`.
3. `python3 scripts/workflow.py validate` → exit 0 (the two known warnings are fine).
4. `python3 installer/build.py` then `python3 installer/build.py --check`.
5. `bash tests/retrofit_smoke.sh` — once, in the foreground, as the only command in its Bash call. Expect PASS with your new assertions added to the 245 baseline; report the new count. Any failure is yours to fix unless it is clearly outside this slice, which you name with its owner.

## `result.md` and `phase.md`

- `result.md`: verdict block first — `status`, `tier: mid`, `model: sonnet`, `effort: high` (you were dispatched on the mid agent file's frontmatter), `summary`, `files_changed`, `validation`, `deviations`, `doc_impact` — then the live `dispatch-summary` output and the smoke count.
- `phase.md`: remove the two S2 notes you consumed; add a note **for S4** with the exact `record-dispatch` invocation the skills must run after every executor return (which `executor-route` lines map to which flags; `--attempt 2` on a retry; `--verdict failed` for an empty/failed return; `--agent design-drafter` for the drafter span) and the fact that `dispatch-summary` exists for the `/executor-route` skill; a note **for S5** that the smoke baseline moved (new count) and that `dispatch-summary --json` exists. Append `## Doc impact` lines: `operations.md: Executor tiers — record-dispatch after every executor return and dispatch-summary by route / model@effort / kind; the table is tuned from this workspace's own runs (P32.S2)` and `architecture.md: works/events.jsonl gains the executor_dispatched event and its first reader, dispatch-summary (P32.S2)`. Rewrite `## Now` (≤ 15 lines) for S3.

## Dispatch

Dispatched by today's rule (D12): `slice-executor-mid` on its frontmatter, `sonnet @ high`. Record those in the verdict block as `- model: sonnet` / `- effort: high`.
