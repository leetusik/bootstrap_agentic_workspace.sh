# Plan — P18.S2: engine — notebook budget warning, Doc-impact case check, drop dashboard `Rebuilt at`

## Goal

Three small, independent engine guardrails in `scripts/workflow.py`, each covered by a terse smoke assert. Nothing here changes the notebook's shape (S1 shipped that) and nothing here is ever an **error** — `intent.md` clarification 4 and the phase's Decisions are explicit: warnings only.

Read `phase.md` first — the `## Notes for later slices` entries tagged **for S2** describe exactly where `finish_slice` now stands and where the case-drift literals are.

## Changes

### 1. `PHASE_MD_BUDGET` warning + `finish-slice` size print

- Add `PHASE_MD_BUDGET = (200, 16 * 1024)` beside the other module constants (`SLICE_KINDS`, `PHASE_STATUSES`, …), with a one-line comment: lines and bytes, both measured, warn on either.
- A small helper, e.g. `phase_md_size(pdir) -> (lines, bytes)`, used by both callers.
- `validate()`: for each active phase whose `phase.md` exists, if `lines > 200 or bytes > 16 KB` → `warnings.append(f"phase {id}: phase.md is {lines} lines / {bytes} bytes, over the notebook budget of {200} lines / {16 KB}; rewrite it under budget (state to phase.md, detail to the slice's result.md)")`. Warnings only (`validate` already keeps a separate `warnings` list, prints it, and exits 0).
- `finish_slice`: after the existing `print(f"finished …")`, print `phase.md: <lines> lines / <bytes> bytes (budget 200 / 16384)` — and append ` — OVER BUDGET` when exceeded. Do not change the `--outcome` behaviour S1 added.

### 2. `## Doc Impact` case-drift warning + the two literals

- `validate()`: if a phase's `phase.md` contains a heading line matching `^## Doc Impact\b` (capital I) → warning naming the phase and the canonical `## Doc impact`. Keep it a heading-line check (`^## `), not a substring search — the prose legitimately quotes both spellings.
- Fix the two `workflow.py` literals: the `parallel-merge-finish` hint print (`section '## Doc Impact'` → `'## Doc impact'`) and the docstring below it. The third site (`.claude/skills/parallel-phase/SKILL.md`) is **S3's** — leave it.

### 3. Drop `- Rebuilt at:` from the two markdown dashboards

- `rebuild_backlog`: remove the `- Rebuilt at:` line from `## Pointer`.
- `rebuild_deferred_dashboard`: remove the `- Rebuilt at:` line from `## Summary`. Its `rebuilt_at` parameter then has no reader — remove the parameter and its two call sites' argument (`rebuild_index_and_state`, `cmd_deferred`) rather than keeping dead plumbing; check `grep -n rebuild_deferred_dashboard` for every caller first.
- **Scope stops here:** `index.json.last_rebuilt_at` and `state.json.updated_at` stay (operator-confirmed).

### 4. Smoke (one Test block, ≈5 asserts, in `tests/retrofit_smoke.sh` on the temp workspace the suite already builds)

`validate` on a phase whose `phase.md` is padded past 200 lines prints `over the notebook budget` and exits 0; a `## Doc Impact` heading makes `validate` warn and exit 0; `finish-slice` output contains `phase.md:` and `budget`; `works/backlog.md` and `works/deferred.md` contain no `Rebuilt at` after `rebuild`; two consecutive `next` calls leave `git status --short` on `works/backlog.md` and `works/deferred.md` empty **when nothing else changed** (that is the churn this fixes — assert on the temp repo, where the suite controls the tree).

### 5. Rebuild the installer

`python3 installer/build.py`, then `--check` green. Commit is the orchestrator's.

## Validate

- `python3 scripts/workflow.py validate` — clean (this repo's P18 notebook is under budget today; report its numbers)
- `bash tests/retrofit_smoke.sh` — all PASS (was 131; report the count)
- `python3 installer/build.py --check` — pass
- `git status --short` after two `python3 scripts/workflow.py next` calls in this repo — `works/backlog.md` and `works/deferred.md` not listed

## result.md and phase.md

Verdict block first in `result.md`. In `phase.md`: consume the two S2 notes you acted on (remove them), add a `## Decisions` line if you decided anything durable (e.g. the removed `rebuilt_at` parameter), append the `## Doc impact` line (`operations.md`: budget warning + size print, case-drift warning, dashboards no longer carry a timestamp), rewrite `## Now` for S3.
