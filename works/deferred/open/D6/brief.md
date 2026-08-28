# Deferred: D6 Widen installer/main.py flag_stale_skills() ownership heuristic beyond the disable-model-invocation marker

## Context

## Why Deferred

The marker now holds for 15 of 17 shipped skills. Both exceptions (design-cowork, create-phase) are in CLAUDE_SKILLS and skipped before the check, so nothing breaks today, but a retired model-invocable skill would not be flagged stale for adopters and the docstring still asserts the marker is universal.

## Trigger to Promote

If a model-invocable skill is retired upstream, or when flag_stale_skills() is next touched.

## Notes

