# design-cowork — read back, publish, PENDING #1

## Read back, then publish

**Read back each job yourself; a `done` is a claim, not your check:**

1. **`python3 scripts/workflow.py design-check <job>`.** **Never rest on the drafter's own
   `design_check` line.** Exit 1 goes back to the drafter on the same open round with exactly the
   named
   problems; if they survive that pass, report them and hold the job.
2. **Read** `result.md` (its intent lines, data, gaps, departures) and `build-prompt.md`, the
   drafter's
   verdict and, when critique was on, the critique's `## Scorecard`. Render it yourself with
   `design-preview` when you need to see something; you never view the published canvas to check it.
3. **Concreteness check.** The bar: *no design decision is left to invent.* A `build-prompt.md` too
   thin to build from goes back to the drafter with the gaps named. A question only the operator can
   settle goes to them at the stop as a decision to take. **Never fill a design gap yourself.**

**Then publish** (main thread only):

1. **Read back first, from the second round on.** `read` the canvas's files with `out_dir` and diff
   them against `jobs/<job>/canvas/project/`. A difference is an operator edit (*The operator's
   words*): record it before you send anything. **Opening a canvas in the app saves a new version**
   with no board change, so a newer version whose `project/` files are unchanged is normal, not an
   edit.
2. **`design-publish-plan <job>`** prints `{url, root, file_path, files}`: the changed files and
   removed ones mapped to `null`. The system files, as server-side copies from the system Artifact
   (`ds/` is never sent from disk), are in it only on the job's **first publish** or when the system
   version its `canvas.json` pins has changed since the last publish (`job.json` `canvas.system`);
   otherwise they are left out, and the server keeps them. Pass the plan to `Artifact` `publish` as
   is, with a per-round `label` (`round 02-revise`); never trim it.
3. **`design-canvas <job> --version <id>`** with the version id the publish returned. It also records
   the system version the publish installed (`canvas.system`), which the next plan compares against.
4. **A publish refused over the operator's in-app edit:** `read` the file it names, diff it, copy it
   into the repo tree and record it verbatim in `feedback.md` as their decision, then republish.
   **Never `force`.**

**Land the notebook's half.** Spec **pointers** into `phase.md`: each job's address and canvas link,
the mockup route once one exists, and the decisions later slices must not re-litigate. The boards and
the full spec stay in the record, linked by path.

## PENDING #1 — one stop per wave

When every job of the wave is published or held: commit,
`set-slice-status <slice> pending --stop-kind wave --on-words "<what their words will do>"`, and STOP. The commit is `feat(design): <slice> drafted — <job>/<round>, …` (a superseding round:
`… — supersedes <job>/<round>`), carrying the handoffs, the canvas trees, the round records, the
critique files and the closes of superseded rounds. The report, per job:

- **the canvas link** to open, and what each Page is for;
- **the scorecard** when critique was on: the open Part 1 / 2a items, the bar line by line, **Holds**
  and **Not seen**;
- the **2b taste notes**, each a decision to take;
- **open wave choices**, on both jobs;
- **what the answer pass left open**: each rebuttal and each fix that did not hold, with both sides;
- **unsure items** under `critic`, and **low-confidence items** when the judge was skipped;
- the drafter's departures, `component_gaps` and `open_questions`;
- a held job's exact need (`needs_operator`, `blocked`, a failed read-back);
- **what their words will do:** literal approval signs that job (or starts its mockup, when one was
  requested); anything else is feedback, and a superseding round re-drafts it. Comments they send to
  Claude and edits they make in the canvas are read when they return.

## Never — the round's channels

- Make a round depend on a `git push` or a repo connection: a design slice authorizes no `git push`.
