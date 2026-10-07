# Plan — P31.S1 Architecture: P26–P30 notes

## Goal

Fold the **9 architecture notes** that `works/phases/active/P31/phase.md` `## Decisions` (*Cut*) assigns to S1 into **one** new architecture version. Follow the phase's rules: *Version source*, *Merge, don't append*, *Notes are the input*, *No restructuring*. Also follow the S1 note and the all-slices note under `## Notes for later slices`.

## Steps

1. Print the notes with `python3 scripts/workflow.py docs-debt`. Every line beginning `architecture.md` (including the two that also name operations) is S1's input. Check the count against *Cut*.
2. Create the version:
   ```
   python3 scripts/workflow.py doc-new-version --doc architecture --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 design contract and drafter, design tool choice, nested install default, rotate docs-phase proposal"
   ```
   Keep the summary short; shorten it if the engine warns.
3. Edit **only** the returned `edit_path`. Fold each note into the section it belongs to, and replace every statement it supersedes. Where a chain exists, the doc states the latest truth:
   - The design loop is P26's file contract plus the drafter, then P27's per-phase tool choice.
   - The install default is P29's nested default, not P28's opt-in `--nested`.
   - The nested marker is `workflow/.agentic-nested.json`.

   If a note contradicts the doc's existing text in a way the chain doesn't settle, record it in `result.md`; never silently choose. Read code only to resolve an ambiguous note.
4. Run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate`.

## Notebook

- `result.md`, verdict block first:
  - the version filename;
  - which note landed in which section;
  - the oversized-section sizes after the edit (record only, never split);
  - any contradictions.
- In `phase.md`, consume the S1 note, record the cut version for S4, and rewrite `## Now`.
- No `## Doc impact` notes; a docs phase leaves none.

Do not commit, do not transition state, and do not run `docs-consolidated`. Touch no other doc.
