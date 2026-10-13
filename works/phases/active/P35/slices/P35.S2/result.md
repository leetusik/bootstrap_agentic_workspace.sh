# P35.S2 — result: research — paired worktrees for a nested install

- status: done
- tier: high
- model: opus
- effort: medium
- summary: Proved a paired host+nested worktree for a nested install on a scratch install with a patched scratch engine. The engine run from `<host-wt>/workflow` resolves HOST_ROOT to the host worktree and claims `stream=phase/…`, and the main checkout skips the phase. Five hazards are now observed facts, each with its fix: host-first teardown silently destroys the nested worktree and its uncommitted state; a host worktree with no `CLAUDE.local.md` of its own loads no contract; the compaction hooks resume the default stream; CLAUDE_AGENTS points into the worktree; a stale `host_anchors.created` over-reports. Answers (a)-(i), two operator questions and a proposed DECOMP2 cut are in `phase.md`.
- files_changed: works/phases/active/P35/slices/P35.S2/result.md, works/phases/active/P35/phase.md
- validation: scratch experiments (below), all observed; `python3 scripts/workflow.py validate` is the orchestrator's re-run. No product file touched (`git status` shows the same set as before the slice).
- deviations: (1) the scratch dir was **not** removed: `rm -rf` is denied by this session's permission rules, and I did not route around the deny. It sits inside the session scratchpad: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/1f05045c-d99c-4193-ad79-5557ad4128a8/scratchpad/p35s2.Wxsv` (plus `scratchpad/dbg-wt.log`, `scratchpad/SCRATCH_PATH` and `scratchpad/tools/`); the operator can remove it. (2) The headless probes in (c) ran `claude -p` in the scratch host. The first three ran the operator's global Stop hook, which sent an ntfy "Claude is done" push; after that, every probe passed `--settings '{"disableAllHooks": true}'`. They also left two transcript dirs under `~/.claude/projects/-private-tmp-claude-502--…-p35s2-Wxsv-host*`, which I left alone.
- doc_impact: none

Evidence classes: **observed** = I ran it, and the output is quoted here; **documented** = cited by URL; **inferred** = reasoned only, and the item says what would confirm it.

## Setup (observed)

- The scratch host is a git repo on `main` with two commits, a tracked `CLAUDE.md`, and `temp/notes.txt` hidden by `.git/info/exclude`. I installed the workspace into it with `sh bootstrap_agentic_workspace.sh "$S/host"`, and it went nested by default. The installer wrote `workflow/` (its own repo on **`master`**, git's default; it has no `.gitattributes`), `CLAUDE.local.md` (the managed block with `@workflow/CLAUDE.workspace.md`), `.claude/settings.local.json` (the PreCompact/SessionStart hooks `cd "$CLAUDE_PROJECT_DIR" && python3 workflow/scripts/workflow.py compact-…`), 18 skills, 4 agents, and the exclude block (`/workflow/`, `/CLAUDE.local.md`, `/.claude/settings.local.json`, per-skill and per-agent lines). The exclude block has **no `.claude/worktrees/` line**. I added `temp/` to `workflow/.git/info/exclude` too.
- I created phases P1 (the main stream), P2 and P3. `parallel-start P2` on the stock engine printed `parallel worktrees are disabled in a nested personal install` and exited 1.
- Prototype patch, applied only to the scratch install's copy of the engine and committed in the scratch nested repo so that the nested worktree inherits it:
  - `_refuse_parallel_when_nested` becomes a no-op, and `current_stream` and `parallel_status` lose their nested early returns;
  - `_ensure_worktrees_excluded(cwd=HOST_ROOT)` writes to the host's common `info/exclude`;
  - the default worktree is `(HOST_ROOT or ROOT)/.claude/worktrees/<tail>`;
  - after the stamp commit, `git -C <host> worktree add (-b $PROTO_HOST_BRANCH | --detach) <host-wt> HEAD`, then `git -C workflow worktree add -b phase/… <host-wt>/workflow HEAD`.

## (a) The paired cut: observed

```
PROTO host: worktree add --detach …/host/.claude/worktrees/P2-side_feature HEAD -> 0
git -C workflow worktree list:
  …/host/workflow                                        690ddbd [master]
  …/host/.claude/worktrees/P2-side_feature/workflow      690ddbd [phase/P2-side_feature]
host `git status --short`: (empty)
```

From `<host-wt>`, `python3 workflow/scripts/workflow.py next` printed `nested_host=<host-wt>`, `stream=phase/P2-side_feature`, `current_phase=P2` and `current_slice=P2.DECOMP`. Importing the module from there gave ROOT = `<host-wt>/workflow`, HOST_ROOT = `<host-wt>` and stream `phase/P2-side_feature`. In the main checkout, `next` printed `parallel_phases_elsewhere=P2:phase/P2-side_feature`, `current_phase=P1`. So the main checkout skips the phase. `parallel-status` and `parallel-gate P2` work in nested once the guard is lifted, with no other change, because `_repo_prefix()` is `''` at the nested repo root.

**Exclude (observed):** with the `.claude/worktrees/` line removed, the host main checkout showed `?? .claude/`; with it back, the status was clean. `_ensure_worktrees_excluded` must therefore write to the **host's** common dir (`git -C HOST_ROOT rev-parse --git-common-dir`), not the nested repo's. Recommendation: the installer also puts `/.claude/worktrees/` into the managed nested exclude block, so `--update` and uninstall own it, and the engine's idempotent write stays as the safety net (it should accept both `/.claude/worktrees/` and `.claude/worktrees/` as already present).

**Exact order of `parallel-start` in nested:**
1. Every guard runs before anything is written:
   - the phase is `planned`, not pinned and has no execution block;
   - the default stream is current, and neither repo is mid-merge or mid-rebase;
   - `phase/…` is free in the nested repo;
   - the host branch is free, or exists and is not checked out anywhere;
   - the host worktree path is free;
   - the host base resolves to a sha.
2. Ensure the host exclude line.
3. Write `execution` (with `host_branch`), re-stamp `host_anchors.created` to the host base sha, and rebuild.
4. Make the nested stamp commit (`--only` the paths).
5. `git -C <host> worktree add -b <host-branch> <host-wt> <base-sha>`.
6. `git -C workflow worktree add -b phase/… <host-wt>/workflow HEAD`.
7. Copy `<host>/CLAUDE.local.md` to `<host-wt>/CLAUDE.local.md`.

**Failure points:**

| Step that fails | What it leaves behind | Recovery to print |
|---|---|---|
| 1 | nothing | — |
| 2 | one idempotent exclude line | — |
| 4 | an uncommitted phase.json edit, as on today's at-root path | — |
| 5 | the stamp committed, no worktrees | the step 5 and 6 commands |
| 6 | the host worktree with no `workflow/` | the step 6 command, or `git -C <host> worktree remove <host-wt>` and un-stamp by hand |
| 7 | both worktrees, and the session gets no contract (see (b)) | the `cp` |

The nested worktree's admin dir is named after the path's basename (`workflow`, `workflow1`, …), so `git -C workflow worktree list` is the only reliable name. That is cosmetic.

**Current teardown fails in nested (observed):** with the host worktree recorded as `execution.worktree`, `parallel-teardown P2` reached `git worktree remove <host-wt>` from the nested repo. It failed with "is not a working tree".

## (b) Host-side wiring: observed and documented

Probe: `/context` run through `claude -p --settings '{"disableAllHooks": true}'`, with the cwd at `<host-wt>`.

| Case | Memory files loaded |
|---|---|
| main host checkout | `host/CLAUDE.md` (40), `host/CLAUDE.local.md` (564), `host/workflow/CLAUDE.workspace.md` (4.5k) |
| worktree with nothing added | `host/CLAUDE.local.md` (564; the **main** checkout's, as an ancestor), `<host-wt>/CLAUDE.md` (38). **No contract**: the main file's `@workflow/…` import resolves outside the worktree and is not expanded. The main checkout's `CLAUDE.md` is not loaded either, because the worktree's own copy replaces it. |
| worktree with a copied `CLAUDE.local.md` | main `CLAUDE.local.md` (564), `<host-wt>/CLAUDE.md`, `<host-wt>/CLAUDE.local.md` (564), `<host-wt>/workflow/CLAUDE.workspace.md` (4.5k): the **phase branch's** contract |

The stream-json `init` from the worktree, which had **no `.claude/` directory at all**, listed the agents `design-drafter, Explore, slice-executor-high, slice-executor-mid` and all the skills. The debug log showed `Watching for changes in setting files … host/.claude/settings.local.json`, which is the main checkout's file. This matches the docs:
- "when the worktree checkout has no `.claude/skills` directory at its root … Claude Code loads the main checkout's project skills … The same read-through covers `.claude/agents`" (https://code.claude.com/docs/en/worktrees, "What worktrees share with the main checkout");
- "In a worktree, it uses the file at the main checkout's root" for `settings.local.json` (https://code.claude.com/docs/en/settings).

Recommendation per file:

| File | What to do | Why |
|---|---|---|
| `CLAUDE.local.md` | **Copy** at `parallel-start`, byte for byte from the main checkout. | It is required. A symlink is unsafe because the import resolves "relative to the file containing the import", and it is unknown whether that means the link or its target. The copy is excluded via the anchored `/CLAUDE.local.md`, so it is ignored, and `git worktree remove` deletes it with the worktree. `--update` needs nothing, because the worktree lives only for one phase. The duplicate 564-token rules block (main's copy is also loaded as an ancestor) is harmless and identical. A minimal import-only file would hang on the ancestor load, which is unspecified behaviour. |
| `.claude/settings.local.json` | **Nothing.** | The main checkout's file is used. |
| `.claude/agents/*`, `.claude/skills/*` | **Nothing**, and the engine must **never create** `<host-wt>/.claude/agents` or `<host-wt>/.claude/skills`. | Either directory would turn off the read-through. |
| Engine `CLAUDE_AGENTS` | Resolve it to the **main** host checkout: the parent of `git -C HOST_ROOT rev-parse --path-format=absolute --git-common-dir`. Fall back to HOST_ROOT when git is unavailable. | Observed: in the worktree it points at `<host-wt>/.claude/agents` (missing), so `validate` warns about 4 missing agent files, and `sync-agents` would write a shadow copy. |

Inferred, to confirm at the gate: a session that **enters** a worktree with `EnterWorktree` (rather than starting there) may keep the main contract it loaded at launch. The contract is identical unless the phase edits it, so that is harmless either way. If the operator approves the external import on an interactive prompt, the main contract could load twice. The operator's `/context` in a live worktree session confirms which.

## (c) The session and hooks: documented and observed

- **EnterWorktree (documented):** "Once in a worktree, Claude can switch directly to another one under `.claude/worktrees/` by calling `EnterWorktree` with the target path". Paths outside the repository's `.claude/worktrees/` need the operator's approval (https://code.claude.com/docs/en/worktrees). `<host>/.claude/worktrees/P<N>-<slug>` is inside the host repo's own home, so the session enters it without that prompt.
- **`$CLAUDE_PROJECT_DIR` and `cwd` (documented):** "`${CLAUDE_PROJECT_DIR}` stays put: it still points at the project root where the session started … `cwd` follows Claude: the `cwd` field in the hook's input JSON is the worktree root, and it moves again when Claude runs `cd`" (worktrees and hooks pages).
- **The bug (observed):** I fed `compact-resume` stdin with `cwd=<host-wt>` and ran the hook exactly as installed (`cd "$CLAUDE_PROJECT_DIR" && python3 workflow/scripts/workflow.py compact-resume`). It printed `current_phase=P1 current_slice=P1.DECOMP`, the default stream's pointer, inside P2's worktree. `compact-gate` reads the same wrong pointer and the wrong tree for its dirty count.
- **Fix (prototyped and observed):** keep the hook command unchanged, so `settings.local.json` and at-root `settings.json` need no migration. In `cmd_compact_resume` and `cmd_compact_gate`, read stdin first, then walk up from the hook's `cwd`. The first directory `d` where `d/<rel>/scripts/workflow.py` + `d/<rel>/works/` exists is the owning engine (`<rel>` = `workflow` when nested, `.` at root). If that engine is not `__file__`, re-run it as `[sys.executable, eng, cmd]` with the same stdin, under a 12 s timeout and an `AGENTIC_HOOK_REDIRECTED=1` recursion guard, and relay stdout and stderr. In every other case, carry on as today. Results:

| Hook stdin `cwd` | Pointer printed |
|---|---|
| `<host-wt>` | `stream=phase/P2-side_feature`, `current_phase=P2` |
| `<host-wt>/workflow/works` | P2 |
| `<host>` | P1 |
| `/tmp` | P1 (fallback to self) |

  The redirected gate reported `slice=P2.DECOMP` and that worktree's own dirty count. **At-root needs the same fix:** its hooks also `cd "$CLAUDE_PROJECT_DIR"`, so a root worktree session resumes on `main`'s pointer today. Inferred from the identical mechanism, and confirmed by the nested simulation. The fix is mode-agnostic.

## (d) The host branch: observed and inferred

- I tested two forms. A detached host worktree (P2) and `-b feature/third` (P3) both work.
- **Detached is unsafe (observed):** I committed on a detached host worktree, then ran `git worktree remove`. It exited 0, and the commit was left with **0 refs containing it**, so GC will drop it.
- **Recommendation:** the operator names the host branch. In nested, `parallel-start <P> --host-branch <name>` is required, and the orchestrator asks for the name when it is missing. If the branch exists and is not checked out, it is reused. Deriving the name from `nested-convention` is not possible: that text describes commit subjects, not branch names. No workspace IDs appear in the name (Decision 3).
- **Base ref:** `--host-base <ref>`, defaulting to the main host checkout's `HEAD`. That matches the engine's "start from the latest commit" and Claude Code's `worktree.baseRef: head`, and needs no fetch. The resolved sha is stamped as `host_anchors.created`. Whether the default should instead be the host default branch (`origin/HEAD`) is an operator question.
- **Teardown:**
  - The host branch is **kept** (the operator's PR).
  - It is deleted only when `rev-list --count <created>..<host-branch>` is 0, using `-D` because `-d` measures against HEAD.
  - Guard: refuse when the host worktree is detached with commits beyond `created`.
  - There is never a local merge into the host default.
- I wrote two `## Operator Questions` entries: the naming rule and the base default.

## (e) Ignored and excluded paths: observed

| Case | Result |
|---|---|
| nested `worktree remove` with an untracked `works/newfile.md` | **refused** (exit 128) |
| nested `worktree remove` with only ignored `temp/n.txt` | **exit 0, deleted** |
| host `worktree remove` with an untracked `src/new.txt` | refused |
| host `worktree remove` with only ignored `temp/` + the copied `CLAUDE.local.md` | **exit 0, deleted** |
| **host-first** `worktree remove` with the nested worktree still inside (`workflow/` is ignored in the host) | **exit 0**. It deleted the nested worktree, **including its untracked `works/newfile.md`**, and left the nested registration `prunable`. |
| `ln -s <main>/temp <wt>/temp` (both repos) | `?? temp`: a symlink does **not** match the directory-only pattern `temp/`, so it shows as untracked, would block `worktree remove`, count as dirt for `compact-gate` and be swept up by `git add -A` |

Recommendations:
- **Teardown is nested-first:**
  1. `git -C workflow worktree remove <host-wt>/workflow`;
  2. the pre-check, run on the host worktree only after step 1;
  3. `git -C <host> worktree remove <host-wt>`;
  4. the host branch rule from (d).
- **Pre-teardown check (both repos):** `git ls-files --others --ignored --exclude-standard --directory`, minus the engine's own files (`CLAUDE.local.md`, and `workflow/` before step 1). If anything remains, refuse, list the files and say how to proceed: move them, or pass `--discard-ignored`.
- **No shared-scratch symlinks in this phase.** They need a non-directory exclude line per path and still risk being committed. The guard alone holds in every case. If wanted later, the list belongs in the nested marker (per install, machine-local intent), not in `executors.toml` (executor routing). That is a deferred-job candidate: "shared scratch paths linked into phase worktrees", with the trigger "an operator asks to see main's `temp/` from a worktree".

## (f) Host anchors: observed

I created P3, then advanced host `main` (`src/m.txt`), then ran `parallel-start P3`, then committed `src/t.txt` in the worktree. `phase-scope P3` from the worktree printed `range=56a2bfc..12bf38e commits=2` with `A src/m.txt` and `A src/t.txt`, which **over-reports** `main`'s file. With `--base <worktree base>` it printed `range=63e9048..12bf38e commits=1`, `A src/t.txt`. Fixes:
- **Re-stamp `host_anchors.created` to the host worktree's base sha** at step 3 of `parallel-start`, before the stamp commit, so both branches carry it.
- `review_pass`: `head_commit()` reads `HOST_ROOT` HEAD, and HOST_ROOT is the host worktree, so the review on the branch stamps the worktree's HEAD **with no change**. This is inferred from the code path; in the scratch run, `phase-scope` in the worktree did read the worktree's HEAD (`head=12bf38e`).
- `_phase_scope_nested` needs no change. It reads `HOST_ROOT` = the worktree while in the worktree, and after teardown, on `main`, it reads `created..review_pass`. Those commits stay reachable while the host branch is kept (it is deleted only when empty).
- **D35 stays deferred.** It is about a rebase onto a newer upstream *during* the PR, which needs a policy choice on which upstream ref to use, and its trigger has not fired. The worktree flow makes it no worse, and the re-stamp removes the separate at-start drift.

## (g) The Streams view: design (inferred from the existing code; it reuses observed helpers)

- **Position:** in `works/backlog.md`, a `## Streams` section right after `## Pointer` and before `## Active Phases`.
- **Columns:** `Stream | Phase | Status | Current slice | Done | Host branch | Worktree | Source`. The `Host branch` column appears only when nested.
- **Rows:**
  - first, the **default stream**: `default`, the pointer's `current_phase` and `current_slice`, `n/m` for that phase, source `working tree`;
  - then one row for each stamped phase that is **in flight**: `execution.worktree` is not null, or `status != done`.
- **Source for a stamped phase's row:**
  - the phase's own stream reads its working tree;
  - otherwise, `_phase_json_at_ref` / `_slices_at_ref` at `branch`, then at `origin/branch`;
  - otherwise, the local copy, labelled as such.
- **The state cell:** a short form of `_parallel_verdict` (in flight `n/m`, `pending`, ready to merge, merged-awaiting-consolidation).
- **When git is consulted:** only when at least one phase has `execution.branch` and is in flight, the same gate as `current_stream`. A torn-down `done` phase is never read from git.
- **On a parallel stream,** its own row comes first, and the default row reads from `execution.base_branch` (a new stamp field: the default branch name at `parallel-start`, `master` in the nested scratch). When that field is absent, the default row reads the local copy.
- **At root,** the same view applies without the host column. In nested, everything is read from the nested repo; the host branch name comes from `execution.host_branch`.
- **Cost:** about 2 + N `git show` calls per stamped phase on every rebuild. Inferred to be cheap: about 10 ms per call. `backlog.md` is already excluded from `compact-gate`'s dirt, and generated files are "regenerated, not merged".
- **D57: fold it in.** It has the same root cause and the same fix. `next`'s `parallel_phases_elsewhere` (`cmd_next` ≈3518) lists every phase with an execution branch, including P33, which is done, merged and torn down (`worktree: None`). The Streams filter (in flight only) applied to that line closes D57. P33's still-pending `consolidation` keeps showing on the separate `consolidation_owed` line, which is correct.

## (h) Shared external resources

**One caveat line** in `parallel-phase` §3 ("Work — in the worktree"): a worktree isolates files only. Docker containers, ports, databases and caches are shared with the main checkout and every other worktree, so start the phase's own services on other ports or names, or not at all. The reason is that this is the operator's hazard to know about, the engine cannot detect it, and machinery for it would be guesswork. Evidence class: inferred, a property of git worktrees.

## (i) The command and text surface (from the code)

**Engine (`scripts/workflow.py`, line numbers as of this slice):**
- `NESTED_PARALLEL_OFF` (36) and its users must go: `_refuse_parallel_when_nested` (2520-2525, called at 2544 start, 2642 teardown, 2697 gate, 2789 merge-finish, 2831 consolidated), the prints in `parallel_skip` (2620) and `parallel_status` (2993), and the `current_stream` early return (1479).
- `parallel_start_hint` (≈3083, `if NESTED is not None or …`): lift it or keep it silent. I recommend lifting it, since the opt-in is the operator's word anyway.
- `_ensure_worktrees_excluded` (2416) takes a target repo.
- `parallel_start` (2528) gets the nested pair, `--host-branch`/`--host-base`, the anchor re-stamp, the `CLAUDE.local.md` copy, and the `execution.host_branch` and `execution.base_branch` fields, plus their `validate` checks (≈1720-1745).
- `parallel_teardown` (2637) gets the nested-first order, the ignored-files guard, the detached-commit guard and the host branch rule.
- `CLAUDE_AGENTS` (273) resolves to the main host checkout.
- `cmd_compact_gate` and `cmd_compact_resume` (3688, 3769) get the cwd redirect.
- `rebuild_backlog` (1649) gets Streams; `cmd_next` (3518) gets the in-flight filter (D57).
- `parallel_status` gets the host branch line when nested.
- The printed `next:` lines of `parallel-start` say `EnterWorktree path=<host-wt>`.

**Installer (`installer/main.py`):**
- l.903: replace "No parallel worktrees: the `parallel-*` commands refuse in a nested install." with a rule that a phase worktree has two halves (the host worktree with `workflow/` inside), that `parallel-start` needs `--host-branch`, and that the host side goes out by the operator's PR, never a local merge.
- l.1053: add `/.claude/worktrees/` to `exclude_entries`.
- The nested `workflow/` gets the `.gitattributes` with `works/events.jsonl merge=union`. It is absent today, and nested merges now happen. Observed: the scratch merge of `phase/P2…` conflicted on `works/state.json` and `works/index.json`, which is expected and resolved by `parallel-merge-finish`. `events.jsonl` did not conflict this time, but nothing protects it.

**Skills:**
- `parallel-phase`:
  - §1.2 "Where": `<host>/.claude/worktrees/P<N>-<slug>` with `workflow/` inside, and the host branch;
  - §1.6 "Enter and exit": the host path;
  - §3: the (h) caveat;
  - §5 steps:
    - 1 gate: unchanged;
    - 2 exit: unchanged;
    - 3 pull: `git -C workflow pull --ff-only`;
    - 4 local merge: in the **nested** repo only, `git -C workflow merge --no-ff phase/…`;
    - 5 merge-finish: unchanged;
    - 7 commit: `git -C workflow commit`;
    - 8 teardown: the paired teardown keeps the host branch;
    - plus a new host step: "host side: the operator's PR from `<host-branch>`; no local merge";
  - the remote variant pushes the **nested** phase branch only if the nested repo has a remote, and pushes the host branch only when the operator asks.
  - The line-24 mention of "the nested worktree home" needs disambiguating, because "nested" means two things now.
- `do-next-slice` l.39 and `do-whole-phase` l.53: in a nested install the `worktree` word now works. Add `--host-branch` (ask the operator for the name) and the two-repo merge note.

**READMEs:** `README.md` 59, 128, 211-212 and 407-408, and `README.en.md` 111-112, 244, 325-327 and 546-547, all say "only `--at-root`" or "parallel is off". They need rewording, and a short "in a nested install" paragraph goes into each "Phase worktrees (on request)" section.

**Smoke:** Test 14 (`tests/retrofit_smoke.sh` ≈1846-1848) asserts the refusal. Replace it with a small nested lifecycle check: start with `--host-branch`, then check `next` in the worktree for the stream, the main checkout skipping the phase, and `stream=default`; then a nested-first teardown that keeps a host branch with a commit. Add one cwd-redirect assertion for `compact-resume`.

**D37: keep it deferred.** In a worktree, the claude-design push would now target the operator-named host branch. That is still the host's ticket branch, and the issue (the design record lives in `workflow/`, which Claude Design cannot read from the host push) is design-specific. Its trigger, the first nested design phase, has not fired. The worktree change only gives D37's eventual fix a named branch to point at (`execution.host_branch`).

## Proposed cut for DECOMP2 (the worktree part; S3's conversion slices come after)

1. **Engine: the nested paired `parallel-start`, streams and wiring.** `implementation / high`, trigger **core invariant** (worktrees and persisted state: the stamp, anchors, execution fields).
   - Scope: lift the guards and `current_stream`; the start order (a); `--host-branch`/`--host-base`; the anchor re-stamp; `host_branch` and `base_branch` plus their validation; the `CLAUDE.local.md` copy; `CLAUDE_AGENTS` to the main checkout; the host exclude.
   - Its validation must show, on a scratch nested install:
     - the worktree's `next` prints `stream=phase/…`;
     - the main checkout skips the phase, and its status is clean;
     - `/context` in the worktree lists the worktree's contract (or `validate` there shows no missing-agent warnings);
     - the at-root smoke tests are unchanged.
2. **Engine: paired teardown and its guards.** `implementation / high`, trigger **deletion**. Depends on 1.
   - Scope: nested-first removal, the ignored-only-in-worktree guard, the detached-commit guard, keep or delete the host branch.
   - Its validation must show:
     - an untracked file in the nested worktree is refused;
     - an ignored file in either repo is listed and refused without `--discard-ignored`;
     - a host branch with a commit is kept;
     - an empty host branch is deleted;
     - no prunable registration is left behind.
3. **Compaction hooks resolve the engine from stdin `cwd`.** `implementation / high`, trigger **wide blast radius** (it runs in every install's compactions, at root included). Independent of 1-2.
   - Its validation must replay hook JSON with `cwd` set to the worktree, a subdirectory, the main checkout and `/tmp`, at root and nested.
4. **Streams view in `backlog.md`, plus the D57 in-flight filter in `next`.** `implementation / low`; the design is pinned in (g). Depends on 1.
   - Its validation must show the at-root and nested backlog with one in-flight phase and one torn-down phase, and no git calls when nothing is stamped.
5. **Installer and text surface.** `docs / low`, or `implementation / low` for the installer lines.
   - Scope: `main.py:903` and `:1053`, the nested `workflow/.gitattributes`, the `parallel-phase` / `do-*` paragraphs, the (h) caveat line, the READMEs.
   - Its validation: `installer/build.py --check` passes; a scratch install shows the new exclude line and the `CLAUDE.local.md` text.
6. **Smoke tests.** `implementation / low`, the small nested lifecycle plus the hook redirect assertion. Depends on 1-3. `retrofit_smoke.sh` runs alone in its Bash call.
7. **v58 release bump and rebuild**, low. Then S3's conversion slices, then REVIEW.

Operator questions block slice 1's `--host-branch` / `--host-base` defaults; DECOMP2 goes `pending` until the operator answers them.
