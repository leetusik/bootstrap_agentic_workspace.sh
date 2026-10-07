# Deferred: D35 Nested phase-scope measures from the merge-base after a rebase

## Context

## Why Deferred

After the ticket branch is rebased or merged onto a newer origin/main, nested phase-scope lists teammates' files from created..HEAD (it over-reports, never hides). Measure from the merge-base with upstream, or document --base $(git merge-base HEAD origin/main).

## Trigger to Promote

The first real ticket rebased before its PR

## Notes

