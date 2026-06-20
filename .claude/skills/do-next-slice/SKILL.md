---
name: do-next-slice
description: Continue the active phase by completing exactly one slice, then stop.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# do-next-slice

Run `python3 scripts/workflow.py next`, then read `AGENTS.md` (or `CLAUDE.md`), `docs/current/*.md` as needed, `docs/index.json`, `works/state.json`, `works/backlog.md`, the selected slice folder, and the phase's `phase.md` (the phase notebook — accumulated decomposition, findings, and cross-slice notes). If you are ever unsure of the operator's intent, consult the phase's `intent.md` (linked from `phase.md`) — the confirmed record of what was asked.

You are the ORCHESTRATOR (main thread): you plan each slice, verify, commit, move workflow state, and talk to the operator. The implementation of an implementation/`fix` slice is delegated to the `slice-executor` subagent — in Claude Code you do not write that slice's code yourself. One slice, then stop.

If `next` prints `WAITING ON OPERATOR` (the current slice or phase is `pending`, shown `[~]`), STOP: the work is waiting on operator co-work. Report what is needed and do not start, finish, or advance it. Resume only after the operator approves and clears the `pending` status back to `in_progress`.

Work exactly one slice:

1. If the selected slice is `todo`, run `python3 scripts/workflow.py start-slice <slice_id>`.
2. Plan the slice at the operator's gate before implementing. Research read-only, surface any clarifying questions, present the plan, and get the operator's approval — in Claude Code, do this in plan mode. This is the slice-level intent step (refine → clarify → confirm when an operator note is ambiguous; consult `intent.md` when unsure). After approval, write the approved **native plan** to this slice's own `plan.md` — free-form, no template; pull relevant context from `phase.md` and let the plan incorporate any operator note (the operator's verbatim intent lives in the phase's `intent.md`). Never pre-fill another slice's `plan.md`. If the operator invoked the skill with `auto` (e.g. `/do-next-slice auto`; "run unattended" also counts), skip the approval pause — plan, write `plan.md`, and dispatch the executor right away. `auto` waives only the approval gate, not the `pending` / `needs_operator` / `blocked` safety stops.
3. Dispatch the `slice-executor` subagent to implement the slice: give it the slice id and folder path; it reads `plan.md`, `phase.md`, `slice.json`, the docs, and the code itself, implements, runs the slice's validation, writes `result.md`, appends durable cross-slice notes to `phase.md`, and returns a structured verdict (`status` = `done` | `needs_operator` | `blocked`, plus `summary`, `files_changed`, `validation`, `deviations`, `doc_versions`). Do not implement the slice yourself. (In Codex, execute the slice inline yourself by the same procedure: implement, run validation, write `result.md`, append `phase.md` notes.)
4. Verify before you trust. Read the returned verdict and `result.md`, re-run `python3 scripts/workflow.py validate` yourself, and re-run the critical checks the executor reported. Then act on `status`:
   - `done` and verified clean → continue to step 5.
   - `needs_operator` → set the slice `pending` (`python3 scripts/workflow.py set-slice-status <slice_id> pending`), report the `operator_need`, and STOP without finishing.
   - `blocked` → record the blocker in `result.md`, report it, and STOP.
   - failed, empty, or unverifiable return → treat the slice as not done: do not finish, do not commit; report and STOP.
5. Mark the slice done with `python3 scripts/workflow.py finish-slice <slice_id>` only when complete and verified.
6. Run `python3 scripts/workflow.py validate`.
7. Commit by default: group the slice's pending changes into focused `type(scope): summary` commit(s) following the Commit Convention. Committing is the orchestrator's job — the executor never commits. Do not branch unless the operator asks; never push.

When the selected slice is a decomposition (`kind: decomposition`), it is **not** delegated — you do it inline, and step 3 means decomposing the phase, not writing code:

- Create the middle slices with `python3 scripts/workflow.py new-slice --phase <P> --slice <P>.S<n> --name "..."` (add `--kind`, `--risk`, `--order`, `--depends-on` as needed). Create the slices **only** — do not pre-fill their `plan.md`; each slice fills its own when it runs.
- Record the slice breakdown (what each slice covers and why) plus any research or findings in the phase's `phase.md`, so later slices share that context.

When the selected slice is a phase review (`kind: review`), step 3 means running the review, not delegating to the executor:

- Invoke the read-only `phase-reviewer` subagent for the phase; record its verdict and the review outcome in `result.md` (the machine verdict is also persisted to `phase.json` by `review-phase`). (In Codex, follow the `review-phase` skill checklist instead.)
- Record the verdict: `python3 scripts/workflow.py review-phase <P> --verdict pass|changes_requested|blocked --reviewer phase-reviewer --note "..."`.
- On `pass`: run `finish-slice <slice_id>`. A passing review marks the phase `done` but it **stays in `active/`** — archiving is a separate, manual step, so do **not** archive now. Archive later, when the operator asks: `archive-all` once every active phase is done, `rotate-backlog` to archive just the done phases while others continue, or `archive-phase <P>` for one phase.
- On `changes_requested`: create fix slices (`python3 scripts/workflow.py new-slice --phase <P> --slice <P>.F<n> --name "..." --kind fix`) and leave the review slice open for re-review; do not finish or archive.
- On `blocked`: record the blocker; do not finish or archive.

For durable doc changes during an implementation/`fix` slice, the executor runs `doc-new-version` + `rebuild-docs` and reports the versions; you confirm them with `validate`. If you make a durable doc change yourself (decomposition or review follow-up), run `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <slice_id>`, edit only the returned `edit_path`, then `python3 scripts/workflow.py rebuild-docs` — never patch `docs/current/*.md` or old versions.

Stop after one slice. Do not advance to the next slice in the same turn.
