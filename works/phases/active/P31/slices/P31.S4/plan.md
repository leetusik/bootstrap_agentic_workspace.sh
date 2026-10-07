# Plan — P31.S4 Decisions: P26–P30 notes

## Goal

Fold the **12 decisions notes** that `works/phases/active/P31/phase.md` `## Decisions` (*Cut*) assigns to S4 into **one** new decisions version. This is the last doc slice. Follow the phase's rules and every `(… for P31.S4)` note under `## Notes for later slices`. The S1, S2 and S3 notes name the versions to cite: architecture v0010, operations v0037 and qa v0013.

## Steps

1. Read S4's input. `python3 scripts/workflow.py docs-debt` prints the notes; every line beginning `decisions.md` belongs to S4. Check the count against *Cut*.
2. Create the version:
   ```
   python3 scripts/workflow.py doc-new-version --doc decisions --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 repo-file design contract, per-phase design tool, nested install default, rotate docs-phase proposal"
   ```
3. Edit only the returned `edit_path`.
   - **Decision Log entries.** Write the new entries at the **top** of `## Decision Log` (newest first), in the doc's existing entry format: `### <title> (phase P<N>, workspace v<NN>)`, then Date, Status, Context, Decision, Consequences / Alternatives as the existing entries do. Write one entry per phase, so five entries: P26 (v47), P27 (v48), P28 (v49), P29 (v50) and P30 (v51). Within each phase entry, fold that phase's notes.
     - **P26:** the move off Claude Design and DesignSync, and why: claude.ai login, `ocx claude`, no DesignSync in a subagent, P25's ranking, D27 superseded. Also:
       - the hard-rule reword the operator confirmed;
       - the schema-1 contract choices and why;
       - the drafter follows the high tier;
       - the `frontend-design` licence;
       - `design-check`'s strict reference text, with P26.F2's "fragments are named in the contract text" **replacing** P26.F1's `#` "reading" (state the final rule once, and mention that F1 was superseded).
     - **P27:** the design tool is a per-phase choice, and an absent choice reads as `drafter`. Also:
       - the `claude-design/` record sits outside schema 1;
       - where the two loops differ, P26's governance wins;
       - under claude-design: one push per round, superseding rounds in the same slice, and a missing DesignSync stops `pending` with no fallback.
     - **P28:** keep the **install-time rewrite and the `wf-<name>` clash map** here, because architecture v0010 and operations v0037 point to decisions for them. The opt-in `--nested` default is **superseded by P29**; mark that in the entry's Status line.
     - **P29:** nested by default everywhere, with `git init` for new or empty directories and the convention recorded as confirmed. Also:
       - `--at-root` / `--into-existing` reach the committed layout;
       - `--update` detects the layout;
       - `--nested` is a no-op;
       - there is no migration;
       - a new dir inside another repo's work tree refuses (the P29 operator question).
     - **P30:** `consolidates` is an explicit marker rather than name or intent detection. Rotate **proposes** rather than creates, which keeps create-phase's confirmation gate. The rotate skill writes `intent.md` itself, so its `allowed-tools` widen while `disable-model-invocation` stays.
   - **Superseded Decisions.** Add bullets where an older entry is replaced, in the section's convention:
     - the Claude Design + DesignSync design-loop entries, superseded by P26 and partly restored as an option by P27;
     - P28's opt-in install default, superseded by P29.

     Leave the older entries' text in place, as the doc's convention does.
   - **Status.** Bring `## Status` up to v51 in its own convention.
   - **Cite, don't restate.** Name v0010 / v0037 / v0013 where an entry would otherwise restate a runbook or test detail.
4. Run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate`.

## Notebook

- `result.md` (verdict block first): the version filename, each note's landing entry, section sizes (record only; the Decision Log stays unsplit, since D25 is deferred), and any contradictions.
- In `phase.md`:
  - Consume the S4 notes.
  - Rewrite `## Now` to say every note is covered and the orchestrator pays P26–P30 next.
- No `## Doc impact` notes.

Do not commit, do not transition state, and do not run `docs-consolidated` (the orchestrator does that). Touch no other doc.
