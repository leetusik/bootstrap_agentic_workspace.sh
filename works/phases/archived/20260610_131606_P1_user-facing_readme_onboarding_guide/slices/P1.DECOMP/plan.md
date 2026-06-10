# Plan

- Phase ID: P1
- Slice ID: P1.DECOMP
- Slice: decompose phase
- Created at: 2026-06-09T23:41:20+09:00

## Goal

Decompose phase P1 (User-Facing README & Onboarding Guide) into concrete implementation
slices that build a user-friendly root `README.md`. This slice creates the middle slices
only and records the breakdown + findings in `phase.md` — it does not write the README and
does not pre-fill the new slices' `plan.md`.

## Scope

In scope:
- Create two implementation slices via `new-slice` (bare folders — no pre-filled plans):
  - `P1.S1` — Core README (order 10)
  - `P1.S2` — Methodology & related projects (order 20, depends_on P1.S1)
- Record the slice breakdown, decisions, and the verified related-projects shortlist /
  positioning / caveats in the phase notebook `phase.md` (not in the slice plans). Each slice
  fills its own `plan.md` when it runs.

Out of scope:
- Writing `README.md` content (done in P1.S1 / P1.S2).
- Pre-filling the new slices' `plan.md`.
- Versioned docs: `README.md` is a normal root file, not a `docs/` doc — no `doc-new-version`.

## Milestones

1. Create `P1.S1` and `P1.S2` with correct kind/risk/order/depends_on (bare folders).
2. Record the breakdown, decisions, and research findings in `phase.md`.
3. Record the decomposition in `result.md`, `finish-slice P1.DECOMP`, and `validate`.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `python3 scripts/workflow.py next` reports `P1.S1` as the current slice.
- `works/backlog.md` lists `P1.S1` and `P1.S2` in order; `P1.DECOMP` shown done.
- `phase.md` holds the decomposition + findings; the new slices' `plan.md` stay untouched templates.

## Operator Input (verbatim)

`/do-next-slice` was invoked with no inline note.

## Decisions (from operator Q&A this turn)

- Research the ecosystem first, then decompose accordingly (deep-research run completed:
  105 agents, 22 sources, 18 verified findings).
- Two slices: core README (S1) + value-add methodology/related (S2).
- Methodology section: fully agent-authored from the repo's design + agent best practices.
- Related section: see-also links + a light, research-backed positioning lead-in.
- Policy correction (operator): decomposition creates slices only and records findings/notes
  in `phase.md`; each slice fills its own `plan.md` when it runs and appends notes back to
  `phase.md`.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None. `README.md` is a root file, not a versioned `docs/` doc.
