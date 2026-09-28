# Deferred: D8 Slim CLAUDE.md to <= 12 KB

## Context

## Why Deferred

CLAUDE.md is 33 KB in 115 lines (~8.5K tokens) and rides every agent's prefix (main thread and every executor dispatch); most of its rule detail is restated in the skills that own the operation, so the contract can go back to being the compact routing layer it claims to be.

## Trigger to Promote

After P18 lands and the just-in-time Read Order is settled; a dedicated editorial phase, not folded into other work.

## Notes

