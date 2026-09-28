# Deferred: D18 Slim the slice-executor bodies

## Context

## Why Deferred

Each executor body is ~28.6 KB, about 70% of what every dispatch loads now that CLAUDE.md is 12.3 KB. The review bullet (~4.1 KB) restates review-phase and the implementation/mockup bullets (~4.1 KB) restate design-cowork's Aside text; an executor cannot invoke a skill, so a cut needs a rule-to-reader map like P23.S1's.

## Trigger to Promote

The next phase that edits either executor body for content, or when the operator next targets per-dispatch cost.

## Notes

