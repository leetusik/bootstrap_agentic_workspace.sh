# Phase P18: Bounded phase notebook and just-in-time reads

_Intent: see [intent.md](intent.md)._

## Objective

Make phase.md a bounded, rewritten state doc (generated ## Slices table, Decisions, Doc impact, Operator Questions, Notes for later slices, ## Now) with result.md as the per-slice log; add the engine support (works/templates/phase.md seed, finish-slice --outcome, rebuild-generated slice block, 200-line/16 KB budget warning, Doc-impact case-drift warning, no 'Rebuilt at' churn in backlog/deferred); rewrite the executor/skill read-and-write rules and the contract's Read Order to load docs sections just-in-time; ship as workspace v35.

## Context

## Decomposition

Five middle slices. The plan's expected shape (S1 engine / S2 agents+skills / S3 contract / S4 release) is kept, with the **engine split in two**: the notebook *shape* (new file formats, a new CLI flag, a new generated region, installer + test wiring, and this phase's own migration) is the heaviest and trickiest work in the phase, and the *guardrails* (two `validate` warnings, one print, one line removed from two dashboards) are an independent, mechanically checkable unit. Splitting gives a real checkpoint — P18's own notebook rendering correctly — before anything is measured against a budget.

| Slice | kind / risk | order | Covers | Why it is its own slice |
|---|---|---|---|---|
| `P18.S1` | implementation / high | 10 | `works/templates/phase.md` + embedded fallback in `new_phase`; `finish-slice --outcome "..."` stored in `slice.json` (warn when omitted, never error); the `## Slices` block regenerated in `rebuild_index_and_state` between `<!-- slices:begin -->` / `<!-- slices:end -->` (id, name, kind/risk, status, outcome, `result.md` link when present) and untouched when the markers are absent; the four installer/test registration points (F2); terse smoke cases; **migrate P18's own `phase.md`** to the new shape | The new formats everything else is written against. Nothing downstream can be specified, tested, or dogfooded until the template, the flag and the generated block exist |
| `P18.S2` | implementation / high | 20 | `PHASE_MD_BUDGET = (200, 16 * 1024)` → `validate` warning + `finish-slice` size print; `validate` warning on a `## Doc Impact` case-drifted heading and the two `workflow.py` literals (`parallel-merge-finish` hint ~1515, docstring ~1526); drop `- Rebuilt at:` from `works/backlog.md` and `works/deferred.md`; terse smoke cases | Guardrails and churn removal, independent of the shape work and separately verifiable. Measuring a budget only makes sense once S1's generated block is part of the file |
| `P18.S3` | implementation / high | 30 | Both executor agents (byte-identical below frontmatter): the just-in-time read list, step 3 (verdict block first in `result.md`), step 4 (edit `phase.md` under budget), the review's `phase.md`↔`result.md` cross-check. Skills: `do-next-slice`, `do-whole-phase`, `review-phase`, `create-phase`, `design-cowork`, and the two `parallel-phase` lines in F5/F6 | The behaviour change. One slice because the agent pair and the driver skills state the same protocol and must not disagree; `sync-agents --check` is its own gate |
| `P18.S4` | implementation / high | 40 | `CLAUDE.md`: Read Order, *Canonical State* notebook line, the slice-files rule (bounded state vs. per-slice log; `## Slices` generated), the `finish-slice` line under *Workflow Commands*. `README.md` + `README.en.md` wherever they restate the read order or the notebook | The contract must be written last among the prose, against what actually shipped in S1–S3, not against the plan |
| `P18.S5` | implementation / low | 50 | `WORKSPACE_VERSION = 34` → `35` (`installer/main.py:38`), `CHANGELOG.md` `## v35` entry, final `python3 installer/build.py` + smoke run | Deliberately `low` (the phase's own cost lever, see N5): one constant, one docs entry, one generated artifact |

## Findings & Notes

- **F1 — installer rebuild rides every slice that touches an embedded file** (`scripts/workflow.py`, `.claude/*`, `works/templates/*`, `CLAUDE.md`): S1–S4 each run `python3 installer/build.py` before returning, because the tracked pre-commit hook runs `installer/build.py --check` on every commit. S5 owns only the version bump + CHANGELOG. (P17 learned this the hard way.)
- **F2 — `works/templates/phase.md` must be registered in four places or the build/tests fail:** `FIXED_LIVE_FILES` in `installer/build.py` (~44-53); `MANAGED_FILES` in `installer/main.py` (~80, the `("deferred_brief.md", "intent.md")` tuple); the emitted fresh-install writer in `installer/main.py` (~522-523, beside the two existing `write_text("works/templates/...")` calls); and the **hand-maintained `DUAL_FIXED` manifest** in `tests/retrofit_smoke.sh` (~491) — Test 6 parses `FIXED_LIVE_FILES` by AST and fails when the manifest drifts from it.
- **F3 — `works/templates/` is machinery in the update policy** (`installer/main.py` ~272): adopters get the new template on `--update`, while every existing `works/phases/**/phase.md` is preserved. That is exactly why the marker-less path must be a silent no-op, not a migration.
- **F4 — `write_text()` always rewrites** (atomic replace, no unchanged-content skip). The `## Slices` writer must read → splice → compare → **write only on change**, or every `next` dirties every active `phase.md` — the opposite of what this phase is for.
- **F5 — do not add `phase.md` to `GENERATED_FILES`.** Only the marker block is generated; `parallel-merge-finish`'s "resolve by taking either side" advice must never apply to the whole notebook. Correct guidance for a conflict *inside* the block: re-run `rebuild`. S3 adds that one line to the `parallel-phase` skill.
- **F6 — `## Doc Impact` case drift lives in three places today:** `scripts/workflow.py:1515` (the hint print) and `:1526` (docstring) → **S2**; `.claude/skills/parallel-phase/SKILL.md:150` → **S3**. The seed literal is `## Doc impact`.
- **F7 — dropping `- Rebuilt at:` leaves `rebuild_deferred_dashboard(groups, rebuilt_at)`'s second argument unused** (callers: `rebuild_index_and_state`, `cmd_deferred`) — clean it up or keep it deliberately. Scope is the **two markdown dashboards only**: `index.json.last_rebuilt_at` and `state.json.updated_at` stay (operator-confirmed, `intent.md` part 3) — do not extend the change to them.
- **F8 — `validate()` keeps `warnings` and `errors` in separate lists**, prints warnings first and still exits 0 with warnings. Both new checks (budget, case drift) go in `warnings`; neither may ever become an error (`intent.md` clarification 4).
- **F9 — the executor agents are byte-identical below frontmatter today:** `diff <(tail -n +9 .claude/agents/slice-executor-mid.md) <(tail -n +9 .claude/agents/slice-executor-high.md)` is empty. Keep it empty, then `python3 scripts/workflow.py sync-agents --check` must report no drift.
- **F10 — smoke suite:** `bash tests/retrofit_smoke.sh` = Tests 0–8, 123 PASS at DECOMP time. Record the count before and after; keep additions terse (CLAUDE.md hard rule).
- **F11 — gate:** the orchestrator is expected to run `accept-gate P18 --waive` right after this slice (workspace machinery, no operator-visible product surface). This repo has no `## Operator Runtime` section and needs none — do not add one in this phase.
- **F12 — P18's own `phase.md` is the migration test bed.** Until S1 lands, this file is the old shape; S1 migrates it in place keeping every line already recorded, S2–S5 then edit it under the new rules, and the review measures the result.
- **F13 — budget calibration data point:** this DECOMP seed alone is 58 lines / 9.6 KB, i.e. ~60 % of the 16 KB half of `PHASE_MD_BUDGET` before any slice appends. S2 still implements the operator-confirmed `(200, 16 * 1024)` warning as specified — but record the phase's real end size in its `result.md`, so the review has evidence for whether the byte half is calibrated.
- **N1 (for S1)** — the seed lives in one long `write_text(...)` line inside `new_phase` (`scripts/workflow.py` ~901); the full target section list is `intent.md` part 1, the engine list part 3.
- **N2 (for S2)** — `finish_slice` (~963) is a two-line wrapper over `set_slice_status`; both the `--outcome` store (S1) and the size print (S2) land there. Coordinate: S1 goes first.
- **N3 (for S3)** — the drivers currently re-read `works/backlog.md` per slice; that re-read is dropped, and `result.md` is read head-first (whole file only on a non-`done` verdict).
- **N4 (for S4)** — the contract is written against what shipped, not against the plan; re-read S1–S3's `result.md` before editing.
- **N5 (for S5)** — keep it genuinely small: the multi-file span is one constant line, one CHANGELOG entry, and a generated artifact produced by a command, so the "more than one file" escalation trigger does not by itself apply. New test invariants belong to S1/S2; the "coming from a pre-v35 workspace" adopter prose is doc consolidation at the review, not this slice.
- **N6 (doc impact, expected)** — `operations.md` (the notebook runbook + the new Read Order), `decisions.md` (an ADR: bounded rewritten state vs. append-only log, and why no prompt-cache setting changed — `intent.md` clarification 2), `qa.md` only if a regression line is warranted. Each slice appends its own line below; the review consolidates.

## Doc impact

_Append one line per durable-truth change: `- <doc>.md: <what changed> (<slice>)`. Consolidated into versions at `P18.REVIEW`, never per slice._

## Operator Questions

_Questions only the operator can answer; every entry is routed at the review -- folded into the acceptance walkthrough (`accept-gate --open`) or filed with `defer-job`. An unrouted entry is a review finding._

- None raised at decomposition. (`intent.md` already resolves the five open questions, including the prompt-cache one.)

## Constraints

## Open Questions

-
