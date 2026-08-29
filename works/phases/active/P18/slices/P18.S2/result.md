# Result — P18.S2: engine — notebook budget warning, `## Doc Impact` case check, drop dashboard `Rebuilt at`

## Verdict

- **status:** done
- **summary:** Three independent guardrails landed in `scripts/workflow.py`, all warnings and no errors: `validate` flags an over-budget `phase.md` (200 lines / 16 KB) and a case-drifted `## Doc Impact` heading, `finish-slice` prints the notebook's current size, the two `## Doc Impact` literals are corrected, and `- Rebuilt at:` is gone from `works/backlog.md` / `works/deferred.md` — so repeated `next` calls no longer dirty the tree. Covered by Test 10 (137 PASS, was 131) and the installer is rebuilt.
- **files_changed:** `scripts/workflow.py`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/backlog.md` + `works/deferred.md` (regenerated without the timestamp), `works/phases/active/P18/phase.md`, `works/phases/active/P18/slices/P18.S2/result.md`
- **validation:** `validate` pass (clean, exit 0) · `bash tests/retrofit_smoke.sh` → **137 PASS / 0 FAIL** · `installer/build.py --check` pass · two `next` calls leave both dashboards byte-identical
- **deviations:** two, both small and recorded in `phase.md` `## Decisions` (the `done`-phase skip; `cmd_deferred` was not a second call site) — see below
- **doc_impact:** one line appended to `phase.md` → `operations.md`: budget warning + `finish-slice` size print, `## Doc Impact` case-drift warning, dashboards no longer carry a timestamp

## What shipped

1. **`PHASE_MD_BUDGET = (200, 16 * 1024)`** beside `SLICE_KINDS`, with `phase_md_size(pdir) -> (lines, bytes)` next to the other notebook helpers — one measurement shared by both callers, so `validate` and `finish-slice` can never disagree about "over budget". `(0, 0)` when the file is absent.
2. **`validate()`**, inside the per-phase loop, two warnings appended to the existing `warnings` list (printed first, exit stays 0):
   - over budget → `phase <id>: phase.md is <n> lines / <n> bytes, over the notebook budget of 200 lines / 16384 bytes; rewrite it under budget (state to phase.md, detail to the slice's result.md)`;
   - `re.match(r"## Doc Impact\b", ln)` over the notebook's **lines** (not a substring search — this very notebook quotes both spellings in prose, and does so today without tripping the check).
3. **`finish-slice`** prints, after `finished <id>`, `phase.md: <lines> lines / <bytes> bytes (budget 200 / 16384)`, with ` — OVER BUDGET` appended when either limit is exceeded. Skipped when the phase has no `phase.md`. S1's `--outcome` behaviour is untouched.
4. **The two case-drifted literals** in `workflow.py` (the `parallel-merge-finish` hint print and `parallel_consolidated`'s docstring) now read `## Doc impact`. The third site, `.claude/skills/parallel-phase/SKILL.md`, is left for S3 — noted in `phase.md`.
5. **`- Rebuilt at:` removed** from `rebuild_backlog`'s `## Pointer` and `rebuild_deferred_dashboard`'s `## Summary`; the latter's now-readerless `rebuilt_at` parameter removed with it. `index.json.last_rebuilt_at` and `state.json.updated_at` stay, as scoped.
6. **Test 10** (6 asserts, one block, on the fresh workspace the suite already builds): warnings at exit 0, the budget warning, the case-drift warning, the `finish-slice` size print with its over-budget flag, no `Rebuilt at` in either dashboard, and — the churn this removes — two `next` calls in a throwaway git repo leaving `git status --short` empty for both dashboards (the assert also checks both files are actually tracked, so it cannot pass vacuously).

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | `Workflow validation passed.` — **clean**, exit 0, no warnings |
| `bash tests/retrofit_smoke.sh` | `ALL RETROFIT SMOKE TESTS PASSED` — **137 PASS, 0 FAIL** (was 131; +6 Test 10) |
| `python3 installer/build.py` → `--check` | `wrote bootstrap_agentic_workspace.sh (412894 bytes)` → `OK: in sync` |
| `python3 -m py_compile scripts/workflow.py` | pass |
| two `python3 scripts/workflow.py next` calls (this repo) | `works/backlog.md` + `works/deferred.md` byte-identical before and after (sha256 compared) |

On `git status --short` both dashboards *are* listed against `HEAD` — that is the one-time content change of this slice (the `- Rebuilt at:` line leaving), not churn; from the new baseline forward `next` adds nothing. Also confirmed: `next` leaves `docs/index.json` untouched, while `rebuild` still rewrites its `last_rebuilt_at` — machine-read and deliberately out of scope.

Notebook size after this slice's edits: **80 lines / 13016 bytes** (79 / 11991 after S1). Recorded in `phase.md` for the review; the two numbers together say lines are cheap and bytes are the binding limit.

## Deviations from plan.md

1. **The budget warning skips a `done` phase.** The plan asked for "each active phase whose `phase.md` exists" *and* for `validate` to come back clean — mutually exclusive here, because pre-v35 `P17` is `done`-but-unarchived at 446 lines / 32850 bytes and would warn on every run, including in the middle of P18's own review. A closed notebook cannot act on "rewrite it under budget", so the check now bites for every status through `in_review` and stops at `done`. Rationale recorded in `phase.md` `## Decisions`; P17's numbers are kept there as the pre-v35 data point.
2. **`cmd_deferred` was not a second call site.** The plan (following a DECOMP note) expected two callers of `rebuild_deferred_dashboard`; `grep` found one — `rebuild_index_and_state`. `cmd_deferred` reaches the dashboard *through* that call, so removing the parameter touched exactly one line. The corrected fact replaced the wrong one in `phase.md` `## Decisions`.

Nothing else departed from the plan. Durable cross-slice material (both decisions, the S3 note about the remaining skill literal, the measured budget calibration, the refreshed smoke baseline) is in [`phase.md`](../../phase.md) and is not repeated here.
