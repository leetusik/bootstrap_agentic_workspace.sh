# Result — P16.S3 (Contract + review/loop skills: the F1/F2/F4/F6 rules)

Status: **done**. The rules that make agents *use* what S1 (engine) and S2 (seeded doc bodies)
landed are now written in the five prose surfaces the plan named — and nowhere else. No engine, no
agent files, no `design-cowork`, no CHANGELOG/README/tests, no `docs/`. Artifact rebuilt.

## The decision the plan left open — settled

**Docs consolidate in the review executor's `pass` path, *before* the gate opens** (the plan's
recommended option), outside parallel mode as today. The stage-4 smoke-list append to
`## Regression Checklist` rides that same consolidation.

- *Why:* one dispatch, no new orchestrator duty, mechanics unchanged. If the operator then reports
  failures, the `changes_requested` → fix → re-review cycle consolidates again and the newer
  versions supersede — doc versions are append-only durable truth, and a version describing code
  that exists is not false.
- *Trade-off accepted:* between a `pass` and the operator's `--clear` there is a window where the
  docs describe truth the operator has not yet accepted. The alternative (defer like parallel mode)
  buys the cleaner "docs describe accepted truth" semantics but costs a second review dispatch or an
  orchestrator-run consolidation — new surface in three skills for a window that closes within one
  operator reply.
- Recorded in `phase.md` *Findings & Notes* marked **binding for S4/S6**, and written into
  `CLAUDE.md`'s durable-docs rule plus `review-phase`'s pass bullet. Parallel mode is unchanged: it
  still defers to the post-merge step.

## What landed, file by file

### `CLAUDE.md` (+4 lines net; still a compact routing contract, no new section)

- *Orchestrator and executor*: a gated review returns a **`walkthrough`**; on a pass the
  orchestrator runs `accept-gate <P> --open --walkthrough "..."` (phase → `pending`), reports, and
  STOPS, recording `pass` only after the operator clears. Waived/legacy phases pass straight away.
- *Canonical State*: `phase.json` "optionally carries the five-field `acceptance` block
  (`required` / `walkthrough` / `requested_at` / `cleared_at` / `note`) … no block at all means a
  legacy phase (created before workspace v32) with no gate".
- *Hard Rules* — **three new bullets**:
  1. **Operator acceptance gate** — the whole lifecycle in contract voice: explicit declaration
     right after `finish-slice <P>.DECOMP` (`--require` / `--waive --note "why"`, never by
     omission), the engine's refusal of an undeclared pass, `--open` → `pending` → STOP, the
     operator's `--clear`, operator-reported failures → `changes_requested` → `fix` slices,
     `accept-gate` is a phase-state command **executors never run**, legacy = pass with one
     advisory line.
  2. **Operator runtime manifest** — `## Operator Runtime` in the operations doc, its six fields,
     "verified in a real browser" means *that* runtime and access path plus the production build
     when they differ, and absent == `UNFILLED` → the executor returns `needs_operator` and the
     orchestrator sets the slice `pending`.
  3. **Questions get asked, not archived — and the review checks the product, not only the
     reports** — the `## Operator Questions` running list, routing at the review (walkthrough or
     `defer-job`; unrouted = finding), and the review executor's own spot-check, fresh-eyes
     walkthrough (explicitly not judged against the design record), and whole-smoke-list re-run.
- Clauses grafted onto six existing sentences: the `pending` rule (an open gate clears with
  `accept-gate <P> --clear`, never `set-phase-status`), the `review-phase` rule (`pass` needs a
  cleared gate; `changes_requested`/`blocked` are never refused), the durable-docs rule (the
  consolidation-timing decision above), and the design rule (`real-browser fidelity` kept verbatim;
  fidelity now also means "works as a product" — one clause, S5 writes the specification).
- *Workflow Commands*: `accept-gate P1 [--require | --waive --note "..." | --open --walkthrough
  "..." | --clear [--note "..."]]` with a half-line description.

### `.claude/skills/review-phase/SKILL.md` (the biggest change, 47 → 78 lines)

- A new gate paragraph after the parallel-mode one: how to read `acceptance.required`
  (`true` / `false` / `null` / block absent = legacy), that the stages and the `walkthrough` apply
  **only** when `required` is `true`, that the executor never runs `accept-gate`, and one sentence
  on parallel mode (the gate opens and clears on the branch before the branch `pass`, so
  `parallel-gate` already implies operator acceptance; only consolidation is deferred).
- *Read* gains the `## Operator Questions` list and, on a gated phase, `## Operator Runtime` +
  `## Regression Checklist`. *Check* gains the routing question and "did you open the product
  yourself?".
- A new **Gate stages** section (`## Gate stages — only when acceptance.required is true`), six numbered
  steps: find the manifest (absent or `UNFILLED` → `needs_operator`), independent spot-check in the
  manifest runtime plus the production build when they differ, fresh-eyes UX walkthrough
  (explicitly not judged against the design record; findings go to the gate, never to silent
  fixes), re-run the **whole** smoke list and append this phase's lines in the shipped shape
  `- [ ] <surface>: <one observable behaviour> (P<N>)`, route every operator question, return the
  `walkthrough`.
- The pass bullet carries the consolidation-timing decision; a new
  **`## After a passing review — what the orchestrator does with it`** section spells out the
  four-step sequence (open → operator walks → record pass without re-dispatch → or
  `changes_requested` + fix slices) and states that waived/legacy phases skip it.
- An explicit prohibition paragraph: **`accept-gate` and `defer-job` are never run on a review
  slice** — the executor returns the walkthrough and *lists* the deferred jobs.

### `.claude/skills/do-next-slice/SKILL.md` and `.claude/skills/do-whole-phase/SKILL.md`

Symmetric edits, same vocabulary:

- The `WAITING ON OPERATOR` paragraph/bullet: an open gate prints `acceptance_gate=open` plus the
  walkthrough and clears with `accept-gate <P> --clear [--note "..."]`, **not** `set-phase-status`.
- The `DECOMP` boundary: declare the gate right after `finish-slice <P>.DECOMP`, in the same
  commit, from `intent.md` + the decomposition; never by omission.
- The review step: plan the gate stages and the `walkthrough` return; then a new bullet placed
  **before** "Record the verdict" — on `pass` with a required gate, do not record yet: `--open`,
  file the review's deferred jobs, `validate`, commit, report, STOP (in `do-whole-phase`: the loop
  ends here like any `pending`); on the resume, record the pass **without re-dispatching the
  review**; operator-reported failures → `changes_requested --note "operator-reported: …"` → `fix`
  slices → re-review.

### `.claude/skills/parallel-phase/SKILL.md`

One paragraph in §4: the gate opens and is cleared on the branch, against the branch's running
product, before the branch `pass` — so `parallel-gate`'s "branch phase `done` + review `pass`"
already implies the operator accepted what is about to be merged. No engine or command change.

### Rebuild

`python3 installer/build.py` → `bootstrap_agentic_workspace.sh`, 355784 bytes.

## Validation

| Command | Outcome |
|---|---|
| `python3 installer/build.py` | wrote the artifact (355784 bytes) |
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **Workflow validation passed** |
| `bash tests/retrofit_smoke.sh` | **ALL RETROFIT SMOKE TESTS PASSED** (Tests 0–8), re-run after the final edits |
| `python3 scripts/workflow.py sync-agents --check` | agent files in sync (untouched here) |
| Test 0 string invariants, asserted directly before the smoke run | all present in `do-next-slice`, `do-whole-phase`, `CLAUDE.md`; all Test 0 negatives still absent |
| Consistency grep across the five files | `accept-gate`, `--require`, `--waive`, `--open --walkthrough`, `--clear`, `## Operator Runtime`, `UNFILLED`, `## Operator Questions`, `## Regression Checklist`, `walkthrough`, `acceptance` all appear with the S1/S2 spellings; no invented flag (`--walkthrough-file` and friends absent) |
| Read-through of all five files for contradictions | consistent on who records what, when (see below) |

The one contradiction risk the plan flagged — `review-phase` vs the loop skills on who records what
— was resolved by making all three describe the same four steps in the same order, with the loop
skills owning the commands and `review-phase` owning the executor's duties. Two wording fixes came
out of the read-through: a stale "the pass below" pointer in `review-phase` (the code block sits
above it), and a stray list-spacing break in `do-next-slice`.

## Deviations from `plan.md`

None of substance.

1. The plan's `CLAUDE.md` sketch offered "a new bullet **or** extension of the review rule" for
   F4+F6; a **new bullet** was chosen — extending the review rule would have made an already-long
   sentence unreadable — and the review rule got a shorter clause about the gate instead.
2. The consolidation-timing decision is stated in the contract too (one clause on the durable-docs
   rule), not only in `phase.md` and `review-phase`. It is durable truth about doc versioning and
   the contract is where that rule already lives.
3. `CLAUDE.md`'s manifest rule spells the stop as "the executor returns `needs_operator`, the
   orchestrator sets the slice `pending`" rather than the plan's shorthand "`pending` stop", so S4
   has one unambiguous phrasing to mirror in the agent files.

## Notes for S4 / S5 / S6

Recorded in `phase.md` *Findings & Notes* (binding). The short list: the `walkthrough` return-field
wording; `needs_operator` (not a self-run `pending`) on a missing/`UNFILLED` manifest; `accept-gate`
**and** `defer-job` on both agent files' Never lists, with the review *listing* deferred jobs;
the declaration-point sentence; the legacy wording; the six-stage order (S5 writes only the
design-side fidelity sweep, not a second copy of the review stages); and the consolidation timing,
which S6's CHANGELOG must state the same way.
