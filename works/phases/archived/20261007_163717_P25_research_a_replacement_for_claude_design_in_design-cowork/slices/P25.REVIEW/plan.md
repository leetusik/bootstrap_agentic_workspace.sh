# Plan — P25.REVIEW (review)

## Context

P25 is a findings-only research phase (see `intent.md`): it returns a ranked top 3 of Claude Design replacements for `design-cowork` and a recommendation on Claude Design. The phase has three slices:
- `P25.DECOMP`: the two-slice cut;
- `P25.S1`: verified the two readings and shortlisted four candidates;
- `P25.S2`: ranked 1. repo frames board, 2. Storybook + addon-mcp, 3. self-hosted Penpot; dropped Doop; recommended retiring the `DesignSync` loop and keeping Claude Design only as an optional import of its handoff bundle.

The acceptance gate is **waived** (`acceptance.required: false`), so there is no walkthrough and no running product to open.

## Boundary

`python3 scripts/workflow.py phase-scope P25` reports `product_files=0` (range `a02ed0a..HEAD`, 3 commits). The phase changed nothing outside `works/`. The Regression Checklist therefore has no line inside the boundary, so re-run none of it. Anything you notice outside the boundary is an observation or a deferred-job candidate, never a finding.

## Review

1. **State integrity:** `python3 scripts/workflow.py validate` exits 0.
2. **Objective and intent coverage.** Against `intent.md`, confirm the deliverable answers everything that was asked:
   - a ranked top 3 with trade-offs per criterion C1–C5;
   - the Claude Design optional-path recommendation;
   - both readings verified and stated (not assumed);
   - the persistent design memory (C5) addressed per option;
   - `frontend-design` placed only where needed;
   - the fixed governance untouched in every loop mapping.

   Read `slices/P25.S2/result.md` in full: it is the operator-facing report. Read `slices/P25.S1/result.md` heads-first, then the sections S2 relies on.
3. **Evidence discipline.** Spot-check that each headline claim names its evidence (probe command and output, doc URL, or "unverified" plus reasoning). Where it is cheap and read-only, re-verify two or three decisive claims yourself, for example a cited doc URL or a Storybook/Penpot fact. Do not re-run the Docker probes.
4. **Consistency.** `phase.md` `## Decisions` must agree with S1's and S2's `result.md` (rank order, drop reasons, recommendation). Nothing may be dropped between the logs and the notebook.
5. **Hard limits held.**
   - `git log a02ed0a..HEAD --stat` touches only `works/` and `docs/index.json` (timestamps).
   - No machinery edits.
   - Teardown: `docker ps -a`, `docker volume ls` and `docker images` show nothing named `p25s2` / penpot, and no probe port is listening.
6. **Doc impact.** Verify that `- (none …)` is correct: the phase changed no durable truth. Return `doc_versions: none — deferred to a docs phase`. Write no gate sections; the gate is waived and nothing changed.
7. **Route every `## Operator Questions` entry** (stack; canvas). With a waived gate there is no walkthrough. Route both as questions the orchestrator puts to the operator with the report, and fold them into one deferred-job candidate: "Adopt the chosen Claude Design replacement in design-cowork". That candidate carries both questions plus S2's §7 adoption notes as its inputs. Also list the Doop re-evaluation candidate from the S2 note. Return each deferred job as a spec (title, reason, trigger) for the orchestrator to file. **Do not run `defer-job` yourself.**
8. Rewrite `## Now` as the close-out, consume the `for P25.REVIEW` notes, and write `result.md` with the verdict block first.

## Verdict

- **`pass`** if the deliverable answers the intent with sourced evidence and the limits held. Findings that you repair inside the notebook (not source) are fine, and should be noted.
- **Otherwise:** finish every check first, then return `changes_requested` with numbered findings and proposed fix slices.

Also return:
- `explain: not written — run /explain for this phase`;
- no walkthrough (the gate is waived).
