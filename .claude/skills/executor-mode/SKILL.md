---
name: executor-mode
description: Show the slice-executor mode (the economy/flex preset for both tiers), or switch it in one step — sets the mode in executors.toml and syncs the executor agent files.
argument-hint: "[economy|flex]"
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# executor-mode

The executor mode is the named preset that sets the model and effort of both slice-executor tiers (`slice-executor-mid`, `slice-executor-high`). It is the top-level `mode` in the repo-root `executors.toml`.

Run `python3 scripts/workflow.py executor-mode $ARGUMENTS` and relay its output:

- **No argument: show the mode.** It prints the active mode and where it comes from (`executors.toml`, or the `economy` default), each tier's model @ effort, any per-tier `[claude.<tier>]` overrides, whether the agent files are in sync, and the presets on offer.
- **A preset (`economy`, `flex`): switch to it.** It rewrites only the `mode = "…"` line in `executors.toml` (adding one when there is none) and syncs `.claude/agents/slice-executor-{mid,high}.md`, so there is no separate `sync-agents` step. Claude Code reloads edited agent files, so the next dispatch runs on the new mode without a restart.

If the switch prints a `note:` that per-tier overrides still win over the preset, relay it as-is. The overrides belong to the operator: never delete or edit them to make a switch "take".

The switch edits the working tree (`executors.toml` and the two agent files) and commits nothing. Commit only when the operator asks.
