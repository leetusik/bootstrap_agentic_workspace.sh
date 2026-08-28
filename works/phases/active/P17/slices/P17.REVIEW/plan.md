# Plan — P17.REVIEW

Review P17 as a whole, then — **only on a pass** — consolidate the phase's "Doc impact" notes into
new doc versions. The phase's acceptance gate is **waived** (`required: false`, machinery-only), so
**no gate stages apply**: no walkthrough, no browser work, no fresh-eyes product walk, no
`## Regression Checklist` run. This repo has no `## Operator Runtime` and no product to browse.

## What this phase claims to have done

`intent.md` is the specification. In one sentence per part: three named design styles the operator
chooses; a runnable mockup carrying the round's single approval; a closed `--kind` set enforced at
creation and warned about in `validate()`; and `create-phase` callable by the agent on instruction
with its confirmation gate unmoved. Shipped as workspace v34.

## Validate the phase together

Re-run each slice's validation from its `plan.md` / `result.md`, plus:

- `python3 scripts/workflow.py validate`
- `bash tests/retrofit_smoke.sh` — the only real test suite here; it must pass
- `python3 installer/build.py --check`
- `python3 scripts/workflow.py sync-agents --check` — S2 edited both executor agent bodies
- `diff .claude/agents/slice-executor-mid.md .claude/agents/slice-executor-high.md` — only
  frontmatter lines 2-5 may differ
- The `--kind` behaviour by hand: an invalid kind is rejected at `new-slice` **and** at
  `promote-deferred --create-phase` (leaving no half-created phase), `co-work` is accepted, and
  `validate` warns but exits 0 on an unknown kind. **Delete any scratch state you create.**

## Judge it

Against `intent.md`, the objective, and the docs. Specifically:

1. **Internal consistency across the seven files.** The `co-work` invariants were restated in six
   files and enforced in zero; S2 added `review-phase` and `README.md` as a seventh and eighth.
   Grep for superseded wording — `never dispatched`, `not dispatched`, `two passes`, `two phases`,
   `two commits`, `Explicit invocation only`, `disable-model-invocation`, `DECOMP2` — and confirm
   every survivor is correctly scoped. **`DECOMP2` must read correctly under all three styles**,
   including `paired`, which has none.
2. **The bans got tighter, not looser.** Four `## Never` bullets in `design-cowork/SKILL.md` were
   narrowed and two more edited. Read the whole block and confirm the skill still holds its line:
   the agent does not decide what things look like, and the mockup transcribes an approved design
   rather than inventing one.
3. **The test suite was repaired, not weakened.** Two assertions pinned wording this phase
   supersedes. Confirm they were replaced with assertions on the *new* invariants and that the
   `disable-model-invocation` assertion still pins both exceptions exactly.
4. **The four behavioural gaps** S2 fixed in the drivers actually read correctly: `plan only` vs.
   `paired`, a slice resuming twice, the mockup span as a real idle window, and distinguishable
   messaging for the two `pending` stops.
5. **Version and changelog agree** with what landed — four commits per design slice, and the
   twice-called `require_slice_kind()`.

Anything wrong is a numbered finding with a proposed `fix` slice, and a `changes_requested`
verdict **stops you before any doc consolidation**.

## Consolidate the docs — pass only

The `## Doc impact` list in `phase.md` names three targets. Not parallel mode, so version them
here with `python3 scripts/workflow.py doc-new-version --doc <name> --summary "..." --source
P17.REVIEW`:

- **`operations.md`** — the `## Visual-design runbook` is the big one: three named styles, the
  dispatched mockup span, the second `pending` window and that only the second is an approval,
  SIGNOFF at the gate, four commits, and `accept-gate --require` for any mockup-shipping phase. Also
  the skill-inventory paragraph's "sole model-invocable skill" claim — there are now two.
- **`decisions.md`** — one ADR for the whole phase: the three styles, approval moving onto a
  runnable mockup, the closed `--kind` set with its two deliberate asymmetries, and agent-runnable
  `create-phase` as the second, narrower exception.
- **`qa.md`** — the mockup's relaxed check versus the apply slice's full functional sweep, against
  the `## Verification doctrine`.

Never hand-edit `docs/current/*.md` — write the new version, and the engine regenerates.

## Route the Operator Questions — both of them

Two entries are open, and **an unrouted entry blocks the pass**. The gate is waived, so there is no
walkthrough to fold them into: both are `defer-job` material. **List them with proposed
`--title` / `--reason` / `--trigger` in your result; the orchestrator files them.** Do not run
`defer-job` yourself.

1. `## Design Style` scaffolded into every phase's `intent.md` vs. appended by `create-phase` only
   when visual. S2 implemented "only when visual" and left `works/templates/intent.md` unchanged;
   reverting would push a template change to every adopting repo.
2. Widening `installer/main.py`'s `flag_stale_skills()` heuristic, now that two shipped skills lack
   the `disable-model-invocation` marker it uses as an ownership test. Inert today; only bites if
   such a skill is later dropped upstream.

## Return

A `review_verdict` of `pass` / `changes_requested` / `blocked`, the doc versions you created, the
two deferred jobs for the orchestrator to file, and the fixed pointer
`explain: not written — run /explain for this phase`. **No walkthrough** — the gate is waived.
Write docs only; never source.
