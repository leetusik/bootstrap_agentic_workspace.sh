# Deferred: D19 Match the contract's smoke pins with whitespace normalized

## Context

## Why Deferred

Test 0's 38 contract pins are raw substrings that must each sit on one line, so any rewrap of a CLAUDE.md line risks a false failure; the design-cowork and parallel-phase lists already normalize whitespace.

## Trigger to Promote

The next time a contract pin breaks on a line wrap, or together with the never-rule floor pin list.

## Notes

