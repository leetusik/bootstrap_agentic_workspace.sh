# Plan — P22.S1: relax the notebook budget and sharpen keep-tests-small (D15+D16)

## Job

Implement two resolved operator decisions in this repo's machinery and doctrine. Read `works/phases/active/P22/phase.md` first — its `## Decisions` and `## Notes for later slices` carry the located edit sites; consume the notes addressed to S1.

## D15 — notebook budget → soft ~100k-token byte cap

- Replace `PHASE_MD_BUDGET = (200, 16 * 1024)` (`scripts/workflow.py:59`) with one generous **byte-only** cap of **400 * 1024** bytes (~100k tokens). Drop the line ceiling entirely — P21 measured that lines never bind. Keep it **warning-only, never an error**, exactly as today.
- Update the machinery sites the constant feeds: `phase_md_size()` docstring (~877), the `validate` warning (~1038), the `finish-slice` printout (~1318). `finish-slice` keeps printing the size (lines and bytes may both print; only bytes judge).
- Update every prose restatement of "200 lines / 16 KB": `CLAUDE.md:45`, `.claude/agents/slice-executor-mid.md:39`, `.claude/agents/slice-executor-high.md:39`, `.claude/skills/design-cowork/SKILL.md:126-127` and `:244`. State the new budget as a soft ~100k-token (~400 KB) sanity cap: the notebook should stop compressing to fit, but stays bounded and curated (edit-not-append doctrine is unchanged).
- `works/templates/phase.md` states no budget — leave it alone.

## D16 — keep-tests-small → core-only

- Sharpen the rule at `CLAUDE.md:55` (its only machinery copy): test files are written **only for very core behavior** — the logic the product cannot afford to break; **never** for style/cosmetic/trivial surface, which is verified live (running the product, smoke checks, the real-browser sweep). Tests stay very small. Keep the existing "grow only when the operator asks or risk warrants" tail. Do **not** add the rule to the executor agent files.

## Smoke test

- `tests/retrofit_smoke.sh` greps the literal `(budget 200 / 16384)` and builds a must-be-over-budget fixture. Reshape those probes for the new cap — keep them terse (D16's own rule applies): asserting the new budget string and that the warning stays advisory (`validate` exits 0) is enough; if generating a >400 KB fixture is what it takes to prove the over-budget warning fires, generate it programmatically (e.g. `yes`/python one-liner), never a checked-in blob. Run the smoke script and make it pass.

## Version + installer

- Bump `WORKSPACE_VERSION` at `installer/main.py:38` from 38 → **39**; open a single `## v39` CHANGELOG section (follow the existing CHANGELOG convention; S2 will append to it and owns the lead bullet — leave that headline slot to S2, write the D15/D16 bullets).
- Run `python3 installer/build.py`; `python3 installer/build.py --check` must pass; the rebuilt `bootstrap_agentic_workspace.sh` is part of this slice's changed files.

## Bookkeeping

- Append `## Doc impact` one-liners in `phase.md` for the durable-truth changes (expect `operations.md` and/or `qa.md` — the notebook-budget statement and the keep-tests-small rule as they appear in durable docs). Never run `doc-new-version`.
- Edit `phase.md` per contract: consume S1-addressed notes, update `## Now` last. Write `result.md` verdict-block-first.
- Validate: `python3 scripts/workflow.py validate` (passes; pre-existing `consolidation_owed=P21` and `oversized_doc_sections=5` warnings are inherited, not yours), `bash tests/retrofit_smoke.sh`, `python3 installer/build.py --check`.
