# Deferred: D22 A running phase stays planned: start-slice never moves it to in_progress

## Context

## Why Deferred

start-slice never sets the phase in_progress and no skill does, so P22 and P23 ran every slice while phase.json said planned. Checks that look only for in_progress then miss a live phase: the new-phase hint (workflow.py:1411), the next worktree hint (:2399) and parallel-gate's default-stream-quiet check (:2074), which could report a quiet default stream mid-run. Outside P23's boundary; not verified further.

## Trigger to Promote

Before the next parallel-start or parallel-gate on a real phase, or the next edit of start_slice / parallel_start_hint.

## Notes

