# Plan — P32.REVIEW: review the executor route-table phase

Kind `review`, risk `high` — the top tier by kind. Follow your agent instructions for a review slice and the `review-phase` skill (`.claude/skills/review-phase/SKILL.md`). **The acceptance gate is waived** (`phase.json` → `acceptance.required: false`, note: workspace machinery only), so the gate stages 1–6 do not apply: no manifest, no browser, no walkthrough (`walkthrough: none`). The phase runs on the default stream (no `execution` block), so on a pass the two gate sections are not needed either — this phase changed neither `## Operator Runtime` nor any product surface the `## Regression Checklist` covers — and you return `doc_versions: none — deferred to a docs phase`. Never edit source on this slice.

## Read

- `CLAUDE.md` (now 12,284 B; it is itself inside the boundary).
- `works/phases/active/P32/intent.md` (whole — the operator's words and the shipped table), `phase.md` (whole — the bounded notebook: D1–D14, `## Doc impact`, `## Operator Questions`, `## Now`), `phase.json`.
- Every slice's `slice.json` and `result.md`, head-first, whole where the detail matters: `P32.DECOMP`, `P32.S1` … `P32.S6`. Note S3's `result.md` is the **second** attempt's (the first was a permission block, recorded in `works/events.jsonl` with `verdict: blocked`).
- The boundary, from `python3 scripts/workflow.py phase-scope P32` (run it yourself; as of planning: range `0d4f751..955d25d`, 11 commits, 21 product files — `scripts/workflow.py`, `executors.toml`, the four agent files, six skills incl. the `executor-mode` → `executor-route` rename, `CLAUDE.md`, `installer/build.py`, `installer/main.py`, `bootstrap_agentic_workspace.sh`, `tests/retrofit_smoke.sh`, `CHANGELOG.md`, both READMEs, `docs/retrofit-guide.md`).
- The `docs/current/operations.md` `## Executor tiers` section only as evidence of the pre-phase truth the `## Doc impact` notes must cover (it is behind the code by design until the docs phase).

## Validate all slices together (re-run; the orchestrator trusted each `done`)

1. `python3 -m py_compile scripts/workflow.py installer/build.py installer/main.py`
2. `python3 scripts/workflow.py validate` → exit 0 (the two warnings `consolidation_owed=P33` and `oversized_doc_sections=8` predate the phase).
3. `python3 scripts/workflow.py sync-agents --check` → in sync; and the four managed files' frontmatter: mid `sonnet`/`high`, high `opus`/`high`, design-drafter `opus`/`high`, Explore `haiku`/`high` with `tools: Read, Grep, Glob` and `omitClaudeMd: true`.
4. Byte-identity of the two tier bodies below the frontmatter (`diff <(tail -n +9 .claude/agents/slice-executor-mid.md) <(tail -n +9 .claude/agents/slice-executor-high.md)` → empty) and `Agent` last on both `tools:` lines.
5. `executor-route` probes against the live repo: bare (five rows, `cheap  mid  haiku  high  executors.toml`, `agent files: in sync`, `proxy=none`); `P32.DECOMP` and `P32.REVIEW` → `route=high`; `P32.S2` → `route=mid`, `model=sonnet`; `P32.S6` → `route=cheap`, `model=haiku`, `attribution=Claude Haiku 5.5`; `P32.S6 --retry` → `route=high`, `attempt=2`; `--drafter` → `subagent_type=design-drafter`; `--explore` → `subagent_type=Explore`; `ANTHROPIC_BASE_URL=http://127.0.0.1:10100 … executor-route P32.S6` → `model=sonnet` plus a `fallback=` line; `CLAUDE_CODE_EFFORT_LEVEL=high … executor-route P32.S2` → a `warning=` line.
6. The toml rejections, in a **throwaway copy** of the repo (never the live file): a `mode = "flex"` line → `retired in workspace v53`; `[claude.cheap] model = "claude-haiku-5-5"` → `must be an Agent-tool alias`; `[claude.nope]` → `unknown route`; `effort = "hgih"` → `effort must be one of`.
7. `python3 scripts/workflow.py dispatch-summary --phase P32` → `records=8` (DECOMP, S1, S2, S3 ×2 — one `blocked`, one `done` at `attempt=2` — S4, S5, S6), routes `high` 3 / `mid` 4 / `cheap` 1; `dispatch-summary --slice P32.S3` → two lines. `dispatch-summary --json | python3 -c 'import json,sys; json.load(sys.stdin)'` parses.
8. `python3 installer/build.py --check` → OK; `grep -n '^WORKSPACE_VERSION' installer/main.py` → 53; `grep -m1 '^## v' CHANGELOG.md` → `## v53 — 2026-10-12`; the v53 section has a **Migration notes** bullet.
9. The derived seed: `python3 -c 'import sys; sys.path.insert(0,"installer"); from build import derive_executors_seed; print(derive_executors_seed(open("executors.toml").read()))' | grep -n 'claude.cheap\|cheap-route'` → the `[claude.cheap]` block commented, markers intact; the live `executors.toml` keeps it uncommented.
10. `wc -c CLAUDE.md` ≤ 12288.
11. `grep -rn 'economy\|flex\|executor-mode\|EXECUTOR_PRESETS' scripts/workflow.py executors.toml .claude CLAUDE.md installer/main.py installer/build.py README.md README.en.md docs/retrofit-guide.md` → only the intended migration sentences (the engine's v53 message, the toml header line, the Korean README paragraph, the retrofit guide's v53 sentence); CHANGELOG mentions outside `## v53` are history and fine.
12. `bash tests/retrofit_smoke.sh` — **once**, in the foreground, as the only command in its Bash call; expect `ALL RETROFIT SMOKE TESTS PASSED`, 258 PASS / 0 FAIL.
13. Commit attribution follows the recorded model (D7): for the eight phase commits since `1a159b0` (`git log --format='%h %s%n%(trailers:key=Co-Authored-By,valueonly)' 1a159b0..HEAD`), the `Co-Authored-By` name matches the `model:` the slice's `result.md` verdict block records (DECOMP/S1/S4 → Opus, S2/S3/S5 → Sonnet, S6 → Haiku; the two chore commits for P33/P34 and the S3 block are the orchestrator's or the blocked executor's).

## Judge

- Did the objective ship, item by item against `intent.md`'s **Confirmed Intent**: one engine-owned table with the shipped rows; dispatch-time model and effort through the skills; frontmatter as fallback only; the cheap route on here and seeded commented-out, falling back under the proxy; design-drafter on the high row; the project `Explore` agent on haiku @ high with per-call upgrade; the `Agent` tool in both tiers for read-only lookups only; the dispatch record and summary; `model`/`effort` in the verdict block; attribution by recorded model; orchestrator effort untouched; v53; the retired `executor-mode` and presets; smoke test and CHANGELOG. Anything the intent promised that the phase did not ship is a finding.
- Did each slice meet its plan, with deviations explained? Known, explained deviations you should not re-find: S1 pulled the installer `Explore.md` entries forward from S5; S1's `warning=` lines drop the "(H1)/(H2)" tags; S3's second attempt after a permission block (not an escalation); S4 compressed the `CLAUDE.md` wording to fit the cap; S5 replaced a BSD-incompatible `sed` with python; S6 ran the smoke suite twice and the CHANGELOG v53 bullets name the retired words on purpose.
- **Cross-check the notebook against the logs:** a decision or constraint a `result.md` records that no longer appears in `phase.md` (`## Decisions` D1–D14, or consumed on purpose) is a finding. In particular: the S1 `result.md` settled the exact `executor-route` output and the toml value checks (D2/D4 were corrected in place — confirm they match what shipped); S2's `dispatch-summary` header-per-line and existence rules; S4's `CLAUDE.md` cuts; S5's nested-rename counts.
- **The `## Doc impact` list** must cover every durable-truth change: operations (*Executor tiers*: table, `executors.toml` schema, `executor-route`, the instrument, Explore, the Agent tool, the dispatch protocol, the cheap route, the migration, orchestrator-effort guidance, installer seed), decisions (route table supersedes v29/v31 presets, v45 `executor-mode`, v46 "haiku never a tier", v0013's frozen effort; reads delegated / writes never), architecture (Explore in the agent set, dispatch-time resolution, `events.jsonl`'s first reader, nesting depth), qa (baseline 258 and the new pins). A durable change without a line is a finding. The notebook's every-slice doc-debt note says open job D51 overlaps — report that overlap for the docs phase, not as a finding.
- **Route the one `## Operator Questions` entry** (v53 vs the parallel P33/P34, which ship v54 on a branch not yet merged into `main`): with the gate waived there is no walkthrough, so list it for the orchestrator as a **deferred job** to file (title, reason, trigger), and state the facts as of your run (`git log --oneline main..phase/P33-*`; whether any `merge(P33)` commit exists; `WORKSPACE_VERSION` on `main`). Also note P33's branch edits `scripts/workflow.py`, `do-whole-phase` and `CLAUDE.md` too — an observation for its integration, outside this phase's boundary, never a finding here.
- Boundary discipline: anything you notice outside the 21 files (for example the oversized doc sections, P33's own state, the operations doc being behind) is an observation or a deferred-job candidate, not a finding.
- The phase shipped no design round and no mockup: nothing to check there.

## Return

`result.md` first with the verdict block (`status`, `tier: high`, `model` and `effort` copied from the `## Dispatch` section at the end of this plan, `summary`, `files_changed` — only `result.md` and `phase.md` — `validation` with every command above and its outcome, `deviations`, `doc_versions: none — deferred to a docs phase`, `review_verdict`, `walkthrough: none`, `explain: not written — run /explain for this phase`), then the numbered findings (if any) with proposed fix slices (`P32.F<n>`, scope line and `risk`: `high` for a defect in a `tier: mid` slice), the deferred jobs to file, the observations, and the smoke count. On `changes_requested` or `blocked`, stop after the judgment — no pass-only work. Edit `phase.md`: `## Now` for the orchestrator (verdict, what is owed to the docs phase, the deferred job to file), nothing in `## Slices`, no decision dropped.

## Dispatch

```
slice=P32.REVIEW
phase=P32
kind=review
risk=high
attempt=1
route=high
reason=kind review
tier=high
subagent_type=slice-executor-high
model=opus
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Opus 5.5
explore_model=haiku
explore_effort=high
```
