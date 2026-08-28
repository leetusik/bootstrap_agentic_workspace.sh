# Phase P17: design co-work styles, the mockup gate, and agent-runnable create-phase

_Intent: see [intent.md](intent.md)._

## Objective

Give design co-work three named operator-chosen styles (build-after / design-only / paired), move the single per-round approval onto a runnable mockup built in the project's own frontend language, close the unvalidated --kind hole in the engine, and let the agent invoke create-phase on instruction while the operator-confirmation gate stays put. Ships as workspace v34.

## Context

## Decomposition

Three middle slices, per the operator's constraint. The cut is **spec → everything that must
agree with it → release**: S1 decides the wording, S2 copies that decision into every other
place that restates it, S3 ships it. `depends_on` runs S1 → S2 → S3, because the propagation
cannot copy from a spec that does not exist yet and the rebuild cannot embed files that are
still moving.

**This phase is not design-bearing.** P17 rewrites the *documentation of* the design process
and touches no product visual surface, so the two-pass shape does not apply: no `co-work`
slice, no `P17.DECOMP2`, no build inventory. Single pass, deliberately — the subject matter
makes the wrong shape tempting.

| Slice | Order | Kind | Risk | Scope |
| --- | --- | --- | --- | --- |
| `P17.S1` | 10 | implementation | high | Rewrite `.claude/skills/design-cowork/SKILL.md` |
| `P17.S2` | 20 | implementation | high | Propagate the spec into the engine, skills, agents, contract |
| `P17.S3` | 30 | implementation | high | Release workspace v34 |

- **`P17.S1` — the spec.** Rewrite `.claude/skills/design-cowork/SKILL.md` (334 lines): the three
  named styles (`build-after` / `design-only` / `paired`) replacing the two-shape bullets in
  `## Shape` (L38-74); the new loop diagram and three-commit shape in `## The loop` (L16-36); a new
  `## The mockup` section; `## Read back, then land it` (L164-195) re-cut to end at *land the
  record*, with SIGNOFF and the regroup moving after the mockup gate; the `## Mechanics`
  never-dispatched refinement (L199-201); and the re-cut `## Never` bans (L313-334 — see the
  three-not-two finding below). **Risk `high`:** one file, but a structural rewrite of the phase's
  own specification that every later slice copies from. `low` is reserved for a one-line/few-line
  edit; this is neither, and a wrong word here propagates into six more files.
- **`P17.S2` — everything that must agree with it.** `SLICE_KINDS` + creation-time validation in
  `scripts/workflow.py` (hard error at `new-slice` and `promote-deferred`, warning in `validate()`);
  `.claude/skills/create-phase/SKILL.md` (the three-way style question **and** removing
  `disable-model-invocation: true`); both drivers (`do-next-slice`, `do-whole-phase`); both executor
  agents (`slice-executor-mid`, `slice-executor-high`); `CLAUDE.md`. Closes with the grep sweep for
  superseded wording. **Risk `high`:** real engine code plus seven-plus files that must move
  together; the contract puts every cross-file change at `high`.
- **`P17.S3` — release.** `installer/main.py:38` `WORKSPACE_VERSION` 33 → 34, the matching
  `## v34 — <date>` entry in root `CHANGELOG.md`, `python3 installer/build.py`, and the rebuilt
  `bootstrap_agentic_workspace.sh` committed with it; `python3 installer/build.py --check` must pass.
  Procedure: `installer/README.md:23`. **Risk `high`:** the hand edits are small, but the slice spans
  `installer/main.py`, `CHANGELOG.md` and a regenerated artifact, and the changelog entry is what
  adopters read to understand a breaking-ish engine change. Not a few-line edit; rated `high`
  deliberately rather than to save cost.

## Findings & Notes

### From `P17.DECOMP`

**The specification is `intent.md`, not the objective line.** Eight resolved clarifications and four
notes; the objective in this file is only its headline. Every slice reads `intent.md` in full before
planning — in particular §2's loop diagram (the exact inline / dispatched / inline shape) and the
Notes section, which carries the **verbatim replacement wording** for the re-cut `Never` bans.

**The six-file consistency problem.** The `co-work` invariants are restated in six files and enforced
by the engine in **zero** places:

| File | Lines carrying the invariants |
| --- | --- |
| `CLAUDE.md` | 24, 58, 64, 65, 75, 95 |
| `.claude/skills/design-cowork/SKILL.md` | 40, 51, 60, 69-70, 199-201, 322, 333-334 |
| `.claude/skills/do-next-slice/SKILL.md` | 12, 25, 26, 37 |
| `.claude/skills/do-whole-phase/SKILL.md` | 12, 20, 21, 22, 25, 29 |
| `.claude/agents/slice-executor-mid.md` | 32, 47 |
| `.claude/agents/slice-executor-high.md` | 32, 47 |

All six must move together — S2 owns that — and the phase needs a **closing grep sweep** for
superseded wording (`co-work`, `cowork`, `DECOMP2`, `never dispatched`, `two passes`,
`disable-model-invocation`). Line numbers above are pre-S1/S2 and will drift; grep, do not trust them.

**The `Never` bans to re-cut are THREE, not two — raising this rather than designing around it.**
`intent.md` (Notes) names two, and both are exact:

- *"Author mockups, palettes, type scales, or cards **yourself**"* → the mockup ban narrows to authoring
  one **before the round has come back** (the mockup *transcribes* an approved design; inventing one is
  designing). Palettes, type scales, cards, "proposals" and options-to-pick-from stay banned unchanged.
- *"Write implementation code in a design slice"* → *"write **product** implementation code in a design
  slice"*.

But a third bullet in the same `## Never` block states the invariant the intent explicitly amends:
**"Delegate a DesignSync call, or dispatch the design slice."** (SKILL.md L322). Intent §2 makes the
mockup build **the one dispatched span** inside the `co-work` slice, so that bullet must narrow to the
DesignSync work alone — otherwise the skill bans, in its own hardest section, the thing it now
requires. It is the same amendment as the `## Mechanics` L199-201 text ("The design slice is NOT
dispatched"), just stated a second time. S1 owns both. **Do not delete either — narrow both.**

**A fourth `Never` bullet needs generalizing for `paired`.** *"Pre-plan past the design gate —
`DECOMP2` and everything after it is planned from the **landed** design, never before it."* The
`paired` style has no `DECOMP2` and cuts its apply slices as bare folders at `DECOMP`. Creating a bare
folder is not pre-planning, so the ban still holds — but its wording names `DECOMP2` specifically and
will read as self-contradictory under `paired`. Generalize the wording; do not weaken the ban.

**`--kind` is the only slice/phase enum with no closed set — and `co-work` is not in the history.**
`scripts/workflow.py` L25-33 closes `PHASE_STATUSES`, `SLICE_STATUSES`, `DEFERRED_STATUSES`,
`REVIEW_VERDICTS`, `EXECUTION_MODES`, `CONSOLIDATION_STATES` — but no `SLICE_KINDS`. `validate()`
(L692-809, slice loop L754-766) never inspects `kind`; `create_slice` writes it verbatim; `--kind`
defaults to `"implementation"` at both `new-slice` (~L1985) and `promote-deferred` (~L2066).
Kinds actually present across `works/phases/**` today:

    implementation 52 · review 17 · decomposition 17 · fix 3 · docs 2 · qa 1

**`co-work` appears zero times** — no design phase has run in this repo yet — so a set built from
history alone would hard-error the very kind the phase exists to protect. The set must be at least:
`implementation`, `review`, `decomposition`, `fix`, `docs`, `qa`, `co-work`. Verify with
`grep -rho '"kind": "[a-z0-9_-]*"' works/phases/ | sort | uniq -c` before writing the literal.

**Backward compatibility is asymmetric by design.** Creation-time validation is a **hard error**
(`new-slice`, `promote-deferred`); `validate()` only **warns** on an unknown kind. That asymmetry is
the whole point: an adopting repo carrying an invented kind survives `/update-workspace` instead of
having its `validate` break on history it cannot change. Do not make `validate()` error.

**Removing `disable-model-invocation: true` touches an installer heuristic.** `installer/main.py`
`flag_stale_skills()` (~L593-611) identifies workspace-managed skill dirs by exactly that marker.
`create-phase` is in `CLAUDE_SKILLS`, so it is skipped before the marker check and nothing breaks
today — and `design-cowork` already ships without the marker, so the precedent exists. But if
`create-phase` were ever dropped upstream it would no longer be flagged stale for adopters. S2 should
make that a conscious decision (leave it, or widen the heuristic), not an accident.

**The style choice needs a home in the `intent.md` scaffold.** Intent §1 says the confirmed style is
recorded in the phase's `intent.md` under a `## Design Style` section that `DECOMP` reads. That file
is scaffolded from `works/templates/intent.md` by `new-phase` (`scripts/workflow.py` L877). S2's file
list in the plan does not name that template — decide explicitly whether the section is scaffolded for
every phase (noise on non-visual phases) or appended by `create-phase` only when the phase is visual.
The second reads better and costs nothing, but it is S2's call to make and to state.

**Two consequences of the mockup that live outside `design-cowork`.** Both are S2 territory and are
easy to miss because the plan's S2 list is a file list, not a rule list: (1) a phase shipping a mockup
changes operator-visible surfaces, so its gate is `accept-gate <P> --require` — **a design-only phase
can no longer be waived** — and the gate-declaration rule sits in `CLAUDE.md` and both drivers; (2)
the mockup is **exempt from the full functional sweep** (it proves look and states, not wiring;
non-functional controls are acceptable and must be named as such in the walkthrough), which qualifies
the works-as-a-product verification doctrine stated in `CLAUDE.md` and `docs/current/qa.md`.

**This phase is machinery-only — no browser verification.** No slice here should claim real-browser
verification, and this repo's `docs/current/operations.md` has no `## Operator Runtime` section (it is
the bootstrap repo; there is no product to browse). Expect `accept-gate P17 --waive` at the `DECOMP`
boundary — the orchestrator's call, not `DECOMP`'s.

**Release discipline (S3).** `installer/README.md:23` — a machinery change that reaches adopters needs
the `WORKSPACE_VERSION` bump **and** the `CHANGELOG.md` entry **and** the rebuilt artifact in the same
commit; `.githooks/pre-commit` and `tests/retrofit_smoke.sh` (Test 7) both run
`python3 installer/build.py --check`. S1 and S2 must not bump the version themselves — S3 owns it, so
the artifact is rebuilt once over final files rather than three times over moving ones.

## Doc impact

- (none yet from `P17.DECOMP` — decomposition changed no durable truth.)
- **Expected across the phase, for the `P17.REVIEW` slice to consolidate:** `operations.md` (the
  `## Visual-design runbook`, L70-198, must gain the three styles and the mockup gate);
  `decisions.md` (a new ADR: three named design styles + approval moving onto a runnable mockup +
  the closed `--kind` set); `qa.md` (the mockup's relaxed sweep versus the apply slice's full sweep,
  against `## Verification doctrine` L28-84). Each slice appends its own note here as it lands.

## Operator Questions

_Questions only the operator can answer; every entry is routed at the review -- folded into the acceptance walkthrough (`accept-gate --open`) or filed with `defer-job`. An unrouted entry is a review finding._

- (`P17.DECOMP`) **Should `## Design Style` be scaffolded into every phase's `intent.md`, or added by
  `create-phase` only when the phase is visual?** Decomposition's read is "only when visual" (a
  `## Design Style` heading on every non-visual phase is noise), but the intent does not say, and it
  changes `works/templates/intent.md` for every adopting repo. S2 will implement the "only when
  visual" reading unless the operator says otherwise — flag at the review either way.
- (`P17.DECOMP`) **Should `installer/main.py`'s `flag_stale_skills()` heuristic be widened** now that a
  second shipped skill (`create-phase`, joining `design-cowork`) lacks the
  `disable-model-invocation: true` marker it uses to recognize workspace-managed skill dirs? Inert
  today; only bites if such a skill is later dropped upstream. Candidate for `defer-job` rather than
  in-phase work.

## Constraints

## Open Questions

-
