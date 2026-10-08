# Plan — P30.REVIEW (phase review, acceptance gate REQUIRED)

**Tier:** high (review, by kind). Review P30 against its objective and `works/phases/active/P30/intent.md`. The confirmed intent is the yardstick:

- `/rotate-backlog` archives the clean phases first.
- By default it then proposes a docs phase for the phases held back only by doc debt, and confirms it once.
- On the yes it creates the phase and fills `intent.md` through create-phase's docs-phase route, then STOPs.
- An `archive-only` opt-out exists.
- The create-phase confirmation gate is unchanged.
- No duplicate docs phase is proposed.
- Phases with other blockers are reported, never proposed.
- The docs phase runs on the default stream.
- The change ships as v51 with the installer rebuilt.

Read `phase.md` in full: `## Decisions` D1–D10 and their "Final" clauses, `## Doc impact`, `## Operator Questions` and `## Notes for later slices`. Read the three slice `result.md` files as well.

## Boundary

`python3 scripts/workflow.py phase-scope P30` gives the range `0f69039..HEAD`, 3 commits and 9 product files:

- the `archive-phase`, `create-phase` and `rotate-backlog` skills
- `CHANGELOG.md` and `README.en.md`
- `bootstrap_agentic_workspace.sh`, `installer/main.py` and `scripts/workflow.py`
- `tests/retrofit_smoke.sh`

Review **only** this boundary. Anything outside it is an observation, never a finding, and comes back as a deferred-job candidate.

## 1. Validate all slices together

1. `python3 installer/build.py --check` must pass.
2. `python3 scripts/workflow.py validate` must pass.
3. **The smoke suite, run exactly once, as the only command in its own foreground Bash call:** `bash tests/retrofit_smoke.sh`. The baseline is 239 PASS / 0 FAIL, as of both S1 and S2. Report the totals.

## 2. Judge against the intent: read the code

Read `rotate_backlog`, `_phase_blocker_kinds` / `_phase_blockers`, the proposal printer, `next_phase_id`, the shared merged-parallel helper, `new_phase`'s `--consolidates` validation, `docs_debt`'s `paid by:` line and `validate`'s shape check. Check:

- **D4 invariant:** the refusal text of `archive-phase`, `archive-all` and rotate is identical to before. Diff against `git show 0f69039:scripts/workflow.py`. `parallel-merge-finish` output is unchanged.
- **Debt-only and covered logic:**
  - A not-done covering phase suppresses only the phases it names.
  - A done covering phase no longer suppresses.
  - An unmerged parallel phase is never proposed.
  - Phases with other blockers are never proposed.
- **The proposal is read-only.** Rotate never runs `new-phase`.
- **Nested-awareness:** the `create:` and `scope:` lines use `WORKFLOW_CMD`.
- **The recorded deviations:** S1's double-quote `_shell_arg` and the `validate` shape check; S2's `WORKSPACE_VERSION` location in `installer/main.py` and its `argument-hint`. Judge each.

## 3. Gate stages: open the running product yourself

The product is the workspace engine plus the skills, so the "running product" is `workflow.py` run in **scratch copies**.

**NEVER run a real `rotate-backlog` (or `archive-*`, or `new-phase`) in this checkout.** That would archive P25 and create phases. Use a `cp -R` of this repo into the session scratchpad, with `git status` checked in the real repo before and after. A fresh `--at-root` install from the built `bootstrap_agentic_workspace.sh` with a fabricated debt-only phase is also acceptable.

Walk as a first-time operator, reading every printed line for clarity and accuracy:

1. In a scratch copy of this repo, run `rotate-backlog`. Expect P25 archived, then the proposal for P26–P29 as `phase=P31`, with name, objective, `create:`, `scope:` and the closing line.
2. Run the printed `create:` line **verbatim**, copy-pasted, in the copy. Check:
   - `phase.json` has `consolidates`;
   - `docs-debt` shows `paid by: P31` per phase;
   - a second `rotate-backlog` prints `docs_phase_covered=P31 …` and no proposal;
   - `validate` passes.
3. Run `rotate-backlog --archive-only` in a fresh copy. It prints no `docs_phase` line.
4. Refusals: `new-phase --consolidates` naming P25 (in a fresh copy, where it is clean) or a nonexistent id writes nothing.
5. **The rotate-backlog skill text against behaviour.** Read `.claude/skills/rotate-backlog/SKILL.md` step by step beside steps 1–3, as if you were the orchestrator running `/rotate-backlog` and `/rotate-backlog archive-only`. Check that:
   - every key it reads is one the engine prints;
   - the confirm-once gate is explicit;
   - the `intent.md` fill points at create-phase's docs-phase route;
   - it STOPs before decomposition;
   - it never mentions starting a worktree.
   
   Also check that the create-phase docs-phase route, the archive-phase skill, the `README.en.md` row and CHANGELOG v51 match the behaviour. Smoke Test 0's create-phase pins must still hold. A text that claims behaviour the engine lacks is a finding.
6. Confirm the frontmatter of the three edited skills is valid YAML. Quoted descriptions with `: ` count, and the `argument-hint` must parse. Check with a short `python3 -c` using a minimal YAML-ish check, or `yaml` if it is available.

**Regression Checklist.**
- In `docs/current/qa.md` `## Regression Checklist`, re-run **only** the lines whose surface one of the 9 boundary files feeds: the archive/rotate commands, `new-phase`, `docs-debt`, `validate`, the installer build and the smoke suite. Never re-run the whole list.
- Append this phase's headline checks as new lines, in the section's format:
  - the rotate proposal after archiving;
  - `--archive-only`;
  - `--consolidates` marks a covering docs phase, so no duplicate proposal is made;
  - `docs-debt` `paid by:`.
- This is the review's gate-section write, done with `doc-new-version --doc qa --source P30.REVIEW` → edit only the returned `edit_path` → `rebuild-docs`.
- `## Operator Runtime` needs no change.

**Route every `## Operator Questions` entry.** There are none at plan time; check again.

## 4. Verdict

- **On a pass:**
  - Verify that `## Doc impact` is complete for what the phase changed. Return `doc_versions: none — deferred to a docs phase`, apart from the qa gate-section version.
  - Return the `explain: not written — run /explain for this phase` pointer.
  - Return a **`walkthrough`** the operator can follow in about five minutes:
    - In a scratch copy (`cp -R` of the repo to a temp dir), run `rotate-backlog` and read the proposal.
    - Run the `create:` line there, then rotate again to see the covered line.
    - Run `--archive-only`.
    - Say what each step should print.
    - Then the real-use note: on accepting, `/rotate-backlog` in this repo would archive P25 and propose P31 for P26–P29.
- **On a non-pass:** finish the whole validation and judgement first. Then return numbered findings with proposed fix slices (kind `fix`, risk `high`, because both slices ran on mid and a retry never returns to mid) and skip the pass-only steps.
- **Either way:** list out-of-boundary observations as deferred-job candidates.

Write `result.md` with the verdict block first: `review_verdict`, `walkthrough`, `doc_versions`, `explain`, and the deferred candidates. Edit `phase.md` `## Now`. Don't commit. Don't run `review-phase`, `accept-gate` or `set-*-status`. Edit no product source.
