# Plan — P28.REVIEW (review / high)

## What is under review

**P28 "Nested personal install"**: a private, zero-footprint install of this workspace inside a host repo the operator doesn't own. Three slices landed and are committed:
- **S1, the engine:** nested mode gated on `workflow/.agentic-nested.json`, host anchors, host-side `phase-scope`, parallel off, host agents through the rename map, host-relative printed paths, `nested-convention`;
- **S2, the installer:** `--nested` and `--update --nested`, the install-time rewrite, `wf-` clash renames, `settings.local.json`, the `CLAUDE.local.md` import, the `info/exclude` block;
- **S3, texts and release:** skills, READMEs and the guide, v49.

Judge them against:
- `intent.md` (the verbatim request and confirmed intent; clarification 3 is **superseded** by the operator's later word, see below);
- `phase.md` `## Decisions` (Engine contract, Nested installer, Nested texts and release);
- the contract.

**Acceptance gate: waived.** The operator said, on 2026-10-07: "And for the review, just use fake repo. I'll report if any problem with real one." This is recorded in `phase.md` Invariants (c) and `phase.json` `acceptance`. So: **walk a fake host yourself, return the verdict, no walkthrough, no `pending` stop.**

## Boundary

`python3 scripts/workflow.py phase-scope P28` gives range `dc42380..d8c187d`, 4 commits, and 11 product files:
- `.claude/skills/{commit,retrofit,update-workspace}/SKILL.md`;
- `CHANGELOG.md`, `README.en.md`, `README.md`;
- `bootstrap_agentic_workspace.sh`;
- `installer/main.py`, `installer/wrapper.sh`;
- `scripts/workflow.py`;
- `tests/retrofit_smoke.sh`.

Review only this boundary. Anything you notice outside it is an observation for a deferred job, never a finding. Re-run only the `## Regression Checklist` lines in `docs/current/qa.md` (§ at about L255) whose surface these files feed; never the whole list.

## Stages

1. **Validate all slices together:**
   - `bash tests/retrofit_smoke.sh`, as the only command in its own foreground Bash call. It must pass in full (Tests 0–15).
   - `python3 scripts/workflow.py validate`.
   - `python3 installer/build.py --check`.
2. **At-root invariant:** spot-check that a fresh at-root install from the current artifact and one from v48's artifact (`git show dc42380:bootstrap_agentic_workspace.sh`) produce the same tree and outputs. The only expected differences are the version stamp, the three edited skills, the engine file and the `--help` lines. S1 and S2 each ran a differential; you only confirm it, you don't re-derive it.
3. **Fake-host walk** in the session scratchpad. Follow the `(from P28.S2 and P28.S3, for P28.REVIEW)` note in `phase.md`, steps 1–5. Use a local bare repo as `origin` so `git switch -c ticket origin/main` is real. After every step, assert the host's `git status --porcelain` is empty and HEAD is unchanged (except your deliberate product commit in step 2). Read the texts as a first-time operator: are the banner, the `CLAUDE.local.md` block and the README section enough to run the per-ticket flow from start to PR?
4. **Loading (step 4):** try one `claude -p` probe from the fake host root that checks a dispatched executor sees the contract. If it is denied or unavailable, do not retry. List it as an item for the operator to watch in the real repo.
5. **Cross-checks:**
   - `## Decisions` against each `result.md`;
   - the `## Doc impact` list is complete (architecture, operations, qa, decisions; each slice's changes covered);
   - the Operator Question (marker name) is answered and routed;
   - `EXPECTED_SKILL_COUNT` is 18;
   - the v49 CHANGELOG entry matches what shipped.
6. **Security and footprint scrutiny:** the core promise is that nothing reaches the team.
   - Look for any path by which a nested install, update or normal slice could modify a tracked host file, stage a workflow file into the host, or leak through `.gitattributes`, hooks or config.
   - Check the tracked-target refusal and the render-then-write ordering.
   - Check the commit skill's new `Bash(git -C workflow …)` pre-approvals: no push, nothing broader than the plan intended.

## Verdict

- **On `pass`:**
  - verify the Doc impact list;
  - return `doc_versions: none — deferred to a docs phase`, writing only the two named gate sections if the review rules call for it;
  - return `explain: not written — run /explain for this phase`;
  - return the fake-host results and the items for the operator to watch in the real repo.
- **On `changes_requested`:** complete the validation and judgment first, then return numbered findings with proposed fix slices and their risk. A fix to mid-tier work (S3: `tier: mid`) is rated `high`.
- **Never edit source.**
- Deferred-job candidates (observations outside the boundary, e.g. engine messages that don't follow a clash rename) go back to the orchestrator to file.

Write `result.md` with the verdict block first, update `phase.md` (`## Now`; consume the REVIEW note) and return your structured verdict.

## Re-review after P28.F1

The first review returned `changes_requested` with one blocking finding: a tracked host `.gitignore` negation outranks `info/exclude`. `P28.F1` (fix, high) has landed and is committed (6b55ace). D35–D38, the first review's deferred candidates, are filed.

This pass is **focused**:
1. **Does F1 close the finding?**
   - Re-run the first review's three reproductions (hosts H, D and E) on the current artifact: H installs clean; D and E refuse with **nothing written**.
   - Try to break the preflight: a negation that targets only `.claude/agents/<ours>.md`, a nested `.gitignore` in `.claude/`, and `--update --nested` after a team commit adds a negation.
   - Confirm the post-write status assert gates the "stays clean" line.
2. **Regressions:** run `bash tests/retrofit_smoke.sh` alone in the foreground (226 checks), `validate` and `build.py --check`. Spot-check that at-root installs are unchanged versus `dc42380`.
3. **Boundary:** `phase-scope P28` now includes F1's files. Review F1's diff and the corrected claims (both READMEs, `docs/retrofit-guide.md`, the v49 CHANGELOG entry).
4. **Route the new Operator Question** (F1: a repo whose `.gitignore` refuses the install has no private-install route). The gate is waived, so route it as a **deferred-job candidate** for the orchestrator to file, with the trigger "the real company repo refuses the nested install". Recommend a shape (e.g. an opt-in override that accepts visible untracked files, or an out-of-tree layout) without deciding it.
5. **Cross-check:** the Doc impact list covers F1, and `## Decisions` carries F1's preflight rule.

Do not redo the first review's full fake-host walk; its results stand except where F1 touched the code. Return `review_verdict` as before. On pass: `doc_versions: none — deferred to a docs phase`, the explain pointer, and any deferred-job candidates.
