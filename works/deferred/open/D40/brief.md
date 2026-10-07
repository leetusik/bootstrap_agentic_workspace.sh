# Deferred: D40 Nested validate/next re-checks the ignore guarantee after install

## Context

## Why Deferred

A teammate's later .gitignore negation makes our host-side files untracked-visible as soon as the operator pulls; validate and next stay silent and only --update --nested notices. Run the same check over the installed targets in nested validate/next and warn.

## Trigger to Promote

The next nested engine change, or an operator report

## Notes

