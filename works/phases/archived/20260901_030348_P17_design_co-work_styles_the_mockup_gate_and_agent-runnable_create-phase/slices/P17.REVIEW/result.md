# Result — P17.REVIEW

**Verdict: `pass`.** Validated all four completed slices together, judged the phase against
`intent.md` and the docs, consolidated the three "Doc impact" targets into new doc versions, and
routed both open Operator Questions as deferred jobs for the orchestrator to file.

The phase's acceptance gate is **waived** (`acceptance.required: false`, machinery only), so **no
gate stages ran**: no walkthrough, no opening a running product, no fresh-eyes walk, no
`## Regression Checklist` re-run. This repo has no `## Operator Runtime` and nothing to browse, and
no P17 slice claimed browser verification — correctly.

The durable, forward-looking half of this review — the bullet-by-bullet `## Never` audit, the one new
finding, and the phase-status advisory — is in `phase.md` → `### From P17.REVIEW`. It is not repeated
here.

## Validation — every slice's commands, re-run together

| Command | Outcome |
| --- | --- |
| `python3 scripts/workflow.py validate` | **pass** — "Workflow validation passed." (rc 0); re-run after doc consolidation, still pass |
| `bash tests/retrofit_smoke.sh` | **pass** — Tests 0-8, 123 `PASS` lines, 0 `FAIL`, exit 0; re-run after the doc edits, still exit 0 |
| `python3 installer/build.py --check` | **pass** — "artifact matches installer/ source" |
| `python3 scripts/workflow.py sync-agents --check` | **pass** — "agent files in sync"; `mid sonnet@xhigh`, `high opus@xhigh`, mode `flex` |
| `diff .claude/agents/slice-executor-{mid,high}.md` | **pass** — only frontmatter lines 2-5 differ (`name`, `description`, `tools`, `model`); bodies byte-identical |
| `grep -n "WORKSPACE_VERSION = 34" installer/main.py` | **pass** — line 38 |

### `--kind` behaviour, exercised by hand

Run in a **throwaway workspace tree** under the session scratchpad (a copy of `scripts/workflow.py`
plus a minimal `works/` + `docs/`), so this repo's `works/` was never mutated — `git status` shows no
`works/phases` change beyond the orchestrator's own `start-slice` and this slice's two files.

| Probe | Result |
| --- | --- |
| `new-slice --kind cowork` | rejected, rc 1, `invalid slice kind: cowork; expected one of ['co-work', 'decomposition', 'docs', 'fix', 'implementation', 'qa', 'review']`; **no slice folder created** |
| `new-slice --kind co-work` | accepted |
| `promote-deferred D1 --phase P9 --create-phase --kind cowork` | rejected, rc 1, and **`P9` was not created** — the deferred job stayed open |
| same with `--kind co-work` | phase created, job promoted |
| `validate` with `"kind": "invented-kind"` on disk | **warns on stdout and exits 0** — the asymmetry holds |

Source read to confirm the shape, not just the behaviour: `require_slice_kind()` at
`scripts/workflow.py:851`, called from `create_slice` (`:857`) **and** from `promote_deferred`
(`:1805`, before the `--create-phase` branch), exactly as `phase.md` records.

## Judgment — the plan's five criteria

1. **Internal consistency across the eight files — holds.** Grepped `never dispatched`,
   `not dispatched`, `is NOT dispatched`, `two passes`, `two commits`, `Explicit invocation only`,
   `two-phase split`, `sole model-invocable`, `disable-model-invocation` across `CLAUDE.md`,
   `.claude/`, `scripts/`, `installer/main.py`, `README.md`, `works/templates/`, `tests/`. Every
   superseded phrase is **gone**; every surviving `never dispatched` is scoped to the **DesignSync
   work**, in all six restating files plus the smoke assertions. All **17 `DECOMP2` hits** are
   style-qualified and read correctly under `paired`, which has none — including the `## Never`
   bullet, the contract's slice-ID line (`"in a build-after design phase only — design-only and
   paired have none"`), and both drivers' `plan only` rules. `## Mechanics` and `## Never` bullet 3
   agree on what is and is not dispatched. Two skills lack the model-invocation marker
   (`design-cowork`, `create-phase`) and the contract's L24 states both exceptions with their
   different widths.
2. **The bans got tighter, not looser — confirmed against the pre-phase file.** Full audit table in
   `phase.md`; the summary is 14 bullets before, 15 after, none deleted, four narrowed, one added,
   one scope-qualified, and the only scope that *shrank* (the functional sweep) shrank exactly onto
   the new stubbed-mockup case while the manifest-runtime rule got **stronger**
   ("everywhere, the mockup included"). The skill still holds its line, stated three separate times.
3. **The test suite was repaired, not weakened.** The two superseded-wording assertions were
   **replaced with assertions on the new invariants**, not deleted: `"The design slice is NOT"` →
   `"the DesignSync work is never dispatched"` + `"The mockup build is the one dispatched span"`;
   `"never writes implementation code"` → the two `*product*` forms. The exempt-skill assertion is
   now `(marker in body) == (name not in {"design-cowork", "create-phase"})` — **exact in both
   directions**, so the marker still cannot be dropped from any of the other 15 by accident. Net +99
   lines: positive pins for the three style names, `## The mockup`, `Only PENDING #2 is an
   approval.`, `Exempt from the full functional sweep`, both agents' mockup-span rules, and five new
   engine probes for the closed `--kind` set (including that `promote-deferred` leaves no half-created
   phase, and that the `validate` warning is asserted on **stdout**, never the exit code).
4. **The four behavioural gaps read correctly.** `plan only` — both drivers now state one general
   rule with three faces (`REVIEW`, `DECOMP2`, and a `paired` apply slice). **Resuming twice** —
   `do-next-slice` spells out three invocations for one design slice; `do-whole-phase` numbers the
   four spans with two loop stops. **The idle window** — `do-whole-phase`'s judgment list and
   `CLAUDE.md`'s skip list both now say a `co-work` slice *does* have a window, short and wedged
   between two operator stops. **Distinguishable messaging** — both drivers carry the same
   PENDING #1 (mechanical wait: handoff path + card contract) vs. PENDING #2 (asking for approval:
   run command, URL, viewports, what is stubbed, literal words) script.
5. **Version and changelog agree with what landed.** `WORKSPACE_VERSION = 34`, `## v34 — 2026-08-29`
   directly above `## v33`, artifact rebuilt after both. The entry states **four** commits per design
   slice (`handoff` / `read-back` / `mockup` / `signoff`) and the **`require_slice_kind()` helper
   called both from `create_slice` and from the top of `promote_deferred`** — i.e. it was written from
   what landed, not from `intent.md`. Spot-checked two migration claims independently: the unknown-kind
   warning is exit-code-neutral (probed above), and `--update` preserves `docs/`, so an adopter's
   `## Visual-design runbook` keeps its old text.

**One new finding, non-blocking** — `review-phase`'s gate **stage 4** is the only stage without a
mockup qualifier, so a now-ungatable `design-only` phase would append a headline check for a
throwaway route onto the cumulative smoke list. Inert until the first `design-only` phase runs;
detail and reasoning in `phase.md`, and it is deferred-job #3 below rather than a fix slice.

## Doc versions created — three, one per "Doc impact" target

Not parallel mode, so consolidation happened here, in the pass path.

| Doc | Version | What it now carries |
| --- | --- | --- |
| `operations` | `v0028_three_named_design_styles_the_runnable-mockup_gate_four_commits_per_round_and_two_model-invocable_skills_v34` | a v34 `## Status` paragraph; the design-summary paragraph re-cut to inline → dispatched → inline; `### Choose the phase shape at intake` → **`### Choose the design style at intake — three named styles`** with all three styles and where the choice lives; the loop rewritten to two `pending` windows and **four commits**, with only PENDING #2 an approval and the distinguishable-reporting rule; a new **`### The runnable mockup — the design in the project's own language`**; `### Close the one normal gate` → **`### Close the gate on the running mockup`**, with the read-back ending at *land the record* and SIGNOFF moved; and both "sole model-invocable exception" claims corrected to **two, of different widths** |
| `decisions` | `v0036_three_named_design_styles_approval_on_a_runnable_mockup_a_closed_--kind_set_and_agent-runnable_create-phase_p17_v34` | **one ADR for the whole phase** — four-part context, the four decisions, seven consequences (including the twice-called guard and the four driver consequences), and six rejected alternatives (history-derived `SLICE_KINDS`, erroring `validate()`, validating `--risk`, argparse `choices=`, a new slice kind for the mockup, scaffolding `## Design Style` into the template, autonomous `create-phase`); `## Status` updated to *thirty-five decisions, current in v34* |
| `qa` | `v0004_the_stubbed_mockup_s_relaxed_check_versus_the_apply_slice_s_full_functional_sweep_v34` | a v34 `## Status` line; the sweep re-headed as an **apply/fidelity duty on real wiring**; a new **The one exemption** block (what is *not* checked, what *is*, that the manifest runtime is **not** relaxed, why the bound is load-bearing, and the review's matching stage-3 qualifier); gate stage 3 in the doc's own list qualified to match |

`python3 scripts/workflow.py rebuild-docs` ran; `docs/current/{operations,decisions,qa}.md` are
regenerated snapshots and were never hand-edited.

## Operator Questions — both routed, as deferred jobs

The gate is waived, so there is no walkthrough to fold them into. **The orchestrator files these; the
review never runs `defer-job`.**

**1.** `--title` **"Confirm: `## Design Style` is appended by `create-phase` only when visual, not
scaffolded into every `intent.md`"** · `--reason` "P17.S2 implemented 'only when visual':
`works/templates/intent.md` is unchanged and every reader (both drivers, the design skill,
`create-phase`) treats the section's absence as 'not a design phase', asking the style at `DECOMP`
instead. Decomposition and S2 both read it that way, but `intent.md` never said, and the alternative
would push a template change to every adopting repo. Operator confirmation of the shipped behaviour."
· `--trigger` "Before the first design-bearing phase runs under v34, or the next time
`works/templates/intent.md` is edited for any reason." · `--source P17.REVIEW`

**2.** `--title` **"Widen `installer/main.py`'s `flag_stale_skills()` ownership heuristic beyond the
`disable-model-invocation` marker"** · `--reason` "The heuristic recognizes workspace-managed skill
dirs by that marker, which now holds for only 15 of 17 shipped skills — `design-cowork` and, since
v34, `create-phase` lack it. Both are in `CLAUDE_SKILLS` and are skipped before the marker check, so
nothing breaks today; but if either were ever dropped upstream it would not be flagged stale for
adopters, and the function's docstring still asserts the marker is universal. S2 left it untouched by
plan." · `--trigger` "If a model-invocable skill is ever retired upstream, or when
`flag_stale_skills()` is next touched." · `--source P17.REVIEW`

**3.** (new, from this review) `--title` **"Qualify `review-phase` gate stage 4 for a phase whose only
surface is a throwaway mockup"** · `--reason` "Stage 3 gained a mockup qualifier in v34; stage 4 —
're-run the whole `## Regression Checklist`, then append this phase's headline checks' — did not.
Since a `design-only` phase can no longer be waived, its review now runs stage 4 against a phase whose
operator-visible surface is a route the apply phase deletes, so appending a headline check for it
leaves a permanently dead line on the cumulative smoke list every later review re-runs. Inert until
the first `design-only` phase; a one-sentence qualifier in `.claude/skills/review-phase/SKILL.md`
(and the qa doc's stage list) fixes it." · `--trigger` "Before the first `design-only` or
mockup-shipping phase reaches its review." · `--source P17.REVIEW`

## Deviations from `plan.md`

**None in substance.** Two notes on the letter:

- The plan's by-hand `--kind` checks say "delete any scratch state you create". Rather than create and
  delete scratch state in this repo's `works/`, the probes ran against a **separate throwaway
  workspace tree in the session scratchpad** — same engine file, zero mutation here. Stronger than the
  plan asked for, and it also let the `promote-deferred --create-phase` probe run without inventing a
  deferred job in this repo.
- The plan lists five judgment criteria; this review adds a **sixth observation** it did not ask for
  (the stage-4 smoke-list gap) under the plan's own standing instruction to raise anything wrong. It
  is filed as a deferred job with the reasoning stated, not silently absorbed and not escalated to a
  `changes_requested` — that judgment call is named explicitly so the operator can overrule it.

No source file was edited: this review wrote **only** the three doc versions, this `result.md`, and
the `phase.md` append. No commit, no `review-phase`, no `accept-gate`, no `defer-job`, no status
transition.

**`explain: not written — run /explain for this phase.`** The review writes no explainer.
