# Plan

- Phase ID: P1
- Slice ID: P1.S1
- Slice: Core README
- Created at: 2026-06-10T01:17:11+09:00

## Goal

Write the core of the root `README.md` — everything except the featured methodology and the
"Related / inspired by" sections (those are P1.S2). Make the workspace approachable to a newcomer:
what it is, how to bootstrap it, how to drive it day-to-day, its structure, how to contribute, and
its license. Link `CLAUDE.md` / `AGENTS.md` / `docs/` as the source of truth instead of duplicating.

## Scope

Sections owned by this slice (final README order; ★ sections 7–8 are P1.S2):

1. Title + one-line tagline (+ optional Apache-2.0 badge)
2. Table of Contents (S2 will add its two entries)
3. What is this? / Why — overview + the problem it solves
4. Quickstart — `bootstrap_agentic_workspace.sh`: prereqs, clone-first install + `curl | sh`
   convenience, run syntax, flags table, what gets created, safety behavior
5. How it works (day-to-day) — phase/slice/deferred model, the routing principle, `scripts/workflow.py`,
   the 10 cross-tool skills + `phase-reviewer`, command cheat-sheet, 4-step read order
6. Project structure — annotated tree
9. Contributing — use the workflow itself; commit convention; keep `CLAUDE.md`+`AGENTS.md` in sync;
   never hand-edit `docs/current/*.md`
10. License — Apache-2.0

End the file at the **S2 insertion anchor**: the blank line between "Project structure" and
"Contributing". P1.S2 inserts sections 7–8 there.

Out of scope (P1.S2): the ★ "How I work with coding agents" methodology and "Related / inspired by".

## Milestones

1. Write `README.md` sections 1–6 + 9–10 from verified repo facts (flags, what-gets-created,
   10 skills, command list, structure tree) recorded in `phase.md` / the plan.
2. Verify links resolve (`CLAUDE.md`, `AGENTS.md`, `LICENSE`, `docs/`, `scripts/workflow.py`) and
   flags match `bootstrap_agentic_workspace.sh --help`.
3. `validate`, finish slice, write `result.md`, append S1→S2 hand-off notes to `phase.md`, commit.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `bootstrap_agentic_workspace.sh --help` matches the documented flags (already confirmed).
- README headings/TOC anchors render; relative links point at existing paths.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None. `README.md` is a root file, not a versioned `docs/` doc. No new doc version is created.
