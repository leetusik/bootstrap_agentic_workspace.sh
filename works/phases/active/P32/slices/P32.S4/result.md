# Result — P32.S4

- status: done
- tier: high
- model: opus
- effort: high
- summary: Both do-* skills now dispatch every executor through executor-route (resolve, pin a ## Dispatch section, pass model/effort per the pass_* lines, record-dispatch every return), use the project Explore for planning lookups and attribute slice commits to the attribution= line; review-phase and design-cowork follow, CLAUDE.md states the rule in one breath at 12,284 B, and /executor-route replaces /executor-mode. Artifact rebuilt; smoke 253/0.
- files_changed: CLAUDE.md; .claude/skills/do-next-slice/SKILL.md; .claude/skills/do-whole-phase/SKILL.md; .claude/skills/review-phase/SKILL.md; .claude/skills/design-cowork/SKILL.md; .claude/skills/executor-mode/SKILL.md -> .claude/skills/executor-route/SKILL.md (git mv, rewritten); bootstrap_agentic_workspace.sh (rebuilt); works/phases/active/P32/phase.md; works/phases/active/P32/slices/P32.S4/result.md
- validation:
  - `wc -c CLAUDE.md` → 12284 (≤ 12288) — PASS
  - `grep -rn 'economy\|flex\|executor-mode' .claude/skills CLAUDE.md` → no matches (rc 1) — PASS
  - `python3 scripts/workflow.py validate` → exit 0, known warnings only (consolidation_owed=P33, oversized_doc_sections=8) — PASS
  - `python3 installer/build.py` + `python3 installer/build.py --check` → wrote 782,563 B, "in sync"; skill count 18 — PASS
  - `bash tests/retrofit_smoke.sh` (once, foreground, alone) → 253 PASS / 0 FAIL, "ALL RETROFIT SMOKE TESTS PASSED" — PASS
  - dry read of the protocol against `executor-route P32.S5` + `--explore` → example `## Dispatch` below — PASS
- deviations: (1) CLAUDE.md wording is compressed from the plan's suggested text to fit the cap without dropping a rule — line 11 gains "routed by `executor-route`" instead of the longer clause, and line 15 says "`Explore` (haiku; upgraded per call for judgment) only reads, never decides." instead of the executor-specific list; the cuts were taken inside the two paragraphs (details below). (2) `git mv` stages the rename in the index, as the plan prescribed; nothing else was staged and nothing committed. (3) `do-next-slice`'s decomposition paragraph ("`risk` selects the executor tier …") was reworded to "route" and names the cheap row, for accuracy — not in the plan's list, one parenthetical.
- doc_impact: operations.md: Executor tiers — the dispatch protocol (executor-route → ## Dispatch → model/effort on the Agent call → record-dispatch), Explore for planning lookups, attribution by recorded model, /executor-route replaces /executor-mode; orchestrator effort stays at the session level (published: max buys little over high for planning-shaped work) (P32.S4) | decisions.md: dispatch-time model/effort through the skills supersedes v0013's "effort frozen at spawn"; reads delegated to Explore, writes never (P32.S4)

## What changed

- **do-next-slice / do-whole-phase.** The old tier sentence (`do-next-slice` step 3, "Otherwise select the tier … (economy: …; flex: …)"; `do-whole-phase`'s "Tier: …" clause) is replaced by one shared protocol paragraph, byte-identical in both: kind → risk → attempt; (1) resolve with `executor-route <slice_id>` [`--retry`] and `--explore`, bump-up-only via `slice.json` + `rebuild`; (2) pin a final `## Dispatch` (slice lines verbatim + `explore_model=` / `explore_effort=`; under `## Escalation: mid → high` on a retry); (3) dispatch with `model` / `effort` only on `pass_model=yes` / `pass_effort=yes`, `fallback=` informational, `warning=` relayed; (4) `record-dispatch` with the S2 flag list after every return, before `finish-slice`, `--verdict failed` for an empty return, drafter span via `--drafter` lines + `--agent design-drafter`; (5) `Explore` for planning lookups, upgraded per call. It ends with `/executor-route` / `dispatch-summary` and "per-row `[claude.<row>]` overrides are the operator's knob — there are no presets." Escalation text gains "resolve with `executor-route <slice_id> --retry`, pin its lines under that section, … record the second attempt" (and the failed-mid path records `--verdict failed` and takes the same `--retry` path). Review dispatch: "resolve it with `executor-route <P>.REVIEW` (the high row) like any slice". `do-whole-phase`'s idle-window bullet names the project `Explore` at the `--explore` model/effort with the upgrade rule; its drafter step names the `--drafter` lines and the record. Both commit steps gain the attribution sentence.
- **review-phase.** Two sentences after the hand-back paragraph: the verdict block carries `model:` / `effort:` beside `tier:`; the rating reads `tier:` alone; a cheap-route slice counts as mid. `--reviewer slice-executor-high` lines untouched.
- **design-cowork.** Line ~215: spans run "on the route table's high row" (drafter: `executor-route --drafter`); ~810: "(the high row; model and effort from `executor-route <slice_id>`, a `co-work` slice being the high row by kind)"; ~934: the drafter "runs on the route table's high row … pass the `model` / `effort` that `executor-route --drafter` prints on the Agent call, pin nothing in the round folder (the design record is the operator's), and record its return with `record-dispatch <slice_id> --agent design-drafter --route high …`". ~1218 unchanged (still correct).
- **executor-route skill.** `git mv .claude/skills/executor-mode .claude/skills/executor-route`; `SKILL.md` rewritten (frontmatter as the plan specified, unquoted description — it has no `: `; 22 lines): runs `executor-route $ARGUMENTS`, bare also `dispatch-summary`, explains rows / `cheap` inheritance / `[claude.<row>]` + `sync-agents`, relays `fallback=` / `warning=` as-is, edits and commits nothing.

## CLAUDE.md byte budget

12,280 B before → **12,284 B** after (cap 12,288). The plan's suggested text would have landed at ~12,590 B; to fit it, the additions were tightened and these cuts were taken, all inside line 11 and line 15, none dropping a rule or a pin:

- line 11: "`; `python3 scripts/workflow.py --help` is the command reference. In Claude Code the operations are also Agent Skills (`/create-phase`, `/do-next-slice`, `/do-whole-phase`, `/review-phase`, …), and" → "` (`--help`: the command reference), its operations also Agent Skills (`/do-next-slice`, …);" (the workspace ships Claude Code only, so "In Claude Code" carried nothing).
- line 15: "plans each slice into its `plan.md`" → "into `plan.md`"; "state transition" → "state change"; "Every slice is delegated to an executor, never run by the orchestrator, with one exception" → drop the redundant middle clause; "plans at the operator's gate by default (inline only on an explicit `auto`)" → "unless told `auto`"; the executor sentence merged into one "never commits, moves state (bar its decomposition/review/docs carve-outs), edits source on a review or writes product code on `research`"; "failed or empty" → "failed/empty", "and the top tier never escalates" → "which never escalates"; the idle-window sentence reordered.

Every pinned phrase (smoke's CLAUDE.md list, including "dispatching its drafting to `design-drafter` and its mockup build (only on request) to `slice-executor-high`", "the round's lifecycle and the operator's words stay inline", "if the two ever disagree the **kind wins**", "**mid the default**", "never returns to mid", "QA-sweep route", "unless the operator asks for a worktree (v43)") is still asserted green by the smoke run.

## Example `## Dispatch` section (dry read for P32.S5 — not written into S5's plan)

From `python3 scripts/workflow.py executor-route P32.S5` and `executor-route --explore` (2026-10-12, no proxy, no warnings):

```
## Dispatch

slice=P32.S5
phase=P32
kind=implementation
risk=low
attempt=1
route=mid
reason=kind implementation rated low
tier=mid
subagent_type=slice-executor-mid
model=sonnet
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Sonnet 5.5
explore_model=haiku
explore_effort=high
```

Read by the protocol: Agent call `subagent_type: slice-executor-mid`, `model: sonnet`, `effort: high`, background; afterwards `python3 scripts/workflow.py record-dispatch P32.S5 --route mid --tier mid --model sonnet --effort "high" --verdict <v> --attempt 1 --agent slice-executor-mid --duration-ms <n> --tokens <n> --tool-uses <n>`; the commit trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. (Should the orchestrator bump S5 up on a named trigger, the lines would read `route=high` / `slice-executor-high` / `opus`.)

## Smoke

`bash tests/retrofit_smoke.sh` → **253 PASS / 0 FAIL** (baseline before S4: 253/0; S4 adds no assertions). Log kept only in the session scratchpad.

## phase.md

Consumed and removed the eight S4-tagged notes (H1, H2, H5, H6, S1's output note, S2's `record-dispatch` note, S3's `explore_*` note, the headroom note); added D14 (the protocol as stated), two `## Doc impact` lines, notes for S5 (dispatch by the new protocol from S5 on; `/executor-route` exists; old dir flagged on `--update`), for S5/S6 (the `update-workspace` step-8 "preserved mode" wording, out of S4's file list), and for S6 (the exact names); rewrote `## Now`.
