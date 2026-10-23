---
name: rotate-backlog
description: "One invocation cleans up every done phase: it archives what is already clean, pays all the doc debt through the docs phase it creates or widens and runs (looping until nothing owes), goes around parked work, and archives every paid phase. It stops only for running work or for uncommitted product edits beside parked work. The word archive-only keeps the plain archive-and-report path; the word gate restores the approval loop."
argument-hint: "[archive-only] [gate]"
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash, Agent
disable-model-invocation: true
---

# rotate-backlog

One invocation cleans up every done phase. It archives the phases that already owe nothing at once, then pays the rest of the doc debt: it resumes the live docs phase (widening it to the new debt when it is undecomposed and still carries the engine-drafted name) or creates the one docs phase that pays it (the invocation is the operator's yes), runs it end to end on the default stream, asks the engine again, and loops until nothing owes. Then it archives every paid phase, the docs phases included.

It goes around **parked** work (a `pending` or `blocked` phase or slice, a slice with `changes_requested`): the docs phase runs ahead of it and never touches it, and the report lists it. That is safe because a docs phase writes only workflow docs and the engine has checked that the product tree is clean; a `/do-whole-phases` run parks only an open acceptance gate. It stops only for **running** work (a slice `in_progress` or `in_review`, a phase `in_review`) or for uncommitted product edits beside parked work. A re-run at any point resumes from the live docs phase.

The engine decides; this skill runs the chain. `python3 scripts/workflow.py rotate-backlog` prints one decision as its **first stdout line**, `rotate=<branch>`, and the branches below follow it. Archiving stays whole-phase only and never uses `--force`: to archive an unfinished phase, use `archive-phase <P> --force` by hand.

## Procedure

1. **`archive-only` in the invocation args:** run `python3 scripts/workflow.py rotate-backlog --archive-only`, relay its report, and **STOP**. That is the plain archive-and-report path: it creates, reorders and runs nothing, and it is not refused on a parallel stream.

2. **Otherwise run the engine** and read its **stdout before its exit code** (`refused` exits 1):

   ```sh
   python3 scripts/workflow.py rotate-backlog
   ```

   Every branch but `refused` and `archive` first archives the phases that are cleanly archivable (never one that owes docs), then prints, after the first line and before the branch's own lines:
   - `archived=<ids>` when it moved any. Relay and commit it first (`chore(works): archive <ids> with rotate-backlog`). It may name a phase the docs phase has just paid, because `docs-consolidated` makes it archivable on the next run.
   - one `parked=<id> status=<status>[ stop_kind=<kind>]` per parked item (a blocked or `changes_requested` item has no `stop_kind`). Relay each; touch none.

   **Every commit of the run, the docs phase's slice commits included, names its own paths** (the phases it archived, created, widened or ran, and the regenerated files under `works/`) and leaves the parked phases' folders out: `git add -- <paths>`, then `git commit -- <paths>`, never `git add -A`.

   Branch on the first line as a prefix:

   - **`rotate=refused`** (`rotate=refused stream=<branch>`): this checkout is a parallel stream. Relay the line and the stderr message, tell the operator to run `/rotate-backlog` from the main checkout, and **STOP**. Nothing was written.

   - **`rotate=archive`**: nothing owes and no docs phase is live. Relay the sweep report verbatim (`rotated <n> done phase(s) to archived:` with its `- <P>: <path>` lines, or `no done phases to rotate…`, or `no active phases to rotate`), plus any `docs_phase_elsewhere=` line (a docs phase on another stream that is not resumed here). Commit the archive (`chore(works): archive <ids> with rotate-backlog`), or commit nothing when nothing was rotated. Report and end the run.

   - **`rotate=stop_midflight`** (`midflight=<id>:<status>, …`): a docs phase is owed or live, and default-stream work is running right now (the list holds running items only). Relay `midflight=`, `archived=` (commit it), the `parked=` lines, `stopped_before=` and the closing line. Nothing was created, widened or reordered. **STOP**; a re-run once no listed slice is `in_progress` or `in_review` and no listed phase is `in_review` goes on.

   - **`rotate=stop_uncommitted`** (`uncommitted=<n>`): something is parked and the product tree holds uncommitted edits, which a parked item may own and the docs phase's commits would take. Relay `uncommitted=` with its path lines, `archived=` (commit it), the `parked=` lines, `stopped_before=` and the closing line. Nothing was created, widened or reordered. **STOP**: the operator commits or stashes those edits, then re-runs. A workspace without git never prints this.

   - **`rotate=resume`** (`rotate=resume docs_phase=<P>`): a docs phase is live.
     1. If a `docs_phase_widened=<P> <old> -> <new>` line was printed, the engine widened the docs phase (undecomposed, with its engine-drafted name) to the debt no docs phase paid yet: it rewrote `consolidates`, name and objective. Add one dated line to `works/phases/active/<P>/intent.md` *Notes* (`- <date>: widened by rotate-backlog from <old> to <new>`). A decomposed or renamed docs phase is never widened: it runs as it is, `docs_debt_waiting=` names the rest, and the loop in step 3 creates one more docs phase for it.
     2. If a `docs_phase_order=<P> <old> -> <new>` line was printed, the engine re-asserted the queue jump: `phase.json` and the regenerated `works/` files changed. Commit the widening and the order change together (`chore(works): widen <P> with rotate-backlog`, or `chore(works): move <P> ahead with rotate-backlog` when only the order moved) before anything else. Relay any `docs_phase_covered=` and `docs_debt_waiting=` lines.
     3. **Run the docs phase `<P>` end to end per the `do-whole-phase` skill, in `auto`.** `python3 scripts/workflow.py next` now points at it (it sorts first by order); its `WAITING ON OPERATOR` for a parked item is not the run's stop while the docs phase sorts first. The `/rotate-backlog` invocation is the explicit `auto` that the contract's decomposition carve-out requires, so the docs phase's `DECOMP` plans inline; `gate` in the invocation args restores the approval loop instead. Its acceptance gate is normally `--waive`d at the `DECOMP` boundary. Every normal stop ends the run (`pending`, `needs_operator`, `blocked`, a failed or empty high return, a non-passing review): report where it stopped and that the next `/rotate-backlog` resumes from there.
     4. When the docs phase is `done`, go to step 3.

   - **`rotate=create`**: a docs phase is owed and none is live.
     1. **Show the proposal** so the operator sees what is being created: `docs_phase_proposal=`, `phase=`, `name=`, `objective=`, and the `scope:` line's `python3 scripts/workflow.py docs-debt` in a few lines (the phases, the note count, the docs). Relay any `docs_phase_covered=` line.
     2. **Run the printed `create:` line exactly as printed.** Its `--order` is the queue jump ahead of planned work. The `/rotate-backlog` invocation is the operator's yes for the engine-drafted name, objective and scope: no pause, no narrowing, no editing. Read the new phase id `<P>` from the `phase=` line and keep it for the rest of the invocation, across a compaction too: this run has created its one docs phase. Relay any parallel `hint:` the engine prints; never act on it.
     3. **Fill `works/phases/active/<P>/intent.md`** as the `create-phase` skill's *docs-phase route* says, which stays the source of truth: origin `operator`; under *Original Input (verbatim)*, the `/rotate-backlog` invocation; under *Confirmed Intent*, the engine-drafted name and objective and the `docs-debt` scope; and the cut the phase's `DECOMP` will make, written down and not made: one `--kind docs` slice per doc, `doc-new-version` then `rebuild-docs` per note, and the payment per covered phase as `docs-debt`'s `pay:` line says (`docs-consolidated <P>`, or `parallel-consolidated <P>`), with the acceptance gate `--waive`d at the `DECOMP` boundary.
     4. **Commit** (`chore(works): create <P> with rotate-backlog`), then continue as `resume` from its step 3.

3. **Loop.** After each docs phase is `done`, run `python3 scripts/workflow.py rotate-backlog` again and branch on its first line:
   - `rotate=archive`: relay the sweep, commit it (`chore(works): archive <ids> with rotate-backlog`) and report; the run ends.
   - `rotate=resume`: another docs phase is live; run it as above.
   - `rotate=create`: only if this invocation has created no docs phase yet; otherwise relay it and end the run, and the next `/rotate-backlog` takes that step.
   - anything else (`stop_midflight`, `stop_uncommitted`, `refused`): relay it, commit any `archived=`, and end the run.

   An invocation creates at most one docs phase, and each docs phase ends `done` or stops the run, so the loop is finite.

## Rules

- The docs phase runs on the **default stream** only, like every docs phase: `doc-new-version` and the payment commands run nowhere else. Never ask for a worktree, and relay without acting on any parallel-run hint `new-phase` or `next` prints.
- Create the docs phase only through the printed `create:` line, as printed. Never narrow, edit or re-word it, and never run `--force`, `archive-phase` or `archive-all` on the operator's behalf.
- Never touch a parked item: not its status, not its folder in a commit, not the files it owns.
- Every stop is reported with the exact engine line that caused it.
- `archive-only` never creates or runs anything.
