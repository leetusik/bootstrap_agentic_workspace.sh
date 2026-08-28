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

### From `P17.S1`

**The spec is landed: `.claude/skills/design-cowork/SKILL.md`, 334 → 480 lines.** S2 copies from it,
not from `intent.md` — where the two differ, the file is the reconciled version and the differences
are listed here.

**Commit count is FOUR per design slice, not three.** The plan for S1 said three; `intent.md` §2's
diagram has four `→ commit` markers and the new loop forces four, because SIGNOFF can no longer ride
the read-back commit — the mockup build and PENDING #2 sit between them. Landed as four, each named:
`handoff` → `read-back` → `mockup` → `signoff`. **S2 must propagate four.**

**Section names S2's grep sweep needs** (headings moved, so grepping the old ones finds nothing):

| Old | New |
| --- | --- |
| `## Shape` | `## Shape — three styles` |
| — | `## The mockup — the design in the project's own language` (new, after `## Read back, then land it`) |
| — | `## Closing the round — SIGNOFF, then regroup` (new, holds the old read-back steps 4 and 5) |
| `## Read back, then land it` | unchanged name, now **ends at step 3** |

**The one-line invariants S2 must restate identically in the other six files:**

- A `co-work` slice is `--kind co-work --risk high`, orchestrator-inline, and writes **no *product*
  implementation code** — the phrase is now "product implementation code", and the mockup is the
  named exception.
- **The DesignSync work is never dispatched** (read-back, regroup). **The mockup build is the one
  dispatched span** — `slice-executor-high`, no DesignSync, built from `build-prompt.md`. A design
  slice runs **inline → dispatched → inline**. The old absolute "the design slice is NOT dispatched"
  is superseded everywhere.
- **Only PENDING #2 is an approval.** PENDING #1 is a mechanical wait; the operator confirmed the
  design inside the Claude Design session and that session ending is the confirmation. **SIGNOFF
  happens at the mockup gate.**
- **A phase shipping a mockup takes `accept-gate <P> --require`** — including `design-only`, which
  can no longer be waived. (Gate-declaration rule lives in `CLAUDE.md` and both drivers.)
- **The mockup is exempt from the full functional sweep**; the sweep is an apply/fidelity duty on
  real wiring. (Qualifies the works-as-a-product doctrine in `CLAUDE.md` and `docs/current/qa.md`.)
- **`design-only` must be chosen at `/create-phase`**; the style is confirmed by the operator and
  recorded in the phase's `intent.md` under **`## Design Style`**; `DECOMP` may ask it late, stopping
  `pending`.
- **`paired` has no `DECOMP2`** and cuts its pairs as **bare folders**; creating a bare folder is not
  pre-planning.

**Two `Never`-block edits beyond the four the plan named — neither weakens a ban.** (1) Added a
bullet: *Treat PENDING #1 as an approval, or sign a round off on the landed record alone.* (2)
Scope-qualified the existing *"Verify only against the record… the functional sweep and the
manifest's runtime are both mandatory"* — it now says the manifest runtime is mandatory **everywhere
including the mockup** and the sweep is mandatory on **every slice shipping real wiring**, because
left as an unqualified absolute it contradicted the mockup's sweep exemption two sections above. If
S2 restates this ban anywhere, restate the qualified form.

**Also updated for consistency, in case S2 greps the old wording:** the closing sentence of
*When the record never drew it* was *"signing the cards is not accepting the product"*; it is now
*"signing the round off — the cards, and the stubbed mockup with them — is not accepting the
product"*, because the operator now signs a mockup too and it is still not the wired product.

**`## Verifying` was left otherwise intact** — two yardsticks, Operator Runtime, whole-regression
re-run, evidence bar, gap channel. Only the sweep's ownership and the gate sentence moved.

## Doc impact

- (none yet from `P17.DECOMP` — decomposition changed no durable truth.)
- (`P17.S1`) **`operations.md`** — the `## Visual-design runbook` now understates the process: it
  describes the two-shape choice, a single `pending` window, SIGNOFF at the read-back and two commits
  per design slice. It needs the three named styles (`build-after` / `design-only` / `paired`), the
  runnable-mockup span with its own `pending` gate, SIGNOFF moving to that gate, four commits, and the
  `accept-gate --require` consequence for any phase shipping a mockup.
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

### From `P17.S1` (orchestrator note — correction to a `DECOMP` instruction)

**"S1 and S2 must not rebuild; S3 owns it" is unworkable, and only the version bump survives.**
`DECOMP`'s Release-discipline note asked S1/S2 to leave `installer/build.py` alone so the artifact
is rebuilt once over final files. The tracked `.githooks/pre-commit` hook makes that impossible: it
runs `installer/build.py --check` on every commit, and `.claude/skills/design-cowork/SKILL.md` is an
embedded payload, so S1's commit was **rejected** until the artifact was rebuilt.

The corrected rule, for S2 and S3:

- **Every slice that edits an embedded machinery file runs `python3 installer/build.py` and stages
  the rebuilt `bootstrap_agentic_workspace.sh` in its own commit.** Embedded files are
  `scripts/workflow.py`, `.claude/agents/*`, `.claude/skills/*/SKILL.md`, `.claude/settings.json`,
  `works/templates/*`, `executors.toml`, `.github/workflows/*`, `.gitattributes`, and `CLAUDE.md`.
  S2 touches almost all of these, so S2 rebuilds too.
- **What S3 still exclusively owns is the `WORKSPACE_VERSION` bump and the `CHANGELOG.md` entry.**
  That was the substance of the note; the rebuild half of it was wrong.
- The rebuild is deterministic (sorted walks + `repr()`), so rebuilding per slice produces no
  spurious diff churn beyond the payload bytes that actually changed.
