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

### From `P17.S2`

**The propagation is complete and the suite is green.** Seven files now restate S1's spec:
`scripts/workflow.py`, `.claude/skills/create-phase|do-next-slice|do-whole-phase|review-phase/SKILL.md`,
both `.claude/agents/slice-executor-*.md`, `CLAUDE.md` — plus `tests/retrofit_smoke.sh`,
`installer/main.py` (one summary print) and `README.md`. **S3 owns only the `WORKSPACE_VERSION`
bump and the `CHANGELOG.md` entry**; everything else is landed and the artifact is rebuilt.

**The plan's `--kind` guard placement was insufficient — raising it rather than designing around
it.** The plan said one guard in `create_slice()` *before* `require_phase` would stop
`promote-deferred --create-phase` from creating a phase and then rejecting the slice. It does not:
`promote_deferred` calls `new_phase()` itself, several lines before `create_slice` is reached, so
the phase was created and *then* the kind was rejected (reproduced in a throwaway workspace: `P9`
existed after `rc=1`). Landed shape: a `require_slice_kind()` helper called from **two** places —
`create_slice` (still the shared chokepoint for both commands, so no call site can bypass it) and
the top of `promote_deferred`, before its `--create-phase` branch. One message, one set. A smoke
test asserts the phase is *not* created on a rejected kind. **Anyone touching either function
later must keep both calls.**

**The engine's asymmetry, stated once so it is not "fixed" later:** unknown kind = hard error at
creation, **warning only** in `validate()` (exit-code-neutral — the test asserts on stdout, never
on the exit status), and `--risk` next door stays deliberately unvalidated because unrecognized
values route to the *high* tier, which is the safe direction. All three are commented in
`scripts/workflow.py` at `SLICE_KINDS`.

**Decision on the open `DECOMP` Operator Question — `## Design Style` is added by `create-phase`
only when the phase is visual.** `works/templates/intent.md` is unchanged, so no adopting repo
gets a `## Design Style` heading on non-visual phases. Every rule that reads it **tolerates its
absence**: both drivers say that a phase whose `intent.md` has no such section has its style asked
at `DECOMP`, which stops `pending` for the answer. Flag it at the review either way (it is still on
the Operator Questions list below).

**Two files outside the plan's list carried statements this phase falsifies.** Both fixed:

- **`.claude/skills/review-phase/SKILL.md`** — the more important of the two, because `design-only`
  phases can no longer be waived, so a gated review will now run its fresh-eyes stage against a
  **stubbed mockup** and would report every deliberately unwired control as dead. Stage 3 gained the
  qualifier (a mockup is exempt from the functional sweep; name its unwired controls in the
  walkthrough instead of filing them as defects), and the checklist gained the spec's
  **orphaned-design-route** check, which the spec assigns to the review and which lived nowhere else.
- **`README.md`** (operator-facing, Korean) — its design section described the loop as ending at the
  landed record. It now names the runnable-mockup gate and the three styles.

**`installer/main.py` summary print** updated for the same reason (it told fresh adopters the loop
had "one normal signoff before separate implementation"). `flag_stale_skills()` was **left alone**
per plan — `create-phase` is derived into `CLAUDE_SKILLS` and skipped before the marker check, so
nothing breaks today; its docstring still says a shipped SKILL.md carries the marker, which is now
true of 15 of 17. That is the second Operator Question below, and `defer-job` material.

**Wording that later slices must copy exactly** (the smoke suite now asserts each of these, so a
paraphrase breaks the build):

- `the DesignSync work is never dispatched` / `The mockup build is the one dispatched span`
- `A design slice writes no *product* implementation code` (Shape) and
  `Write **product** implementation code in a design slice` (Never)
- `signing the round off — the cards, and the stubbed mockup with them — is not accepting the product`
- the three style names, `## The mockup`, `Only PENDING #2 is an approval.`,
  `PENDING #1 is a mechanical wait`, `Exempt from the full functional sweep`,
  `Stubbed data, no backing work`
- in **both** drivers: `mockup build is the one dispatched span`, all three style names,
  `PENDING #1`, `PENDING #2`, `## Design Style`, `mechanical wait, not an approval`
- in **both** agents: `The mockup span of a `co-work` (design) slice`, `*product* implementation work`,
  `exempt from the full functional sweep` (lowercase there — the design skill's copy is capitalised)

The design-skill assertions are matched against a **whitespace-flattened** copy of the file, because
that spec hard-wraps its prose; the driver/agent/contract files are long single lines and are matched
literally.

**Two exempt skills now, not one.** `tests/retrofit_smoke.sh` previously asserted that every skill
except `design-cowork` carries `disable-model-invocation: true`. It now checks membership in
`{"design-cowork", "create-phase"}` — the assertion is still exact in both directions, so the marker
still cannot be dropped from any other skill by accident. **`create-phase` is the narrower
exception:** callable on instruction, never on the agent's own initiative, and its step-3 operator
confirmation gate did not move.

**`works/` was left as found.** The scratch `P17.S99` slice used to prove the kind guard was deleted
and its lone `slice_created` line removed from `works/events.jsonl` (there is no deletion event, so
the line would have recorded a slice that never existed). `docs/index.json` picked up a `rebuild`
timestamp and was restored with `git checkout` — **S2 created no doc versions**, as a non-review
slice must not.

### From `P17.S3`

**v34 is released and the phase is complete.** `installer/main.py:38` is `WORKSPACE_VERSION = 34`,
`CHANGELOG.md:12` opens `## v34 — 2026-08-29`, and `bootstrap_agentic_workspace.sh` was rebuilt
**after** both edits (404,486 bytes). `build.py --check`, `workflow.py validate` and
`tests/retrofit_smoke.sh` (Tests 0-8) all pass; the smoke suite reads the version out of
`installer/main.py` by regex and asserts the installed marker matches, so it exercised **34**, not a
hard-coded 33. Those three commands plus S1's and S2's are the whole re-run list for `P17.REVIEW`.

**The changelog's five migration claims were each checked against the code, not assumed** — the
review can spot-check rather than re-derive them:

| Claim in the entry | Evidence |
| --- | --- |
| `--update` overwrites the contract, both agents and every skill; a retrofitted repo gets the sidecar | `installer/main.py` `_update_handle()` — `CLAUDE.md` writes in place unless `CLAUDE.workspace.md` exists, then `_merge_contract` |
| An out-of-set `kind` warns and leaves the exit code alone | `scripts/workflow.py` `validate()` — the message goes on `warnings`, which only prints; `return 1` is reached from `errors` alone. `tests/retrofit_smoke.sh:365-368` asserts warn **and** `rc == 0` |
| An in-flight design phase under the old shape needs nothing | the engine has never enforced round shape and still does not — nothing in `workflow.py` reads a round, a mockup route, or `## Design Style`; the whole loop is prose |
| `--update` preserves all of `docs/`, so an adopter's `## Visual-design runbook` keeps the old text | `_update_handle()` returns "preserved" for every `docs/` path except `docs/README.md` |
| `sync-agents` after the update | the installer prints exactly that as its own "Next:" line (`installer/main.py:667`) |

**Nothing new for the Doc impact list, and nothing new for Operator Questions.** `CHANGELOG.md` and
the version constant are release records, not durable truth; the list stands as S1/S2 left it
(`operations.md` ×2, `decisions.md`, `qa.md`) and is what the review consolidates. The two open
Operator Questions are still the `DECOMP` pair — `## Design Style` scaffolding, and the
`flag_stale_skills()` heuristic — and both still need routing at the review.

**An independent grep sweep for superseded wording found nothing left to fix.** `never dispatched`,
`two passes`, `two-phase split` and `disable-model-invocation` across `.claude/`, `CLAUDE.md`,
`README.md`, `scripts/` and `installer/main.py`: every surviving `never dispatched` is correctly
scoped to the **DesignSync work**, and the only `disable-model-invocation` hits outside skill
frontmatter are `flag_stale_skills()` itself (Operator Question 2). No finding against S1 or S2.

## Doc impact

- (none yet from `P17.DECOMP` — decomposition changed no durable truth.)
- (`P17.S1`) **`operations.md`** — the `## Visual-design runbook` now understates the process: it
  describes the two-shape choice, a single `pending` window, SIGNOFF at the read-back and two commits
  per design slice. It needs the three named styles (`build-after` / `design-only` / `paired`), the
  runnable-mockup span with its own `pending` gate, SIGNOFF moving to that gate, four commits, and the
  `accept-gate --require` consequence for any phase shipping a mockup.
- (`P17.S2`) **`operations.md`** — two sections drift further. (1) The `## Visual-design runbook`
  (L58-99, L162-164) still describes the single two-pass shape, one `pending` window, a
  never-dispatched `co-work` slice and SIGNOFF at the read-back; it needs the three named styles,
  the dispatched mockup span, the second `pending` window (and that only the second is an
  approval), four commits, and `accept-gate --require` for any phase shipping a mockup. (2) The
  skill-inventory paragraph (L201-202, L288-289) says `design-cowork` is the **sole** skill without
  `disable-model-invocation: true`; there are now **two** — `create-phase` is agent-callable **when
  instructed**, never autonomous, with its confirmation gate unmoved.
- (`P17.S2`) **`decisions.md`** — one ADR covering this phase's engine + contract change: the
  **closed `--kind` set** (hard error at `new-slice` *and* at `promote-deferred`, before its
  `--create-phase` branch; warning-only and exit-code-neutral in `validate()` so adopting history
  survives an update; `--risk` deliberately left unvalidated because unknown values route to
  `high`), and **agent-runnable `create-phase`** as the second, narrower model-invocable exception.
  The three-styles/mockup half of the ADR is S1's note above; they are one decision and should
  consolidate into one entry.
- (`P17.S2`) **`qa.md`** — confirms S1's expectation and adds a second source: the mockup's relaxed
  check versus the apply slice's full functional sweep is now also stated in `review-phase`'s gate
  stage 3 (a stubbed mockup's unwired controls are named in the walkthrough, not filed as defects)
  and in both executor agents.
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
  changes `works/templates/intent.md` for every adopting repo. **S2 implemented "only when visual"**:
  `works/templates/intent.md` is unchanged and every rule that reads the section tolerates its
  absence. Still an operator decision to confirm at the review — reverting it would mean a template
  change reaching every adopting repo.
- (`P17.DECOMP`) **Should `installer/main.py`'s `flag_stale_skills()` heuristic be widened** now that a
  second shipped skill (`create-phase`, joining `design-cowork`) lacks the
  `disable-model-invocation: true` marker it uses to recognize workspace-managed skill dirs? Inert
  today; only bites if such a skill is later dropped upstream. Candidate for `defer-job` rather than
  in-phase work. **S2 left the heuristic and its docstring untouched, per plan** — the docstring now
  says a shipped SKILL.md sets the marker, which holds for 15 of 17 skills. Route this one at the
  review (most likely `defer-job`).

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
