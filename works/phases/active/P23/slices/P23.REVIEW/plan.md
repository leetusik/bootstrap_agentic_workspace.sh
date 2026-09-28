# Plan — P23.REVIEW (review): phase review

## Context

P23's objective (`phase.json`, `intent.md`): bring `CLAUDE.md` from 50,048 B / 49,646 chars (over Claude Code's 40k-char per-file warning, loaded into every session and every executor dispatch) down to D8's ≤ 12 KB routing layer **without dropping a load-bearing rule**; research first, cut what the code derives, move skill-owned detail to its owner, keep every never-rule in the contract, re-point the smoke pins, rebuild, and ship it as workspace v44. Pays D8.

What the slices report (verify, do not trust): S1 mapped 166 rule units and a 58-entry never-rule floor; DECOMP2 cut S2 → S3 → S4 and recorded the operator's answer to OQ1; S2 cut Workflow Commands and 32 duplicate units and opened v44 (commit `a63ed44`); S3 collapsed the Aside, worktree and design bullets to stubs (`ee84e6a`); S4 rewrote the rest to the outline, landing **12,259 B** with 58/58 never-rules by phrase (`6e06311`). Smoke counted 180 PASS / 0 FAIL at each boundary.

The acceptance gate is **waived** (`phase.json` `acceptance.required: false`, "machinery and doctrine only"), so skip the gate stages: no running product, no walkthrough, no Regression Checklist re-run. Follow the `review-phase` skill's checklist otherwise, and its rule to finish the whole judgment before branching on the verdict.

## Boundary

`python3 scripts/workflow.py phase-scope P23` prints the boundary: range `58d30a5..6e06311`, 7 commits, 13 product files, all modified:

```
.claude/agents/slice-executor-high.md   .claude/agents/slice-executor-mid.md
.claude/skills/do-next-slice/SKILL.md   .claude/skills/do-whole-phase/SKILL.md
.claude/skills/parallel-phase/SKILL.md  CHANGELOG.md  CLAUDE.md  README.en.md  README.md
bootstrap_agentic_workspace.sh  installer/main.py  scripts/workflow.py  tests/retrofit_smoke.sh
```

`CLAUDE.md` is loaded by every session and dispatch and cited by every skill and both executor bodies, so its boundary includes **every inbound reference to it** (step 3). Anything you notice outside that is a deferred-job candidate, never a finding.

## Read

- `CLAUDE.md` (the new contract) and `git show e08bd7a:CLAUDE.md` (the pre-P23 contract, 50,048 B).
- `works/phases/active/P23/phase.md` whole, `intent.md`, `phase.json`.
- Each slice's `result.md`, head first (verdict block), whole where the detail matters: S1 §3–§5 is the map; S2's cut list with carriers; S3's stub phrases; S4's per-section bytes and 58-row never-rule table.

## Check

1. **Validate all slices together**, each in its own Bash call:
   - `python3 scripts/workflow.py validate` (the P21/P22 `consolidation_owed`, `stale_docs` and `oversized_doc_sections` advisories are pre-existing).
   - `python3 installer/build.py --check`.
   - `wc -c CLAUDE.md` ≤ 12,288; `wc -c .claude/agents/slice-executor-*.md`; the two executor bodies identical below the frontmatter.
   - Smoke **once**: `bash tests/retrofit_smoke.sh > <your scratch>/p23-review-smoke.log 2>&1` as the **only** command in its Bash call, foreground, `timeout: 600000` (chained or backgrounded runs have stalled at 0 % CPU here). Then, in a separate call, count `^PASS` / `^FAIL` and read the tail. Expect 180 / 0.
2. **No load-bearing rule lost: the heart of this review.** Do not stop at S4's table.
   - Cross-check S4's 58-row table against the *Never-rule floor* note: every N-id present, and each phrase actually states that rule (not merely a substring match).
   - Run your own independent sweep of the **pre-P23** contract: every prohibition or obligation clause (`never`, `do not`, `don't`, `only when`, `only after`, `must`, `may not`, `STOP`, `refuse`, `cannot`) and every operator- or orchestrator-only command. For each, find where it lives now: a contract stub, or the named skill / executor body / engine behavior that carries it. A clause whose only carrier was the old contract and which now appears nowhere is a **finding**.
   - Give extra attention to what was cut as "carried elsewhere" but that a reader outside that skill needs, for example: REVIEW / `DECOMP2` / paired apply never pre-planned; `ready` slices dispatch from their approved plan; a design phase's gate follows its mockup; the push-only-when-asked remote variant; the docs-phase `consolidation` debt blocking archiving; the idle-window limits.
   - Check both executor bodies read coherently with the new contract. Pay particular attention to the three carve-outs (decomposition / review / docs) and the docs-slice carve-out's wording against the operator-approved text in `slices/P23.DECOMP2/plan.md`.
3. **Every inbound reference still resolves.** Grep `.claude/` (skills and agents), `installer/`, `README*.md` and `works/templates/` for references to `CLAUDE.md`, "the contract", or a contract section or bold lead. Include *Workflow Commands*, *Hard Rules*, *Driving This Workspace*, *Orchestrator and executor*, *Making a phase ≠ executing it*, *Commit Convention*, "the slice-files rule", "the small-test-files rule", and "see `CLAUDE.md`". Each must point at text that still exists and still says what the reference claims. A dangling or now-false reference inside the boundary is a finding.
4. **Intent coverage.** Walk `intent.md` steps 1–5 and the scope boundary:
   - research first;
   - Workflow Commands cut with its pins re-homed;
   - skill-owned detail moved to its owner;
   - every never-rule kept;
   - pins re-pointed, installer rebuilt, `WORKSPACE_VERSION` 44, and one `## v44` CHANGELOG section with a Migration notes line that is accurate for an adopter;
   - executor bodies grew by far less than the contract shrank;
   - no adopter edited, and no new loading mechanism.
5. **Doc impact coverage.** Does `phase.md`'s `## Doc impact` list cover every durable-truth change the phase made?
   - This includes the contract's shape and its `--help` reference, the executor carve-out, and the `--order` / `--depends-on` help.
   - It also includes the template tag, the smoke pin lists, and v44.
   - Decide whether the smaller skill edits (D-3 in `parallel-phase`, D-4 in the do-* skills) change durable truth.
   - A missing note is a finding.
6. **Notebook vs logs.** Cross-check `## Decisions` and the notes against every slice's `result.md`. A decision or constraint a `result.md` records that `phase.md` no longer carries (and did not consume on purpose) is a finding.
7. **Operator Questions routed.** OQ1 is recorded as answered at the DECOMP2 gate and landed by S2; confirm that. Any other entry must be routed (the gate is waived, so a route means a deferred job).
8. **D13.** Its trigger fired in S3. Confirm that the any-browser sentence is byte-identical to the pre-P23 text. Leave D13 open, and mention it in `result.md` and your return.
9. **Deferred-job candidates.** Validate the three in the notebook (executor slimming; whitespace-normalized contract pins; a never-rule floor pin list) and add any you find outside the boundary. For each, give title, reason and trigger; the orchestrator files them.

## Verdict branch

- **Pass:** verify the Doc impact list (above) and report `doc_versions: none — deferred to a docs phase`. Write no doc versions: the gate is waived and neither gate section changed. The orchestrator records the verdict, files the deferred jobs and drops D8.
- **`changes_requested` / `blocked`:** stop after judgment; return numbered findings and proposed fix slices (`P23.F<n>`, one line of scope each, with the `risk` each needs).
- Either way: write `result.md` verdict block first and edit `phase.md` (`## Now` last). Never edit source, never commit, never run `review-phase`, `defer-job`, `drop-deferred` or any status command, and do not touch `works/deferred/`.

## Return

`review_verdict`; a one-line summary; files_changed; validation outcomes (bytes, counted PASS/FAIL); the never-rule and inbound-reference results; numbered findings (if any) with proposed fix slices; deferred jobs to file (title / reason / trigger); the D13 mention; `doc_versions: none — deferred to a docs phase`; `explain: not written — run /explain for this phase`.
