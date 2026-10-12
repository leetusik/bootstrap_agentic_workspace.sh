# Deferred: D56 Tighten the one-shot rotate-backlog wording

## Context

## Why Deferred

Three wording nits from the P33 review, no behaviour change: the rotate-backlog skill's allowed-tools lacks EnterPlanMode/ExitPlanMode which the gate word uses; CLAUDE.md 'Capture intent first' is not amended for the /rotate-backlog route though the create-phase exception and 'Making a phase != executing it' are; create-phase's docs-route sentence 'Steps 2-4 below still hold' reads as if it also applies under /rotate-backlog.

## Trigger to Promote

the next phase that edits the rotate-backlog or create-phase skill or CLAUDE.md, or the first /rotate-backlog gate run that hits a plan-mode permission prompt

## Notes

