# Plan — P15.S6: Ship the removal as workspace v31 with a CHANGELOG entry

The release slice. Two files — `installer/main.py` (one constant) and `CHANGELOG.md` (one
appended section) — plus the rebuilt artifact.

Read `works/phases/active/P15/phase.md` and every slice's `result.md` before writing the entry.
The CHANGELOG is what adopters actually read to decide whether to update, so it has to describe
the whole phase accurately, not just the last slice.

## 1. `installer/main.py` — `WORKSPACE_VERSION = 30` → `31`

It sits at ~L38. That is the entire code change.

## 2. `CHANGELOG.md` — append a `## v31` section

Newest-first, so it goes directly below the preamble and above `## v30 — 2026-08-13`. Date it
**2026-08-14**. Match the existing house style exactly: a handful of bullets each opening with a
**bolded claim sentence** and then the substance, closing with a **Migration notes:** line.

Headings must stay strictly descending and unique — `tests/retrofit_smoke.sh` asserts that.

Cover, drawn from the slice results:

- **Codex support is removed; the workspace ships Claude Code only.** `.agents/` (34 files),
  `.codex/` (3 files), and `AGENTS.md` are gone. `CLAUDE.md` is the single routing contract —
  the `AGENTS.md` equivalence header and the build's byte-equality assertion went with it.
- **The engine is single-harness.** Executor presets carry one model/effort pair per tier
  (`economy` = sonnet@high / opus@high, `flex` = sonnet@xhigh / opus@xhigh); `executors.toml`
  accepts `[claude.<tier>]` only, and a leftover `[codex.*]` table is a hard error naming this
  release rather than a generic parse failure.
- **Retrofit is less invasive than before.** The installer no longer writes, merges, or touches
  a repo's own `AGENTS.md` on any path, and writes no `AGENTS.workspace.md` sidecar. An
  `AGENTS.md` a project maintains for other tools is left byte-identical.
- **`--update` flags the retired machinery instead of deleting it** — `.agents`, `.codex`,
  `AGENTS.md`, and the orphaned `AGENTS.workspace.md` each appear once in the stale line and
  survive the update; removal stays the operator's call.
- **Docs and tests match the code.** Passages that documented behaviour this release changed
  were corrected against the source, not just stripped — the retrofit guide's contract-merge
  promise and manual-fallback steps, and `installer/README.md`'s build-check list. The lifecycle
  smoke test now asserts Codex's *absence* as regressions (no `.agents/`/`.codex/` installed, no
  `AGENTS.md` in a fresh workspace, a repo's own `AGENTS.md` sha-pinned across a retrofit) and
  covers the stale-flagging mechanism itself.

**Migration notes** — the adopter-facing half. Preview with `--update --dry-run`. The update
flags `.agents`, `.codex`, `AGENTS.md`, and `AGENTS.workspace.md` as stale machinery and never
deletes them, so remove them by hand; an `AGENTS.md` your project maintains for other tools is
yours to keep. Drop any `[codex.*]` table from `executors.toml` — `sync-agents` now rejects it —
then re-run `sync-agents` to re-apply your preserved mode and overrides. Phases, docs, and the
seed-once `executors.toml` are preserved as always.

`docs/retrofit-guide.md` already carries an adopter-procedural version of this (S5 added it).
**Do not duplicate it verbatim** — the CHANGELOG states what the release changes and the minimum
steps; the guide walks the procedure. Point at the guide rather than repeating it.

## Consistency check

`v31` is now pinned in prose in three places, all of which already say 31 and none of which need
editing — they are stated here only so you can confirm they agree with the bump:
`scripts/workflow.py`'s rejection message, `.claude/skills/update-workspace/SKILL.md` step 8, and
`docs/retrofit-guide.md`'s migration paragraph. Plus the four `# Codex support dropped in v31`
comments on the `OBSOLETE_MACHINERY` entries in `installer/main.py`.

**The smoke test needs no edit.** S4 dropped the literal `== 30`, so the release block now
asserts only `main_version == top_changelog == marker_version`. Bumping the constant and adding
the heading satisfies it automatically once the artifact is rebuilt — `marker_version` is read
from a fresh install, so a stale artifact is exactly what that equality catches.

## Out of scope

Do not rewrite any existing CHANGELOG section — v29 and v30 are Codex-heavy releases and stay as
written history. Do not touch `tests/`, `docs/versions/**`, or `docs/current/**`.

## Validation

- `python3 installer/build.py`, then `--check` — both pass. `installer/main.py` is embedded, so
  the regenerated artifact must be left for the orchestrator to stage in the same commit.
- **Run the artifact** (the standing rule): fresh-install into a temp dir under the scratchpad
  and confirm `works/.workspace-version.json` reports `31`.
- `bash tests/retrofit_smoke.sh` — green, 115 PASS / 0 FAIL. The release block is the one that
  proves the three-way version agreement; confirm it passes rather than assuming.
- `python3 scripts/workflow.py validate` passes.
- Confirm exactly one `## v31` heading, dated 2026-08-14, directly above `## v30`, and that the
  headings remain strictly descending.

## Notes for `phase.md`

Record the release version and date, and confirm the three v31 prose pins agree with the bumped
constant.
