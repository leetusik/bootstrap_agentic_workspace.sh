# Plan — P26.S3: rewrite `design-cowork` around the files

## Context

S1 landed the on-disk contract (schema 1): the `design-cowork` section *The design record — the on-disk contract (schema 1)* plus `design-init/open/check/close/register`. S2 landed the `design-drafter` subagent. The rest of `design-cowork/SKILL.md` still describes the Claude Design + `DesignSync` loop. This slice rewrites the **loop mechanics** around the files and the drafter, keeping **every governance line's meaning**.

Binding `phase.md` notes (read them first):
- `for P26.S3`, from DECOMP: the section map, keep governance, the `frontend-design` ban lift, the frontmatter, what is out of scope, the smoke pins;
- `for P26.S3`, from S1: the loop's calls mapped onto the commands, the pane-worded leftovers, the mockup/Mechanics lines;
- `for P26.S3`, from S2: the dispatch order, the prompt contents, the new-direction signal, and the read-back on return;
- `for every slice`: the build and smoke rules.

## The new loop (the orchestrator's shape; write it precisely)

A `co-work` slice, per round:

1. **Inline:** `design-open --slug <s> --slice <slice>`, then write `rounds/<NN-s>/handoff.md`. It names the numbered card paths, says what to design and decides nothing, and states **"new visual direction: yes/no"**.
2. **Dispatched:** dispatch `design-drafter` in the background. The prompt carries only the round folder and the slice id. Handle its verdict:
   - `needs_operator`: fix the handoff with the operator, never fill the gap;
   - `blocked`: carries the named `design-check` problems.
3. **Inline read-back:**
   - Run `design-check <paths>` yourself. Never rest on the drafter's own line.
   - Read the cards and the round's `result.md`.
   - Run the concreteness check.
   - Commit the drafted round.
   - **PENDING #1** (`set-slice-status <slice> pending`, STOP). Report:
     - the card paths to open, with how to view them: open the card files directly in a browser until a design dashboard is registered, then the dashboard;
     - departures and `open_questions`;
     - whether `frontend-design` was used;
     - what the operator's words will do.
4. **Resume on the operator's words:**
   - **Literal approval, no mockup requested:** write `SIGNOFF.md` with their words, run `design-close <round> --words "<their words>"`, then `finish-slice` and commit. That is **one stop**.
   - **Feedback or revision:** record `feedback.md`, run `design-close <round> --superseded`, then `design-open` again in the **same slice** (the round inherits the addressed cards), re-dispatch the drafter, and return to PENDING #1. Nothing is signed.
   - **Mockup requested** (`Mockup: requested`, or asked for in the operator's words before the round closes): on their return, dispatch the mockup build to `slice-executor-high` from `build-prompt.md`, unchanged in meaning. That leads to **PENDING #2**. On their literal approval of the running mockup, write `SIGNOFF.md` and run `design-close --words`. That is **two stops**.

**Governance that must keep its meaning:**
- styles and rounds;
- immutable signed rounds, with superseding rounds on rejection;
- only the operator's literal words sign;
- the mockup gate (on request, a throwaway route, a second stop);
- RESPECT THE DESIGN;
- Verifying.

**The drafter replaces Claude Design as the one who draws.** The rule "never invent visual decisions in an executor" becomes: the design subagent drafts, the operator decides. A *slice executor* still never makes design decisions, and the mockup span builds only what the record says.

## Work

1. Rewrite the mechanics sections to the loop above. Use the DECOMP section map in `## Decisions`, and re-derive the line numbers, since S1 shifted them. The sections are:
   - §The loop (the diagram too);
   - §The handoff;
   - §The card set (the pane-worded leftovers; the marker bullet S1 fixed stays);
   - §Read back, then land it;
   - §Closing the round (keep the literal-signoff rule verbatim in meaning; the regroup becomes `design-close`);
   - §Mechanics (retire the `DesignSync` / `/design-sync` / main-thread-only material; state what is main-thread vs dispatched now);
   - the relevant §Never lines.

   Align cross-references to S1's contract section. Don't rewrite it.
2. **Frontmatter:**
   - drop `DesignSync` from `allowed-tools`;
   - rewrite `description:`: the design subagent drafts, the operator decides; the design lives as files in the repo. Quote or reword any `: `.

   Keep the trigger wording ("Use when a phase or slice touches a design system, a redesign, mockups…"), so the auto-fire behaviour is unchanged.
3. **Add a short "Importing a Claude Design bundle (optional)" subsection:**
   - the operator may still design in Claude Design and export its handoff bundle into the repo, at a path the handoff names that the contract readers ignore;
   - the drafter translates the bundle into cards under the contract, logging every departure;
   - the workspace never requires a claude.ai account, and `DesignSync` is not used.
4. **§Never:**
   - lift the `frontend-design` ban **for the drafter on new-direction rounds only**;
   - keep it for everyone else;
   - keep every other Never line's meaning.
5. **Out of scope:** D7, D13, and the Aside fallback paragraph in §Verifying. Don't touch `CLAUDE.md`, the do-* / create-phase / review-phase skills or the executor bodies; that is S4.
6. **Smoke:**
   - update the design pins in `tests/retrofit_smoke.sh` (Test 0, the design-cowork block) to the new wording;
   - retire the dead phrases as `gone` pins, e.g. `DesignSync is main-thread only`, `Connect GitHub`, `_ds_manifest.json`, `list_files`;
   - add a few `required` pins for the new load-bearing phrases: literal signoff, `design-close`, `design-drafter`, and "new visual direction";
   - `@dsCard` stays pinned.
7. Run `python3 installer/build.py`. In its own foreground Bash call with a 600 s timeout, run `bash tests/retrofit_smoke.sh` and report the count. Then run `python3 installer/build.py --check` and `python3 scripts/workflow.py validate`.

## Result and notebook

- `result.md`, verdict block first. It includes a **before/after governance audit table**: each governance rule, where it lived before, where it lives now, and "meaning unchanged" or the exact reason it changed. The review cross-checks it.
- `phase.md`:
  - `## Decisions`: the loop shape in 2–3 lines;
  - `## Doc impact`: operations, the Visual-design runbook rewritten to the file loop, the drafter and the bundle import. Decisions: why the loop moved off Claude Design (P25) and the drafter replaced it;
  - consume the S3 notes, and leave S4 exactly the wording it must mirror in `CLAUDE.md` and the do-* skills (the new co-work steps and stop counts);
  - rewrite `## Now`.
