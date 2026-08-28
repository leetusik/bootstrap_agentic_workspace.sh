# Result — P16.REVIEW (phase review)

**Verdict: `pass`.** All six middle slices ship what `intent.md` §4 asked for, they agree with each
other and with the engine, and the release is complete. Docs consolidated into four new versions.

**P16 reviews under the legacy path.** Its `phase.json` carries **no `acceptance` block** (the phase
was created under v31, before the gate it built existed) and this repository ships machinery, not a
browsable product — there is no `## Operator Runtime` here and nothing to open in a browser. So the
six gate stages are skipped, `walkthrough` is `none`, and no gate was declared on P16 (shared
decision 4). `explain: not written — run /explain for this phase`.

## Validation — all slices together

Everything below was run from the repo root at review time, after S6's commit.

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **passed** — "Workflow validation passed." (exit 0) |
| `python3 installer/build.py --check` | **passed** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py sync-agents --check` | **passed** — `mid sonnet @ xhigh`, `high opus @ xhigh`, mode flex, agent files in sync |
| `bash tests/retrofit_smoke.sh` | **passed** — exit 0, **119 `PASS` lines, zero `FAIL`**, including Test 0's v32 gate invariants and the three new engine probes in Test 5 |
| `python3 scripts/workflow.py validate` (again, after doc consolidation) | **passed** |
| `python3 installer/build.py --check` (again, after doc consolidation) | **passed** (docs are not embedded; the artifact is untouched by this slice) |

### Independent re-verification (not taken from the slices' reports)

Three scripted probes, all in **throwaway copies under the session scratchpad**; the real `works/`
was never written to and no source file was touched by this slice.

**1. The engine end-to-end** (`scratchpad/rvcopy`, a `copytree` of the repo with `works/phases/active/*`
emptied) — 36 assertions, **all pass** except two that were my harness's fault (see below):

- `new-phase` stamps exactly the five null `acceptance` fields, **positioned right after `review`**;
  the `phase.md` scaffold carries `## Operator Questions` between *Findings & Notes* and *Constraints*.
- `review-phase --verdict pass` on an undeclared phase is **refused**, names `--require` / `--waive`,
  and **writes nothing** (phase still `planned`, review still `pending`).
- `--require` sets `required: true` with no status change; `pass` is then refused again, naming
  `--open` / `--clear`.
- `--open --walkthrough "…"` records the walkthrough + `requested_at`, sets the phase `pending`;
  `next` prints `WAITING ON OPERATOR`, `acceptance_gate=open`, `WALKTHROUGH:` + the text, and
  `accept-gate P90 --clear`. `--open` with no walkthrough errors. `validate` is green with a gate open.
- `--clear --note "…"` stamps `cleared_at`, returns the phase to `in_progress`; `pass` is then
  **accepted** and marks the phase `done`.
- `--verdict changes_requested` nulls `walkthrough` / `requested_at` / `cleared_at` and keeps
  `required` + `note`.
- `--waive` without `--note` errors and names `--note`; with it, `required: false` + reason, and the
  waived phase passes with no gate.
- A phase with the block **stripped** (legacy): `validate` says nothing about it, bare `accept-gate`
  reports it and writes nothing, `pass` is accepted printing one advisory line.
- `validate` errors on `done` + `required: true` + `cleared_at: null` with the shipped message.
- *The two "failures" were mine:* I passed probe phases whose `DECOMP` slices I never finished, so
  `validate` reported the **pre-existing** "done but has unfinished slices" error. Re-reading the
  final `validate` output confirms the only acceptance-related error is the intended one on the
  done+uncleared phase, and none at all for the legacy phase.

**2. The operator-reports-failures path** (the most likely untested transition — the phase is
`pending` when the operator comes back): `--open` → `review-phase --verdict changes_requested` is
**accepted while the gate is open**, returns the phase to `in_progress`, resets the three gate
fields, reopens the `REVIEW` slice as `changes_requested`, and afterwards `next` no longer advertises
an open gate, `--clear` is refused ("nothing open"), and `pass` is refused again until the gate
re-opens. 9/9 assertions pass.

**3. Fresh install of the rebuilt artifact** (temp dir under the scratchpad, install log written
**outside** the target, directory deleted afterwards) — 23/23 assertions pass:
`works/.workspace-version.json` → `"workspace_version": 32`; `docs/current/operations.md` carries
`## Operator Runtime`, the verbatim `- Status: UNFILLED — fill before any slice claims real-browser
verification` marker, all six field bullets, positioned between *Local Development* and *Environment
Variables*; `docs/current/qa.md` carries the cumulative smoke list, the `(P<N>)` line shape, the
manifest citation, and no `- [ ] <check>` stub; the **`v0001_bootstrap` version files** carry the
same text (durable, not only a snapshot); the fresh workspace validates; `new-phase` there stamps the
five null fields and scaffolds `## Operator Questions`; and `review-phase --verdict pass` there
refuses the undeclared phase.

**4. Does the new Test 0 actually bite?** I extracted Test 0's python body from the shipped suite and
ran it against **mutated copies** of `.claude/`, `CLAUDE.md` and `installer/` (never the real tree).
Control passes; all six mutations fail with the expected assertion: mid's body altered →
`slice-executor tier bodies drifted`; `UNFILLED` → `TBD` in the seed; `accept-gate` removed from the
review skill's never-run line; `never by omission` removed from `CLAUDE.md`; the gate-stage opener
removed from the high tier; the smoke-list line shape changed in the seeded qa body. S6's claim holds
independently.

**5. Cross-file consistency matrix** over `CLAUDE.md`, six skills, both agent files, the two seeded
doc bodies, `CHANGELOG.md`, both READMEs, `docs/retrofit-guide.md`, `tests/retrofit_smoke.sh` and
`scripts/workflow.py`: `accept-gate`, `--require`, `--waive`, `--open`, `--clear`, `--walkthrough`,
`## Operator Runtime`, `UNFILLED`, `## Operator Questions`, `## Regression Checklist`,
`acceptance.required`, `needs_operator`, `walkthrough`, `never by omission`, `real-browser fidelity`
and the `- [ ] <surface>: …` line shape all appear with the spellings S1/S2 shipped. **Zero hits** for
`--walkthrough-file` and `deferred_jobs_to_file` — no file describes a flag or field that does not
exist, and `accept-gate --help` matches the documented surface exactly. The consolidation-timing
sentence reads the same in `CLAUDE.md`, `review-phase`, both agent files and the CHANGELOG: *the pass
path, before the gate opens; parallel mode still defers.*

## Judgment — F1–F6 against `intent.md` §4

- **F1 — operator runtime manifest: ships.** Seeded `## Operator Runtime` with six fields + a
  greppable `UNFILLED` marker; contract Hard Rule; the same rule in both executor prompts and in
  `design-cowork`'s *Where it runs*; the review's stage 1. Absent == unfilled == `needs_operator` →
  `pending` everywhere, one phrasing. Reaches fresh installs only — correctly identified, documented
  in the v32 Migration notes, and precisely why the "never assume" rule exists.
- **F2 — acceptance gate, machine-enforced: ships**, and is the strongest part of the phase. One
  command, one five-field block, one accessor, one halt state reused. The refusal fires before any
  write; `changes_requested`/`blocked` are never refused; the reset re-opens the gate. Verified end
  to end by me, including the failure-report cycle.
- **F3 — works as a product: ships.** `design-cowork` had *no* fidelity specification; it now has one,
  with the four-item sweep, both runtime modes, every manifest viewport, and the record framed as
  floor-not-ceiling ("matching it is not acceptance"). The review's fresh-eyes stage is explicitly
  **not** judged against the design record and routes to the gate, never to silent fixes. Each of the
  incident's eleven complaints maps onto a sweep item or the gate.
- **F4 — gap channel: ships.** `## Operator Questions` is in the engine's scaffold, the contract, both
  agent prompts, `design-cowork`'s *When the record never drew it*, and the review's stage 5 with
  "an unrouted entry is a finding" stated as a bar on the pass. Procedure + one named list + no new
  engine check is the right weight.
- **F5 — cumulative smoke: ships**, by reusing `## Regression Checklist` rather than inventing a
  parallel list — the leaner answer, and it inherits the once-per-phase versioning cadence F5 wanted.
  "Re-run **whole**" is stated in the seed, the review skill, both agent prompts and `design-cowork`.
- **F6 — review independence: ships** as stage 2, in the skill, the contract and both prompts, with
  "never pass a phase purely on other slices' reports" said in those words.

**House principles.** Lean dashboards: no new dashboard column, no `validate` nagging for legacy
phases, five fields and no more. Terse tests: one suite, ~36 net lines added, safety-critical strings
only, and the parity invariant is a single line. Explicit invocation: `accept-gate` is
orchestrator/operator-only and appears on both executors' Never lists.

**Lifecycle coherence.** Read as an orchestrator would — `do-whole-phase` + `review-phase` + the
executor prompt — the sequence is stated identically in all three (declare at the `DECOMP` boundary →
build → review stages → return `walkthrough` → `--open` + STOP → operator `--clear` or
`changes_requested` → record the pass without re-dispatching). Waived and legacy phases are inert at
every step, which is why this machinery-only repo is unaffected. Parallel mode composes with one
paragraph and no engine change.

**Did each slice meet its plan?** Yes; every deviation is declared in the relevant `result.md` and
each is a defensible simplification: S1 skipped `--walkthrough-file` (the plan made it optional) and
treats a *malformed* block as legacy while `validate` owns shape; S2 skipped the optional Manual-QA
bullet; S3 chose a new contract bullet over extending the review rule and put the consolidation
decision in the contract too; S4 added no second return field (decision 8) and reached full body
parity — stronger than the plan predicted; S5 used bold-lead paragraphs instead of five `###`s;
S6's CHANGELOG entry is 74 lines against a 51-line "ceiling" (the plan's own required coverage does
not compress further) and put `accept-gate` in the Korean README's prose rather than its
skill-only table.

**Release completeness.** `WORKSPACE_VERSION = 32` is the single version stamp in the tree (every
other `v31` is history); the `## v32 — 2026-08-23` CHANGELOG entry carries three-part **Migration
notes**; `update-workspace`, both READMEs and `docs/retrofit-guide.md` carry the adopter prose; Test 0
pins the invariants and the smoke suite's existing three-way version check enforces the bump.

**Operator questions:** the phase's `## Operator Questions` list is explicitly empty (`DECOMP` and
`S1`–`S6` each recorded "none" — a machinery phase whose judgment calls were settled in *Shared
design decisions*). Nothing to route, so the pass is not blocked. **Deferred jobs:** none to file.
`D2` and `D4` were already closed by the orchestrator from S4's and S6's recommendations; `D3`
correctly did not fire (`installer/build.py` untouched).

**Observations, not findings (no fix slice warranted).** (1) P16's own notebook carries a level-3
`### Operator questions` under *Findings & Notes* rather than the canonical `## Operator Questions` —
it was written before S1 shipped the scaffold; the shipped heading is right and every new phase gets
it. (2) This repo's own operations doc deliberately has no `## Operator Runtime`; the consolidated
`operations` version now says so in one paragraph, so a future agent does not read its absence as an
oversight.

## Doc versions created (pass path, this repo is not in parallel mode)

Consolidated from the 15-line *Doc impact* list in `phase.md` — one version per affected doc,
capturing the whole phase. Only version files were edited, then `rebuild-docs`; `docs/current/*.md`
was never hand-edited.

| Doc | Version | Covers |
|---|---|---|
| `architecture` | `v0005_operator_acceptance_gate_on_phase.json_and_the_gated_phase-review_lifecycle_v32` | the five-field `acceptance` block + `phase_acceptance()`, the `accept-gate` surface, the three enforcement points (`review_phase` refusal/reset, `validate`, `next`), parallel-mode inertness, the executor prompts carrying the gate duties, and the tier-parity invariant pinned by Test 0 |
| `operations` | `v0027_driving_the_accept-gate_lifecycle_the_operator_runtime_manifest_rule_and_the_v32_release` | how the gate is driven end to end (declare → open → clear → record, never `set-phase-status`), the review executor's duties, the manifest rule, why this repo has no manifest, and the v32 release + migration (incl. the live-phase-only opt-in and the fresh-installs-only seed) |
| `qa` | `v0003_works_as_a_product_beside_matches_the_record_…` | the two yardsticks, the four-item functional sweep, where verification runs, the review's six gate stages, terse evidence — and this repo's own `## Regression Checklist` rewritten to the new cumulative-smoke-list contract with three machinery lines tagged `(P16)` |
| `decisions` | `v0035_operator_acceptance_gate_as_contract_law_…` | one Decision Log entry: context (the incident + RC1–RC7), the decision in nine parts (gate, declaration point, legacy default, consolidation timing, manifest, works-as-a-product, gap channel, smoke list, review independence, one switch), eight rejected alternatives, and the consequences; plus the updated *Status* header |

`python3 scripts/workflow.py rebuild-docs` → `python3 scripts/workflow.py validate` → **passed**;
`docs/current/*` matches `docs/index.json`.

## Deviations from `plan.md`

None of substance.

- The plan listed "at least" nine engine checks; I ran the full set plus the gate-open →
  `changes_requested` transition it did not name (the operator-reports-failures path), and added an
  independent mutation proof of Test 0 rather than trusting S6's report of one.
- The plan's *Doc impact* sketch for `qa` did not mention rewriting **this repo's** own
  `## Regression Checklist`; I did, because P16 changed that heading's contract and leaving this
  repo's copy as `- [ ] <check>` would have left the docs describing the pre-v32 world.

## For the orchestrator

- Record: `python3 scripts/workflow.py review-phase P16 --verdict pass --reviewer slice-executor-high
  --note "..."` — P16 is legacy-shaped, so the engine allows the pass directly and prints one
  advisory line. Do **not** run `accept-gate` on P16.
- No deferred jobs to file; no fix slices proposed.
- `explain: not written — run /explain for this phase`.
