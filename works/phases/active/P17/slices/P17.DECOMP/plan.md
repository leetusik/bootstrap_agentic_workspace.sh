# Plan — P17.DECOMP

Decompose P17 into **exactly three** middle slices, record the breakdown and findings in
`phase.md`, and stop. Create bare folders only — never pre-fill another slice's `plan.md`.

## Read first

- `works/phases/active/P17/intent.md` — the whole confirmed intent, eight resolved
  clarifications, and four notes. **This is the specification for the phase**; the objective
  in `phase.md` is only its headline.
- `CLAUDE.md` — the contract this phase edits.
- `.claude/skills/design-cowork/SKILL.md` — the 334-line skill this phase rewrites.
- `.claude/skills/create-phase/SKILL.md` — frontmatter carries `disable-model-invocation: true`.
- `scripts/workflow.py` — the closed sets near L25-33 (`PHASE_STATUSES`, `SLICE_STATUSES`,
  `DEFERRED_STATUSES`, `REVIEW_VERDICTS`, `EXECUTION_MODES`, `CONSOLIDATION_STATES`);
  `new-slice` argparse at ~L1985 and `promote-deferred` at ~L2066; `validate()` at ~L692-809
  with its slice loop at ~L754-766.

## This phase is NOT a design-bearing phase

**Do not apply the two-pass decomposition.** P17 rewrites the *documentation of* the design
process; it touches no product visual surface. Create **no `co-work` slice**, **no
`P17.DECOMP2`**, and no build inventory. The single-pass shape is correct here. Rejecting the
reflex is the point — the phase's subject matter is design co-work, which makes the wrong
shape tempting.

## Operator constraint: exactly three middle slices

The operator asked for three. Presented at confirmation as guidance, and it is a sound cut —
spec first, then everything that must agree with it, then the release:

1. **The spec** — rewrite `.claude/skills/design-cowork/SKILL.md`: the three styles
   (`build-after` / `design-only` / `paired`) replacing the two-shape bullets in `## Shape`
   (L38-74); the new loop diagram and three-commit shape in `## The loop` (L16-36); a new
   `## The mockup` section; `## Read back, then land it` (L164-195) ending at *land the
   record*, with SIGNOFF and the regroup moving after the mockup gate; the `## Mechanics`
   refinement at L199-201; and the two re-cut `## Never` bans (L313-334).

2. **Everything that must agree with it** — `SLICE_KINDS` + validation in `scripts/workflow.py`;
   `.claude/skills/create-phase/SKILL.md` (the three-way style question **and** removing
   `disable-model-invocation: true`); both drivers (`do-next-slice`, `do-whole-phase`); both
   executor agents (`slice-executor-mid`, `slice-executor-high`); `CLAUDE.md`.

3. **Release** — `installer/main.py:38` `WORKSPACE_VERSION` 33 → 34, the matching
   `CHANGELOG.md` entry, and `python3 installer/build.py` with the rebuilt
   `bootstrap_agentic_workspace.sh`. Procedure: `installer/README.md:23`.

Use `--order` 10 / 20 / 30 and name them `P17.S1` / `P17.S2` / `P17.S3`. Set `--depends-on`
so S2 depends on S1 and S3 on S2 — the propagation must not run before the spec it copies
from exists, and the rebuild must not run before the files it embeds are final.

**Rate `--risk` deliberately.** All three plausibly land at `high`: each spans more than one
file, and the contract reserves `low` for a one-line/few-line edit or docs. S3 is the only
arguable one — its hand edits are small, but it spans `installer/main.py`, `CHANGELOG.md`,
and the regenerated artifact. Decide it yourself against the contract's rule; do not rate a
slice `low` to save cost.

## Record in `phase.md`

Under `## Decomposition`, the three slices with one line each on scope and why the risk was
rated as it was. Under `## Findings`, at minimum:

- **The six-file consistency problem.** The `co-work` invariants are stated in `CLAUDE.md`
  (L58, L65, L75), `design-cowork/SKILL.md` (L40, L332), `do-next-slice/SKILL.md` (L12, L26,
  L37), `do-whole-phase/SKILL.md` (L12, L21, L25, L29), and both `slice-executor-*.md` (L32) —
  and are enforced in **zero** places by the engine. All must move together; S2 owns that, and
  the phase needs a closing grep sweep for superseded wording.
- **The two `Never` bans are re-cut, not deleted** (intent.md records the exact new wording).
  This is the sharpest edit in the phase: the mockup *transcribes* an approved design, so the
  ban moves to authoring one **before the round has come back**, and the implementation-code
  ban narrows to **product** implementation code.
- **`--kind` is the only slice/phase enum with no closed set.** `validate()` never inspects
  `kind`; `create_slice` writes it verbatim. Kinds already in use in this repo's history:
  `implementation`, `review`, `decomposition`, `fix`, `docs`, `qa` — all six must be in the
  set or existing slices break.
- **Backward compatibility:** creation-time validation is a hard error, but `validate()` only
  warns on an unknown kind, so an adopting repo carrying an invented kind survives
  `/update-workspace`.
- Anything you find that contradicts the intent — raise it rather than designing around it.

## Boundaries

- Create the three slices and write `phase.md`. **Write no implementation code**, and do not
  touch `design-cowork/SKILL.md`, `workflow.py`, `CLAUDE.md`, or any release file.
- Do not pre-fill any slice's `plan.md`. Bare folders only.
- Do not run `doc-new-version` — append "Doc impact" notes to `phase.md` instead; the review
  consolidates. The docs this phase will touch are `operations.md` (the `## Visual-design
  runbook`, L70-198), `decisions.md` (a new ADR), and `qa.md` (the mockup's relaxed sweep vs.
  the apply slice's full sweep).
- Do not run `accept-gate` — that is the orchestrator's call at this boundary.

## Validation

`python3 scripts/workflow.py validate` passes, and `next` reports `P17.S1` as the current
slice with `P17.S2` next.
