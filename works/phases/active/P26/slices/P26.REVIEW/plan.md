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
