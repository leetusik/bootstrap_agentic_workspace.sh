# Plan — P7.DECOMP: decompose "Retire embedded /explain"

Operator-approved orchestrator plan (do-whole-phase, manual mode). Executor: `slice-executor-high`.

## Job

Decompose phase P7 into its middle slices: verify the researched removal footprint below, create the middle slice(s) with `new-slice` (bare folders — never pre-fill their `plan.md`), and seed `phase.md` (Decomposition, Findings & Notes, Constraints). Write `result.md` and return a structured verdict. You never commit and never transition slice/phase status.

## Gate status (verified by orchestrator — do not re-block on it)

The phase gate is SATISFIED: the knowledge repo's P7 "Claude Code plugin" is `done`, review `pass` (2026-07-14, reviewer slice-executor-high; see `~/projects/personal/knowledge/works/phases/archived/20260715_132925_P7_claude_code_plugin/phase.json`). The plugin ships the explain skill + a KB scaffold flow, installable via `/plugin`. Bootstrap P8's intent confirms execution order: this phase runs first.

## Researched removal footprint (verify against the repo; note any misses in phase.md)

**Skill copies (delete):**
- `.claude/skills/explain/SKILL.md`
- `.agents/skills/explain/SKILL.md` + `.agents/skills/explain/agents/openai.yaml`

**Installer wiring (edit):**
- `installer/wrapper.sh` — `--with-explain` usage line (~16), `with_explain=0` (~52), case arm (~65), `export WITH_EXPLAIN` (~90)
- `installer/main.py` — lines ~60–68: `WITH_EXPLAIN` env read, the `--update` keep-refreshing special case, `OPTIONAL_SKILLS` / `_excluded` filtering of `CLAUDE_SKILLS`/`CODEX_SKILLS`. Explain is the only optional skill — the whole optional-skill mechanism goes.
- `installer/main.py` — `WORKSPACE_VERSION` 14 → **15**.
- Rebuild rule (non-negotiable): `python3 installer/build.py` and the rebuilt `bootstrap_agentic_workspace.sh` land **in the same commit** as the machinery edits; `--check` must pass (pre-commit hook enforces).

**`--update` behavior after retirement (decided — record in phase.md):** rely on the generic `flag_stale_skills` mechanism — an installed `.agents/skills/explain` (has the `agents/openai.yaml` marker) gets flagged stale ("remove manually?"); `.claude/skills/explain` carries no `disable-model-invocation: true` marker so it is left untouched as an operator-owned skill. Never deletes. CHANGELOG migration notes must tell existing installs to remove old copies manually and install the knowledge plugin instead.

**Tests:** `tests/retrofit_smoke.sh` — keep the "default install omits explain" assertions (~lines 173–174) as a regression; replace Test 8 (~209–218, `--with-explain` installs it) with an assertion that `--with-explain` now fails as an unknown option.

**Repo docs:** `README.en.md` — flag-table row (~162), prose (~172), skills-table row (~273), skill-interface prose (~287–289): remove explain/`--with-explain`, point at the knowledge repo's plugin (pull the exact `/plugin` install pointer from the knowledge repo's plugin manifest/README — verify it, do not invent it). Root `README.md` (Korean) has no explain-feature mentions (verify). `CHANGELOG.md`: new `## v15` entry with **Migration notes**; historical entries stay untouched.

**Deferred D1** ("Make /explain portable so public users can use it") — resolved by deletion; the orchestrator will run `drop-deferred D1` after the removal slice lands. Note it in phase.md; do not run deferred commands yourself.

**Doc impact (REVIEW consolidates; slices only append one-line notes to phase.md):** operations doc (supersedes v0010 opt-in and v0011 KB-API truth — explain no longer ships; plugin pointer) and decisions doc (P7 decision: embedded explain retired in favor of the knowledge repo plugin).

**Clean baseline (orchestrator-verified):** `installer/build.py --check` OK; `workflow.py validate` OK; no explain refs in `.claude/settings.json`, `scripts/workflow.py`, `works/templates/`, or other skills (only the prose word "explains").

## Suggested breakdown (you decide finally; record rationale in phase.md)

**One implementation slice** — `new-slice --phase P7 --slice P7.S1 --name "Remove explain from the distribution" --kind implementation --risk medium` — because the removal is atomic: skills + installer wiring + version bump + CHANGELOG + README + smoke test + rebuilt installer must land in one commit; any split leaves a lying intermediate state (e.g. a `--with-explain` flag that installs nothing, or a smoke test asserting the old behavior). You may argue a different split in phase.md, but: risk `low` is off the table (installer surgery is not mechanical plan-following), and the same-commit rebuild rule cannot be split across slices.

## Done means

- Middle slice(s) created (bare folders with `slice.json` only), risks set deliberately.
- `phase.md` seeded: Decomposition (breakdown + rationale), Findings & Notes (verified footprint incl. any corrections, the `--update`/stale decision, the plugin install pointer), Constraints (same-commit rebuild, workspace v15 + CHANGELOG policy, D1 drop by orchestrator, doc-impact-at-review).
- `result.md` written; structured verdict returned.
