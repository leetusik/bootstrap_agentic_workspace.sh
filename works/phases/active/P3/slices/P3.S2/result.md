# Result

- Phase ID: P3
- Slice ID: P3.S2
- Slice: installer into-existing retrofit mode
- Review status: pending
- Next action: execute P3.S3 (retrofit skill, dual-applied)

## Outcome

Implemented the `--into-existing` non-destructive retrofit mode in
`bootstrap_agentic_workspace.sh`, gated strictly behind the flag; the
fresh-install path is unchanged.

- **Shell:** new `--into-existing` flag (usage line, arg parse, `export INTO_EXISTING`).
- **Write policy:** factored the atomic writer into `_atomic_write`; `write_text`
  is now retrofit-aware — skip-if-exists for content, plus a centralized docs gate
  (skip `docs/*` writes when `not INSTALL_DOCS`). Added `_merge_settings_json`
  (union `permissions.allow`/`deny`, preserve all other keys; sidecar on
  unparseable), `_merge_contract` (keep theirs + marked block + `*.workspace.md`
  sidecar, idempotent), and `_retrofit_handle` (dispatch skip/merge).
- **Guards (PLAN pass):** in retrofit — (1) works-present → **exit 0 clean no-op**
  (idempotent; checked first so a re-run that sees our own workflow.py doesn't
  abort), (2) foreign `scripts/workflow.py` → **exit 1 abort before any write**,
  (3) compute `INSTALL_DOCS` (skip docs subsystem if the target already has a
  docs system). Fresh guards unchanged in the `else`.
- **Final step:** gated — `next` (works-only rebuild) when docs are skipped, else
  `rebuild`+`validate` as before; prints a created/skipped/merged + subsystem
  summary. Fresh print block preserved.
- **README:** added the `--into-existing` row to the Options table.
- **`scripts/workflow.py` left untouched** — no workflow.py dual-apply surface.

## Deviations from Plan

- One correction during testing: the first idempotency attempt aborted (exit 1)
  because the re-run hit the foreign-`workflow.py` guard (we'd installed it on run
  1). Fixed by ordering the works-present no-op **before** the workflow.py guard,
  so an already-adopted repo exits 0. Updated the guide's "Re-running is safe"
  wording to match (detect + exit cleanly, not "re-apply merges").

## Validation Run

- `sh -n bootstrap_agentic_workspace.sh` → OK. Python validated by execution.
- **Fresh install** into empty temp dir → exit 0, `validate` passed, all dirs +
  P1 seeded; fresh print block intact (regression clean).
- **Retrofit** into a sample repo (git history, README, src/app.py,
  scripts/util.py, custom CLAUDE.md, .claude/settings.json with `Bash(make:*)` +
  `env`): exit 0; created 74 / skipped 0 / merged CLAUDE.md+AGENTS.md+settings.json;
  README/app.py/util.py **byte-identical** (sha256); `git status` = only `??`
  additions + `M` on the 3 merge files; `CLAUDE.workspace.md`/`AGENTS.workspace.md`
  sidecars (6940B) created; settings unioned with `Bash(make:*)` and `env` preserved;
  `validate` passed; **git HEAD unchanged**; P1 name = the seeded value.
- **Idempotent re-run** → exit 0 "nothing to retrofit" no-op; marker block count 1;
  `make` perm count 1.
- **workflow.py collision** → exit 1, **zero files written** (atomic), foreign file
  intact.
- **Foreign docs/** → docs subsystem skipped, their `docs/index.json` untouched, no
  `v0001_bootstrap.md` scattered, no `docs/current/`, works + workflow.py installed,
  P1 seeded.

## Files Changed

- `bootstrap_agentic_workspace.sh` (flag, write policy, guards, rebuild-gate, summary)
- `README.md` (Options table row)
- `docs/retrofit-guide.md` (idempotency wording aligned to impl)
- generated: works dashboards updated by slice lifecycle

## Doc Versions Created

- None (covered by S1's operations v0002 + decisions v0003).

## Roadmap Updates

- Next: P3.S3 (retrofit skill), which orchestrates this installer mode.

## Retrospective

- The non-obvious correctness point that testing surfaced: idempotency and the
  "abort on foreign workflow.py" guard collide on a second run, because our own
  installed workflow.py looks like a collision. Ordering the works-present no-op
  first resolves it cleanly. The two-pass PLAN/APPLY made the atomic-abort
  guarantee real (the workflow.py-collision test wrote zero files).
