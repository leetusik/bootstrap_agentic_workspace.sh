# Result — P32.REVIEW: review the executor route-table phase

## Verdict

- status: done
- tier: high
- model: opus
- effort: high
- summary: Reviewed P32 across its boundary (`phase-scope P32`: 11 commits, 21 product files) and re-ran every slice's validation together — smoke 258 PASS / 0 FAIL, validate exit 0, every executor-route probe, toml rejection, dispatch-summary, seed and attribution check green. The objective shipped item by item. Verdict `pass`. Two gaps in the notebook were closed in `phase.md` (one `## Doc impact` line was missing, and D4/D5/D8 were behind what shipped), and the one operator question goes to the orchestrator as a deferred job.
- files_changed: works/phases/active/P32/slices/P32.REVIEW/result.md; works/phases/active/P32/phase.md
- validation:
  1. `python3 -m py_compile scripts/workflow.py installer/build.py installer/main.py`: pass
  2. `python3 scripts/workflow.py validate`: pass, exit 0. The only warnings are the two that predate the phase: consolidation_owed=P33 and oversized_doc_sections=8. Re-run after the notebook edits: pass.
  3. `sync-agents --check`: pass (in sync, 2 overrides). Frontmatter as the plan states: mid sonnet/high; high opus/high; design-drafter opus/high; Explore haiku/high with `tools: Read, Grep, Glob` and `omitClaudeMd: true`.
  4. Tier body identity (`diff <(tail -n +9 mid) <(tail -n +9 high)`): empty, pass. `Agent` is last on both `tools:` lines: pass.
  5. `executor-route` probes: pass.
     - Bare form: five rows, `cheap  mid  haiku  high  executors.toml`, `agent files: in sync`, `proxy=none`.
     - Routes: DECOMP and REVIEW → high; S1 → high (`risk high (not low)`); S2 → mid/sonnet; S6 → cheap/haiku/`Claude Haiku 5.5`; `S6 --retry` → high with attempt=2.
     - `--drafter` → design-drafter; `--explore` → Explore.
     - Proxy and env: a loopback proxy gives `model=sonnet` plus a `fallback=` line (also for `localhost:` and `[::1]`). `CLAUDE_CODE_EFFORT_LEVEL` and `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` each print a `warning=`.
     - `slice_route` exercised directly over research, co-work, fix, qa, docs-medium, retry, unknown kind and unset risk: all as D4 states.
  6. toml rejections in a scratch copy (the live file was never touched): pass.
     - Refused as expected: `mode = "flex"` → `retired in workspace v53`; `[claude.cheap] model = "claude-haiku-5-5"` → `must be an Agent-tool alias`; `[claude.nope]` → `unknown route`; `effort = "hgih"` → `effort must be one of`.
     - Also checked:
       - A full model id with `effort = ""` on mid gives `pass_model=no` and `pass_effort=no`, and no effort line in the frontmatter.
       - An unset cheap row inherits a full-id mid with `pass_model=no`.
       - `record-dispatch` accepts an empty effort, refuses a bad verdict or route (rc 2), and refuses an unknown slice (rc 1).
       - Drift in Explore.md is a `validate` warning, never an error.
  7. `dispatch-summary --phase P32`: pass. records=8; high 3 / mid 4 (one blocked, one retry) / cheap 1. `--slice P32.S3` prints two lines (attempt 1 blocked, attempt 2 done). `--json` parses.
  8. `installer/build.py --check`: OK. `WORKSPACE_VERSION = 53`. The CHANGELOG head is `## v53 — 2026-10-12`, and the v53 section has the **Migration notes** bullet (a–f). Pass.
  9. Derived seed: the `[claude.cheap]` block is commented out with its markers intact, and the live `executors.toml` keeps it uncommented. Pass.
  10. `wc -c CLAUDE.md` → 12284 (≤ 12288): pass
  11. Retired-word grep (economy/flex/executor-mode/EXECUTOR_PRESETS) over the plan's file list, excluding `.claude/worktrees/` (P33's worktree, outside the boundary): pass. The only hits are the intended migration sentences: workflow.py 396–397, executors.toml 32, README.md 363 and retrofit-guide 290.
  12. `bash tests/retrofit_smoke.sh`, run once in the foreground as the only command in its Bash call: **ALL RETROFIT SMOKE TESTS PASSED, 258 PASS / 0 FAIL**. Pass.
  13. Commit attribution (`git log 0d4f751..HEAD` trailers): pass. DECOMP, S1 and S4 are Opus 5.5; S2, S3 and S5 are Sonnet 5.5; S6 is Haiku 5.5. Each matches the model in that slice's verdict block and its dispatch record. The S3-blocked chore is Sonnet (the blocked executor's run).
- deviations: none from the plan's checks. Two additions beyond them:
  - (a) The review made the notebook corrections listed under Findings. These are edits to `## Decisions` and an appended `## Doc impact` line, all inside `phase.md`; no source was touched.
  - (b) It added extra probes: `slice_route` over every kind, the full-id/empty-effort overrides, `record-dispatch` misuse, drift as a warning, and an IPv6 loopback.
- doc_versions: none — deferred to a docs phase
- review_verdict: pass
- walkthrough: none (acceptance gate waived: `acceptance.required: false`)
- explain: not written — run /explain for this phase

## Judgment against the Confirmed Intent

Every item shipped:

- **One engine-owned table with the shipped rows.** `EXECUTOR_ROUTES` has five rows. The defaults match the intent table exactly: review, decomposition, risk-high and every second attempt run opus @ high; research runs opus @ medium; implementation and fix rated low run sonnet @ high; docs and qa rated low run haiku @ high here. `executors.toml` overrides it row by row.
- **Model and effort chosen at dispatch time.** Both `do-*` skills carry one byte-identical protocol paragraph, 3,598 B, checked by extraction: resolve, pin `## Dispatch`, pass `model`/`effort` according to the `pass_*` lines, and record every return. `review-phase` and `design-cowork` follow the same protocol.
- **Frontmatter is the fallback only.** `sync-agents` writes the frontmatter of all four managed agent files from the rows.
- **The cheap route.** It is on here and seeded commented-out for adopters (derived from the live file, one source). Under a loopback proxy it falls back to the mid model.
- **design-drafter** stays on the high row.
- **The project `Explore` agent.** It runs on haiku @ high, read-only. The skills, the bodies and the contract all carry the per-call upgrade.
- **The `Agent` tool** is in both tiers, for reads only. The rule is enforced in prose, which is the only mechanism available: Claude Code's sub-agents doc says the `Agent(type)` allowlist is ignored in a subagent definition. That is consistent with D9.
- **The dispatch record and its summary** exist (`record-dispatch` and `dispatch-summary`).
- **`model`/`effort` in the verdict block**, and commit attribution follows the recorded model (validation 13).
- **The orchestrator's effort is untouched.** No skill frontmatter carries `effort:` or `model:`.
- **v53 ships, with `executor-mode` and the presets retired.** A leftover `mode` line is refused with the migration message, and `--update` flags the old skill directory as stale.
- **The smoke test and the CHANGELOG** are in place.

Each slice met its plan. All deviations are explained, and none of the known ones were re-found. S6 running the smoke suite twice was a departure in process only, with identical results.

## Findings (closed in the notebook by this review; no fix slice proposed)

1. **A `## Doc impact` line was missing.** It concerns operations.md `## Environment Variables`, which still says "The workspace machinery reads **no environment variables**". Since P32.S1, `executor-route` reads three of them: a loopback `ANTHROPIC_BASE_URL`, `CLAUDE_CODE_EFFORT_LEVEL` and `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`. The `executors.toml` table in that section also still lists the top-level `mode` key and the preset defaults. S1's operations line names only *Executor tiers*, so a docs phase working from the list would leave this section wrong.
   - **Closed:** the line is now appended to `## Doc impact`, tagged "owed since P32.S1; added at P32.REVIEW".
   - **Stricter alternative:** if the orchestrator would rather route this through a fix slice than accept the review's append, it would be `P32.F1` (append that one line; `risk: high` would not apply, because S1 was `tier: high`, so `low`).
2. **Three `## Decisions` lines had fallen behind what the slices settled.** Their `result.md` files held the detail, but the notebook did not.
   - **D5** (S2): it still read `dispatch-summary [--phase P]` and said nothing of `--slice`, `--json`, the split by kind, the one-key-per-line header, the skipped malformed lines, the existence rule, or the fact that `retries` counts any attempt ≥ 2.
   - **D4** (S1, deviation 9): the misuse exits were missing.
   - **D8** (S5): the measured nested-rename facts were missing (6/6 tokens per body, `wf-Explore`).
   - **Closed:** all three are corrected in place. Nothing a `result.md` records is now missing from `phase.md`.
   - **Also checked:** D2 and D4 match the shipped engine, verified by probes. S4's `CLAUDE.md` cuts are in D14, and no rule was dropped (I read the edited paragraphs).

**A nit inside the boundary, with no fix proposed:** step 8 of `update-workspace` says the update "refreshes the generated `slice-executor-*` agent files". It refreshes all four managed files (design-drafter and Explore too). The instruction it gives, run `sync-agents`, is correct. Fold the wording in at the next edit of that skill.

## Doc impact verification

The list now has 13 lines and covers every durable-truth change the phase made:

- **operations** (*Executor tiers*): the route table, the `executors.toml` schema, `executor-route`, the instrument, Explore, the Agent tool, the dispatch protocol, the cheap route, the migration, the orchestrator-effort guidance, the installer seed. Plus *Environment Variables* (finding 1).
- **decisions**: the presets, v45 `executor-mode`, v46 "haiku never a tier" and v0013 superseded; reads may be delegated, writes never.
- **architecture**: Explore in the agent set, dispatch-time resolution, `executor_dispatched` as the first reader of `events.jsonl`, nesting depth.
- **qa**: the 258 baseline and the new pins.

Overlap for the docs phase: open job **D51** (decisions/operations executor text up to v45/v46) covers the same sections. Pay both together. This is not a finding.

## Operator question → deferred job for the orchestrator to file

- **Title:** Integrate P33's v54 over P32's v53 (and renumber P34)
- **Reason:** P32 shipped v53 on `main`. P33's branch ships v54 and edits the same files: `scripts/workflow.py`, `do-next-slice`, `do-whole-phase`, `review-phase`, `CLAUDE.md`, `CHANGELOG.md`, `README.en.md`, `installer/main.py`, the smoke test and the artifact. Its merge must:
  - keep v53 below v54 in the CHANGELOG;
  - re-base its skill and contract text on P32's dispatch protocol;
  - rebuild the artifact;
  - re-fit `CLAUDE.md` under the 12,288 B cap.

  P34's intent also claims v54, so it needs the next free number.
- **Trigger:** when P33's acceptance gate clears and its branch is merged into `main` (parallel-merge), or when P34 starts, whichever comes first.
- **Facts as of this run:**
  - No `merge(P33)` or `merge(P34)` commit exists on `main`.
  - On `main`, `WORKSPACE_VERSION = 53` and the CHANGELOG head is `## v53`.
  - `git log --oneline main..phase/P33-one-shot_rotate-backlog_consolidate_the` shows 4 commits (ad87400, ea90793, 96f6a54, 26f05b7), and the branch is 8 commits behind `main`. It carries `WORKSPACE_VERSION = 54` and `## v54`.
  - P33 is `pending` on its own gate; P34 is `planned`.

  So the question's trigger (P33 merging before S5 set v53) never happened, and the numbering holds as planned.

## Observations (outside the boundary — not findings)

- P33's branch `CLAUDE.md` is 12,583 B by `wc -c`, already over the 12,288 B cap on that branch. This bears on the integration job above, not on P32.
- `consolidation_owed=P33` and `oversized_doc_sections=8` predate this phase.
- `docs/current/operations.md` `## Executor tiers` is behind the code by design until the docs phase pays the list.
- `dispatch-summary` counts S3's same-tier re-dispatch after a permission block as a "retry". That is correct by the attempt number, but anyone tuning the table should read `retries` as "attempt ≥ 2", not "escalations". The definition is now recorded in D5.

## Smoke count

258 PASS / 0 FAIL — `ALL RETROFIT SMOKE TESTS PASSED` (run once, foreground, alone).

## Notebook

`phase.md` edits: D4, D5 and D8 corrected in place; one `## Doc impact` line appended; one routing line appended under `## Operator Questions`; `## Now` rewritten. Nothing inside the generated `## Slices` block was edited. The every-slice doc-debt note stays for the docs phase.
