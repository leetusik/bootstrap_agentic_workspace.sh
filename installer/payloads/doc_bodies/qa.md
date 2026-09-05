# QA

## Status

No QA strategy is finalized yet.

## Purpose

Use this doc for test commands, acceptance criteria style, manual QA missions, browser QA flows, regression checks, and known fragile areas.

## Test Commands

- Unit:
- Integration:
- E2E:
- Lint/typecheck:

## Acceptance Criteria Style

- <rule>

## Manual QA Missions

### Mission Name

- Route / entry:
- What a real user would try:
- What would feel wrong:
- Evidence to collect:

## Regression Checklist

The product's **cumulative smoke list**: headline behaviours only, one line each, append-only
across phases. Each phase's fidelity/review slice **appends** its surfaces' headline checks and
**re-runs the lines inside its phase's boundary** — this phase's own surfaces plus every earlier
line whose surface a file the phase changed feeds (`python3 scripts/workflow.py phase-scope <P>`
prints those files; a shared file widens the boundary to everything it feeds) — in the operator
runtime (`## Operator Runtime` in the operations doc), recording the lines outside the boundary by
count with the diff as the proof. The **whole** list is re-run by a QA phase the operator creates,
never by a phase review. Headline behaviours, not exhaustive assertions — if a check needs a
paragraph it belongs in a *Manual QA Mission*, not here.

Line shape: `- [ ] <surface>: <one observable behaviour> (P<N>)` — the tag says which phase added it.

- [ ] <landing>: login / entry point is visible and works (P<N>)
- [ ] <main board>: every visible control does something observable (P<N>)
- [ ] <timers / live data>: ticks or refreshes without wiping in-progress typing (P<N>)

## Known Fragile Areas

- <area>

## Open Questions

-
