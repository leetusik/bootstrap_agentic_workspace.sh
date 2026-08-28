# Plan — P16.S3 (Contract + review/loop skills: the F1/F2/F4/F6 rules)

## Goal

Write the rules that make agents *use* what S1 and S2 landed: the operator acceptance gate
(F2), the operator-runtime requirement (F1), catalogue routing (F4), and review independence
(F6) — in `CLAUDE.md`, `.claude/skills/review-phase/SKILL.md` (the biggest change),
`.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`, and one
sentence in `.claude/skills/parallel-phase/SKILL.md`. Prose only — no engine, no executor
agent files (S4), no `design-cowork` (S5), no CHANGELOG/tests/README (S6).

## Read first

- `works/phases/active/P16/phase.md` — **all nine shared design decisions** (binding), the
  *Findings & Notes* bullets appended by S1 ("The engine surface S3-S5 must quote verbatim…",
  the `## Operator Questions` scaffold heading, the refusal/reset behaviour, the `--require`
  on a done phase gotcha) and by S2 (the exact `## Operator Runtime` field list and the
  `UNFILLED` marker line, the smoke-list line shape).
- `works/phases/active/P16/slices/P16.S1/result.md` and `P16.S2/result.md` — the shipped
  command help and the shipped seed texts; quote from them, never from memory.
- `works/phases/active/P16/intent.md` §3 (RC1–RC7) and §4 (F1–F6) — the why.
- The five files you edit, whole. Also `tests/retrofit_smoke.sh` Test 0 (the
  "Safety-critical orchestration rules" and "assert the whole text" blocks): the strings it
  asserts in `do-next-slice`, `do-whole-phase`, and `CLAUDE.md` **must stay present verbatim**
  — e.g. `WAITING ON OPERATOR`, `` `kind: co-work` ``, `never dispatched`, `DesignSync`,
  `` never pass `run_in_background: false` ``, `` never glob `~/.claude/plans/` ``,
  `` `plan only` ``, `real-browser fidelity`, `Approval must be literal`,
  `Work resumes only after explicit operator input clears the same item`. Run Test 0 before
  you finish.
- `CLAUDE.md` *Hard Rules* — the `pending` rule and the design rule are the two you extend;
  the *Workflow Commands* list gains `accept-gate`.

## The lifecycle you are writing (derive every rule from this; it must read the same in all five files)

For a phase whose gate is `required: true` (decision 9 — a `--waive`d phase is untouched):

1. **Declare at the `DECOMP` boundary.** Right after `finish-slice <P>.DECOMP`, the
   orchestrator runs `accept-gate <P> --require` (operator-visible surfaces change) or
   `accept-gate <P> --waive --note "why"` (explicitly not) — decided from `intent.md` and the
   decomposition. A phase with an `acceptance` block whose `required` is still `null` cannot
   pass its review, so forgetting is impossible; the rule belongs in the loop skills at the
   DECOMP boundary step and in `CLAUDE.md`.
2. **Build.** Implementation / `fix` slices that claim "verified in a real browser" verify in
   the `## Operator Runtime` runtime and access path (operations doc), and additionally in the
   production build when it differs; an absent **or `UNFILLED`** section → the slice stops
   `pending` and asks the operator for the manifest, never assumes (F1). Operator questions
   the work raises go on `phase.md`'s `## Operator Questions` list, not only in `result.md`.
3. **Review executor** (dispatched by the orchestrator, `slice-executor-high`): validates all
   slices together; then — gate required — performs decision 8's stages: (a) independently
   opens the running product in the manifest runtime and spot-checks the phase's headline
   claims (F6 — never passes on other slices' reports alone); (b) a fresh-eyes UX walkthrough,
   explicitly not judged against the design record, findings routed to the walkthrough (F3 —
   the design-side spec lands in S5, you state the review-side duty); (c) re-runs the whole
   `## Regression Checklist` smoke list (qa doc) and appends this phase's headline checks
   (that append is a doc change → goes through the review's doc consolidation, see below);
   (d) routes every `## Operator Questions` entry — into the walkthrough as a decision to take,
   or to `defer-job` (which the executor may **not** run: it lists the deferred jobs for the
   orchestrator to file, or the orchestrator files them on return) — an unrouted entry is a
   finding and the review may not pass with one (F4). It returns `review_verdict` **plus
   `walkthrough`**: the concrete script (URLs to open, actions to try, in the manifest
   runtime) plus the decisions-to-take. On `changes_requested`/`blocked` it still stops before
   pass-only work as today.
4. **Open the gate.** On `review_verdict: pass` the orchestrator does **not** record the
   verdict yet: it runs `accept-gate <P> --open --walkthrough "<the returned walkthrough>"`
   (phase → `pending`), files any deferred jobs the review listed, commits, reports the
   walkthrough to the operator, and STOPS. `next` now prints `WAITING ON OPERATOR`, the
   walkthrough, and `accept-gate <P> --clear`.
5. **Operator walks through.** Either (a) accepts → `accept-gate <P> --clear [--note "..."]`
   (the operator, or the orchestrator on their explicit say-so) → phase `in_progress`; or
   (b) reports failures → the orchestrator records
   `python3 scripts/workflow.py review-phase <P> --verdict changes_requested --note "operator-reported: …"`
   (never refused; resets the gate), creates `fix` slices from the operator's report, runs
   them, and re-reviews from step 3.
6. **Record the pass.** On the resume after a clear, the orchestrator sees the `REVIEW` slice
   still `in_progress` with a `result.md` carrying `review_verdict: pass` and the gate
   showing `cleared_at` — it records `review-phase <P> --verdict pass --reviewer
   slice-executor-high --note "..."` **without re-dispatching the review**, then `validate`,
   commit. (Legacy phases — no `acceptance` block, e.g. every phase created before v32 and
   **this phase P16 itself** — skip steps 1, 4–6: `pass` records directly with the engine's
   advisory line, exactly as today.)

**Decision you must settle (DECOMP left it open) — when a gated phase's docs consolidate.**
Pick one and record it in `phase.md` under *Findings & Notes* so S4 (executor prompt) and S6
(CHANGELOG) say the same thing:

- **Recommended: consolidate in the executor's `pass` path, before the gate opens** (as
  today, outside parallel mode). One dispatch, no new orchestrator duty, and the mechanics are
  unchanged; if the operator then reports failures, the `changes_requested` → fix → re-review
  cycle consolidates again and the new versions supersede (versions are append-only durable
  truth; a version describing code that exists is not false). The smoke-list append (step 3c)
  rides the same consolidation.
- Alternative: defer like parallel mode and consolidate after the clear — cleaner semantics
  ("docs describe accepted truth") but a second review dispatch or an orchestrator-run
  consolidation, i.e. more surface in three skills. Choose it only if you judge the semantic
  gain worth it; state the trade-off either way.

## Changes, file by file

### `CLAUDE.md`

- *Driving This Workspace* → *Orchestrator and executor* paragraph: one or two sentences on
  the acceptance gate in the review's description (the review returns a `walkthrough`; a
  gated phase stops `pending` at `accept-gate --open`; `pass` is recorded only after the
  operator's `--clear`; legacy phases pass directly).
- *Hard Rules*: a new bullet for the **operator acceptance gate** (the whole lifecycle above
  in contract-voice: declaration at the DECOMP boundary with `--require`/`--waive --note`
  — explicit, never by omission; engine refusal; operator clears; failures → `fix` slices via
  `changes_requested`; legacy default; `accept-gate` is a phase-state command executors never
  run). A new bullet for the **operator runtime manifest** (F1: `## Operator Runtime` in the
  operations doc; real-browser claims verify there + prod when different; absent/`UNFILLED` →
  `pending` stop). A new bullet (or extension of the review rule) for **catalogue routing and
  review independence** (F4 + F6: `## Operator Questions` list in `phase.md`; routed at the
  review into the walkthrough or `defer-job`; unrouted = finding; the review executor
  spot-checks the running product itself; fresh-eyes walkthrough findings go to the gate,
  never silent fixes; the whole smoke list is re-run and appended). Extend the existing
  `review-phase` rule bullet so the `pass` path mentions the gate. Keep the design rule's
  `real-browser fidelity` string; add that fidelity now includes "works as a product" (one
  clause — S5 writes the spec).
- *Canonical State*: one line that `phase.json` may carry the `acceptance` block.
- *Workflow Commands*: add `accept-gate <P> [--require | --waive --note "..." | --open --walkthrough "..." | --clear [--note "..."]]` with a half-line description.
- Keep the file a compact routing contract — add sentences, not sections, and keep every
  Test 0 string.

### `.claude/skills/review-phase/SKILL.md`

The review executor's checklist. Add: the gate-conditioned stages (independent spot-check,
fresh-eyes walkthrough, whole-smoke-list re-run + append, operator-question routing), the
`walkthrough` return, how the manifest is found (`## Operator Runtime`; absent/`UNFILLED` →
`needs_operator`), the orchestrator's sequence after a `pass` (open gate → stop → operator
clears → record pass; failures → `changes_requested` + fix slices), the legacy note, the
doc-consolidation timing you settled, and the explicit `accept-gate` / `defer-job` prohibition
for the executor. Keep the parallel-mode paragraph coherent (the gate opens on the branch, the
operator walks the branch's product; `parallel-gate` is unchanged).

### `.claude/skills/do-next-slice/SKILL.md` and `.claude/skills/do-whole-phase/SKILL.md`

- At the DECOMP boundary: after `finish-slice <P>.DECOMP`, declare the gate (`--require` /
  `--waive --note`) from `intent.md` + the decomposition, commit with the slice.
- The review step: plan the review to return `walkthrough`; on `pass` with a required gate:
  `accept-gate --open`, file deferred jobs, commit, report, STOP (`do-whole-phase`: the loop
  ends here, like any `pending`); on resume with the gate cleared, record `pass` without
  re-dispatch; operator-reported failures → `changes_requested` + fix slices. Legacy: as
  today.
- The `WAITING ON OPERATOR` paragraph: mention that an open acceptance gate clears with
  `accept-gate <P> --clear`, not `set-phase-status`.
- Keep all Test 0 strings.

### `.claude/skills/parallel-phase/SKILL.md`

One sentence in §4 (review on the branch): the acceptance gate opens and clears on the branch
before `pass`, so `parallel-gate`'s "branch done + review pass" already implies the operator
accepted the branch's running product.

### Rebuild

`python3 installer/build.py` → `python3 installer/build.py --check` passes.

## Validation

- `python3 installer/build.py --check` → OK; `python3 scripts/workflow.py validate` → passed.
- `bash tests/retrofit_smoke.sh` → passes (Test 0 pins the strings you must keep; you add no
  assertions — S6 does).
- Consistency grep across the five files: `accept-gate`, `--require`, `--waive`, `--open
  --walkthrough`, `--clear`, `## Operator Runtime`, `UNFILLED`, `## Operator Questions`,
  `## Regression Checklist`, `walkthrough` all appear with the spellings S1/S2 shipped; no file
  describes a flag or heading that does not exist.
- Read the five files once end to end for contradictions (especially review-phase vs
  do-next-slice on who records what, when).

## Record

- `result.md`: per-file summary of the rule text added, the consolidation-timing decision and
  its rationale, validation outcomes, deviations.
- `phase.md` *Findings & Notes*: the consolidation-timing decision (one bullet, marked
  binding for S4/S6); anything S4/S5/S6 must mirror (e.g. the exact `walkthrough` field
  wording you used). *Doc impact*: `decisions` — the acceptance gate (declaration point,
  legacy default, consolidation timing); `operations` — how the orchestrator/operator drive
  the gate and the manifest rule; `qa` — the review's new stages (spot-check, fresh-eyes,
  smoke re-run).

## Do not

- Edit `scripts/workflow.py`, `.claude/agents/*`, `.claude/skills/design-cowork/`,
  `installer/payloads/`, `CHANGELOG.md`, `README*`, `docs/`, or `tests/`.
- Invent a flag, heading, or field that S1/S2 did not ship.
- Commit, or run any workflow state-transition command (incl. `accept-gate` on P16 — P16
  stays legacy by decision 4).
