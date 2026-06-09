---
name: do-whole-phase
description: Finish the active phase end-to-end, including the review and any fix slices.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash
disable-model-invocation: true
---

# do-whole-phase

Read `AGENTS.md` and the phase's `phase.md`, run `python3 scripts/workflow.py next`, then finish every remaining slice in the current phase only.

Rules:

- Re-read `works/state.json`, `works/backlog.md`, and the phase's `phase.md` after each slice.
- For each slice, fill its **own** `plan.md` before implementing (pull context from `phase.md`); if the operator passed a note with the command, record it verbatim under a `## Operator Input (verbatim)` heading in that slice's `plan.md`. Never pre-fill another slice's `plan.md`.
- When the slice is a decomposition (`kind: decomposition`), create the middle slices with `new-slice` (folders only — do not pre-fill their `plan.md`) and record the breakdown, findings, and notes in `phase.md`.
- When a slice finishes, write its `result.md` and append durable cross-slice notes to `phase.md` so later slices can build on them.
- Use `doc-new-version` for durable doc changes; never patch old doc versions or `docs/current/*.md` directly.
- Commit at every clean slice boundary by default, following the Commit Convention (branch first if on `main`; never push).
- When you reach the phase review slice, run the review:
  - In Claude Code, invoke the `phase-reviewer` subagent (read-only) and take its verdict.
  - In Codex, follow the `review-phase` skill checklist yourself.
- Record the verdict: `python3 scripts/workflow.py review-phase <P> --verdict pass|changes_requested|blocked --reviewer <name> --note "..."`.
- If the verdict is `changes_requested`, create concrete fix slices with `python3 scripts/workflow.py new-slice --phase <P> --slice <P.Fn> --name "..." --kind fix`, complete them, then re-review.
- Only a `pass` verdict marks the phase `done` (review-phase does this for you).
- A passing review leaves the phase `done` in `active/`; do **not** archive it here. Archiving is batched: only when every active phase is done (the last review slice complete) run `python3 scripts/workflow.py archive-all` to archive them all at once.
- Do not continue into the next phase.
