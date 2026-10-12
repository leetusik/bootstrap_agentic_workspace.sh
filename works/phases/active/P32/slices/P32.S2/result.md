# Result — P32.S2: Engine — record-dispatch and dispatch-summary

- status: done
- tier: mid
- model: sonnet
- effort: high
- summary: Added `record-dispatch` (appends an `executor_dispatched` event to `works/events.jsonl`) and `dispatch-summary` (read-only; by route, model @ effort, kind; `--phase`, `--slice`, `--json`; malformed lines skipped and counted) to `scripts/workflow.py`, with 8 smoke assertions; back-filled the P32.DECOMP and P32.S1 dispatches in the live log; artifact rebuilt; smoke 253 PASS / 0 FAIL.
- files_changed: scripts/workflow.py, tests/retrofit_smoke.sh, bootstrap_agentic_workspace.sh (rebuilt), works/events.jsonl (two live records), works/phases/active/P32/phase.md, works/phases/active/P32/slices/P32.S2/result.md
- validation: `python3 -m py_compile scripts/workflow.py` pass; live back-fill + `dispatch-summary` / `--phase P32` / `--slice P32.S1` as the plan expects (records=2, high n=2 done 2 tokens 358900; `--phase P9` exits 1); `python3 scripts/workflow.py validate` exit 0 (two known warnings: consolidation_owed=P33, oversized_doc_sections); `python3 installer/build.py` then `--check` OK; `bash tests/retrofit_smoke.sh` run alone in the foreground: 253 PASS / 0 FAIL (baseline 245 + 8).
- deviations: none of substance. The summary header prints `records=` / `phases=` / `since=` / `until=` as separate key=value lines (the engine's per-line convention) rather than one line. `--phase` is accepted when the phase dir is active, archived (glob), or has records; `--slice` when records exist or the slice is active.
- doc_impact: operations.md (Executor tiers: record-dispatch / dispatch-summary) and architecture.md (events.jsonl gains `executor_dispatched` and its first reader) — appended to `phase.md` `## Doc impact`.

## Notes

`phase.md` updated: consumed the two S2 notes, added notes for S4 (exact `record-dispatch` invocation) and S5 (new baseline 253, `--json` shape), Doc impact lines, `## Now`.

Record fields: `slice, phase, kind, risk, route, tier, agent, model, effort, attribution, attempt, verdict, duration_ms, tokens, tool_uses, note` (+ `ts`, `type` from `append_event`). `tier` defaults to `ROUTE_TIER[route]` (null for `explore`); `agent` defaults to the tier's installed agent (or `Explore`). Duration/token aggregates average/sum only records that carry them.

## Live `dispatch-summary` (after the back-fill)

```
records=2
phases=P32
since=2026-10-12T17:12:59+09:00
until=2026-10-12T17:12:59+09:00

[by route]
route  n  done  escalate  needs_op  blocked  failed  retries  mean_min  total_min  tokens
high   2     2         0         0        0       0        0       9.9       19.9  358900

[by model @ effort]
model @ effort  n  done  escalate  needs_op  blocked  failed  retries  mean_min  total_min  tokens
opus @ xhigh    2     2         0         0        0       0        0       9.9       19.9  358900

[by kind]
kind            n  done  escalate  retries  tokens
decomposition   1     1         0        0  145242
implementation  1     1         0        0  213658
```

`dispatch-summary --slice P32.S1`: `attempt=1 route=high model=opus effort=xhigh verdict=done duration_ms=721125 tokens=213658 ts=…`.

Note for the orchestrator: this slice's own dispatch (sonnet @ high, mid route) is not yet recorded; run `record-dispatch P32.S2 --route mid --model sonnet --effort high --verdict done …` from the completion notification (this changes `works/events.jsonl`, so do it before or with the commit).
