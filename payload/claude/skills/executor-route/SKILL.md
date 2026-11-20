---
name: executor-route
description: Show the executor route table (model and effort per route, the per-row executors.toml overrides, the agent files' sync state) and the adapter's meter; with a slice id, the dispatch decision for that slice.
argument-hint: "[<slice_id> [--retry] | --drafter [--phase <P>] | --explore]"
allowed-tools: Bash(python3 adapters/claude_code/adapter.py:*)
disable-model-invocation: true
---

# executor-route

Run `python3 adapters/claude_code/adapter.py route $ARGUMENTS` (the Claude Code adapter) and relay its output as is, `fallback=` and `warning=` lines included. With no argument it prints the table; then also run `python3 adapters/claude_code/adapter.py meter` and relay what each slice really cost, metered from the transcripts. With a slice id (`--retry` for a second attempt) it prints the lines the orchestrator pins as `## Dispatch`; `--drafter [--phase <P>]` and `--explore` print the same for those spans.

The skill edits nothing. To change a row, the operator edits its `[claude.<row>]` block in `executors.toml` and runs `python3 adapters/claude_code/adapter.py sync-agents`; never edit their overrides yourself.
