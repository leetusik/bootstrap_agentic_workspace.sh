# Deferred: D59 Shared scratch paths linked into phase worktrees

## Context

## Why Deferred

A worktree starts without the main checkout's excluded scratch (e.g. an operator-excluded temp/). A symlinked temp shows as '?? temp', which blocks git worktree remove, counts as compact-gate dirt and is swept up by git add -A; a list of shared paths would need a non-directory exclude line per path and belongs in the nested marker, not executors.toml (P35.S2 (e)).

## Trigger to Promote

An operator asks to see the main checkout's temp/ (or other excluded scratch) from a phase worktree

## Notes

