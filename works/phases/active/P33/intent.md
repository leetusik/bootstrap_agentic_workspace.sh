# Intent — P33

- Captured at: 2026-10-12T16:12:18+09:00
- Origin: operator

## Original Input (verbatim)

> the /rotate-backlog , I want this to be work like below:
> --
> 1. don't rotate rightaway. check if there is phase that owe a doc conslidation
> 2. if any, create phase for the doc consolidation
> 3. after the doc consolidation, automatically cleaen up the phases.
> 4. one /rotate-backlog command contain /create-phase , /do-whole-phase . one command, all clean.

When the orchestrator started reading the engine to change the skill in place, the operator interrupted:

> it's standalone task and need dedicated version.

## Confirmed Intent (refined + clarified)

**One `/rotate-backlog` invocation does the whole clean-up.** Today (v51) the command archives the clean phases first, then prints a docs-phase proposal, asks once, creates the docs phase on the operator's yes and STOPs; the operator runs `/do-whole-phase` by hand and `/rotate-backlog` again later to archive what the docs phase paid for. P33 replaces that three-step habit with one command:

1. **Check the debt first, archive nothing up front.** The run starts from `docs-debt` (and the engine's `rotate-backlog` proposal logic), not from an archive sweep.
2. **When any active phase owes consolidation, create the docs phase** through `create-phase`'s *docs-phase route*: `new-phase … --consolidates <every owing phase>` with the engine-drafted name and objective, `intent.md` filled per the route (origin `operator`, the invocation verbatim, the `docs-debt` scope, the cut `DECOMP` will make). **The `/rotate-backlog` invocation is the operator's yes** for that phase: the proposal is still printed so the operator sees what is being created, but there is no confirmation pause. This amends the contract and the `create-phase` skill for the docs-phase route only ("invocation is not the gate; confirmation is" stays true for every other phase). When a live docs phase already covers the debt (`docs_phase_covered=`), nothing is created and the run continues from that phase.
3. **Run the docs phase end to end** through `do-whole-phase` on the default stream, **in `auto` by default** (DECOMP planned inline, straight through); `gate` is the opt-in word that restores the approval loop. The normal stops still end the run: `pending`, `needs_operator`, `blocked`, a failed or empty high return, a failed review. The docs phase's acceptance gate is normally `--waive`d at its `DECOMP` boundary, as today.
4. **Then archive every done phase, the docs phase included** (the paid phases are clean once `docs-consolidated <P>` / `parallel-consolidated <P>` has run for each). Whole phases only, no `--force`, exactly the archive sweep `rotate-backlog` does today, just moved to the end.
5. **When nothing owes, archive the done phases right away** and report (today's `archive-only` output), and `/rotate-backlog archive-only` keeps the archive-and-report path with no docs phase.

**Queue and stream.** The docs phase jumps the queue: it runs ahead of planned work when every other slice on this stream is at a boundary (`todo`, `ready` or `done`). When any slice is mid-flight (`in_progress` or `pending`), or the phase it belongs to is `pending`, `/rotate-backlog` stops and reports instead of interleaving. The docs phase never runs in a worktree (`doc-new-version` and the payment commands only run on the default stream).

**Resumable.** A stop ends the run and reports exactly where it stopped. The next `/rotate-backlog` resumes from the live docs phase (which `rotate-backlog` and `docs-debt` already see as covering the debt), continues it through `do-whole-phase`, and archives at the end. The command is safe to re-run at any point of the chain.

**Ships as workspace v54** (P32, already planned, ships v53): engine (`rotate-backlog` and whatever knob the queue jump and the mid-flight check need), the `rotate-backlog` skill, the `create-phase` docs-phase route and gate wording, the `archive-phase` skill, the `do-whole-phase` line that forbids archiving at the end of a run, the contract (`CLAUDE.md`: the create-phase invocation exception, the archiving rule), the smoke test, the installer rebuild (`WORKSPACE_VERSION` to 54, `installer/build.py --check`), and the CHANGELOG v54 entry with its Migration notes line. Durable docs (operations *Durable-doc consolidation*, decisions) are versioned in a later docs phase via `## Doc impact` notes.

## Clarifications Resolved

- Q: Should the `/rotate-backlog` invocation itself count as the yes for the engine-drafted docs phase, or keep one confirmation ask before creating it? — A: **Invocation is the yes.** No pause; the proposal is still printed. Amends the contract for the docs-phase route only.
- Q: Should the embedded `do-whole-phase` run the docs phase in `auto` (DECOMP planned inline, straight through), with `gate` as the opt-in word? — A: **`auto` by default.** The normal stops (pending, blocked, needs_operator, a failed review) still end the run.
- Q: When another phase is active on this stream (P32 is planned now), should the docs phase jump the queue when every other slice is at a boundary, and should `/rotate-backlog` stop and report when a slice is mid-flight? — A: **Jump the queue, stop if mid-flight.** A later `/rotate-backlog` resumes from the live docs phase.
- Q: Confirm the name and objective, one phase, no worktree, workspace v54? — A: **Yes, create P33 with this.**

## Notes

For `DECOMP`, from the orchestrator's 2026-10-12 read of the machinery (read-only; nothing was changed):

- **Where today's behaviour lives.** Engine: `scripts/workflow.py rotate-backlog [--archive-only]` archives every clean phase, then prints `docs_phase_proposal=` (`phase=`, `name=`, `objective=`, the exact `create:` line, a `scope:` pointer), `docs_phase_covered=<P> (pays …)` or `docs_phase=none`; `docs-debt` prints the worklist and the `pay:` / `paid by:` lines; `new-phase --consolidates` is the only docs-phase marker (a top-level `consolidates` key in `phase.json`). Skills: `.claude/skills/rotate-backlog/SKILL.md` (propose-then-confirm, STOPs after `new-phase`, never decomposes); `.claude/skills/create-phase/SKILL.md` (*The docs-phase route* names `/rotate-backlog` as the default entry point and says "Invocation is not the gate; confirmation is"); `.claude/skills/archive-phase/SKILL.md`; `.claude/skills/do-whole-phase/SKILL.md` ("A passing review leaves the phase `done` in `active/`; do **not** archive it here"). Contract lines that move: "the agent may call `create-phase` **when instructed**, never on the agent's own initiative"; "Making a phase ≠ executing it"; "A decomposition slice plans at the operator's gate by default (inline only on an explicit `auto`)"; "Archiving is manual and takes whole phases only".
- **Durable docs that describe today's behaviour** (for the `## Doc impact` notes, not for editing here): `docs/current/operations.md` *Durable-doc consolidation — a docs phase* (the *Starting one*, *`/rotate-backlog` is the default entry point (v51)* and *Running one* paragraphs), the v51 release note near the top and the pre-v51 migration line; `docs/current/decisions.md` v0043 (the rotate docs-phase proposal decision).
- **Queue mechanics to settle at `DECOMP`.** `next` selects the current phase on this stream by order; the embedded run has to target the docs phase ahead of a `planned` phase with a lower order (an engine knob: an explicit phase argument to the run, or an order bump at creation), and the mid-flight check needs a single engine read (any slice `in_progress` / `pending`, any phase `pending` on this stream). Prefer engine-printed decisions over skill-side inference.
- **Resumption.** A live docs phase already surfaces as `docs_phase_covered=` and as `paid by: <P> (<status>)` in `docs-debt`; the resumed run should continue that phase rather than propose or create another.
- **Commits.** Each docs slice commits as today; the archive sweep commits as `chore(works): …` as today (`0d4f751`'s predecessor `34cb98d chore(works): archive P26-P31 with rotate-backlog` is the shape).
- **Overlap with P32 (planned, v53).** P32 edits `do-whole-phase`, the executor files and the contract's executor section; P33 edits `do-whole-phase`'s end-of-run line and the contract's create-phase and archiving rules. Independent phases, both on the default stream; whichever runs second rebases on the other's text. Not a dependency.
- **Upstream-repo rule.** After editing any embedded machinery file, run `python3 installer/build.py` and commit the rebuilt `bootstrap_agentic_workspace.sh` in the same commit; `--check` must pass (the pre-commit hook enforces it).
