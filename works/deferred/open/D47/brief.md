# Deferred: D47 No parallel-run hint and no parallel-start for a docs phase

## Context

## Why Deferred

P30.REVIEW N-3: new-phase --consolidates still prints the parallel-start hint when another phase is in progress, and parallel-start would accept a docs phase, though doc consolidation runs only on the default stream (pre-existing)

## Trigger to Promote

the next engine change to new-phase or parallel-start

## Notes

