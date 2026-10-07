# Result — P28.REVIEW (review / high)

- **status:** done
- **tier:** high
- **summary:** Reviewed P28 inside its boundary: validation (Tests 0–15, 223 checks), an at-root differential against v48, and a fake-host walk from install to a pushed ticket branch with `--update --nested`. Everything the phase claims holds, but one footprint gap is real. When a host's tracked `.gitignore` re-includes a path the install writes, the negation outranks `info/exclude`, so our files show as untracked. `git add -A` would then stage them. The installer still prints "the host's git status stays clean". Verdict `changes_requested`, with one fix slice.
- **review_verdict:** `changes_requested`
  1. **(blocking) The no-footprint guarantee fails silently when the host's `.gitignore` re-includes an install target.**
     - **Cause:** Git ranks a matching `.gitignore` pattern above `.git/info/exclude`, so a negation such as `!.claude/skills/**`, an allowlist-style `*` / `!*/` / `!*.md`, or `!CLAUDE*.md` un-hides what our exclude block lists.
     - **Evidence:** three scratch hosts.
       - Host H: `.claude/*`, `!.claude/skills/`, `!.claude/skills/**`. All 18 skill files show as `??` after install, and `git check-ignore -v --no-index` names `.gitignore:3:!.claude/skills/**` as the deciding line.
       - Host D: allowlist-style. 23 untracked entries; after the first `workflow/` commit, `git add -A --dry-run` would add our skills, `CLAUDE.local.md` and `workflow/` (as an embedded-repo gitlink).
       - Host E: `!CLAUDE*.md`. `CLAUDE.local.md` is visible.
     - **What is wrong:** in all three the banner still says "the host's git status stays clean". Nothing checks or warns before or after the write, on install or on `--update --nested`.
     - **Proposed fix:** `P28.F1`, below.
- **proposed fix slices:**
  - **`P28.F1`: make the nested install verify that every host-side target is actually ignored.** Kind `fix`, risk **high**. The trigger is a **core invariant**: the phase's no-footprint guarantee, which DECOMP named as S2's core invariant; S2 ran at `tier: high`.
    - Scope, in `installer/main.py` `nested_plan()`, before any write, on install and `--update --nested` alike: run `git check-ignore -v --no-index --non-matching` over every host target (each installed skill dir's `SKILL.md`, each agent file, `CLAUDE.local.md`, `.claude/settings.local.json`, and `workflow/`). A target whose deciding pattern is a negation (`!…`) from a file other than `info/exclude` cannot be hidden, so refuse with nothing written, naming each target and its deciding `file:line:pattern`. That is the default the intent implies ("after install, `git status` in the host repo is clean").
    - Optionally, a per-directory `.gitignore` containing `*` inside our own skill dirs. A lower-level `.gitignore` outranks the parent's negation and hides itself. The plan decides; files directly in team directories cannot use it.
    - Add a post-write belt-and-braces assert that `git status --porcelain --untracked-files=all -- <targets>` is empty. Print the "stays clean" line only when that holds.
    - One Test 15 assert: host H's `.gitignore` is refused with nothing written.
    - Adjust the claim in both READMEs' `--nested` section and in the v49 CHANGELOG entry ("One `.git/info/exclude` block hides all of it"). Whether to edit v49 in place or bump is the orchestrator's call; the standing note says the version stays 49 unless the operator asks.
    - Then `python3 installer/build.py` and `--check`.
- **files_changed:** `works/phases/active/P28/slices/P28.REVIEW/result.md`, `works/phases/active/P28/phase.md`
- **validation:**
  - `bash tests/retrofit_smoke.sh`, alone in the foreground: PASS, `ALL RETROFIT SMOKE TESTS PASSED`, 223 checks, Tests 0–15.
  - `python3 scripts/workflow.py validate`: PASS. The only warnings are the P26/P27 consolidation debt, stale docs and oversized sections, none from P28.
  - `python3 installer/build.py --check`: PASS (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`).
  - `python3 scripts/workflow.py phase-scope P28`: range `dc42380..d8c187d`, 4 commits, 11 product files. The 12th changed file, `docs/retrofit-guide.md`, sits under `docs/`, which phase-scope excludes, so I reviewed it by hand.
  - At-root differential, fake-host walk and footprint scrutiny: below.
- **deviations:** none from `plan.md`.
  - The `claude -p` probe ran once and was not denied.
  - I did not run `review-phase` even inside the fake host, per the dispatch. The host `review_pass` anchor is covered by S1's hand check and a code read: the gate check runs before any write, and the anchor is written after it.
- **doc_versions:** none. The verdict is `changes_requested`, so the pass-only doc duties did not run; the gate is waived, so there are no gate sections.
- **explain:** not written — run /explain for this phase
- **walkthrough:** none (acceptance waived by the operator, 2026-10-07: "for the review, just use fake repo. I'll report if any problem with real one.")
- **deferred-job candidates** (title · reason · trigger), for the orchestrator to file with `defer-job`:
  1. *Nested `phase-scope` over-reports after the ticket branch is rebased or merged onto a newer `origin/main`.* Reason: `created..HEAD` then includes teammates' commits. Verified: a teammate's `src/app.py` appeared, and `--base $(git merge-base HEAD origin/main)` gives the right two files. It over-reports and never hides anything. Fix by measuring from the merge-base with the branch's upstream, or at least documenting the `--base` form in the README per-ticket flow. Trigger: the first real ticket that rebases before its PR, or an operator report.
  2. *README caveats the private install should state.* Reason:
     - `git clean -fdx` in the host deletes our ignored host-side files (skills, agents, `CLAUDE.local.md`, `settings.local.json`); `workflow/` survives as a nested repo, and `--update --nested` restores the rest;
     - tools that read the working tree rather than git, such as a local `docker build` with `COPY .` or `npm publish`, do not honour `info/exclude`.

     Trigger: the next README touch (F1 may absorb it) or an operator report.
  3. *The `claude-design` round's `git push` step in a nested install pushes the host's ticket branch, not `workflow/`.* Reason: the skills are mode-neutral apart from the path rewrite, so in a nested install that push lands on the host branch. Trigger: the first design phase run in a nested install.
  4. *Engine texts that ignore a clash rename or the host prefix.* Reason: engine messages name a skill by its original name (already a README caveat). `sync-agents` prints `config source: executors.toml`, not `workflow/executors.toml`. The installed `wf-commit` keeps its `# commit` H1. Trigger: the next nested engine change or an operator report from a host with a clash.
- **items for the operator to watch in the real repo:**
  - the host's `.gitignore` shape: until F1 lands, run `git status --porcelain` right after install, and it must be empty;
  - whether a company-managed policy disables `bypassPermissions`, which the three agents set;
  - whether the first interactive run's trust dialog appears and the import is approved;
  - rebasing the ticket branch before a PR: use `phase-scope <P> --base $(git merge-base HEAD origin/main)`;
  - `git clean -fdx` removes the host-side files, and `--update --nested` restores them.

## Stage 1: all slices validated together

All three commands above were run fresh in this slice. The smoke log is in the session scratchpad (`smoke.log`). The Test 14 (8 checks) and Test 15 (12 checks) lines all PASS, and Tests 0–13 are unchanged.

## Stage 2: the at-root invariant (confirmed, not re-derived)

I installed the v48 artifact (`git show dc42380:bootstrap_agentic_workspace.sh`) and the current v49 artifact fresh into two scratch dirs.
- **Installer output:** identical after normalising the target path.
- **Tree (`diff -rq`):** differs only in `.claude/skills/{commit,retrofit,update-workspace}/SKILL.md`, `scripts/workflow.py` and `works/.workspace-version.json` (49).
- **`--help`:** differs only by the five `--nested` lines.
- **Engine:** `next`, `validate`, `parallel-status`, `docs`, `new-phase` and `phase-scope` give identical output on both trees. The only difference is the argparse choices list, which gains `nested-convention`, and the `--help` entry for it.

## Stage 3: fake-host walk (instrument: shell scripts over git, no browser)

**The fake host.** A bare `origin.git`, seeded with three Conventional Commits. The team tree tracks:
- `CLAUDE.md`, `.claude/settings.json`, `.github/workflows/ci.yml`, `.gitattributes` and `CONTRIBUTING.md` (which says "No AI co-author trailers");
- a team `commit` skill (`name: commit`) and a team `reviewer` agent;
- `src/app.py` and the host's own `docs/guide.md`.

It is cloned as `host`. After every step the host's `git status --porcelain --untracked-files=all` was empty. HEAD, local config, hooks, `core.hooksPath` and the tracked-content hash were unchanged, except my deliberate product commits.

1. **Fresh install.** `--nested` exits 0, and the host snapshot is byte-identical.
   - `info/exclude` holds one block with `/workflow/`, `/CLAUDE.local.md`, `/.claude/settings.local.json`, 18 skill dirs and 3 agent files.
   - `workflow/` is a nested repo with `CLAUDE.workspace.md`, no `CLAUDE.md` and no `.claude/`.
   - `commit` is renamed to `wf-commit` (`name: wf-commit`), and the team's `commit` skill is unchanged.
   - Scanning 28 installed texts, plus `CLAUDE.local.md`, the contract, the templates, `executors.toml` and `docs/README.md`, finds no unprefixed `scripts/workflow.py` or workspace path and no `workflow/workflow/`.
   - `settings.local.json` allows `Bash(python3 workflow/scripts/workflow.py:*)`.
   - The inferred convention quotes both CONTRIBUTING lines, including the no-trailers rule.
2. **One ticket.**
   - Setup: the first `git -C workflow` commit, then `git switch -c ticket2 origin/main`. `next` shows `UNCONFIRMED (inferred: …)`, and `nested-convention --confirm --text … --trailers forbidden` flips it to `confirmed (coauthor_trailers=forbidden)`.
   - `new-phase --phase P1` records `host_anchors.created` as the host HEAD. `phase-scope` lists nothing right after `new-phase`, then shows an uncommitted `src/gadget.py` in the working-tree list.
   - After two product commits plus one state commit, `phase-scope P1` (text and `--json`, `mode=nested`) lists exactly `A src/gadget.py` and `M docs/guide.md`: nothing under `workflow/` and none of the untracked host files.
   - `parallel-start` refuses (rc 1). `parallel-status` prints the line (rc 0). `validate` passes. `next` prints `slice_path=workflow/works/...`.
   - **What the team receives:** I pushed the first ticket branch to the fake `origin`. The tree on `origin/ticket` is the team's files plus `src/widget.py`. `main..ticket` changes one file, the commit message is `feat(APP-3): add the widget`, and grepping the pushed patch for `workflow/`, `P1`, `CLAUDE.local` or `agentic` finds nothing.
   - **Rebase probe:** after a teammate commit to `origin/main` and `git rebase origin/main`, `phase-scope` also lists the teammate's `src/app.py`. That is deferred-job candidate 1.
3. **Update.**
   - Before updating, I added an operator note to `CLAUDE.local.md` and an `env` key plus an allow rule to `settings.local.json`.
   - `--update --nested --dry-run` reports host side updated 0, added 0, unchanged 24, and the whole-tree hash is identical before and after.
   - `--update --nested` exits 0 with HEAD unchanged. It keeps the confirmed convention and the `commit→wf-commit` rename, the operator's note, `env` key and allow rule, and the engine allow entry. One exclude block and one `CLAUDE.local.md` block remain, there is no `workflow/workflow`, and the version marker reads 49.
   - A second `--update --nested` changes nothing on the host side.
   - A plain `--update` refuses with "re-run with --update --nested" (rc 1). Re-running `--nested` says "already installed" (rc 0). `sync-agents` from the host root reports "already in sync".
4. **Loading (one `claude -p` probe, CLI 2.1.292, from the host root).** The main session dispatched `slice-executor-mid` with a read-only prompt. The executor reported both `CLAUDE.local.md` and the imported `workflow/CLAUDE.workspace.md` as loaded. It quoted Read Order item 1 verbatim (`python3 workflow/scripts/workflow.py next`) and the first nested rule verbatim. The main session confirmed both were also in its own context.
   - The executor self-labelled `tier: high`. That is its own mislabel: no personal agent shadows ours (`~/.claude/agents` holds only `ocx-*`).
   - As in S2, the untrusted workspace ignored the host's `settings.json` allow entry.
   - The host status stayed empty after the probe.
5. **First-time read.** For the start-to-PR flow, the banner, the `CLAUDE.local.md` block and the README section (both languages, same structure) are enough. Banner and README give the same order: first `workflow/` commit, start at the host root, accept trust, confirm the convention. What is missing is the three caveats above (rebase → `--base`, `git clean -fdx`, build tools), and the false "stays clean" claim in negating hosts, which is F1.

## Footprint and security scrutiny

| Case | Result |
|---|---|
| Tracked target (`git add -f .claude/settings.local.json`) | refused, naming it; no `workflow/`, no `CLAUDE.local.md`, `info/exclude` byte-identical. Pass |
| Host agent file `slice-executor-mid.md` + a team skill whose `name:` is `explain` | both renamed (`wf-slice-executor-mid`, `wf-explain`, `name:` lines right), `do-next-slice` names `wf-slice-executor-mid` 5×, no bare old name left, `sync-agents --check` in sync, team files untouched. Pass |
| Team adds a tracked `.claude/skills/explain/` after install | `--update --nested` refuses, naming it, nothing written. Safe, but the operator has to hand-edit the marker to proceed (the decision "only newly shipped names are clash-checked"); an observation, no fix proposed |
| `.claude/*` + `!.claude/skills/` + `!.claude/agents/` (common shape) | clean. Pass |
| `.claude/*` + `!.claude/skills/` + `!.claude/skills/**` (host H) | **18 skills visible**; finding 1 |
| allowlist `*` / `!*/` / `!*.md` (host D) | **23 entries visible; `git add -A` would stage skills, `CLAUDE.local.md` and `workflow/` as a gitlink**; finding 1 |
| `!CLAUDE*.md` (host E) | **`CLAUDE.local.md` visible**; finding 1 |
| Wrapper: `--nested --force-empty-ok`, `--nested --dry-run` without `--update`, a non-git dir | all refused, the non-git dir left empty. Pass |
| Render-then-write ordering | by construction: `nested_preflight()` and `nested_plan()` run before `ROOT.mkdir` and only read (git queries, file reads). Every refusal, including post-check and tracked-target, exits before the first write; shown live by the tracked-target case. Pass |
| Engine writes into the host | only `CLAUDE_AGENTS` (our own agent files, through the rename map) for `sync-agents`/`executor-mode`; no host git writes, no config, no hooks. Pass |
| `/commit` pre-approvals | `git -C workflow status/diff/log/add/reset/commit` only, no push; `git -C workflow add ../x` cannot reach host paths (git refuses paths outside the repo); no broader than the plan intended. Pass |

## Stage 5: cross-checks

- **`## Decisions` vs the results.** Every decision and constraint in `P28.DECOMP`, `S1`, `S2` and `S3`'s `result.md` appears in `## Decisions` or `## Doc impact`. Four small implementation constraints were only implicit, and I added them in one line under "Engine contract" (`phase.md`). Not findings:
  - S1: `validate` errors when the host is not a git work tree, and the nested `new-phase` suppresses the busy hint;
  - S2: convention inference uses `--no-merges`, and `git init` runs on a fresh install only.
- **`## Doc impact`.** It is complete: architecture (S1, S2, S3), operations (S1, S2, S3), qa (Tests 14 and 15), decisions (S3).
  - `product`, `security` and `experience` are unfilled seeds in this repo, so nothing is owed there.
  - READMEs, CHANGELOG and the retrofit guide are product files, not versioned docs.
  - The S1 architecture line still says `workflow/nested.json`. The S2 line records the rename to `.agentic-nested.json` and supersedes it, so the docs phase must use the new name. The list is append-only, so I left it as is.
- **Operator Questions.** The one entry, the marker name, was answered by the operator before S2 ("Rename to .agentic-nested.json"), implemented in S2, and observed live in the fake host. It is routed and needs no walkthrough line.
- **`EXPECTED_SKILL_COUNT`.** It is 18 in `installer/build.py` and `installer/main.py`, with 18 skill dirs; Test 0 and Test 5 pass.
- **The v49 CHANGELOG entry** matches what shipped, item by item. I checked the refusals, the rename, the `phase-scope` host anchors, `nested-convention`, `--update --nested`, the three skills, and the at-root claim against the differential. The one exception is "One `.git/info/exclude` block hides all of it", which is false in negating hosts and is part of F1.

## Regression Checklist (`docs/current/qa.md`, 6 lines). Classified against `phase-scope P28`

| Line | Surface | Inside? (fed by) | Result |
|---|---|---|---|
| L20 fresh install validates + stamps `workspace_version` (P16) | installer | inside (`installer/main.py`, the artifact) | pass: Test 5 "fresh workspace validates", "release version agrees…"; the differential's fresh marker reads 49 |
| L21 undeclared/uncleared gate refuses `review-phase --verdict pass` (P16) | engine | inside (`scripts/workflow.py`) | pass: Test 5 "refuses an undeclared acceptance gate". The uncleared branch is unchanged apart from its printed `WORKFLOW_CMD` (byte-identical at root), and it is checked before any write (code read, L1877–1879) |
| L22 Test 0 invariants incl. tier body parity (P16) | machinery text | inside (three skills) | pass: Test 0 |
| L23 `## Slices` renders, `finish-slice --outcome` fills its row (P18) | engine | inside | pass: Test 9 |
| L24 marker-less notebook byte-identical; `next` twice does not dirty dashboards (P18) | engine | inside | pass: Tests 9 and 10 |
| L25 `new-slice --kind research` / closed-set error (P19) | engine | inside | pass: Test 5 |

Inside: 6. Outside: 0. Every line's surface is fed by a file in the diff. No append: the gate is waived and the verdict is not `pass`.

## Notebook

`phase.md`: I consumed the REVIEW note, added the `P28.F1` note, added the one Decisions line, and rewrote `## Now`. Doc impact and Operator Questions are untouched: the review adds no durable truth on `changes_requested`, and no new operator question. The scratch scripts (`walk_setup.sh`, `walk_step2.sh`, `walk_step2b.sh`, `walk_rebase.sh`, `walk_step3.sh`, `walk_sec.sh`, `walk_sec2.sh`, `rootdiff.sh`) are in this session's scratchpad. The F1 note carries the reproduction recipe inline, because the scratchpad does not outlive the session.
