# Result — P7.REVIEW: phase review of "Retire embedded /explain"

**Verdict: `pass`.** The phase met its objective, honored intent, and kept the workspace
contract; all phase-wide validation is green. Consolidated the phase's Doc impact notes into
two new durable doc versions (operations v0015, decisions v0021).

## 1. Phase-wide validation (all run, all green)

| Command | Outcome |
|---|---|
| `python3 installer/build.py --check` | **PASS** — "OK: bootstrap_agentic_workspace.sh is in sync with installer/ source" (exit 0) |
| `sh tests/retrofit_smoke.sh` | **PASS** — ALL RETROFIT SMOKE TESTS PASSED (exit 0). Rewritten Test 8 green ("--with-explain is rejected (exit=1)", "reports the unknown-option error", "explain skill never installed"); kept Test-5 regressions green ("default install omits Claude/Codex explain (opt-in)") |
| `python3 scripts/workflow.py validate` | **PASS** — "Workflow validation passed." (exit 0), before and after doc versioning |
| `grep -rn "with-explain\|WITH_EXPLAIN\|OPTIONAL_SKILLS" .` | Survivors ONLY in CHANGELOG.md (history + v15), tests/retrofit_smoke.sh (kept 173–174 + new Test 8), docs/** (pre-consolidation history), works/** — all expected |
| `grep -rni "skills/explain" .` | Same expected-survivor set; zero unexpected hits |

**Must-be-zero locations confirmed clean (0 hits each):** `installer/`, `.claude/` (explain dir
absent), `.agents/` (explain dir absent), `README.md` + `README.en.md`, and the rebuilt
`bootstrap_agentic_workspace.sh`. No survivor falls outside {CHANGELOG.md, tests/, docs/, works/}.

**Consistency spot-checks (all pass):**
- `WORKSPACE_VERSION = 15` in `installer/main.py` (line 38) **and** embedded in the rebuilt artifact.
- CHANGELOG top entry is `## v15 — 2026-07-21` with a **Migration notes** line and the verified plugin
  pointer: `/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge`, then
  `/knowledge:setup` and `/knowledge:explain`.
- README.en.md skill counts match the real repo (`.claude/skills/*/` = 15, `.agents/skills/*/` = 14):
  "14 core Agent Skills, mirrored" (line 170), "15 Agent Skills" (252), "15 Agent Skills (Claude Code)"
  (324), "mirrored for Codex (minus do-whole-phase)" (327) — all correct. Plugin pointer (lines 273–276)
  matches the CHANGELOG's commands. No lingering `--with-explain` flag-table or explain skill row.

## 2. Review findings per dimension

- **Objective met.** Skill copies gone (`.claude/skills/explain`, `.agents/skills/explain` both
  absent); `--with-explain` path gone (rejected as unknown option — Test 8); KB/optional wiring gone
  (`WITH_EXPLAIN`/`OPTIONAL_SKILLS` removed from `installer/main.py`, four bits removed from
  `wrapper.sh`); users pointed at the plugin (README.en.md + CHANGELOG); installer rebuilt
  (`--check` OK, in-commit); **D1 resolved** — `works/deferred/dropped/D1/` exists with dropped_reason
  citing P7.S1, `deferred` reports `open=0 promoted=0 dropped=1`.
- **Intent honored.** Gate was orchestrator-verified before work (knowledge repo P7 pass; recorded in
  phase.md Context) — "leave current state as is till knowledge done" respected. The plugin pointer is
  the **verified** one (read from the knowledge repo's `marketplace.json`/`plugin.json` in DECOMP), not
  invented; namespace change `/explain` → `/knowledge:explain` captured.
- **Contract kept.** S1 ran no `doc-new-version` (the S1 commit `31c78d9` touches no `docs/` file — docs
  consolidated only here, at REVIEW). Same-commit rebuild rule held: commit `31c78d9` contains both the
  machinery edits (`installer/main.py`, `installer/wrapper.sh`) **and** the rebuilt
  `bootstrap_agentic_workspace.sh`. Historical CHANGELOG entries byte-untouched (the S1 CHANGELOG diff is
  24 additions, 0 deletions); `docs/versions/` byte-untouched by S1; root `README.md` untouched
  (not in the commit).
- **Slices met their plans.** DECOMP created the single medium-risk slice P7.S1 and seeded phase.md as
  planned (no deviations). S1 applied every planned edit cleanly and recorded two deviations, both
  correct: (a) the smoke test legitimately retains `--with-explain`/`skills/explain` strings because
  plan step 4 itself requires the kept regressions + a Test-8 rejection assertion — the plan's sweep
  bullet ("zero hits in tests/") was over-broad; (b) the 173–174 failure-branch message strings were
  left verbatim per plan (they only print on failure). Both are justified and do not affect correctness.

## 3. Docs consolidated (passing review)

Two new durable doc versions, `--source P7.REVIEW`, then `rebuild-docs` + `validate` (green):

- **operations v0015** — replaced the "Optional skills at install (`--with-explain`)" section with
  "The explain feature ships as a plugin now (retired from the bootstrap, since v15)": what was removed,
  the plugin install pointer, the `--update` never-auto-delete behavior with the accepted stale-flag
  asymmetry, the v15 release note, and D1 resolution. Also updated the Status paragraph's explain pointer
  from the v2 opt-in line to the v15 retirement. Supersedes the operational truth of operations v0010/v0011.
- **decisions v0021** — added a new top Decision Log entry "Retire the embedded `/explain` feature — it
  ships as a Claude Code plugin now (phase P7)" (decision, rationale, alternatives, consequences,
  source), bumped the Status count to "Eighteen decisions" and appended the P7 clause. Notes it supersedes
  the P5/P6 explain operational truth while leaving those history entries in place.

Rebuild changed only `docs/current/{operations,decisions}.md` + `docs/index.json` (regenerated) plus
the two new `docs/versions/**` files — no source, no other works state.

## Deviations from plan.md

None. Executed the plan's validation list, review dimensions, and doc-consolidation steps as written.
Wrote only docs + this `result.md` + the phase.md review note; ran no commit and no state transition
(the orchestrator records the verdict via `review-phase`).
