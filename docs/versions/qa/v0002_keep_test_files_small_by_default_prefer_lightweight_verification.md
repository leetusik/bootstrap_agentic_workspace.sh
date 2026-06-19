---
doc_id: qa
version: v0002
created_at: 2026-06-19T10:36:13+09:00
source: create-phase
summary: keep test files small by default; prefer lightweight verification
previous: v0001_bootstrap
---

# QA

## Status

Default testing posture: **keep test files small**. Tests are welcome, but each suite stays terse — minimal high-value cases, no fixture or scaffolding sprawl. The workspace itself follows this with a single committed smoke test (`tests/retrofit_smoke.sh`) plus `python3 scripts/workflow.py validate`.

## Purpose

Use this doc for test commands, acceptance criteria style, manual QA missions, browser QA flows, regression checks, and known fragile areas.

## Testing Philosophy

- **Minimal by default.** Prefer lightweight verification — run the code, `validate`, a small smoke check — over broad automated suites.
- **Keep test files small.** When a test is worth committing, keep the file or suite terse: a few high-value cases, no fixture or scaffolding sprawl.
- **Grow on demand.** Expand coverage only when the operator asks or the risk clearly warrants it; note the reason here when you do.

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

- [ ] <check>

## Known Fragile Areas

- <area>

## Open Questions

-
