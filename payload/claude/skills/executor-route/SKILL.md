---
name: executor-route
description: Show the executor route table (model and effort per route, the per-row executors.toml overrides, the agent files' sync state) and the metered dispatch summary; with a slice id, the dispatch decision for that slice.
argument-hint: "[<slice_id> [--retry] | --drafter [--phase <P>] | --explore]"
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# executor-route

Run `python3 scripts/workflow.py executor-route $ARGUMENTS` and relay its output as is, `fallback=` and `warning=` lines included. With no argument it prints the table; then also run `python3 scripts/workflow.py dispatch-summary` and relay what each slice really cost, metered from the transcripts. With a slice id (`--retry` for a second attempt) it prints the lines the orchestrator pins as `## Dispatch`; `--drafter [--phase <P>]` and `--explore` print the same for those spans. A loop's `screen` row runs `slice-executor` on the mid row's values unless `[claude.screen]` sets it; a `cycle` routes by its charter stage, and its retry always goes high (`executor-route <cycle>` prints attempt 2's row with no `--retry`).

The skill edits nothing. To change a row, the operator edits its `[claude.<row>]` block in `executors.toml` and runs `sync-agents`; never edit their overrides yourself.
