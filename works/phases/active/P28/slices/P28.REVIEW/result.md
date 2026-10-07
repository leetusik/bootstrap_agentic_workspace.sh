# Result — P28.REVIEW (review / high), re-review after P28.F1

- **status:** done
- **tier:** high
- **summary:** Re-reviewed P28 after `P28.F1`. F1 closes the first pass's only finding. Host H installs clean, and hosts D and E refuse with nothing written. Seven further host shapes built to break the preflight all refuse cleanly or install clean, and so does `--update --nested` after a teammate's negation. The post-write `git status` assert is what gates the "stays clean" line. Smoke (226 checks), `validate`, `build.py --check` and the at-root differential all pass. Verdict `pass`. F1's operator question is routed as a deferred-job candidate.
- **review_verdict:** `pass`
- **files_changed:**
  - `works/phases/active/P28/slices/P28.REVIEW/result.md`, this file, rewritten;
  - `works/phases/active/P28/phase.md`: one `## Doc impact` line appended, the F1 question's routing appended under `## Operator Questions`, the consumed note removed, `## Now` rewritten.
- **validation:**
  - `bash tests/retrofit_smoke.sh`, alone in its own foreground call: PASS, `ALL RETROFIT SMOKE TESTS PASSED`. 226 PASS, 0 FAIL across Tests 0–15, including F1's three new Test 15 asserts.
  - `python3 scripts/workflow.py validate`: PASS (`Workflow validation passed.`). The only warnings are the P26/P27 consolidation debt, stale docs and oversized sections, none from P28.
  - `python3 installer/build.py --check`: PASS (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`).
  - `python3 scripts/workflow.py phase-scope P28`: range `dc42380..6b55ace`, 6 commits. The same 11 product files as the first pass; F1 adds no new file to the list. `docs/retrofit-guide.md` sits under the excluded `docs/`, so I reviewed it by hand.
  - Scratch hosts and the at-root differential: see "Re-review detail" below. The scripts are `rr/lib.sh`, `rr/t1_hde.sh` … `rr/t5_atroot.sh`, and the smoke log is `smoke_rr.log`, all in this session's scratchpad.
- **deviations:**
  - Per the re-review plan, I did not redo the first pass's full fake-host walk or its `claude -p` loading probe: F1 touched neither the walk's flow nor loading.
  - **One cross-check correction, not a finding.** `## Doc impact` had no `decisions.md` line for F1's decision. F1's architecture/operations line carries the mechanism, but P26.F1 set the precedent of logging a fix's decision there. I appended one line, tagged as the review's cross-check.
- **doc_versions:** none — deferred to a docs phase. The gate is waived, so there is no stage-4 checklist append, and this phase did not change `## Operator Runtime`.
- **walkthrough:** none (acceptance waived by the operator, 2026-10-07: "for the review, just use fake repo. I'll report if any problem with real one.")
- **explain:** not written — run /explain for this phase
- **deferred-job candidates** (title · reason · trigger), for the orchestrator to file with `defer-job`:
  1. **A private-install route for a host whose `.gitignore` refuses `--nested`.** This routes F1's operator question.
     - **Reason:** a host whose tracked `.gitignore` re-includes an agent file, `CLAUDE.local.md`, `.claude/settings.local.json` or `workflow/` now refuses with nothing written, and there is no override. An allowlist repo (`*` / `!*/` / `!*.md`) always refuses.
     - **Recommended shape, not decided:** first, narrow workarounds that keep `git status` empty, chosen per target:
       - a self-hiding, untracked `.claude/agents/.gitignore` of `*` when the team tracks nothing in `.claude/agents/`;
       - the engine repo kept outside the work tree, e.g. beside the clone and reached by an absolute `@import`, if Claude Code's external-import approval allows it.
     - **Only if no workaround fits:** an explicit opt-in such as `--allow-visible`. It installs, lists every path that stays visible, and relies on `/commit`'s never-stage rule. It is never the default.
     - Option (a) from the question, accepting that no private install is possible there, stays open to the operator.
     - **Trigger:** the real company repo refuses the nested install.
  2. **Nested mode never re-checks the ignore guarantee after install.**
     - **Reason:** I verified this on scratch hosts Ua and Ub. A teammate's later `.gitignore` negation (`.claude/.gitignore` with `!agents/*.md`, or a root `!CLAUDE*.md`) shows our files as `??` as soon as the operator pulls. `validate` and `next` still pass without a word, and only `--update --nested` notices. It refuses with nothing written, but its message says the files *would* stay visible when they already are.
     - **Why it is not blocking:** `/commit` never uses `git add -A` and repeats the never-stage rule, so a slice will not stage them. A manual `git add -A` or an IDE's "stage all" would. The intent's promise is a clean status after install, and that holds.
     - **Fix shape:** nested `validate` (or `next`) runs the same `check-ignore` or `status` over the marker's `installed` targets and warns, naming the deciding line. The update refusal says the files are visible now.
     - **Trigger:** the next nested engine change, or an operator report.
- **items for the operator to watch in the real repo:**
  - **If `--nested` refuses there,** that is candidate 1's trigger: report the refusal lines; do not work around them by hand.
  - **Right after install,** `git status --porcelain --untracked-files=all` must be empty, and the banner must say "verified".
  - **After pulling a teammate's `.gitignore` change,** `git status` must stay empty. If our files show up, stage nothing and report it (candidate 2).
  - Whether a company-managed policy disables `bypassPermissions`, which the three agents set.
  - Whether the first interactive run shows the trust dialog and the import is approved.
  - **Rebasing before a PR:** run `phase-scope <P> --base $(git merge-base HEAD origin/main)` (D35).
  - `git clean -fdx` removes the host-side files, and `--update --nested` restores them (D36).

## Re-review detail

### 1. Does F1 close the finding? Yes

**The first pass's three reproductions**, on the current artifact (`t1_hde.sh`). A bare `origin.git`, a clone as `host`, and a team commit holding the `.gitignore`.
- **"Nothing written"** means four checks hold: the host signature is unchanged (whole-tree listing without objects, `info/exclude`, HEAD, status and local config), HEAD is unchanged, there is no `workflow/`, and the exit is non-zero.
- **"Status"** means `git status --porcelain --untracked-files=all`.

| Host | `.gitignore` | Result |
|---|---|---|
| H | `.claude/*`, `!.claude/skills/`, `!.claude/skills/**` | rc 0, HEAD unchanged, status empty, `git add -A --dry-run` empty. The banner prints "each dir hides itself with a .gitignore of \*" and "verified: the host's git status stays clean". `check-ignore` names `.claude/skills/explain/.gitignore:1:*` for `SKILL.md` and for the file itself |
| D | `*`, `!*/`, `!*.md` | rc 1, nothing written. Names the 3 agents and `CLAUDE.local.md` (`.gitignore:3:!*.md`), and `workflow/` (`.gitignore:2:!*/`) |
| E | `!CLAUDE*.md` | rc 1, nothing written: `CLAUDE.local.md: re-included by .gitignore:1:!CLAUDE*.md` |

**Attempts to break the preflight** (`t2_break.sh`). Every case below either refused with nothing written, HEAD unchanged and status empty, or installed with an empty status and `git add -A --dry-run`.

| Case | Host shape | Result |
|---|---|---|
| B1a | `.claude/agents/*` + `!.claude/agents/slice-executor-mid.md` (one of our agents only) | refused, naming only that file and `.gitignore:2` |
| B1b | `!.claude/agents/slice-executor-high.md` alone | refused, naming it |
| B1c | the team tracks its own `slice-executor-mid` agent, so ours becomes `wf-slice-executor-mid`, plus `!.claude/agents/wf-*.md` | refused, naming `.claude/agents/wf-slice-executor-mid.md`: the preflight asks about the **renamed** name |
| B2a | tracked `.claude/.gitignore` = `!agents/*.md` | refused, naming the 3 agents and `.claude/.gitignore:1` |
| B2b | tracked `.claude/.gitignore` = `*` / `!.gitignore` / `!settings.local.json` | refused, naming `.claude/settings.local.json` and `.claude/.gitignore:3` |
| B2c | tracked `.claude/.gitignore` = `*` / `!.gitignore` / `!skills/` / `!skills/**` | installs, status empty (self-hiding skill dirs) |
| B2d | tracked `.claude/skills/.gitignore` = `!**` | installs, status empty (the per-dir file is deeper) |
| B2e | tracked `.claude/agents/.gitignore` = `!*.md` | refused, naming the 3 agents and `.claude/agents/.gitignore:1` |
| B3a | `*` / `!.claude/` / `!.claude/**` / `!.gitignore` | refused, naming the agents and `settings.local.json` (`.gitignore:3:!.claude/**`); the skills self-hide |
| B3b | `!/workflow` (no slash) | refused: `workflow/: re-included by .gitignore:1:!/workflow` |
| B4 | `!claude.local.md` (case differs; macOS clone, `core.ignorecase=true`) | refused, naming `CLAUDE.local.md`: `check-ignore` honours `ignorecase` exactly as `status` does |
| B5 | `.claude` is a tracked symlink to `tools/claude` | refused with "cannot check … (git check-ignore exit 128: … beyond a symbolic link); nothing written". Safe, though the message is technical |

**`--update --nested` after a team commit adds a negation** (`t3_update.sh`). Each host is a clean install with a first `workflow/` commit. A teammate then pushes a change to `origin`, and the host pulls it.

| Case | Teammate's change | Result |
|---|---|---|
| Ua | adds `.claude/.gitignore` = `!agents/*.md` | `--dry-run` and the real update both exit 1, naming the 3 agents. Host signature, HEAD and the `workflow/` content hash are unchanged. Before the update, status already showed the 3 agents as `??` while `validate` passed: candidate 2 |
| Ub | appends `!CLAUDE*.md` to `.gitignore` | same: both refuse, nothing written. Status already showed `?? CLAUDE.local.md` before the update |
| Uc | `.claude/*` + `!.claude/skills/` + `!.claude/skills/**` | the dry run gives rc 0, "unchanged 42" and "checked: …", and writes nothing. The update gives rc 0, "verified", status empty. It changes only `workflow/`'s generated files: the version marker, the indexes and `state.json`, plus a re-inferred unconfirmed convention |

**Upgrading a pre-F1 install.** I installed the `d8c187d` artifact into host H: 18 untracked skill files, and it still printed "stays clean" (the old bug). The current `--update --nested` reports "added 18, unchanged 24" and "verified", and the untracked count drops to 0.

**The post-write assert gates the clean line** (`t4_postcheck.sh`, a scratch copy of the artifact with the one preflight call replaced by `unignored = []`):
- **Install on host E:** exit 1, `Error: the nested install is written, but the host's git can see these paths …`, `?? CLAUDE.local.md`, and the `Next:` line. Neither "stays clean" nor "verified" is printed.
- **`--update --nested` after a negation:** exit 1, listing `?? CLAUDE.local.md`; "verified" is not printed.
- **Dry run:** prints only "checked: …". It never claims "verified".
- **Code read** (`installer/main.py` L1313–1316, L656–669, L983–996):
  - `nested_verify_clean` runs on every non-dry nested path before the banner, and exits on failure;
  - `verified_clean` is set only on an empty status;
  - the install banner prints the clean line only when it is true;
  - re-running `--nested` exits 0 at "already installed" from `nested_preflight` with no clean claim.

**F1's code, read against the diff.**
- **The `check-ignore -z -v --non-matching` parse** (four fields per path) and the negation test (`pattern.startswith("!")`) are right.
- **Ordering:** the tracked-target refusal runs before the preflight, and both run before `ROOT.mkdir`.
- **The temporary `workflow/`** is created only when absent and is removed in a `finally`.
- **The self-hiding files** come first in the write order, since `.gitignore` sorts before `SKILL.md`.
- **`status_paths`** covers every host write: each skill dir (and its `.gitignore`), each agent file, `CLAUDE.local.md`, `settings.local.json` and `workflow`. `info/exclude` sits under `.git`.
- **Test 15's three asserts** check rc, the deciding-line text, the absence of `workflow/` and an unchanged signature.

### 2. Regressions: none

- **Smoke, `validate`, `--check`:** see the verdict block.
- **At-root differential** (`t5_atroot.sh`): fresh at-root installs from the `dc42380` (v48), `d8c187d` (pre-F1) and `HEAD` artifacts.
  - **`d8c187d` vs `HEAD`:** identical installer output, an identical tree (`diff -rq`, no differences) and identical `--help`. F1 is invisible at root.
  - **`dc42380` vs `HEAD`:** identical installer output. Ignoring timestamps, the trees differ only in `.claude/skills/{commit,retrofit,update-workspace}/SKILL.md`, `scripts/workflow.py` and `workspace_version` 48→49. `--help` differs by the 5 `--nested` lines. That is the same as the first pass.

### 3. Boundary and the corrected claims

F1's diff is `installer/main.py`, the rebuilt artifact, `tests/retrofit_smoke.sh`, both READMEs, `CHANGELOG.md` and `docs/retrofit-guide.md`, all nested-only. Every claim below matches observed behaviour.
- **Both READMEs**, the Korean one with the same structure:
  - the new list item says each skill dir holds a `.gitignore` of `*`;
  - the paragraph says a host `.gitignore` ranks above `info/exclude`, that the installer checks before writing and refuses naming the file and the deciding line, that `--update --nested` checks the same way, and that it confirms an empty status before saying clean.
- **`docs/retrofit-guide.md`:** the old unconditional "stays clean" now reads "a successful install leaves the host's git status clean", after the refusal sentence.
- **CHANGELOG v49**, amended in place: per-dir `.gitignore`, the preflight with the deciding line on install and update, and the post-write check. `WORKSPACE_VERSION` stays 49, per Invariant (d).
- **A wording nit, not a finding:** README.en's lead-in still says "all hidden by the host's `.git/info/exclude` (never its `.gitignore`)". "Its" means the host's tracked `.gitignore`, which is never edited, so it stays true. The very next list item names our own per-dir `.gitignore` files.

### 4. Operator Questions, routed

- **(P28.S1) marker name:** answered by the operator, implemented in S2, routed in the first pass.
- **(P28.F1) a host that refuses has no way forward:** routed as deferred-job candidate 1, with the trigger "the real company repo refuses the nested install" and a recommended shape, not a decision. The routing line is appended under the entry in `phase.md`.

No entry is unrouted.

### 5. Cross-checks

- **`## Decisions` vs F1's `result.md`:** "Ignore guarantee (P28.F1)" carries every F1 decision:
  - the self-hiding dirs, their write order and their counting;
  - the per-dir file, neither rewritten nor in the marker (F1's recorded deviation);
  - the preflight's method, its targets and the temporary `workflow/`;
  - the refusal rule with no override, the non-0/1 exit refusal, and the one safe approximation;
  - the post-write check and the three banner lines;
  - the release handling.

  The only detail it omits is why `GIT_OPTIONAL_LOCKS` is an env var (older git); that stays in F1's `result.md`. Nothing is dropped.
- **`## Doc impact`:** F1's two lines cover architecture, operations and qa (Test 15's three asserts, 226 checks). I appended the `decisions.md` line for F1's decision (see deviations). The first pass's coverage of S1–S3 stands.
- **D35–D38**, the first pass's candidates, are filed. Neither new candidate duplicates one of them.

### Regression Checklist (`docs/current/qa.md` L20–25, 6 lines), classified against `phase-scope P28`

| Line | Surface | Inside? (fed by) | Result, this pass |
|---|---|---|---|
| L20 fresh install validates and stamps `workspace_version` (P16) | installer | inside (`installer/main.py`, the artifact) | pass: Test 5 "fresh workspace validates" and "release version agrees …"; the differential's fresh marker reads 49 |
| L21 an undeclared or uncleared gate refuses `review-phase --verdict pass` (P16) | engine | inside (`scripts/workflow.py`) | pass: Test 5 "refuses an undeclared acceptance gate". F1 did not touch the engine |
| L22 Test 0 invariants, incl. tier body parity (P16) | machinery text | inside (three skills) | pass: Test 0 |
| L23 `## Slices` renders, and `finish-slice --outcome` fills its row (P18) | engine | inside | pass: Test 9 |
| L24 a marker-less notebook stays byte-identical, and `next` twice does not dirty the dashboards (P18) | engine | inside | pass: Tests 9 and 10 |
| L25 `new-slice --kind research`, and the closed-set error (P19) | engine | inside | pass: Test 5 |

Inside: 6. Outside: 0. The diff (`phase-scope P28`, 11 files) feeds every line's surface. Nothing is appended, because the gate is waived.

### Notebook

`phase.md` changes:
- **`## Doc impact`:** one `decisions.md` line appended.
- **`## Operator Questions`:** the F1 entry's routing appended.
- **`## Notes for later slices`:** the "(from P28.S3, for any fix slice)" note removed. F1 consumed it, and Invariant (d) carries the rule.
- **`## Now`:** rewritten.
- **`## Decisions`:** untouched; this pass settled nothing new.

## First pass (2026-10-07, before P28.F1), kept for the record

- **Verdict `changes_requested`, with one blocking finding.** A tracked host `.gitignore` negation outranks `.git/info/exclude`. On hosts H (`!.claude/skills/**`), D (allowlist) and E (`!CLAUDE*.md`), the install's files showed as untracked, and `git add -A` would have staged them, while the banner said "the host's git status stays clean".
- **Fix:** `P28.F1` (fix, high, core invariant): an ignore preflight before any write on install and update, optional self-hiding skill dirs, a post-write status assert, a Test 15 assert, and corrected README/CHANGELOG claims. It landed as 6b55ace.
- **Everything else passed and still stands:**
  - validation (223 checks then);
  - the v48 at-root differential;
  - the fake-host walk from install through one ticket to a pushed branch, whose patch carried no workflow traces;
  - `phase-scope` on the host diff, `--update --nested` keeping the convention, renames and operator text;
  - the clash renames, the tracked-target refusal, the wrapper refusals and render-then-write ordering;
  - the `/commit` pre-approvals (`git -C workflow` status/diff/log/add/reset/commit, no push);
  - the `claude -p` probe, which showed an executor loading `CLAUDE.local.md` and the imported contract.
- **Its four deferred-job candidates are filed as D35–D38:** rebase/merge-base `phase-scope`, README caveats (`git clean`, working-tree tools), the `claude-design` push target in a nested install, and engine texts that skip a rename or the host prefix.
- **Observation, no fix proposed:** a team adding a tracked skill whose name is one of ours, after install, makes `--update --nested` refuse safely, and the operator must hand-edit the marker to proceed.
