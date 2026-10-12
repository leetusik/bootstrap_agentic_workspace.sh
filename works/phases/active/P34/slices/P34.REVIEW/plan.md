# Plan — P34.REVIEW (phase review, gate required)

## Context

P34 shipped boundary-gated compaction as workspace v55 in four slices: S1 the engine commands `compact-gate` / `compact-resume`; S2 the two hooks in `.claude/settings.json` and the installer's additive hooks merge; S3 `## Compact Instructions` in `CLAUDE.md`, the reorder of `do-whole-phase` / `do-next-slice`, and the phase's `## Doc impact` list; S4 the release (version, CHANGELOG, retrofit guide). The acceptance gate is **required** (`phase.json` `acceptance.required: true`), so this review runs the gate stages and returns a walkthrough. Follow the `review-phase` skill (`.claude/skills/review-phase/SKILL.md`) — this plan only pins what that skill leaves to the plan.

Read first: `CLAUDE.md`; `works/phases/active/P34/intent.md` (confirmed intent, clarifications, the research notes); `phase.md` whole (Decisions, Doc impact, Operator Questions, the two remaining notes — the one addressed to you is consumed here); each slice's `result.md` head-first (`P34.DECOMP`, `S1`, `S2`, `S3`, `S4`), whole where the detail matters — **S3's log matters**: the mid executor applied the first `CLAUDE.md` edits, then the auto-mode classifier denied all of its Bash, and the orchestrator finished the slice inline on the operator's explicit word; its `result.md` lists the cut wordings and the measurements.

## Boundary

`python3 scripts/workflow.py phase-scope P34` measures from P34's creation commit, which also created P33 (the two phases were created together) — so its 24-commit range and 25-file list include P32's and P33's files. **P34's own boundary is the five commits `410a0e6..HEAD`** (`git diff --stat 410a0e6..HEAD -- . ':!works' ':!docs/index.json'`): `scripts/workflow.py`, `tests/retrofit_smoke.sh`, `installer/main.py`, `.claude/settings.json`, `CLAUDE.md`, `.claude/skills/do-whole-phase/SKILL.md`, `.claude/skills/do-next-slice/SKILL.md`, `CHANGELOG.md`, `docs/retrofit-guide.md`, `bootstrap_agentic_workspace.sh`. Record both (the engine's print and the narrowed range with the reason) in `result.md`. Anything outside is an observation (a deferred-job candidate for the orchestrator to file), never a finding.

## Validate all slices together

Each slice's validation commands are in its `result.md` verdict block; together they reduce to:

- `python3 scripts/workflow.py validate` (pre-existing P32/P33 doc-debt and stale-docs warnings are expected, not findings)
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh` — **alone in its own Bash call**, once; expect `ALL RETROFIT SMOKE TESTS PASSED` with 289 PASS (count `^PASS` lines from that same run's captured output — do not run it twice)
- `wc -c CLAUDE.md` ≤ 12,288; the skills' offsets as S3 recorded them (recompute: the byte offset where the `- Commit at every clean slice boundary` bullet ends in `do-whole-phase` and where `7. Commit by default` ends in `do-next-slice`, both < 16,000)
- `grep -n "^## v55" CHANGELOG.md` → line 12; `WORKSPACE_VERSION = 55`

## Gate stages (the manifest runtime is the CLI — `## Operator Runtime` in `docs/current/operations.md`, l.~1817: no browser surface, verification is live CLI runs in this checkout, mutating probes in `cp -R` copies)

1. **Independent spot-check, in this checkout (read-only for the tree):** pipe fabricated hook JSON through both commands and read stdout, stderr and the exit code yourself — `printf '{"trigger":"manual"}' | python3 scripts/workflow.py compact-gate` (no stdout, rc 0, trace `rule=manual`); `printf '{"trigger":"auto","session_id":"review","scratchpad_dir":"<your scratchpad>"}' | python3 scripts/workflow.py compact-gate` (this slice is `in_progress`, so a block JSON naming `P34.REVIEW`, rc 0 — delete the counter file you created afterwards); the same with `"agent_id":"x"` added (allow, `rule=subagent`); with `AGENTIC_COMPACT_CEILING=1` and a `transcript_path` pointing at a two-line fake transcript in your scratchpad whose assistant line carries `message.model` `claude-fable-5-1` and `message.usage` (allow, `rule=ceiling`); garbage stdin (`printf 'x'`, allow, rc 0, `rule=error`); `printf '{}' | python3 scripts/workflow.py compact-resume` (prints `compaction=done source=compact`, the `next` output with `current_slice=P34.REVIEW`, and the resume line; note that it restamps the two dashboards — accepted by Decision). Then the **boundary case in a `cp -R` copy** of this checkout under your scratchpad: commit everything there, `finish-slice`-free check — set the copy's pointer to a clean boundary by committing, run `next`, then the gate (allow, `rule=boundary`), then touch an untracked product file (block, `dirty: 1 file`). Confirm `.claude/settings.json`'s two hook entries match the Decisions' command lines and `timeout` 15. Check the installer end to end once: `sh bootstrap_agentic_workspace.sh <mktemp -d> --at-root --force-empty-ok` yields a `settings.json` with both hooks and a marker at `workspace_version` 55 (the smoke suite covers retrofit/update/nested; do not repeat those).
   - **What you cannot do here:** load the hooks into a live Claude Code session — project hooks load at launch, and this session (and you, its subagent) predate them. That is the operator's walkthrough step, not a finding and not a `needs_operator`.
2. **Fresh-eyes walkthrough, inside the boundary:** read `## Compact Instructions` and the reordered first 16 KB of each execution skill as a first-time reader would — is the resume line findable and unambiguous; does step 3 of `do-next-slice` still read as one instruction with the co-work pointer; does `CHANGELOG.md` v55's Migration notes tell an adopter exactly what to do; does `docs/retrofit-guide.md` now describe the hooks merge consistently. Everything confusing goes into the walkthrough as a finding, never into a fix.
3. **Checklist lines inside the boundary:** `## Regression Checklist` in `docs/current/qa.md` (l.~318–358) is this repo's machinery list, re-run as a whole by the smoke suite plus `validate`; `scripts/workflow.py` and `tests/retrofit_smoke.sh` feed every line, so **every line is inside** and the single smoke run above is the re-run. Record the classification table in `result.md` (block · lines · inside/outside · result: all inside, the suite's PASS count as proof; the P33 line's "247 PASS" is a stale number the review's appended line supersedes). **Append** this phase's headline checks as `- [ ] … (P34)` lines: `compact-gate` blocks mid-slice / on a dirty tree and allows at a clean boundary, on manual, on `agent_id`, above the ceiling, after the cap, on garbage input, always exit 0; `compact-resume` prints the pointer and the resume line; a fresh install ships both hooks; retrofit / `--update` / nested merge hooks additively and idempotently with foreign handlers kept; the contract ≤ 12,288 B with Test 0's pins; the smoke count (289 PASS at P34).
4. **Route the operator question** (`phase.md` `## Operator Questions`, one entry: set `/autocompact 300k` now?) into the walkthrough as a decision for the operator. Add any new question you find there too, routed the same way.
5. **Return the walkthrough** — short and concrete, in the CLI runtime: (a) relaunch Claude Code in this checkout (project hooks load at launch) and run `/hooks` — both `PreCompact`/`auto` and `SessionStart`/`compact` entries appear; (b) run `/compact` once — manual compaction is never blocked, and the resumed context shows `compaction=done source=compact`, the pointer and the resume line; (c) optionally pipe `printf '{"trigger":"auto","session_id":"me"}' | python3 scripts/workflow.py compact-gate` mid-slice and at a boundary to see the two decisions; (d) decide the question: `/autocompact 300k` (recommended once the veto is live, the operator's own setting) or keep 500k; (e) accept with `python3 scripts/workflow.py accept-gate P34 --clear [--note "..."]`.

## Doc duties on a pass

- Verify `phase.md`'s `## Doc impact` (8 lines) covers every durable-truth change the slices' logs describe — the S3 log's contract trims, the S4 retrofit-guide edits (direct edits to a non-versioned doc, so no line needed — say so) — and return `doc_versions: none — deferred to a docs phase`.
- Write the two named gate sections with `doc-new-version` (`--source P34.REVIEW`): `## Regression Checklist` in `qa` (stage 3's appended lines, editing only that section) and `## Operator Runtime` in `operations` **only if this phase changed it** — it did not (CLI runtime unchanged; the hooks run inside the operator's Claude Code session, which that section may now mention in one line if you judge it part of "how the operator runs the product"; otherwise write no operations version and say so). Then `python3 scripts/workflow.py rebuild-docs` and `validate`.
- Never `accept-gate`, `defer-job`, `review-phase`, `finish-slice`, commits or source edits.

## Return

`review_verdict` (`pass` | `changes_requested` | `blocked`) with numbered findings and proposed `P34.F<n>` fix slices on a non-pass (rated `high` for a defect in a `tier: mid` slice — S2, S4, and S3's executor span were mid), the `walkthrough`, the deferred-job candidates (title · reason · trigger) for the orchestrator to file, `doc_versions`, and the fixed line `explain: not written — run /explain for this phase`. `result.md` verdict block first; edit `phase.md` (consume the note addressed to you, record the review's decisions, rewrite `## Now`).

## Dispatch

slice=P34.REVIEW
phase=P34
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
