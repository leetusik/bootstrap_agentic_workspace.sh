# Result — P30.DECOMP (decomposition)

- status: done
- tier: high
- summary: Cut P30 into P30.S1 (engine: rotate-backlog proposes the docs phase) → P30.S2 (skills, texts and release v51) → P30.REVIEW. Both middle slices are implementation/low bare folders with S2 depending on S1. Decisions D1–D10 and the slice notes are recorded in phase.md, and the acceptance gate is to be required.
- files_changed: works/phases/active/P30/slices/P30.S1/slice.json (new-slice), works/phases/active/P30/slices/P30.S2/slice.json (new-slice), works/phases/active/P30/phase.md, works/phases/active/P30/slices/P30.DECOMP/result.md
- validation: `python3 scripts/workflow.py validate` PASS; `python3 scripts/workflow.py next` → current_slice P30.DECOMP, next_slice P30.S1 (P30.S1 becomes current once the orchestrator finishes this slice)
- deviations: none
- doc_impact: none (a decomposition changes no durable truth; D6 assigns the notes to S1 and S2)

## What was done

1. `new-slice --phase P30 --slice P30.S1 --name "Engine: rotate-backlog proposes the docs phase" --kind implementation --risk low` gave order 10, `depends_on` [].
2. `new-slice --phase P30 --slice P30.S2 --name "Skills, texts and release v51" --kind implementation --risk low --depends-on P30.S1` gave order 20, `depends_on` [P30.S1].
3. Each folder holds only `slice.json`, and no `plan.md` was pre-filled. The generated `## Slices` table now lists DECOMP, S1, S2 and REVIEW.
4. `phase.md` was edited:
   - `## Decisions`: the cut with its risk rationale, plus D1–D10 (compact).
   - `## Notes for later slices`: four notes for S1, one for S2 and one for REVIEW.
   - `## Now`: points at S1.

   No `## Doc impact` or `## Operator Questions` entries were added, because none were raised.

## Risk rationale

Both slices are `low`. The plan pins the approach completely. The only persisted-shape change is an optional `phase.json` key (`consolidates`) that is absent by default, so it needs no migration. The archive gate's blocking decision, the manifest and the behaviour of `archive-all` and `archive-phase` are explicitly untouched (D4). There is no open design, no unlocated root cause and no wide blast radius. `_phase_blockers` is restructured, but it has only three callers, all in `workflow.py`, and they must keep identical text.

## Read-only exploration findings (now notes in phase.md)

These were checked against `scripts/workflow.py` at DECOMP time. They live in `phase.md` `## Notes for later slices`; this is the detail behind them.

- The plan's line references were confirmed: `_phase_blockers` L3334, `rotate_backlog` L3424, `new_phase` L1717, `docs_debt` L2538, the helpers at L849/925/959/1034/1040/1046, and the parsers for new-phase at L4231 and rotate-backlog at L4409.
- `rotate_backlog` has two early returns: `no active phases to rotate` and `no done phases to rotate; …`. The plan names only the second. The first has no debt-only phase by construction, so `docs_phase=none` is the consistent reading. That is left to S1 to confirm and record.
- A parallel phase's "merged" test already exists. It is `merge-base --is-ancestor <branch> HEAD`, with a deleted branch counting as merged, in `parallel_merge_finish` (~L2484) and at ~L2722. `consolidation_command` returns `parallel-consolidated` for parallel phases, so a printed per-phase pay command must go through it.
- Smoke fixture (`tests/retrofit_smoke.sh` ~L874–906): P2 is debt-only until `docs-consolidated P2` + `archive-phase P2` at ~L900, and later assertions expect `docs_debt=none` and a cleared STALE flag. The rotate probes therefore have to run before that line, and probe (b)'s extra phase must not leak into the later assertions. The baseline is 235 PASS / 0 FAIL (P29.S1 / P29.REVIEW).
- The `docs-debt` scope today is P26–P29, with 46 notes over 4 docs. A real archived docs phase, P24 ("Consolidate the P21–P23 doc impact…"), is the naming precedent for D2's `name=` line.
