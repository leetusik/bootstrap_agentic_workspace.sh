# Result

- Phase ID: P3
- Slice ID: P3.S4
- Slice: end-to-end verification and smoke test
- Review status: pending
- Next action: P3.REVIEW (phase review)

## Outcome

Added `tests/retrofit_smoke.sh`, a committed, repeatable, self-cleaning E2E test
for the retrofit. `tests/` is outside the managed namespace, so it never installs
into an adopter's repo. All 31 checks pass (exit 0):

- **Test 1 — non-destructive retrofit** into a sample repo (git history, README,
  src/app.py, scripts/util.py, custom CLAUDE.md/AGENTS.md, .claude/settings.json
  with `Bash(make:*)` + `env`): exit 0; README/app.py/util.py **byte-identical**
  (sha256); git HEAD unchanged; only `.claude/settings.json`+`CLAUDE.md`+`AGENTS.md`
  modified (rest are additions); contract preserved + sidecar + exactly one marker;
  settings additively merged (custom perm + `env` survive); `validate` passes; P1
  seeded from state (not the "Bootstrap Intake" placeholder).
- **Test 2 — idempotent re-run:** exit 0, "nothing to retrofit", marker not duplicated.
- **Test 3 — foreign `scripts/workflow.py`:** aborts (exit 1), **zero files written**
  (atomic), foreign file intact.
- **Test 4 — pre-existing `docs/`:** docs subsystem skipped, their `docs/index.json`
  untouched, no doc files scattered, no `docs/current/`, works still installed.
- **Test 5 — fresh-install regression:** no-flag path still exits 0, validates, and
  now ships the `retrofit` skill (the only intended delta).
- **Test 6 — dual-apply:** live `scripts/workflow.py` == bootstrap-embedded
  `WORKFLOW_PY`; all three live `retrofit` skill files == `COMMAND_SKILLS` output.

## Deviations from Plan

- None. No CI was wired because the repo has no `.github/`; the test is runnable
  via `bash tests/retrofit_smoke.sh` and can be added to CI later.

## Validation Run

- `bash tests/retrofit_smoke.sh` → "ALL RETROFIT SMOKE TESTS PASSED", exit 0 (31/31).
- `python3 scripts/workflow.py validate` (this repo) → "Workflow validation passed."

## Files Changed

- `tests/retrofit_smoke.sh` (new, executable)

## Doc Versions Created

- None (operations v0002 / decisions v0003 from S1 already capture the retrofit truth).

## Roadmap Updates

- All four middle slices complete. Next: P3.REVIEW.

## Retrospective

- The dual-apply assertion (Test 6) is the highest-leverage check: it would have
  caught a future skill or `workflow.py` edit that updated only one of the two
  copies — the exact failure mode P2 flagged. Diffing the live repo against a
  freshly-generated install makes "are the embedded and live copies in sync?" a
  one-command answer.
