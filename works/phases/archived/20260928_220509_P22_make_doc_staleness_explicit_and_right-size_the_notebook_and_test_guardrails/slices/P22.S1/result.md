# Result — P22.S1: relax the notebook budget and sharpen keep-tests-small (D15+D16)

- **status:** done
- **summary:** D15 and D16 shipped together: `PHASE_MD_BUDGET` is now one soft byte cap of 400 KB (~100k tokens, warning-only, line ceiling dropped) across the engine and all six prose restatements, `CLAUDE.md`'s keep-tests-small rule is now core-only, the smoke probes were reshaped around a generated >400 KB fixture, and `WORKSPACE_VERSION` moved to 39 with a `## v39` CHANGELOG section opened for S2.
- **files_changed:**
  - `scripts/workflow.py` (constant, `phase_md_size()` docstring, `validate` warning, `finish-slice` print)
  - `CLAUDE.md` (D15 notebook line, D16 keep-tests-small rule)
  - `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md` (step 4 budget sentence, byte-identical bodies preserved)
  - `.claude/skills/design-cowork/SKILL.md` (two budget restatements)
  - `tests/retrofit_smoke.sh` (two doctrine literals, Test 10 fixture + `finish-slice` grep)
  - `installer/main.py` (`WORKSPACE_VERSION` 38 → 39)
  - `CHANGELOG.md` (new `## v39 — 2026-09-02` section: D15 + D16 bullets + Migration notes; lead "Why this release" bullet deliberately left to S2)
  - `bootstrap_agentic_workspace.sh` (rebuilt by `installer/build.py`)
  - `works/phases/active/P22/phase.md` (notebook edit), this `result.md`
- **validation:**
  - `python3 scripts/workflow.py validate` — PASS (exit 0; only the inherited `consolidation_owed=P21` and `oversized_doc_sections=5` warnings)
  - `bash tests/retrofit_smoke.sh` — PASS (exit 0, 152 PASS lines, `ALL RETROFIT SMOKE TESTS PASSED`)
  - `python3 installer/build.py` then `python3 installer/build.py --check` — PASS (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`)
  - `python3 scripts/workflow.py sync-agents --check` — PASS (agent files still in sync; body edits touch no frontmatter)
- **deviations:** one, additive only — a third `## Doc impact` line for `decisions.md` beyond the `operations.md` + `qa.md` the plan expected (see *Doc impact* below).
- **doc_impact:** three one-line notes appended to `phase.md` (`operations.md`, `qa.md`, `decisions.md`). No `doc-new-version` was run.

## What landed

### D15 — one soft byte cap

`scripts/workflow.py:63` is now:

```python
PHASE_MD_BUDGET = 400 * 1024
```

a bare int, not a pair. The three consumers were updated to match:

- `phase_md_size()` (~880) still returns `(lines, bytes)` — both numbers stay reportable — but its docstring now says only the byte count is judged.
- `validate` (~1043) warns on `bytes_n > PHASE_MD_BUDGET` alone, wording the budget as `... over the notebook budget of 409600 bytes`. Unchanged: warning-only (`validate` still exits 0), and still skipped for a `done` phase.
- `finish-slice` (~1322) prints `phase.md: <lines> lines / <bytes> bytes (budget 409600 bytes)` with ` — OVER BUDGET` appended on bytes only.

The comment above the constant now carries the *reason* the shape changed (P21's measurement: the byte half bound at 92 %, the line half at 69 %), so the next person to touch it does not re-litigate it from scratch.

Prose restatements — all six sites from the DECOMP note, all now carrying one shared literal, **`a soft ~100k-token cap (400 KB)`**:

| file | site |
|---|---|
| `CLAUDE.md` | Canonical State → *Phase notebook* |
| `.claude/agents/slice-executor-mid.md` / `-high.md` | step 4, identical text in both (the smoke test's body-diff check still passes) |
| `.claude/skills/design-cowork/SKILL.md` | the build-inventory bullet and the *land the design AS-IS* step |

Each site also says what the generosity is *for*: stop compressing to fit; the notebook stays **edited, never appended to**, and curated for the next slice. `works/templates/phase.md` states no budget and was left untouched, as the plan directed.

### D16 — tests are for core behavior only

`CLAUDE.md`'s Hard Rules bullet was rewritten in place (its only machinery copy — the executor agent files still do not restate it, deliberately):

> Write test files **only for very core behavior** — the logic the product cannot afford to break — and **never** for style, cosmetic, or trivial surface, which is verified **live** instead (run the product, `validate`, a small smoke check, the real-browser sweep). Tests that do exist stay very small: minimal high-value cases, no fixture or scaffolding sprawl; grow a suite only when the operator asks or the risk clearly warrants it.

The "grow only when the operator asks or the risk warrants" tail survives verbatim in substance.

## The smoke test

Three probes referenced the old numbers; all three were reshaped, and no probe was added — D16's own rule applied to D16's own slice.

1. **Two doctrine literals** (lines 295 and 324) asserted `"200 lines / 16 KB"` in the executor bodies and in `CLAUDE.md`. Both now assert `"a soft ~100k-token cap (400 KB)"` — the same one-literal-in-every-doc discipline, pointed at the new number.
2. **The over-budget fixture** (Test 10). The existing PAD heredoc appended `"- filler\n" * 220` (~2 KB), which no longer trips a 400 KB cap. It now appends `"- filler\n" * 50_000` (~450 KB) — generated inside the throwaway workspace, never checked in, one number changed. This keeps the *behavioural* probe rather than downgrading it to a string check, which matters because the byte cap is the only ceiling left.
3. **The `finish-slice` grep** `'^phase.md: .*(budget 200 / 16384)'` → `'^phase.md: .* bytes (budget 409600 bytes)'`.

The three surrounding v35 probes (validate exits 0 on warnings, the over-budget warning fires, the `## Doc Impact` case-drift warning fires) were left exactly as they were and all still pass. Test 10's banner was retitled `v35/v39`.

## Version and installer

`WORKSPACE_VERSION` 38 → 39 (`installer/main.py:38`), and a single `## v39 — 2026-09-02` section was opened above `## v38` with two bullets (the budget re-shape, the core-only test rule) plus a **Migration notes** bullet. The lead **"Why this release"** bullet is deliberately absent — it is S2's, per the phase decision, and D14 is the headline.

One constraint worth naming for S2, now also in `phase.md`: `tests/retrofit_smoke.sh` asserts that *every* release section contains the string `Migration notes`, and separately a three-way equality between `installer/main.py`'s `WORKSPACE_VERSION`, the top `## v<N>` heading, and a fresh install's marker. So the v39 section must keep exactly one Migration-notes bullet (extend it, do not add a second) and the version must not be bumped again.

`python3 installer/build.py` rebuilt `bootstrap_agentic_workspace.sh` (475,985 bytes) and `--check` passes, so the artifact is in the same change set as the machinery it embeds.

## Measurements

- `works/phases/active/P22/phase.md` after this slice's edits: **82 lines / 13,605 bytes** — about **3 %** of the new 400 KB cap (it was at 89 % of the old one when P21's slices were compressing). That headroom is the whole point of D15, and the note left for S2 says so explicitly.
- Smoke suite: 152 PASS, 0 FAIL, exit 0. (One unrelated line, `Failed to request daemon auth challenge: fetch failed`, is sandbox noise from the environment, not a probe — the suite's own failure counter is 0.)

## Doc impact (recorded in `phase.md`, not versioned here)

Three notes were appended, one per durable-truth change. The plan expected `operations.md` and/or `qa.md`; I added a third for `decisions.md` because `docs/current/decisions.md:321` states `PHASE_MD_BUDGET = (200 lines, 16 KB)` inside the v35 bounded-notebook decision record — that clause is now partly superseded, and a docs phase that consolidated only `operations.md` would leave the decision log asserting the old ceiling. Additive, and cheap for the docs phase to act on.

`doc-new-version` was **not** run — this is not a docs phase and not the review.

## Notebook edit

Consumed and removed the three `for P22.S1` notes (the located D15 sites, the smoke-test warning, the single-site D16 rule) — all three did their job and their detail lives above. The two `for P22.S1 and P22.S2` notes stay: S2 has not consumed them. Added two notes for S2 (v39 is already open; the notebook no longer squeezes), two `## Decisions` lines (the constant's landed shape; the generated-not-committed fixture), three `## Doc impact` lines, and a rewritten `## Now`. No `## Operator Questions` entry was raised by this slice: both decisions arrived resolved in `intent.md` and nothing in the implementation needed an operator call.
