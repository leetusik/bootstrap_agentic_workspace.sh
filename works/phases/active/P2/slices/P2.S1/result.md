# Result

- Phase ID: P2
- Slice ID: P2.S1
- Slice: Engine: rotate-backlog command + archive repositioning
- Review status: pending
- Next action: execute P2.S2 (skills)

## Outcome

Added the `rotate-backlog` command to the workflow engine and repositioned single-phase `archive-phase` as first-class — in both live `scripts/workflow.py` and its embedded twin in the bootstrap.

- New `rotate_backlog(args)` function (after `archive_all`): archives every phase with no `_phase_blockers` (all slices done + review `pass`), leaves the rest active, then `rebuild_index_and_state()`. Reuses `_phase_blockers` + `_archive_one` (no forked archive logic). No `--force` flag — by definition it only touches cleanly-archivable phases.
- New `rotate-backlog` argparse subparser (after `archive-all`).
- Reworded the `archive-phase` subparser help ("Archive a single review-passed phase (first-class; use when only some phases are done)") and the `archive_phase` comment (first-class single-phase archive; rotate-backlog for the partial sweep, archive-all for the full sweep, `--force` = exceptional cleanup only).
- Synced the embedded `WORKFLOW_PY` heredoc (bootstrap) from the updated live file; re-diff confirms byte-identical (39707 chars each).

## Deviations from Plan

- Also added a top-level `.gitignore` (`__pycache__/`, `*.pyc`). Out of the engine scope strictly, but running `scripts/workflow.py` (and my compile check) generates bytecode that would otherwise show as untracked noise. Live-repo hygiene only; not a workflow rule/skill/tooling change, so not mirrored into the bootstrap.

## Validation Run

- `python3 -c "import py_compile; py_compile.compile('scripts/workflow.py', doraise=True)"` — compiles.
- `python3 scripts/workflow.py rotate-backlog --help` — subcommand parses; appears in top-level help.
- Embedded-vs-live diff script — IDENTICAL (39707 chars).
- **Full bootstrap integration test** into a temp dir — exit 0 (its internal `rebuild`+`validate` passed); generated `scripts/workflow.py` byte-identical to live; `rotate-backlog` in the fresh workspace printed "no done phases to rotate; 1 phase(s) still active: P1".
- **Positive-path test** in the temp workspace — made P1 done+pass, added an in-progress P2, then `rotate-backlog` archived P1 only and left P2 active; `validate` passed afterward.
- `python3 scripts/workflow.py validate` (real repo) — passed; P1/P2 active tree untouched.

## Files Changed

- `scripts/workflow.py` — `rotate_backlog` function + subparser; archive-phase repositioning.
- `bootstrap_agentic_workspace.sh` — embedded `WORKFLOW_PY` synced from live.
- `.gitignore` — new (Python bytecode).
- `works/phases/active/P2/slices/P2.S1/{plan,result}.md`.

## Doc Versions Created

- None (decision doc is P2.S4).

## Roadmap Updates

- None.

## Retrospective

- Syncing the embedded engine by **regenerating the heredoc body from the live file** (string-slice between `WORKFLOW_PY = r'''` and the next `'''`) is more reliable than hand-editing both copies; it guarantees byte-identity. Precondition: live `workflow.py` must contain no `'''` (asserted in the sync). Later engine slices should reuse this method, then re-diff.
- The temp-dir bootstrap run is the strongest verification available and is non-destructive to the real repo — worth repeating in REVIEW after all slices land.
