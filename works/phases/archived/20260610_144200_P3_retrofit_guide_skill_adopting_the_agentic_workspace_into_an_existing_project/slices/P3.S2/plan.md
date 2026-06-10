# Plan

- Phase ID: P3
- Slice ID: P3.S2
- Slice: installer into-existing retrofit mode
- Created at: 2026-06-10T14:04:40+09:00

## Goal

Implement the `--into-existing` non-destructive retrofit mode in
`bootstrap_agentic_workspace.sh`, exactly to the spec in `docs/retrofit-guide.md`
and the four-tier model in `phase.md`. The fresh-install (no-flag) path must stay
byte-for-byte unchanged.

## Scope

- Shell: add `--into-existing` flag (usage, parse, `export INTO_EXISTING`).
- Python:
  - `RETROFIT` global + `RETROFIT_SUMMARY`; `INSTALL_DOCS` recomputed in guards.
  - Refactor `write_text` into `_atomic_write` + retrofit-aware `write_text`;
    add `_merge_settings_json`, `_merge_contract`, `_retrofit_handle`.
  - Guards: in retrofit, a **PLAN pass** — idempotent works-present no-op (exit 0)
    → foreign `scripts/workflow.py` abort (exit 1) → compute `INSTALL_DOCS`.
    Fresh guards unchanged in the `else`.
  - Centralize the docs-subsystem gate in `write_text` (skip `docs/*` writes when
    `not INSTALL_DOCS`) to avoid re-indenting the docs block.
  - Gate the final rebuild: `next` (works-only) when docs skipped, else
    `rebuild`+`validate`; print a retrofit summary; keep the fresh print block.
- README Options table: add the `--into-existing` row.
- Out of scope: the `retrofit` skill (S3), the committed smoke test (S4).
- **Do not** change `scripts/workflow.py` (avoids the workflow.py dual-apply surface).

## Milestones

1. Shell flag + Python retrofit policy (write/merge/guards/rebuild-gate/summary).
2. Fresh-install regression: empty dir → identical behavior, `validate` passes.
3. Retrofit E2E on a sample repo: non-destructive (sha256), merges, P1 seeded.
4. Edge cases: idempotent re-run (exit 0), workflow.py collision (abort, atomic),
   foreign docs/ (subsystem skipped).

## Validation

- `sh -n bootstrap_agentic_workspace.sh` (shell syntax); Python validated by running it.
- Fresh install into empty temp dir → exit 0, `validate` passes, P1 seeded.
- Retrofit into a sample repo with README/src/scripts/CLAUDE.md/.claude/settings.json →
  pre-existing files byte-identical (sha256), `git status` only additions + the 3
  intended merges, sidecars created, settings unioned (custom perm survives),
  `validate` passes, P1 = seeded name, git HEAD unchanged.
- Idempotent re-run → exit 0 no-op. workflow.py collision → exit 1, zero writes.
  Foreign docs/ → docs skipped, their index.json untouched, works installed.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None new in S2 (operations v0002 + decisions v0003 from S1 already cover the
  retrofit truth; S2 implements to that spec).
