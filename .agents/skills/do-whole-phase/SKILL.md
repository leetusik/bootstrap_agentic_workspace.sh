---
name: do-whole-phase
description: Finish the active phase end-to-end, including the review and any fix slices.
---

# do-whole-phase

Read `AGENTS.md` and the phase's `phase.md` (and its `intent.md` when present), run `python3 scripts/workflow.py next`, then finish every remaining slice in the current phase only. If you are ever unsure of the operator's intent, consult `intent.md` — the confirmed record of what was asked.

You are the ORCHESTRATOR (main thread): you plan each slice, verify, commit, move workflow state, and talk to the operator. Implementation and `fix` slices are delegated to the `slice-executor` subagent, one at a time and sequentially; decomposition stays with you; the review goes to `phase-reviewer`. Same contract as `do-next-slice`, looped over the phase.

Rules:

- If a slice or the phase is `pending` (shown `[~]`; `next` prints `WAITING ON OPERATOR`), STOP the loop: it needs operator co-work (validation or an operator-run action). Report what you need and do not start, finish, or advance past it. Resume only after the operator clears `pending` back to `in_progress`. If you hit such a point mid-slice, set it `pending` with `set-slice-status <slice_id> pending` and STOP.
- Re-read `works/state.json`, `works/backlog.md`, and the phase's `phase.md` after each slice.
- **Default loop — one slice at a time: plan → operator approves → executor, repeated.** For each slice, plan first at the operator's gate (in Claude Code, plan mode): research read-only, surface any clarifying questions, present the plan, and wait for approval. After approval, write the approved **native plan** to that slice's **own** `plan.md` (free-form — no template; let it incorporate any operator note), pulling context from `phase.md`; then dispatch the executor; then re-read state and plan the next slice. The gate pauses the run before every slice. Never pre-fill another slice's `plan.md`. The operator's verbatim intent lives in the phase's `intent.md`, not duplicated per slice.
- **`auto` (operator opt-in) skips the approval pauses.** If the operator invokes the skill with `auto` (e.g. `/do-whole-phase auto`; "run unattended" also counts), run the loop without stopping for approval: for each slice, plan → write `plan.md` → dispatch the executor → verify → finish → commit → next, to the end of the phase. `auto` waives only the approval gate — the safety halts still apply: a `pending` slice/phase, or any `needs_operator` / `blocked` / failed executor return, STOPS the loop even in `auto`.
- Implementation and `fix` slices: dispatch the `slice-executor` subagent (one at a time — wait for it to return before the next) to implement against `plan.md`; it writes `result.md`, appends notes to `phase.md`, and returns a structured verdict. (In Codex, execute each slice inline yourself by the same procedure.) Then verify before you trust: read the verdict and `result.md`, re-run `python3 scripts/workflow.py validate`, and re-run the executor's critical checks. On `needs_operator`, set the slice `pending`, report, and STOP; on `blocked`, record the blocker and STOP; on a failed/empty/unverifiable return, treat the slice as not done and STOP. Only a verified `done` proceeds.
- When the slice is a decomposition (`kind: decomposition`), it stays with you (no executor): create the middle slices with `new-slice` (folders only — do not pre-fill their `plan.md`) and record the breakdown, findings, and notes in `phase.md`.
- When a slice finishes (its `result.md` and `phase.md` notes written — by the executor, or by you for decomposition), run `finish-slice <slice_id>`, then `python3 scripts/workflow.py validate`.
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
