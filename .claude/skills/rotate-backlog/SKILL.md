---
name: rotate-backlog
description: "Archive every currently-done phase, then propose the docs phase that pays the doc debt holding the rest back and create it on one operator confirmation; the word archive-only skips the proposal."
argument-hint: "[archive-only]"
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write
disable-model-invocation: true
---

# rotate-backlog

Archive every phase that is **currently done** (all slices complete with a passing review and no doc debt), leave the rest active, then — **by default** — turn the phases held back *only* by unpaid doc consolidation into a **proposed docs phase** the operator confirms once.

**This is the partial rotation `archive-all` cannot do.** `archive-all` refuses unless *every* active phase is done; `rotate-backlog` sweeps just the done phases and leaves the rest. It archives whole phases only, and there is no `--force`: to archive an unfinished phase, use `archive-phase <P> --force`. The proposal changes none of that — archiving is untouched, and `rotate-backlog` itself never creates a phase.

## Procedure

1. **Run the rotation.**

   ```sh
   python3 scripts/workflow.py rotate-backlog
   ```

   If the invocation args contain `archive-only`, run `python3 scripts/workflow.py rotate-backlog --archive-only` instead, relay its output, and **STOP**: that is the archive-and-report behaviour with no proposal.

2. **Relay** what was archived and what was left active, with the reason the output gives for each.

3. **Read the ending of the output.** Every default run ends in one of these:

   - `docs_phase=none` — nothing is held back only by doc debt. Report it and **STOP**.
   - `docs_phase_covered=<PX> (pays …)` — a live docs phase already covers those phases. Name it and say nothing needs creating for them.
   - a `docs_phase_proposal=` block — `phase=`, `name=`, `objective=`, the exact `create:` line and a `scope:` pointer — for the owing phases no live docs phase covers.

   One run can print covered lines **and** a proposal; handle each as above.

4. **Propose, and ask once.** Present the proposed `phase`, `name` and `objective`, plus the scope from `python3 scripts/workflow.py docs-debt` in a few lines: the phases, the note count, the docs. The operator may edit the name or the objective, or **narrow the phase list** — a phase left out keeps owing and stays active. Wait for an explicit answer.

   **The confirmation gate is `create-phase`'s, unchanged:** typing `/rotate-backlog` is not the confirmation, and `new-phase` runs only after the operator confirms the name and objective. A no, or no answer, creates nothing.

5. **On their explicit yes, create the phase.** Run the printed `create:` line as is. If the operator edited the name or objective or narrowed the list, run the same shape with their text, and with `--consolidates` naming only the kept phases (a phase left out keeps owing). Then fill the new phase's `works/phases/active/<P>/intent.md` **exactly as the `create-phase` skill's *docs-phase route* says**, which stays the source of truth:

   - Origin `operator`.
   - Under *Original Input (verbatim)*, the operator's own words: their `/rotate-backlog` invocation and their confirming reply.
   - Under *Confirmed Intent*, the confirmed name and objective and the `docs-debt` scope.
   - The cut the phase's `DECOMP` will make, written down and not made: one `--kind docs` slice per doc, `doc-new-version` → `rebuild-docs` per note, and the payment per covered phase (`docs-consolidated <P>`, or `parallel-consolidated <P>` as `docs-debt`'s `pay:` line says). The acceptance gate is normally `--waive`d at the `DECOMP` boundary.

6. **STOP and report.** Give the phase id, the `intent.md` path, and that `/do-whole-phase` (or `/do-next-slice`) executes it. **Never decompose it or write any slice's `plan.md`** — that is the phase's own `DECOMP`, later.

## Rules

- The docs phase runs on the **default stream**, like every phase: `doc-new-version` and the payment commands only run there. Never offer to run it anywhere else, and relay without acting on any parallel-run hint `new-phase` prints.
- A phase blocked for any other reason (unfinished, unreviewed, or a parallel phase not yet merged) is reported as before and never proposed.
- Never run `new-phase` before the operator's yes, and never run `archive-phase`, `archive-all` or a `--force` on the operator's behalf.
