---
name: do-whole-phase
description: Finish the active phase end-to-end, including the review and any fix slices.
---

# do-whole-phase

Read `AGENTS.md` and the phase's `phase.md` (and its `intent.md` when present), run `python3 scripts/workflow.py next`, then finish every remaining slice in the current phase only. If you are ever unsure of the operator's intent, consult `intent.md` — the confirmed record of what was asked.

You are the ORCHESTRATOR (main thread): you plan each slice, verify, commit, move workflow state, and talk to the operator. Every middle slice — decomposition, implementation, and `fix` — is delegated to the `slice-executor` subagent, one at a time and sequentially; only the review goes to `phase-reviewer`. Same contract as `do-next-slice`, looped over the phase.

Rules:

- If a slice or the phase is `pending` (shown `[~]`; `next` prints `WAITING ON OPERATOR`), STOP the loop: it needs operator co-work (validation or an operator-run action). Report what you need and do not start, finish, or advance past it. Resume only after the operator clears `pending` back to `in_progress`. If you hit such a point mid-slice, set it `pending` with `set-slice-status <slice_id> pending` and STOP.
- Re-read `works/state.json`, `works/backlog.md`, and the phase's `phase.md` after each slice.
- **Default loop — plan → operator approves the readied plan → executor, repeated.** The orchestrator advances on its own: after each slice it **automatically enters plan mode to plan the next** — it never stops to ask permission to start planning. For each slice: in Claude Code, **call the `EnterPlanMode` tool** to enter plan mode, do read-only research (surface any clarifying questions), then **call `ExitPlanMode` to present the readied plan** for the operator's approval. (In Codex, present the readied plan inline and wait for approval.) The only pause is approving the finished plan — never a pause before planning begins. After approval (the harness exits plan mode), write the approved **native plan** to that slice's **own** `plan.md` (free-form — no template; let it incorporate any operator note), pulling context from `phase.md`; then dispatch the executor; then re-read state and head straight into planning the next slice (`EnterPlanMode` again). Never pre-fill another slice's `plan.md`. The operator's verbatim intent lives in the phase's `intent.md`, not duplicated per slice.
- **`auto` (operator opt-in) skips plan mode and the approval.** If the operator invokes the skill with `auto` (e.g. `/do-whole-phase auto`; "run unattended" also counts), do **not** enter plan mode (no `EnterPlanMode` / `ExitPlanMode`): for each slice, plan inline → write `plan.md` → dispatch the executor → validate (state integrity) → finish → commit → next, to the end of the phase. `auto` waives only the plan-approval pause — the safety halts still apply: a `pending` slice/phase, or any `needs_operator` / `blocked` / failed executor return, STOPS the loop even in `auto`.
- Delegated slices (decomposition, implementation, `fix`): dispatch the `slice-executor` subagent (one at a time — wait for it to return before the next) to do the slice's job against `plan.md`; it writes `result.md`, appends notes to `phase.md`, and returns a structured verdict. (In Codex, execute each slice inline yourself by the same procedure.) Then trust the verdict: read it and `result.md`, and run `python3 scripts/workflow.py validate` (state integrity only — do **not** re-run the slice's tests; the phase review validates all slices together). On `needs_operator`, set the slice `pending`, report, and STOP; on `blocked`, record the blocker and STOP; on a failed or empty return, treat the slice as not done and STOP. A `done` verdict proceeds.
- When the slice is a decomposition (`kind: decomposition`), it runs the same path as any slice: you plan it, then dispatch the `slice-executor`, whose job is to create the phase's middle slices with `new-slice` (bare folders — never pre-filling their `plan.md`) and record the breakdown, findings, and notes in `phase.md`.
- When a slice finishes (its `result.md` and `phase.md` notes written by the executor), run `finish-slice <slice_id>`, then `python3 scripts/workflow.py validate`.
- Durable doc changes: the executor runs `doc-new-version` + `rebuild-docs` for its slice and reports the versions (you confirm via `validate`); if you make one yourself, use the same commands and never patch old doc versions or `docs/current/*.md` directly.
- Commit at every clean slice boundary by default, following the Commit Convention (do not branch unless the operator asks; never push). Commits are the orchestrator's job — the executor never commits.
- When you reach the phase review slice, run the review:
  - In Claude Code, invoke the `phase-reviewer` subagent (read-only) and take its verdict.
  - In Codex, follow the `review-phase` skill checklist yourself.
- Record the verdict: `python3 scripts/workflow.py review-phase <P> --verdict pass|changes_requested|blocked --reviewer <name> --note "..."`.
- If the verdict is `changes_requested`, create concrete fix slices with `python3 scripts/workflow.py new-slice --phase <P> --slice <P.Fn> --name "..." --kind fix`, complete them (via the executor), then re-review.
- Only a `pass` verdict marks the phase `done` (review-phase does this for you).
- A passing review leaves the phase `done` in `active/`; do **not** archive it here. Archiving is a separate manual step — later, when the operator asks, use `archive-all` once every active phase is done, `rotate-backlog` to archive just the done phases while others continue, or `archive-phase <P>` for one phase.
- Do not continue into the next phase.
