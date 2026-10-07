# Plan — P31.S2 Operations: P26–P30 notes and the Operator Runtime section

## Goal

Fold the **20 operations notes** that `works/phases/active/P31/phase.md` `## Decisions` (*Cut*) assigns to S2 into **one** new operations version, plus **D50**: a real `## Operator Runtime` section. Follow the phase's rules: *Version source*, *Merge, don't append*, *Notes are the input*, *No restructuring* (except the runbook retitle) and *D50*. Also follow the shared doc-slice note and the S2 note under `## Notes for later slices`, which name candidate homes for each group of notes.

## Steps

1. **Read S2's input.** `python3 scripts/workflow.py docs-debt` prints the notes; every line beginning `operations.md`, including those that also name architecture, belongs to S2. Check the count against *Cut*. P31.S1's `result.md` records how the shared notes were stated in architecture v0010; keep the two docs consistent.
2. **Create the version:**
   ```
   python3 scripts/workflow.py doc-new-version --doc operations --source "P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW" --summary "P26-P30 design loop runbook, nested install default, rotate docs-phase proposal, Operator Runtime"
   ```
   Shorten the summary if the engine warns.
3. **Edit only the returned `edit_path`.**
   - **Runbook.** The visual-design runbook (`## Visual-design runbook (Claude Design + DesignSync; single-harness since v31)` and its subsections) is rewritten to the current truth:
     - P26's file loop: the design record contract under `docs/reference/design/`, the `design-*` commands, `design-drafter` dispatched in the background, read-back with `design-check`, literal signoff, superseding rounds, the mockup gate, and `design-register` as the operator's step.
     - P27's per-phase tool choice: `drafter` is the default and `claude-design` the alternative, with the `claude-design/` record, `design-migrate` and the claude-design runbook branch, including P27.F1's feedback-first routing.
     - The P26.F1/F2 self-contained card rule, as the contract text now states it (P26.F2 supersedes P26.F1's `#` wording).
     - Retitle the H2 to match, e.g. `## Visual-design runbook (two design tools: drafter or Claude Design, since v47/v48)`.
     - Keep the parts the notes leave true: styles, the mockup gate, implementation fidelity.
   - **Install modes.** State P29's truth throughout:
     - nested by default;
     - `--at-root` for the committed layout;
     - `--update` detects the layout;
     - `--nested` is a redundant no-op;
     - `--force-empty-ok` needs `--at-root`.

     P28's opt-in wording does not survive except as history where the doc's convention keeps it. P27.F3 (the utf-8 coding cookie) goes in the installer building section.
   - **P30.** Add `/rotate-backlog`'s proposal, `--archive-only`, `new-phase --consolidates` and `docs-debt`'s `paid by:` line to `## Durable-doc consolidation …`, plus anywhere the doc says rotate "leaves it active".
   - **Status and executor tiers.** Bring `## Status` up to the latest release (v51), in the doc's own Status convention, and add the drafter to `## Executor tiers` (P26.S2).
   - **D50: `## Operator Runtime`.** Add it near `## Local Development`, in the template's order (see `installer/payloads/doc_bodies/operations.md` for the field list). Fill it for **this** repo:
     - **Run commands:** the engine `python3 scripts/workflow.py <command>`; the built installer `sh bootstrap_agentic_workspace.sh <dir> [--at-root|--update|…]`, rebuilt with `python3 installer/build.py`.
     - **Mode:** there is no dev/production split; the built artifact is what ships, and `build.py --check` keeps it in sync.
     - **Origin:** none (CLI). The operator runs it in a terminal on the Mac.
     - **Devices / browsers:** none; there is no web surface.
     - **Browser instrument:** none. "Verified in a real browser" claims do not apply to this repo; verification is live CLI runs.
     - **Aside account:** n/a.
     - **What else is needed:** **scratch directories**. Mutating commands (`rotate-backlog`, `archive-*`, `new-phase`, installs) run in `cp -R` copies or fresh `mktemp -d` installs, never against this checkout unless the operator asks.
     - **Smoke suite:** `bash tests/retrofit_smoke.sh`, run once, alone in its own foreground Bash call.
     - **No `Status: UNFILLED` line,** since the fields are real.
4. Run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate`.

## Notebook

- `result.md`, verdict block first:
  - the version filename;
  - each note's landing section;
  - the D50 section, and that D50 is paid by this slice;
  - the oversized-section sizes after the edit (record only);
  - any contradiction the chains don't settle.
- In `phase.md`, consume the S2 note, add a note for S4 with the v0037 filename and anything decisions should reference, and rewrite `## Now`.
- No `## Doc impact` notes.

Do not commit, do not transition state, and do not run `docs-consolidated`. Touch no other doc.

---

## Promoted Deferred Context

# Deferred: D50 Record an Operator Runtime section in this repo's operations doc

## Why Deferred

P30.REVIEW observation (outside the boundary): operations.md has no ## Operator Runtime section; gate stage 1 relies on the P29 precedent that the product is the CLI with no browser

## Trigger to Promote

the next docs phase
