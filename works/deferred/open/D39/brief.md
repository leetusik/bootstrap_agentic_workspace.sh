# Deferred: D39 A private-install route for a host whose .gitignore refuses --nested

## Context

## Why Deferred

Such a host refuses with nothing written and there is no override; an allowlist repo always refuses. Recommended shape (undecided): first narrow per-target workarounds that keep git status empty (a self-hiding .claude/agents/.gitignore when the team tracks nothing there, or the engine repo outside the work tree via an absolute @import); only if none fits, an explicit --allow-visible opt-in that lists every visible path, never the default. 'No private install there' stays open to the operator.

## Trigger to Promote

The real company repo refuses the nested install

## Notes

