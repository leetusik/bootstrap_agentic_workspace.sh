# Plan

- Phase ID: P3
- Slice ID: P3.S4
- Slice: end-to-end verification and smoke test
- Created at: 2026-06-10T14:04:40+09:00

## Goal

Deliver the phase's verification: a committed, repeatable smoke test that proves
the retrofit works on a representative existing repo and is non-destructive, and
that locks the dual-apply invariant against future drift.

## Scope

- `tests/retrofit_smoke.sh` — a **non-managed** path (tests/ is not in
  `MANAGED_*`, so it never installs into adopter repos). Builds throwaway sample
  repos under `$TMPDIR`, runs the retrofit, asserts, and self-cleans.
- Assertions: non-destructive (sha256 before/after), git HEAD unchanged,
  only-intended modifications, contract preserved + sidecar + single marker,
  additive settings merge (custom perm + unrelated key survive), validate,
  P1 seeded-from-state (not the placeholder), idempotent re-run (exit 0, no marker
  dup), foreign `workflow.py` atomic abort, foreign-docs subsystem gate,
  fresh-install regression (+ ships the retrofit skill), and **dual-apply**
  (live `scripts/workflow.py` == embedded `WORKFLOW_PY`; live retrofit skill files
  == `COMMAND_SKILLS` output).
- Out of scope: a CI workflow (no `.github/` present); the test is runnable via
  `bash tests/retrofit_smoke.sh` and can be wired into CI later.

## Milestones

1. Write `tests/retrofit_smoke.sh`; `chmod +x`.
2. Run it green end-to-end.
3. Record results; finish + commit.

## Validation

- `bash tests/retrofit_smoke.sh` → every check PASS, exit 0.
- `python3 scripts/workflow.py validate` (this repo) → passes.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None (the QA harness is the deliverable; the retrofit truth is already in
  operations v0002 / decisions v0003).
