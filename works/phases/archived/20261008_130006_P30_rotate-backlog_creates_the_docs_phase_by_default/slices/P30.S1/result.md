# Result — P30.S1 (Engine: rotate-backlog proposes the docs phase)

- status: done
- tier: mid
- summary: The engine now implements D1–D5. `new-phase --consolidates` marks a docs phase, `rotate-backlog` prints a read-only docs-phase proposal on every exit path (`--archive-only` opts out), and `docs-debt` shows a `paid by:` line. Typed blockers keep every refusal text identical. Smoke is 239 PASS / 0 FAIL, up 4 from 235.
- files_changed: scripts/workflow.py, tests/retrofit_smoke.sh, bootstrap_agentic_workspace.sh (rebuilt by installer/build.py), works/phases/active/P30/phase.md, works/phases/active/P30/slices/P30.S1/result.md
- validation:
  - `python3 scripts/workflow.py validate`: PASS
  - `python3 scripts/workflow.py rotate-backlog --help`: shows `--archive-only`
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: PASS (in sync)
  - `bash tests/retrofit_smoke.sh`, alone in its own foreground call: PASS, 239 PASS / 0 FAIL (baseline 235, +4 new asserts)
  - scratch-copy runs of `rotate-backlog` (below): PASS
- deviations:
  - The `create:` line double-quotes `--name` and `--objective` instead of `shlex.quote`. `shlex.quote` turns the objective's `'## Doc impact'` into `'…'"'"'## Doc impact'"'"'…`, which is unreadable. The helper `_shell_arg` falls back to `shlex.quote` for any text with `"`, `$`, backtick, backslash or `!`, so the line stays copy-pasteable. The plan's own example shows double quotes.
  - `validate` gained a small shape check for `consolidates` (an error for anything but a non-empty list of `P<N>` ids). No allowlist existed, so the plan's "accept the key" needed no change. The check is an addition to the plan.
  - The smoke block has 4 asserts, within the plan's 3–5.
- doc_impact: four `## Doc impact` lines appended to phase.md (operations, architecture, decisions, qa), each tagged `(P30.S1)`.

## What changed in `scripts/workflow.py`

- **Typed blockers.** `_phase_blocker_kinds(pdir)` returns `[(kind, text)]` with kinds `slices`, `review` and `consolidation`. `_phase_blockers` is now the list of its texts. Refusal text is identical: `archive-phase P26` still prints `phase P26 is not archivable (docs not consolidated -- run a docs phase over its '## Doc impact' notes, then: python3 scripts/workflow.py docs-consolidated P26). Finish/review it, or use --force …`.
- **Shared merged test.** `_parallel_branch_merged(execution, git_ok=None)` was factored out of `parallel_merge_finish` (no branch, a deleted branch, or no git all count as merged; otherwise `merge-base --is-ancestor <branch> HEAD`). `parallel_merge_finish` calls it and its output is unchanged. The second twin at ~L2722 is a status display with a different shape (`merged=None` for the phase's own stream), so I left it.
- **`_debt_only(pdir)`:** the kinds are exactly `["consolidation"]`, and the phase is either on the default stream or a parallel phase whose branch is merged.
- **`new-phase --consolidates P26,P27`.** `_parse_consolidates` splits on commas, strips spaces and dedupes in order. It runs before any write and refuses with `--consolidates refused, nothing was written: …` naming each id that is not an active phase or whose consolidation is not `pending`, and refuses an empty list. The key is stored as `"consolidates": […]` only when the flag is given, and `new-phase` then prints a `consolidates=…` line.
- **Helpers.** `phase_consolidates(data)` is a tolerant reader. `consolidation_cover(phases)` maps each debt phase id to the active, not-`done` phases whose `consolidates` names it. `next_phase_id()` is one above the highest number over active phases and archived ones (`archive_manifest.json` `phase_id`, else the `_P<N>_` in the folder name).
- **`rotate-backlog [--archive-only]`.** Every existing line and early return is untouched. `_print_docs_phase_proposal()` is called after the archive output, and on the `no done phases to rotate` and `no active phases to rotate` paths, unless `--archive-only`.
- **`docs-debt`.** One `  paid by: <P> (<status with spaces>)` line after each `pay:` line for each covering phase. Nothing else changed, and it stays read-only.

## Final printed key names (S2 writes from these)

These equal the D2 draft.

```
docs_phase=none
docs_phase_covered=<PX> (pays P26, P27)           # one line per covering phase, printed first
docs_phase_proposal=P26, P27, P28, P29
phase=P31
name=Consolidate the doc impact of P26–P29
objective=consolidate the '## Doc impact' notes from P26, P27, P28, P29 into new versions of architecture, decisions, operations, qa
create: <WORKFLOW_CMD> new-phase --phase P31 --name "…" --objective "…" --consolidates P26,P27,P28,P29
scope: <WORKFLOW_CMD> docs-debt
proposal only: nothing was created -- confirm the name and objective with the operator first (create-phase's docs-phase route)
```

Early-return choice: both early returns call the same function. `no active phases to rotate` therefore prints `docs_phase=none`, and `no done phases to rotate; …` prints the full block. Because the function runs on every non-`--archive-only` path, a normal rotate with no debt-only phase also gets one new `docs_phase=none` line (additive).

## Proposal output, from a `cp -R` scratch copy of this repo

The real repo was never rotated. The copy lives in the session scratchpad.

```
$ python3 scripts/workflow.py rotate-backlog
rotated 1 done phase(s) to archived:
- P25: works/phases/archived/20261007_155401_P25_research_a_replacement_for_claude_design_in_design-cowork
left 5 phase(s) active: P26, P27, P28, P29, P30
docs_phase_proposal=P26, P27, P28, P29
phase=P31
name=Consolidate the doc impact of P26–P29
objective=consolidate the '## Doc impact' notes from P26, P27, P28, P29 into new versions of architecture, decisions, operations, qa
create: python3 scripts/workflow.py new-phase --phase P31 --name "Consolidate the doc impact of P26–P29" --objective "consolidate the '## Doc impact' notes from P26, P27, P28, P29 into new versions of architecture, decisions, operations, qa" --consolidates P26,P27,P28,P29
scope: python3 scripts/workflow.py docs-debt
proposal only: nothing was created -- confirm the name and objective with the operator first (create-phase's docs-phase route)
```

Other scratch probes, all as designed:

- **Refusal.** `new-phase … --consolidates P30,P99,P25` printed `--consolidates refused, nothing was written: P30 (owes no doc consolidation: consolidation is None); P99 (not an active phase); P25 (not an active phase). …`, with rc=1 and the active set unchanged. `--consolidates ","` was refused with its own message.
- **Create and cover.** Running the exact printed command with a messy list (`"P26, P27,P28 ,P29,P26"`) stored four ids in order. The next `rotate-backlog` printed `no done phases to rotate; 6 phase(s) still active: …` then `docs_phase_covered=P31 (pays P26, P27, P28, P29)` and no proposal. `--archive-only` printed only the first line. `docs-debt` printed `  paid by: P31 (planned)` under each of P26–P29.
- **Partial cover.** With P31 covering only P26 and P27, the output was `docs_phase_covered=P31 (pays P26, P27)`, then a proposal for `P28, P29` named `…of P28–P29` with phase `P32`.
- **Parallel.** P28 given a parallel `execution` block with an unmerged branch left the proposal as `P29` only (never debt-only). Deleting that branch (counts as merged) put P28 back into the proposal.
- **No active phases.** After `archive-all --force` in the copy: `no active phases to rotate` then `docs_phase=none`, and with `--archive-only` only the first line. `next_phase_id()` gave P32, one above the highest archived phase, P31.

## Smoke

A new block sits beside the `docs-debt` fixture in `tests/retrofit_smoke.sh`, ahead of the v39 staleness assertions. It runs on `cp -R "$F/." "$ROT/"` (a `newtmp` copy, cleaned up by the suite's own trap), so the fixture's later assertions are untouched. It runs the printed `create:` line through `eval`, which proves that the line is copy-pasteable.

1. `rotate-backlog` prints `docs_phase_proposal=P2` and the `new-phase --phase <next> … --consolidates P2` line. P2 stays active and the proposed phase is not created.
2. After running that command, `rotate-backlog` prints `docs_phase_covered=<P> (pays P2)` and no `docs_phase_proposal=`.
3. `new-phase --consolidates P1` (owes nothing) refuses with `owes no doc consolidation` and the active set is unchanged.
4. `rotate-backlog --archive-only` prints no `docs_phase` line.

The suite ran once, alone in its own foreground call: 239 PASS / 0 FAIL. The installer was rebuilt before the run, because the suite installs from `bootstrap_agentic_workspace.sh`.

## Notes

- No file in the real repo was rotated, archived or created by the probes. `git status` shows only the intended edits plus the usual generated and notebook files.
- `phase.md` was updated in place: D1 and D2 carry the final choices, four `## Doc impact` lines were appended, the four consumed S1 notes were removed, an S2 note was added, and `## Now` was rewritten. The detail behind those lives here.
