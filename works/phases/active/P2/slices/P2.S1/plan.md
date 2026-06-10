# Plan

- Phase ID: P2
- Slice ID: P2.S1
- Slice: Engine: rotate-backlog command + archive repositioning
- Created at: 2026-06-10T12:51:40+09:00

## Goal

Add a `rotate-backlog` command to the workflow engine and reposition single-phase `archive-phase` from "escape hatch" to a first-class option — in BOTH live `scripts/workflow.py` and its byte-identical embedded twin (`WORKFLOW_PY` heredoc in the bootstrap).

## Scope

- In scope (per the embed-site map + rotate-backlog spec in `phase.md`):
  - Add a `rotate_backlog(args)` function after `archive_all`, reusing `_phase_blockers` + `_archive_one`; archive every currently-done phase, leave the rest active, then `rebuild_index_and_state()`. No `--force`.
  - Add a `rotate-backlog` argparse subparser after the `archive-all` subparser.
  - Reword the `archive-phase` subparser help and the `archive_phase` comment to first-class framing (single-phase archive for when only some phases are done; force = exceptional cleanup only).
  - Sync the embedded `WORKFLOW_PY` block in `bootstrap_agentic_workspace.sh` from the updated live file so they stay byte-identical.
- Out of scope: skill files, CLAUDE.md/AGENTS.md, decisions doc (later slices).

## Milestones

1. Edit live `scripts/workflow.py`: reword archive-phase help+comment; add `rotate_backlog` + subparser.
2. Regenerate the embedded `WORKFLOW_PY` heredoc in the bootstrap from the updated live file.
3. Verify: embedded == live (re-diff); `rotate-backlog --help` parses; `validate` passes. Do NOT run a real rotate (would archive P1).

## Validation

- `python3 scripts/workflow.py rotate-backlog --help` — subcommand parses (non-destructive).
- Embedded-vs-live diff script reports IDENTICAL.
- `python3 -c "import py_compile; py_compile.compile('scripts/workflow.py', doraise=True)"` — compiles.
- `python3 scripts/workflow.py validate` — passes.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None in this slice (engine only). Decision doc is P2.S4.
