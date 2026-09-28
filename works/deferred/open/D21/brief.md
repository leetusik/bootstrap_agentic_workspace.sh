# Deferred: D21 Correct two stale one-line descriptions (new-slice --help, executors.toml tier comment)

## Context

## Why Deferred

workflow.py --help says new-slice creates 'slice.json + markdown files' but it writes only slice.json (workflow.py:1446; CLAUDE.md says nothing is scaffolded), and P23 made --help the command reference; the executors.toml tier comment leaves research out of what the high tier takes.

## Trigger to Promote

The next edit of workflow.py's argparse help or of executors.toml, or the next docs phase.

## Notes

