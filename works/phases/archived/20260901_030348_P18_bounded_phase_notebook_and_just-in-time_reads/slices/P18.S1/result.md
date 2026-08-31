# Result — P18.S1: engine — phase.md template, generated `## Slices` block, `finish-slice --outcome`

## Verdict

- **status:** done
- **summary:** The phase notebook now has a shape the engine owns: `new-phase` seeds it from `works/templates/phase.md` (with a byte-identical embedded fallback), `rebuild` regenerates the `## Slices` table between the two markers in every active notebook that has them, and `finish-slice --outcome "one line"` fills that table's Outcome cell. Registered in all four installer/test points, covered by a new smoke test (131 PASS, was 123), and P18's own notebook is migrated to the new shape.
- **files_changed:** `works/templates/phase.md` (new), `scripts/workflow.py`, `installer/build.py`, `installer/main.py`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P18/phase.md` (migrated), `works/phases/active/P18/slices/P18.S1/result.md`
- **validation:** `validate` pass · `rebuild` ×2 → notebook unchanged on the second run · `bash tests/retrofit_smoke.sh` → 131 PASS / 0 FAIL · `installer/build.py --check` pass · `ast.parse(workflow.py)` pass
- **deviations:** one, hardening the marker match to own-line only (see below)
- **doc_impact:** one line appended to `phase.md` → `operations.md`: template seed + generated `## Slices` block + `finish-slice --outcome`

## What shipped

1. **`works/templates/phase.md`** — the operator-confirmed section set: `## Objective`, `## Slices` (marker block), `## Decisions`, `## Doc impact`, `## Operator Questions`, `## Notes for later slices`, `## Now`. `## Context` / `## Findings & Notes` / `## Constraints` / `## Open Questions` are gone from the seed.
2. **`scripts/workflow.py`**
   - `PHASE_MD_TEMPLATE_FALLBACK` + `phase_md_template()`: the file when present, the embedded copy otherwise (an adopter on a pre-v35 tree still gets a correct notebook). Smoke asserts the two are byte-identical.
   - `new_phase` writes the seed through `render_template(...)`; the `rebuild_index_and_state()` it already calls at the end fills the block immediately, so a fresh phase's table is populated on creation (verified).
   - `render_slices_block(pdir, phase)` / `refresh_phase_md_slices(pdir, phase)`, called once per **active** phase at the end of `rebuild_index_and_state`. Columns `| Slice | Name | Kind / risk | Status | Outcome | Result |`, rows in `order`, cells through `clean_cell`, `Result` linking `slices/<id>/result.md` when the file exists, em dash otherwise. Read → splice → compare → write **only on change**; no markers → return untouched; `phase.md` deliberately stays out of `GENERATED_FILES`.
   - `finish_slice` gained `--outcome`: stored in `slice.json` **before** the status change (the rebuild that `set_slice_status` triggers then renders the row in the same command), warning + exit 0 when omitted. `create_slice` seeds `"outcome": None` so the field is visible in new slice files.
3. **Registration** — `FIXED_LIVE_FILES` (`installer/build.py`), `MANAGED_FILES` (`installer/main.py`), the emitted fresh-install writer (`installer/main.py`, comment updated), `DUAL_FIXED` (`tests/retrofit_smoke.sh`).
4. **Test 9** (7 asserts, one block): template seed shape, block filled at creation, `--outcome` reaching the row, the omitted-`--outcome` warning at exit 0, no rewrite of an unchanged notebook, byte-identical marker-less notebook, fallback-vs-template equality.
5. **P18's own `phase.md`** migrated in place, keeping every recorded line: `## Decomposition` kept below `## Slices`; F1–F13/N1–N6 split into `## Decisions` and `## Notes for later slices` (each tagged); N1 consumed and dropped (its content is §2 above); N2 rewritten for S2 against what `finish_slice` now looks like; `## Now` added last.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | `Workflow validation passed.` |
| `python3 scripts/workflow.py rebuild` ×2 + `diff` | second run leaves `P18/phase.md` byte-identical (change-only write confirmed) |
| `bash tests/retrofit_smoke.sh` | `ALL RETROFIT SMOKE TESTS PASSED` — **131 PASS, 0 FAIL** (was 123: +7 Test 9, +1 dual-apply of the new template) |
| `python3 installer/build.py` → `--check` | `wrote bootstrap_agentic_workspace.sh (410448 bytes)` → `OK: in sync` |
| `python3 -c "import ast;ast.parse(...)"` | pass |
| manual: retrofit into a throwaway git repo | installs `works/templates/phase.md`; `new-phase` renders the table; `validate` passes |
| manual: template deleted, then `new-phase` | fallback seed renders identically; `finish-slice` without `--outcome` warns and exits 0 |

`git status --short` still shows `works/backlog.md`, `works/deferred.md`, `works/index.json`, `works/state.json` and `docs/index.json` dirty after a second `rebuild` — that is the pre-existing timestamp churn S2 removes for the two markdown dashboards, not the notebook.

## Deviation from plan.md

**Markers must be alone on their line.** The plan specified a plain "splice between `<!-- slices:begin -->` and `<!-- slices:end -->`". The first implementation did exactly that and corrupted P18's own notebook on the first `rebuild`: the `## Decomposition` table's S1 row *quotes* both literals in prose, so `str.find` matched inside a table cell and the generated table landed there. Fixed by matching lines whose `strip()` equals the marker (revert + re-splice verified). A notebook, a plan, or a skill may now discuss the markers freely — which this repo's own phase.md does, making it a live regression case.

Two additions inside the plan's intent, both noted above: `create_slice` seeds `"outcome": None`, and Test 9 asserts fallback-vs-template byte equality (a duplicated string is a real drift risk).

## Budget calibration (for the review)

`works/phases/active/P18/phase.md` after migration: **79 lines / 11,891 bytes**, of which the generated block is 11 lines. Against S2's `PHASE_MD_BUDGET = (200, 16 * 1024)` that is 40 % of the line half but **72 % of the byte half**, before S2–S5 append anything — with this repo's long-line prose the byte half binds first, and will likely warn before the phase ends. Data point, not a request to change the constant.

## Cross-slice notes

Everything later slices need is in [`phase.md`](../../phase.md) — `## Decisions` (marker rule, change-only write, registration points), `## Notes for later slices` (tagged for S2/S3/S4/S5) and `## Now`. Not repeated here.
