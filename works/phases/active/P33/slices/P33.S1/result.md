# Result: P33.S1, Engine: rotate-backlog decides the chain, archives last

- **status:** done
- **tier:** high
- **summary:** `rotate-backlog` now checks the doc debt first and prints its decision as the first line, `rotate=<refused|archive|stop_midflight|resume|create>`. It archives only when nothing owes. The create line carries a queue-jump `--order`, resume re-asserts that order on the live docs phase, a run stops for default-stream work that is off a boundary, and a parallel stream is refused. `--archive-only` is byte-identical to before. The v51 smoke block is rewritten and extended (4 asserts become 12), smoke is 247/0, and the installer is rebuilt.
- **files_changed:** `scripts/workflow.py`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P33/phase.md`, `works/phases/active/P33/slices/P33.S1/result.md`
- **validation:**
  - `bash tests/retrofit_smoke.sh`: pass, **247 PASS / 0 FAIL** (baseline at HEAD `ad87400`: 239 / 0, run on a `git archive` export). The 3 baseline PASS lines missing from the new run are the reworded v51 rotate asserts; the `--consolidates` refusal assert is unchanged. Net +8.
  - `python3 installer/build.py --check`: pass.
  - `python3 scripts/workflow.py validate`: pass (exit 0). Warnings: the expected `consolidation_owed=P33` and `oversized_doc_sections=8`, plus `stale_docs=architecture, decisions, operations, qa`, which this slice's four `## Doc impact` notes raise by design.
  - Scratch walkthrough of every branch, outside git: pass (transcript below).
- **deviations:** (1) The `archive` condition is "no live docs phase and no *uncovered* debt-only phase", not "no debt-only phase". The two differ only when the debt is covered solely by a docs phase stamped onto another stream: `archive` then runs and prints `docs_phase_elsewhere=`, where the literal rule would have printed a `create` branch with nothing to create. (2) Three informational follow-up lines the plan did not name: `stopped_before=` (on stop_midflight), `docs_debt_waiting=` (on resume, for uncovered debt) and `docs_phase_elsewhere=` (on archive). (3) `--archive-only` is not refused on a parallel stream, because the plan keeps today's behaviour exactly. (4) The jump order is rounded to 6 decimals to trim float noise (`1.3 - 1`). (5) The optional `review-phase` pass-message edit was taken (one line). (6) `refused` was verified by a unit-style Python call that patches `git_current_branch`, which the plan allows, not from a git checkout on the branch: creating that branch in scratch would have meant running git outside this worktree.
- **doc_impact:** four lines appended to `phase.md` `## Doc impact` (operations.md, architecture.md, decisions.md, qa.md), each tagged `(P33.S1)`.

## What changed

`scripts/workflow.py`:

- New, above `rotate_backlog`:
  - the constants `ROTATE_BOUNDARY_SLICE_STATUSES` (`todo`, `ready`, `done`) and `ROTATE_MIDFLIGHT_PHASE_STATUSES` (`pending`, `blocked`, `in_review`);
  - `_live_docs_phases`: not-`done`, default-stream, `consolidates` non-empty, in phase order;
  - `_midflight`: `<id>:<status>`, each phase before its slices, live docs phases excluded, parallel streams never counted;
  - `_open_orders` and `_queue_jump_order`: `min(open default-stream orders) - 1`, `_clean_order`-normalised, or None;
  - `_reassert_queue_jump`: one `order` write, a `phase_reordered` event and a rebuild, only when the docs phase does not sort strictly first; a tie counts as not first;
  - `_docs_debt_split`: `(covered_by, uncovered)` from `_debt_only` and `consolidation_cover`;
  - `_print_docs_phase_covered`;
  - `_rotate_sweep`: today's sweep and report, moved verbatim.
- `_print_docs_phase_proposal` now takes `(uncovered, order)`. It prints `--order <jump>` **before** `--consolidates`, and its last line is reworded.
- `rotate_backlog` is rewritten to the precedence refused → archive → stop_midflight → resume → create, and its module comment is updated.
- Untouched: `_debt_only`, `_phase_blocker_kinds`, `_phase_blockers`, `_archive_one`, `archive_all`, `archive_phase` and the manifest.
- The `rotate-backlog` / `--archive-only` argparse help is rewritten.
- The `review-phase` pass message's archive line now reads: ``Archive done phases later, whole phases only: `rotate-backlog` (it pays the doc debt first, then archives every done phase), or `archive-all` once every active phase is done.``

The exact printed lines for every branch, with their exit codes, are recorded in `phase.md` `## Decisions` (*Engine (landed in P33.S1)*). That is the contract S2 writes the skill against, so it is not repeated here.

`tests/retrofit_smoke.sh`: the v51 block in Test 5, which runs on the copy `$ROT`, is rewritten, and a second copy `$ROT2` is added for the order re-assert. Fixture `$F`'s later assertions are untouched. The new asserts, in order:

1. `rotate=create` comes first, the `create:` line ends in `--consolidates P2`, nothing is created, and P2 stays active.
2. The `create:` line's `--order` is below the planned P1's order (`0 < 1`).
3. The `create:` line runs as is (`eval`) and `next` points at the docs phase.
4. A re-run prints `rotate=resume docs_phase=<P>` and `docs_phase_covered=<P> (pays P2)`, with no proposal and no `docs_phase_order=`.
5. Kept: `--consolidates` refuses a phase that owes nothing.
6. Kept and extended: `--archive-only` prints no `rotate=` line and no `docs_phase` line.
7. With P1 `pending` and P1.S1 `in_progress`, the first line is `rotate=stop_midflight midflight=P1:pending, P1.S1:in_progress`, followed by `stopped_before=resume docs_phase=<P>`, and nothing is archived.
8. With the docs phase's own DECOMP `in_progress`, the run is still `rotate=resume`.
9. After `docs-consolidated P2`, the paid but unreviewed docs phase still resumes, and P2 stays active.
10. Once the docs phase is waived, its REVIEW is done and its review passes: `rotate=archive`, last line `docs_phase=none`, P2 and the docs phase leave `active/`, and P1 stays.
11. `$ROT2`: a docs phase created without `--order` (order 3) resumes with `docs_phase_order=P7 3 -> 0`, `phase.json` `"order": 0`, a `phase_reordered` event, and `next` pointing at it.
12. A second run writes no order (idempotent).

The `refused` branch is not in the smoke, as the plan allows; it is in the walkthrough below.

## Where `v54` appears (for a merge-time renumber)

- `scripts/workflow.py`: the comment `# v54 (P33): \`rotate-backlog\` is the one resumable step…` above the `ROTATE_*` constants, and `# v54 (P33): the one resumable step…` inside `rotate_backlog`.
- `tests/retrofit_smoke.sh`: the block comment `# v54 one-shot rotate-backlog (P33; v51 made it propose the docs phase)…`.

No help text, output line or assert message carries the number. The `bad` messages say `rotate probe:`.

## Scratch walkthrough (outside git)

The copy was made with `cp -R scripts works docs` from this worktree into the session scratchpad, which is not a git repo, so it is the default stream. P33's `execution` block keeps it off the default stream; P32 (order 1) and P34 (order 3) are planned. Every command ran from the copy root, `python3 scripts/workflow.py …`. Nothing was run in this worktree except `validate`, `installer/build.py` and the smoke test.

**0: `refused`** (a unit-style call: `refused_probe.py` loads the copy's engine, patches `git_current_branch` to P33's branch, calls `main(["rotate-backlog"])` and hashes `works/` and `docs/` before and after):

```
stream before patch: None
stream after patch: phase/P33-one-shot_rotate-backlog_consolidate_the
stdout: rotate=refused stream=phase/P33-one-shot_rotate-backlog_consolidate_the
exit: non-zero (message: rotate-backlog wrote nothing: doc consolidation and archiving run on the default stream only -- run it from the main checkout, not this phase's worktree)
tree unchanged: True
--archive-only on the same stream (unchanged, no refusal): no done phases to rotate; 2 phase(s) still active: P33, P34
```

**1: `archive`, nothing owes:**

```
rotate=archive
no done phases to rotate; 3 phase(s) still active: P32, P33, P34
docs_phase=none
rc=0
```

**2: `create`.** Debt was staged on P32 first: a `## Doc impact` note, `accept-gate --waive`, both slices done, `review-phase P32 --verdict pass`. The `--order 2` is P34's 3 minus 1; P33 is parallel and excluded.

```
rotate=create
docs_phase_proposal=P32
phase=P35
name=Consolidate the doc impact of P32
objective=consolidate the '## Doc impact' notes from P32 into new versions of operations
create: python3 scripts/workflow.py new-phase --phase P35 --name "Consolidate the doc impact of P32" --objective "consolidate the '## Doc impact' notes from P32 into new versions of operations" --order 2 --consolidates P32
scope: python3 scripts/workflow.py docs-debt
proposal only: nothing was created -- /rotate-backlog runs the create: line as is (the invocation is the operator's yes; create-phase's docs-phase route)
rc=0
(active: P32 P33 P34 -- nothing created)
```

**3: `stop_midflight` before create** (P34 set to `in_review`, P34.DECOMP to `in_progress`; reset afterwards, and the run is `rotate=create` again):

```
rotate=stop_midflight midflight=P34:in_review, P34.DECOMP:in_progress
stopped_before=create owing=P32
nothing was archived, created or reordered: the docs phase never interleaves with running work -- re-run rotate-backlog once every listed slice is todo, ready or done and no listed phase is pending, blocked or in_review
rc=0
```

**4: the create line run as is:**

```
created phase P35: works/phases/active/P35
consolidates=P32 (docs phase: pays the doc debt of those phases; docs-debt shows it as 'paid by P35')
current_phase=P35
current_slice=P35.DECOMP
  "order": 2,
```

**5: `resume`, and what counts as mid-flight:**

```
== rotate-backlog -> resume (already first: no order write)
rotate=resume docs_phase=P35
docs_phase_covered=P35 (pays P32)
== the docs phase's own slice in_progress (P35.DECOMP) is not mid-flight
rotate=resume docs_phase=P35
docs_phase_covered=P35 (pays P32)
== another phase's slice in_progress (P34.DECOMP) stops the resume
rotate=stop_midflight midflight=P34.DECOMP:in_progress
stopped_before=resume docs_phase=P35
nothing was archived, created or reordered: ...
```

**6: `resume` with the order re-asserted** (P35's order set to 10 to stand in for a v51–v53 docs phase):

```
current_phase=P34                      (before: the docs phase sat behind planned work)
rotate=resume docs_phase=P35
docs_phase_order=P35 10 -> 2
docs_phase_covered=P35 (pays P32)
{"ts": "2026-10-12T17:08:09+09:00", "type": "phase_reordered", "phase": "P35", "old_order": 10, "new_order": 2, "reason": "rotate-backlog queue jump"}
  "order": 2,
current_phase=P35
== re-run: already first, no docs_phase_order line
== a tie (order 3 = P34) is re-asserted:      docs_phase_order=P35 3 -> 2
== fractional 2.5 already sorts ahead of 3:   no docs_phase_order line
```

**7: a paid docs phase resumes until its review passes** (`docs-consolidated P32`, then):

```
rotate=resume docs_phase=P35
rc=0
```

**8: `archive` last** (P35: gate waived, slices done, `review-phase P35 --verdict pass`):

```
rotate=archive
rotated 2 done phase(s) to archived:
- P32: works/phases/archived/20261012_170827_P32_one_executor_route_table_dispatch-time_model_and_effort_no_presets_haiku_cheap_route
- P35: works/phases/archived/20261012_170827_P35_consolidate_the_doc_impact_of_p32
left 2 phase(s) active: P33, P34
docs_phase=none
rc=0
```

**7x/7y: uncovered debt behind a live docs phase** (a copy taken at step 7, with P34 also made debt-only):

```
rotate=resume docs_phase=P35
docs_phase_covered=P35 (pays P32)
docs_debt_waiting=P34 (no docs phase pays it yet; rotate-backlog proposes one once P35 is done)
-- after P32 paid and P35 passed: P34 still owes, so create (no --order: no other open default-stream phase), nothing archived
rotate=create
docs_phase_proposal=P34
...
create: python3 scripts/workflow.py new-phase --phase P36 --name "Consolidate the doc impact of P34" --objective "..." --consolidates P34
```

**Fractional and negative jump** (a copy with a planned P40 at `--order 0.3`): `create: … --order -0.7 --consolidates P34`. That line, run as is, wrote `"order": -0.7`, `next` pointed at the new docs phase, the re-run was `rotate=resume`, and `validate` passed.

**No active phases:** `rotate=archive` / `no active phases to rotate` / `docs_phase=none`, rc 0.

**Debt covered only by a docs phase on another stream** (a docs phase `--consolidates P34`, then stamped `execution.mode=parallel`):

```
rotate=archive
rotated 2 done phase(s) to archived:
- P32: …
- P35: …
left 3 phase(s) active: P33, P34, P36
docs_phase_elsewhere=P36 (pays P34; on another stream, not resumed here)
docs_phase=none
```

**`--archive-only` is byte-identical to the pre-slice engine.** Two copies of the same state were taken; one ran the HEAD `scripts/workflow.py` from the baseline export and the other the new one. After the archive timestamps were normalised, `diff` was empty:

```
rotated 2 done phase(s) to archived:
- P32: works/phases/archived/<TS>_P32_…
- P35: works/phases/archived/<TS>_P35_consolidate_the_doc_impact_of_p32
left 2 phase(s) active: P33, P34
--archive-only output identical to the pre-slice engine
```

## phase.md

- `## Decisions`: the engine line is replaced by *Engine (landed in P33.S1)*, which records the exact lines and exit codes per branch, `--archive-only`, the new `review-phase` line and the two edges S1 settled. The queue-jump line gains the rounding. Nothing else is touched.
- `## Doc impact`: four lines appended.
- `## Notes for later slices`: consumed both `(from P33.DECOMP, for P33.S1)` notes and the shared `## Doc impact` timing note (its engine half is now written; the S2 half is restated in the new S2 note). The shared worktree note and S2's *Texts* note are kept. Added one note `(from P33.S1, for P33.S2)` and one `(from P33.S1, for P33.REVIEW)`.
- `## Now`: rewritten for S2.

## Notes

- Clean phases now wait in `active/` while any debt is uncovered or any docs phase is live, because `archive` runs only when nothing owes. Combined with S2's "one docs phase per invocation" rule, a run that leaves new debt behind ends on `rotate=create` without archiving. This follows the confirmed intent ("archive nothing up front"), so it is not raised as an operator question.
- `stop_midflight` exits 0. Only `refused` exits non-zero, as the plan specifies.
