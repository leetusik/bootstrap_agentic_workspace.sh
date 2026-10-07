# Deferred: D42 A refused --update creates its missing target dir

## Context

## Why Deferred

ROOT.mkdir runs before the 'no agentic workspace found' error, even on --dry-run; v49 at-root behaviour now also reached by a bare --update with no install and by --update --nested on a missing path (P29.REVIEW)

## Trigger to Promote

next installer change or an operator report

## Notes

