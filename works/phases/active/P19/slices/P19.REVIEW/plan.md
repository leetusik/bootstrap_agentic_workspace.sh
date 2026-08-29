# Plan — P19.REVIEW: phase review

Follow the `review-phase` skill (`.claude/skills/review-phase/SKILL.md`). Validate both middle
slices together, judge the phase against its objective and `intent.md`, route every
`## Operator Questions` entry, and — **only on a pass** — consolidate the `## Doc impact` notes into
new doc versions.

**The gate is `acceptance.required: false`** (waived at the `DECOMP` boundary: workspace machinery
only, and this repo ships no browsable product). So **skip the gate stages entirely** — no product
walk, no regression checklist re-run, no `walkthrough`. This is not a shortcut being taken; it is
what a waived phase means, and it changes how questions route (below).

## What shipped, and what to judge it against

Two changes, both machinery, shipped as workspace **v36**:

- **`P19.S1`** — `research` added to the closed `SLICE_KINDS` set with four semantics (findings-only;
  always `slice-executor-high` **by kind**, whatever `risk` says; findings land in `phase.md`; a
  `DECOMP2` usually follows), and `DECOMP2` rewritten as a device with two peer origins rather than a
  `build-after` fixture.
- **`P19.S2`** — **Aside** prescribed as the default real-browser verification instrument (MCP first,
  CLI/REPL as the Bash surfaces) in place of scripted Playwright-style automation, as
  prescription + surface + fallback; plus `WORKSPACE_VERSION` 36 and the `## v36` changelog.

`intent.md` is the confirmed operator intent and unusually specific — check both halves actually
landed as confirmed, including the ones easy to lose: `research` must not be routable to `mid` by a
`low` rating; the `## Operator Runtime` rule must be untouched by the Aside change.

## Validate everything together

Re-run, do not take the slices' word for it: `python3 scripts/workflow.py validate` ·
`bash tests/retrofit_smoke.sh` · `python3 installer/build.py --check`. Read both `result.md` files
and cross-check the notebook against them, per the contract — a dropped decision or an unrouted
question is a review finding.

Then check the two claims most worth verifying by hand, because both slices asserted them and
neither could be caught by prose review alone:

1. **The agent bodies are byte-identical below the frontmatter.** Both slices edited both files.
2. **The engine really accepts `--kind research` and still rejects an invented kind** — on scratch
   state you clean up, never on P19, whose 4-slice cap is the operator's.

And one judgement call worth a real look rather than a nod: **is the Aside fallback wording a
loophole?** S2 was told not to write a fallback that makes the prescription decorative nor a
prescription that a Linux workspace fails. Read what it actually wrote and say whether it holds.

## Route all three operator questions — the gate is waived, so routing means `defer-job`

Three entries sit on `## Operator Questions` (two from `DECOMP`, one from `S2`). With no acceptance
gate there is no walkthrough to fold them into, so **every one must be listed for `defer-job`**:
title, reason, trigger, in `result.md` and in your return. You may not run `defer-job` — the
orchestrator files them. An unrouted entry is a finding, and you may not pass with one.

The third is the sharpest and should not be flattened into the other two: Aside is a real desktop
browser signed into the operator's own accounts, so an agent driving it can act as the operator, and
v36 says *use Aside* without saying *with which profile*. Give it its own job.

## On a pass, consolidate the docs

Five `## Doc impact` lines across three docs — `operations.md` (two), `decisions.md` (two),
`qa.md` (one). One new version **per doc**, capturing the whole phase, not per note:
`python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source P19.REVIEW`, edit
only the returned `edit_path`, then `python3 scripts/workflow.py rebuild-docs`. Never hand-edit
`docs/current/*`. Not parallel mode, so consolidation happens here.

Note `operations.md` has an *Executor tiers* section whose routing row S1's note says needs the
kind-first rule; `qa.md`'s *Verification doctrine* is the section Aside completes.

## On a non-pass, stop before consolidation

Finish validation and judgment across the whole phase first — the orchestrator wants the complete
picture in one cycle, not one finding per cycle — then return the verdict with numbered findings and
proposed `P19.F<n>` fix slices, one line of scope each, and do no pass-only work.

## Return

`review_verdict`, the deferred jobs to file, `doc_versions`, and the fixed pointer
`explain: not written — run /explain for this phase`. No `walkthrough` — the gate is waived. Write
`result.md` verdict-block-first. Do not commit, do not run `review-phase`, do not run `defer-job`,
do not transition status.
