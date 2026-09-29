# Plan — P26.REVIEW (review)

## Context

P26 replaced the Claude Design + `DesignSync` design loop with design files kept in the repo and a dedicated drafter, released as **workspace v47**. See `intent.md`: the five deliverables, the fixed governance, no interim viewer, Claude Code only, and a later dashboard repo that reads the contract.

The slices:
- **S1:** the schema-1 on-disk contract plus `design-init/open/check/close/register`.
- **S2:** the `design-drafter` agent, following the high tier.
- **S3:** the `design-cowork` rewrite, with a 37-row governance audit.
- **S4:** the `CLAUDE.md`, do-*, create-phase, executor, banner and README sweep, plus the v47 CHANGELOG.

The acceptance gate is **waived** (machinery only, no `## Operator Runtime` in this repo), so there is no walkthrough.

## Boundary

`python3 scripts/workflow.py phase-scope P26` covers range `869f207..HEAD`, 6 commits, and 18 product files:
- `.claude/agents/{design-drafter,slice-executor-mid,slice-executor-high}.md`;
- `.claude/skills/{create-phase,design-cowork,do-next-slice,do-whole-phase}/SKILL.md`;
- `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `README.en.md`, `bootstrap_agentic_workspace.sh`, `executors.toml`;
- `installer/{README.md,build.py,main.py}`, `scripts/workflow.py`, `tests/retrofit_smoke.sh`.

Re-run only the `## Regression Checklist` lines (`docs/current/qa.md`) whose surface these files feed. Never re-run the whole list. Anything outside the boundary is an observation or a deferred-job candidate, never a finding.

## Review

1. **Validate all slices together:**
   - `python3 installer/build.py --check`;
   - `python3 scripts/workflow.py sync-agents --check`;
   - `python3 scripts/workflow.py validate`;
   - in its own foreground Bash call with a 600 s timeout: `bash tests/retrofit_smoke.sh` (expect 195 PASS / 0 FAIL);
   - the in-boundary checklist lines.
2. **Exercise the contract end to end yourself** in a scratch fresh install (install from the built `bootstrap_agentic_workspace.sh` into a scratch dir outside the repo, with `AGENTIC_DESIGN_REGISTRY` and `HOME` pointed at scratch paths). Don't rest on the slices' reports. Run:
   - `design-init` → `design-open` → write two numbered cards by hand with valid `@dsCard` line 1 → `design-check` passes;
   - a gap or unnumbered card fails with named problems;
   - `design-close --words` snapshots the round, rewrites line 1 only, and a re-run is idempotent;
   - a supersede chain (`design-close --superseded` → `design-open` in the same slice);
   - `design-register` is idempotent;
   - confirm `~/.config/agentic-workspace` was never created.

   Compare the on-disk result against the contract summary at the end of `slices/P26.S1/result.md`. A separate dashboard repo will build against that summary, so any mismatch between it, the `design-cowork` contract section and the engine is a finding.
3. **Intent coverage.** Each of the five deliverables is present:
   - the contract;
   - the drafter, background-dispatchable, using `frontend-design` only on new-direction rounds;
   - the `design-cowork` rewrite, with `DesignSync` retired and the bundle import optional;
   - the hard-rule reword in `CLAUDE.md` L52;
   - the register hook.

   Also confirm: no interim viewer; Claude Code only; no claude.ai account needed anywhere.
4. **Governance held.** Cross-check S3's governance audit (`slices/P26.S3/result.md`) against `git diff 869f207..HEAD -- .claude/skills/design-cowork/SKILL.md`, and spot-check at least five rows. Then check the per-round co-work steps agree across `design-cowork`, `do-whole-phase` and `do-next-slice`:
   - the stop and commit counts;
   - PENDING #1 / #2;
   - literal signoff.
5. **Consistency sweep:** `grep -rn "DesignSync\|Claude Design" CLAUDE.md .claude installer/main.py README.md README.en.md docs/retrofit-guide.md`. Only the optional bundle import and deliberate "no DesignSync" lines may remain.
   - The drafter's frontmatter is valid YAML (no unquoted `: ` in `description:`).
   - `CLAUDE.md` is within its size cap.
6. **Doc impact.** Verify that `phase.md`'s `## Doc impact` covers every durable-truth change: operations, architecture, decisions and qa. Return `doc_versions: none — deferred to a docs phase`. The gate is waived, so write no gate sections.
7. **Route every `## Operator Questions` entry.** The one entry asks whether a repo needs more than one design project. With the gate waived, return it as a deferred-job spec for the orchestrator to file, and as a question for the orchestrator to relay to the operator. List any other deferred-job candidates as specs (title, reason, trigger), for example S4's observation that nothing checks a design phase ends with no `open` round. **Never run `defer-job` yourself.**
8. Rewrite `## Now` as the close-out, consume the `for P26.REVIEW` notes, and write `result.md` with the verdict block first.

## Verdict

- **`pass`** when everything holds. Findings you repair inside the notebook are fine; note them. Never edit source.
- **Otherwise:** finish every check first, then return `changes_requested` with numbered findings and proposed fix slices, each rated. A fix to a defect in a slice whose verdict reads `tier: mid` (S2 and S4) is `risk: high`.

Also return `explain: not written — run /explain for this phase`.

## Re-review after P26.F1

The first review returned `changes_requested` with findings 1–4, and fix slice `P26.F1` (commit `b84eb1e`) addressed them. See `slices/P26.F1/result.md`. Re-run the review over the **whole** boundary (`phase-scope P26`; the range now ends at HEAD and includes the F1 commit), not only the fixes:

1. **Validate everything together.** Run `build.py --check`, `sync-agents --check`, `validate`, and smoke on its own (expect 195 PASS). Run the in-boundary checklist lines.
2. **Verify each finding is fixed, with your own probe:**
   - **Finding 1:** the drafter's `frontend-design` licence is keyed to the handoff line, and a missing line becomes an open question.
   - **Finding 2:** in a scratch install, `//` and `http://` fail with a named reason, while `https:`, `data:`, `../tokens.css` and `#` pass.
   - **Finding 3:** the CHANGELOG is consistent.
   - **Finding 4:** the do-* feedback step writes the revision handoff and reads back, matching `design-cowork`.
3. **Judge F1's own call:** in-page `#` fragments stay allowed although the contract text does not name them (a reading of the inline-SVG rule). Either accept it, or make the contract text name `#` explicitly as a finding, so the contract, the engine and the dashboard summary agree. The dashboard repo builds against the contract text.
4. **Check that F1 introduced no regression.** It widened the rejected set to `mailto:` / `tel:` / `javascript:` / `about:`. Confirm the contract section, the engine and the relay-ready dashboard summary in your earlier `result.md` all agree now; update that summary if needed.
5. **Operator question: already routed.** It is filed as **D29**, and D30/D31 are also filed. Confirm and don't re-list them.
6. **Doc impact list:** confirm it's complete, including F1's three lines.
7. Rewrite `result.md` (verdict block first) and `## Now`.

Verdict rules as above. Also return `explain: not written — run /explain for this phase`.
