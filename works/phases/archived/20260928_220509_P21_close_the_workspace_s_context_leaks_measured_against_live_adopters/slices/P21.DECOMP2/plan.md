# Plan — P21.DECOMP2 (cut remedy slices from research findings)

## Context

Read `works/phases/active/P21/phase.md` whole — S1's findings are landed there, and the notes tagged "for P21.DECOMP2" carry the full remedy list (R1–R5) with target files, expected `--risk`, and confidence. Full reasoning is in `slices/P21.S1/result.md` §11; consult it where a cut needs the blast-radius detail, do not re-derive the measurements. `intent.md` is the operator's confirmed intent.

## What to do

1. Cut the remedy slices from the R1–R5 list with `python3 scripts/workflow.py new-slice` — **bare folders only, never pre-fill their `plan.md`**. Decisions that are yours to make, deliberately:
   - **Granularity:** one slice per remedy is the default, but respect the hard sequencing constraint — **R2 must land with or before R1**. Merging R1+R2 into a single slice, or ordering R2 strictly before R1 via `--order`, are both acceptable; pick the one that keeps each slice's blast radius reviewable and say why in `phase.md`.
   - **Risk ratings:** follow the expected ratings in the note (machinery/cross-file = `high`; only a genuinely one-line or docs-only edit is `low`). The rating routes the executor tier — when in doubt, `high`.
   - **R3 sizing:** OQ1 (docs-phase cadence) is unanswered and must not block you. Cut R3 in the cadence-independent form — debt visibility in `next`/`validate` is needed at *any* cadence; note in `phase.md` that the operator's OQ1 answer can tune thresholds later without re-cutting.
   - **R5:** cut it per the note (secondary, independent). If you judge it docs-only guidance, `--risk low` is fine; if it touches `workflow.py`, `high`.
   - **OQ2 (contract growth):** do NOT cut a slice for it — it is explicitly an operator call. Leave it in `## Operator Questions` for the review to route.
   - Use `--order` values that place the new slices between DECOMP2 (order 3) and REVIEW, in dependency order; use `--depends-on` where real.
2. Edit `phase.md` under budget (it currently sits at 16,367 of 16,384 bytes — consuming the large "for P21.DECOMP2" notes will free room; the new `## Slices` rows will use some back; you MUST leave it under 16,384 with a few hundred bytes of headroom for `finish-slice` outcome lines):
   - Record the cut and its rationale (granularity, ordering, any deviation from R1–R5 as listed) in `## Decisions` — replace superseded lines, don't stack.
   - Consume (remove) the notes tagged "for P21.DECOMP2". Keep the "for P21.REVIEW" notes and the upstream-repo/installer note intact (retag it for the implementation slices + REVIEW if you reword it).
   - Add any note the implementation slices genuinely need, tagged **(from P21.DECOMP2, for P21.Sn)** — pointers to result.md sections, not restated content.
   - Rewrite `## Now` (≤ 15 lines) as the handoff to the first remedy slice.
   - Do not touch `## Operator Questions` except to append (nothing to answer here); never hand-edit the generated `## Slices` block.
3. Run `python3 scripts/workflow.py rebuild` then `python3 scripts/workflow.py validate` — both must pass, with no notebook-budget warning.
4. Write this slice's `result.md`, structured verdict block first: the cut, the ordering rationale, what you deliberately did not cut and why.

## Boundaries

- Bare folders only; no plan.md for any new slice.
- No product/machinery code edits in this slice — cutting is the whole job.
- Do not run accept-gate (the gate is already waived; flag in your verdict if any cut remedy touches an operator-visible surface, which would make the orchestrator revisit it).
- Do not commit; do not transition statuses beyond what new-slice does.

## Verdict

Return: status, one-line summary for `finish-slice --outcome` (keep it short — the notebook is tight), files_changed, validation outcomes, the slice list you cut (id / name / kind / risk / order), and your acceptance-gate read.
