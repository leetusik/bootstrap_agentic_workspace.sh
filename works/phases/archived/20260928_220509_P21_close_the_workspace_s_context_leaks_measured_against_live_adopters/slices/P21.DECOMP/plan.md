# Plan — P21.DECOMP (decomposition)

## Context

P21 closes the workspace's context leaks, measured against four live adopter repos. Read the phase's `intent.md` (works/phases/active/P21/intent.md) in full — it is the confirmed operator intent — and the seeded `phase.md` beside it. The core structural fact, already decided by the operator and recorded in the objective: **the fix list is not knowable before the measurement**, so this DECOMP cuts a research slice first and a `P21.DECOMP2` after it, and nothing else. Do not guess at remedy slices — that is DECOMP2's job, after the findings land.

## What to do

1. Read `works/phases/active/P21/intent.md` and `works/phases/active/P21/phase.md`, plus `CLAUDE.md`'s research-slice and DECOMP2 rules (the "`research` is a findings-only slice kind" and "`DECOMP2` has two origins" bullets).
2. Create exactly two middle slices with `python3 scripts/workflow.py new-slice` (bare folders — never pre-fill their `plan.md`):
   - `P21.S1` — a `research` slice: `--phase P21 --slice P21.S1 --name "measure context spend across four live adopters" --kind research --risk high --order 2` (DECOMP is order 1, REVIEW is last; check the existing orders with `python3 scripts/workflow.py validate` / the slice.json files and pick orders that slot S1 and DECOMP2 between DECOMP and REVIEW).
   - `P21.DECOMP2` — the re-cut: `--phase P21 --slice P21.DECOMP2 --name "cut remedy slices from research findings" --kind decomposition --risk high --order 3 --depends-on P21.S1`.
3. Edit `phase.md` (under its 200-line / 16 KB budget):
   - Record the slice breakdown rationale in one or two lines under `## Decisions` (research-first because the fix list depends on measurement; DECOMP2 re-cuts).
   - Under `## Notes for later slices`, tag for the research slice **(from P21.DECOMP, for P21.S1)**: the four adopter repo paths — `/Users/sugang/projects/personal/changple5`, `/Users/sugang/projects/personal/changple_web`, `/Users/sugang/projects/personal/Mijual`, `/Users/sugang/projects/personal/arb_upbit_1` — read-only evidence, never edited from here; re-measure rather than trusting intent.md's numbers; record method + numbers in phase.md; the five open questions and the confirmed doc-rewrite leak live in intent.md and are the research agenda.
   - Rewrite `## Now` (≤ 15 lines) as the handoff for the research slice.
4. Run `python3 scripts/workflow.py rebuild` so the `## Slices` table regenerates, then `python3 scripts/workflow.py validate`.
5. Write `result.md` in this slice's folder, structured verdict block first.

## Boundaries

- Bare folders only: create no `plan.md` for S1 or DECOMP2.
- Do not run `accept-gate` (orchestrator's job), do not commit, do not transition any slice/phase status beyond what `new-slice` itself does.
- No adopter-repo reads are needed in this slice; the paths are handed to S1 as notes.

## Acceptance-gate input for the orchestrator

In your verdict summary, state your read on the gate: this phase changes workflow machinery and doctrine only (no operator-visible running product), so `--waive` is expected — flag anything in your decomposition that would change that.
