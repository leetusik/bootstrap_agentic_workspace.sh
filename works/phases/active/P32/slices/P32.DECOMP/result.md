# Result — P32.DECOMP

## Verdict

- status: done
- tier: high
- summary: Decomposed P32 into six bare slices — S1 engine route table + `executor-route` (implementation/high), S2 `record-dispatch` + `dispatch-summary` (low), S3 agent bodies + `Explore.md` (low), S4 skills and contract (high), S5 installer/release + full smoke run (low), S6 CHANGELOG + READMEs (docs/low) — and recorded D1–D13, the rated breakdown, H1–H6 (re-checked against the sub-agents doc) and the code anchors each slice needs in `phase.md`. Raised one operator question (v53/v54 order against the now-parallel P33) and flagged two gaps the plan left: S1 must create `Explore.md` or its own `sync-agents --check` fails, and `docs/retrofit-guide.md` carries preset text no slice owned (recommended for S6).
- files_changed: works/phases/active/P32/phase.md; works/phases/active/P32/slices/P32.DECOMP/result.md; works/phases/active/P32/slices/P32.S1..S6/slice.json (created by `new-slice`); regenerated works/index.json, works/backlog.md, works/state.json, works/events.jsonl
- validation: `python3 scripts/workflow.py validate` — passed (exit 0; two pre-existing warnings: consolidation_owed=P33, oversized_doc_sections=8); `python3 scripts/workflow.py next` — `current_slice=P32.DECOMP` (still in_progress until the orchestrator's `finish-slice`), `next_slice=P32.S1`; `python3 installer/build.py --check` — passed (no machinery touched)
- deviations: (1) advisory `--depends-on P32.S1` added to S2, from the plan's own "mechanical once S1 fixes the row names"; (2) the plan's D1 heading says "five rows" and its prose "four rows" — recorded as five rows of which four are slice routes; (3) `next` shows `next_slice=P32.S1` rather than `current_slice=P32.S1`, because DECOMP stays in_progress until `finish-slice`.
- doc_impact: none (seeded empty per plan step 5; the phase's owed docs are listed in a `## Notes for later slices` entry)

## What was done

1. Read `plan.md`, `phase.md`, `intent.md` (whole), `phase.json`, `scripts/workflow.py` 265–600, `executors.toml`, both tier agent files and `design-drafter.md` frontmatter, `installer/build.py` (`FIXED_LIVE_FILES`, `EXPECTED_SKILL_COUNT`), `installer/main.py` 150–200 / 440–470 / 490–510 / 905–960 / 1385–1455, `tests/retrofit_smoke.sh` 440–560 / 800–822 / 990–1050 / 1074–1150, the operations doc's `## Executor tiers` (evidence, STALE in part — D51), and grepped the five skills for their dispatch/tier sentences.
2. Cut the slices with `new-slice` (orders 1–6; REVIEW stays at 9999). Folders hold only `slice.json` — no `plan.md` pre-filled.
3. Rewrote `phase.md` below the generated block: `## Decisions` (D1–D13 + breakdown), `## Operator Questions` (one entry), `## Notes for later slices` (H1–H6, code anchors, sequencing, doc-debt list), `## Now`. `## Doc impact` left empty. `phase.md` is ~22 KB.
4. `python3 scripts/workflow.py rebuild` touched only `docs/index.json`'s `last_rebuilt_at`; reverted that one timestamp line with `git checkout -- docs/index.json` (my own change) to keep the diff clean.

## Fact check against the code (plan step 2)

All plan facts confirmed. One refinement and five findings the plan did not carry:

- **H1/H2/H4 re-checked** against code.claude.com/docs/en/sub-agents (Claude Code 2.1.296 on this machine; none of `ANTHROPIC_BASE_URL`, `CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_SUBAGENT_MODEL[_FORCE]`, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` is set). Effort: "`CLAUDE_CODE_EFFORT_LEVEL` takes precedence over both" (per-invocation and frontmatter) — answers the intent's open "verify at DECOMP" question. Model: H2 refined in place — `FORCE` alone yields the main model (built-in Explore excepted), `FORCE` + `CLAUDE_CODE_SUBAGENT_MODEL` yields that model, and a mod's `agent.spawn` hook model also replaces the per-invocation one. Explore override keeps `model`; effort retention undocumented (as H4 says). Nesting default 3 since 2.1.219. H5/H6 not re-fetched (taken from the plan).
- **Finding 1 — Explore.md sequencing (S1/S3).** S1's validation runs `sync-agents --check`; once the `explore` row's file is in `executor_agent_files`, a missing `Explore.md` makes `sync-agents` exit 1. Recommended in the notebook: S1 creates `Explore.md` (D8 frontmatter, minimal body); S3 finalizes the body.
- **Finding 2 — CLAUDE.md headroom (S4).** 12,280 B by `wc -c` vs P23's 12,288 B cap: 8 bytes. Not smoke-enforced; a decision. `CLAUDE.md` has no `executor-mode` mention (the plan's S4 row implies one); the preset words live in `do-next-slice` line 26.
- **Finding 3 — nested rename of an unhyphenated agent (S5).** `nested_rewrite` renames agents by bare token, written for hyphenated names; `Explore` would rewrite capitalised prose "Explore" on a host clash. And with no clash, our `Explore.md` overrides the built-in for every session in the host repo.
- **Finding 4 — smoke `DUAL_FIXED` (S5).** It diffs `$REPO_ROOT/executors.toml` against the fresh install; D3's derived seed breaks that line.
- **Finding 5 — unowned preset text (S6).** `docs/retrofit-guide.md` 173–180 describes economy/flex (and an already-stale "17 Agent Skills"); no slice covered it. Also post-install message `installer/main.py` 1511 names economy/flex/`executor-mode` (S5 note).
- **Finding 6 — parallel P33.** `parallel-status` shows P33 running in a worktree (`phase_parallel_started` 2026-10-12 16:45:46, after this slice started), although P33's `intent.md` recorded "no worktree". P33 ships v54 and overlaps `scripts/workflow.py`, `do-whole-phase`, `CLAUDE.md`; P34 also claims v54. Raised the P32-side version-order question in `## Operator Questions`; the worktree-vs-intent mismatch itself is outside P32 and is reported here for the orchestrator only.

## Notebook

Decisions, the breakdown, the operator question and every note are in `works/phases/active/P32/phase.md` — not restated here.
