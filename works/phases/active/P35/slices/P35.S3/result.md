# P35.S3 — result: research — converting this repo to the nested layout

- status: done
- tier: high
- model: opus
- effort: medium
- summary: Proved the whole conversion twice on scratch clones. Sources move to `payload/` (undotted names) and the artifact stays byte-identical; the workspace history is extracted with `filter-branch` (331 → 292 commits) and attached under a fresh nested install with `reset --soft`; the nested engine sees P32-P35 as before; `--update` works; the upstream CI passes (smoke 292/292, same as baseline); rollback is proven twice. The finding that shapes the cut: the host commit must land before the install, so the switch interleaves commits in two repos. Three operator questions.
- files_changed: works/phases/active/P35/slices/P35.S3/result.md, works/phases/active/P35/phase.md
- validation: all on scratch clones, none on this checkout. `build.py` byte-identical after the move (sha 9e8a625c… before and after): pass. Pre-commit hook passes on the relocation commit and refuses a stale `payload/` edit: pass. Nested `next`/`validate`/`docs`/`phase-scope P35`: pass (phase-scope after the anchor stamp). `--update`: pass (0 machinery updated, host clean). `build.py --check`: pass. `tests/retrofit_smoke.sh` alone: 292 PASS / 0 FAIL, the same PASS lines as baseline. Rollback: pass ×2. The orchestrator re-runs only `python3 scripts/workflow.py validate`.
- deviations: (1) `rm -rf` is denied, so the scratch dir stays on disk for the operator to remove: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/1f05045c-d99c-4193-ad79-5557ad4128a8/scratchpad/p35s3.OEAp` (two converted clones, the extracted history repos, the stashes, the rollback backups, the patches). (2) Commits were made inside the scratch clones only, to exercise the hook and the history attach. (3) One extra `git ls-remote origin` (read-only) to confirm that no `phase/*` branch exists on the remote.
- doc_impact: none new beyond Decision 8's expected notes (the conversion slice writes them when it lands).

Evidence classes: **[O]** observed on the scratch clone, **[D]** documented (cited), **[I]** inferred (plus what would confirm it). Scratch root: `$S = …/scratchpad/p35s3.OEAp`. Clone `repo`: a step-by-step run, committing the host first. Clone `repo2`: the proposed real runbook end to end, including an uncommitted "executor delta". Patches for the conversion slice are in `$S/patches/1-relocate.diff` and `2-smoke-root-reads.diff`. Line refs will drift after the S2 build lands, so treat them as a guide.

## (a) The source tree

**Name.** I used `payload/` in the dry run. Whether that name is final is an Operator Question (`payload/`, `src/`, or `installer/payloads/tree/`). The name is a single constant in `build.py` and in the smoke suite, so renaming it later is trivial.

**The layout is the emit path with the first component undotted, and `CLAUDE.md` becomes `contract.md`:**

```
payload/contract.md                         <- CLAUDE.md (the shipped contract, header kept)
payload/scripts/workflow.py                 <- scripts/workflow.py
payload/executors.toml                      <- executors.toml (the seed's source; the live config goes to workflow/)
payload/claude/settings.json                <- .claude/settings.json
payload/claude/agents/*.md                  <- .claude/agents/*.md
payload/claude/skills/<name>/SKILL.md       <- .claude/skills/<name>/SKILL.md  (18)
payload/works/templates/*.md                <- works/templates/*.md
payload/github/workflows/workspace-ci.yml   <- .github/workflows/workspace-ci.yml (the adopter CI seed)
payload/gitattributes                       <- .gitattributes
```

**Why undotted [D].** Claude Code loads `<subdir>/.claude/skills/` and `<subdir>/CLAUDE.md` (and `CLAUDE.local.md`) **on demand, the first time Claude reads or edits a file in that subdirectory**. Sources:
- code.claude.com/docs/en/skills: "Skills in a `.claude/skills/` directory below where you started … load the first time Claude reads or edits a file in that subdirectory"; "A project-root skill and a nested skill | Both load".
- code.claude.com/docs/en/memory: "Claude also discovers `CLAUDE.md` and `CLAUDE.local.md` files in subdirectories … loads each one once Claude reads, writes, or edits another file in that subdirectory".

A mirrored `payload/.claude/skills` would therefore surface 18 duplicate skills, and a `payload/CLAUDE.md` would inject the raw contract every time someone edited a source. A `payload/.gitattributes` would also apply to `payload/`. So none of these dotted names may exist under `payload/`.

**Every listed file must move.** The installer refuses a host that tracks a file it would write: `.claude/skills/*`, `.claude/agents/*`, `CLAUDE.local.md`, `settings.local.json`. `.claude/settings.json` would keep firing `python3 scripts/workflow.py compact-*` hooks. `CLAUDE.md` would load beside the nested contract. The seeds (`.github/workflows/workspace-ci.yml`, `.gitattributes`) would run or apply at the root.

**`scripts/workflow.py` must move too: it is a trap [O].** I copied it alone into an empty git dir (`$S/trap`):
- `next` printed `no active slice; create a phase or promote deferred work`. This is a silent wrong answer.
- `validate` failed on the missing agents.
- `rebuild` crashed, but only after **creating a root `works/`** (`state.json`, `backlog.md`, `index.json`, `deferred.md`).

A root `works/` plus a root `scripts/workflow.py` is exactly what `resolve_layout` reads as an at-root workspace, so a later `--update` would refuse with "holds both".

**`build.py` edit [O].** It is +15/−7, and only the source paths change; the emit keys are untouched:
- add `SRC = REPO / "payload"`;
- add `src_rel(emit)`, which returns `emit[1:] if emit.startswith(".") else emit`;
- `read()` defaults to `base=SRC`;
- `FIXED_LIVE_FILES` reads `read(src_rel(rel))`;
- the skills glob becomes `SRC/"claude/skills"`, with key `"." + relpath`;
- the contract is read from `contract.md`.

Result: `python3 installer/build.py` produces `bootstrap_agentic_workspace.sh` **byte-identical** to the committed one (`git diff --quiet` → BYTE-IDENTICAL; shasum `9e8a625c0c8cdad5244183153c4260ec3afb2a4a` both before and after).

**Pre-commit hook [O].** The regex becomes `^(installer/|payload/|bootstrap_agentic_workspace\.sh$)`. On the relocation commit it printed `OK: … in sync`. When I staged a `payload/claude/skills/commit/SKILL.md` edit without rebuilding, it refused (`DRIFT … pre-commit: staged machinery drifts`, rc=1).

**`tests/retrofit_smoke.sh` [O].**
- Add `SRC="$REPO_ROOT/payload"` after `BOOT=`.
- Retarget every source read. The shell side covers lines ≈886/888/1196/1319/1383/1404/1407-1412/1428-1431/1817/1859-1860/2033. Dual-apply diffs `"$SRC/${rel#.}"` against `"$F/$rel"`, and `CLAUDE.md` maps to `$SRC/contract.md`.
- Inside the Python heredocs: `root / ".claude…"` → `root / "payload/claude…"`, `root / "scripts/workflow.py"` → `root / "payload/scripts/workflow.py"`, `root / "CLAUDE.md"` → `root / "payload/contract.md"`, plus `works/templates/phase.md`. That is 13 lines in Test 1 (≈95-600) plus Tests 6/7b.
- The first run missed the Test 1 heredoc reads and failed 1 check. With those retargeted: **292 PASS / 0 FAIL**. The baseline smoke on `pre-nested-conversion` (fresh clone `$S/base`) also gives 292 PASS, and `diff` of the two PASS lists is empty.
- `installer/build.py`'s `FIXED_LIVE_FILES` AST cross-check (Test 6) needs no change, because emit keys are unchanged.

**Upstream CI [O].** Add a new `.github/workflows/upstream-ci.yml`: on push and pull_request, run `python3 installer/build.py --check` and `bash tests/retrofit_smoke.sh`. It has no `workflow.py validate` and no `parallel-gate` job. The shipped seed moves to `payload/github/workflows/workspace-ci.yml` and never runs here.

**Text to update in the conversion slice** (no artifact change):
- `installer/README.md` ≈4-38 (it says "live files"), :90 ("This upstream repo stays at-root" → superseded), and ≈95-122 ("embeds these live files verbatim (target path == repo-relative)");
- the `build.py` module docstring;
- the `.gitignore` comment about keeping `executors.toml` at commented defaults (`payload/executors.toml` is now only the seed's source);
- `README.en.md:708-710` (edit `payload/**` or `installer/**`). `README.md` (ko) has no such dev note.

## (b) What stays at the root

**Tracked after the conversion [O]**, 56 files: `.githooks/pre-commit`, `.github/workflows/upstream-ci.yml`, `.gitignore`, `bootstrap_agentic_workspace.sh`, `CHANGELOG.md`, `CLAUDE.md` (new, upstream dev), `docs/retrofit-guide.md`, `installer/**` (15), `LICENSE`, `payload/**` (31), `README.md`, `README.en.md`, `tests/retrofit_smoke.sh`. There is no root `works/`, `scripts/`, `.claude/` (tracked), `executors.toml` or `.gitattributes`.

**The upstream `CLAUDE.md`.** A draft was used in the dry run; it is 29 lines and ≈2 KB, at `$S/repo` in history `95ea9b8:CLAUDE.md`. It covers:
- the repo is the product, and the workspace is a private nested install driven by `python3 workflow/scripts/workflow.py` with the contract loaded via `CLAUDE.local.md`;
- the `payload/` layout rule (no dotted or live names under it);
- the build rule (edit `payload/**` / `installer/**` → `build.py` → commit the artifact in the same commit; the hook enforces it);
- the release rule (`WORKSPACE_VERSION` + the top CHANGELOG section with Migration notes in one commit);
- the dogfood refresh (`sh bootstrap_agentic_workspace.sh --update .`, then commit in `git -C workflow`);
- CI is `upstream-ci.yml`;
- run the smoke suite alone.

**Add one line the draft lacks** [I, from the layout]: "`.claude/skills`, `.claude/agents`, `CLAUDE.local.md` and `workflow/` are **installed copies**, untracked, and each skill dir carries a `.gitignore *`. Never edit them; edit `payload/`, rebuild, `--update .`". Otherwise an edit to an installed skill shows no diff and is silently lost at the next `--update`.

**The shipped contract's "Upstream repo only" bullet.** Recommendation: **drop it** (or reword it to "follow that repo's own CLAUDE.md").
- After the conversion, the bullet's paths (`scripts/workflow.py`, `.claude/*`, `works/templates/*`, "this contract") point at **installed copies** in this repo. They are wrong, and they invite exactly the silent-loss edit above.
- Adopters never have `installer/`.
- Dropping it changes the artifact, so it ships in a release. Order the v58 release slice **after** the conversion, so the conversion stays byte-identical and v58 carries the bullet drop. The adopter CI seed's "upstream only" guarded steps and its "works unchanged in the upstream bootstrap repo" comment can be trimmed in the same release; they are harmless in adopters.

**This repo's own CI:** `upstream-ci.yml` (above), distinct from the seed.

## (c) Keeping the history

**Tool [O]:** `git filter-branch` (git 2.45.2). No install is needed, and it took 16 s for 332 commits:

```
git clone -q --no-local --single-branch --branch main <host> <hist> && cd <hist> && git reset -q --hard pre-nested-conversion
git remote remove origin; git tag -l | xargs -n1 git tag -d
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --prune-empty --index-filter '
git ls-files -s | grep -E "	(works/|docs/(current/|versions/|index\.json$|README\.md$)|executors\.toml$)" | GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && if [ -f "$GIT_INDEX_FILE.new" ]; then mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE"; else git read-tree --empty; fi' -- main
git update-ref -d refs/original/refs/heads/main
```

The pattern has a literal TAB before `(`. The extraction keeps `docs/README.md`, but the installer's nested-rewritten `docs/README.md` wins later. It drops `docs/retrofit-guide.md`. No `pip install` is needed, and there is no `git filter-repo`.

**Counts [O]:**
- host `pre-nested-conversion` = **331** commits → extracted = **292**: 39 pure-product commits pruned as empty, and the one merge (`merge(P33)…`) is kept;
- nested after the install commit = **293** in `repo2` (294 plus rebuild/stamp/update commits in `repo`);
- `.git` is 4.6 MB vs the host's 63 MB.

**`git log --follow` spot checks [O]:**

| File | Extracted history | Host history |
|---|---|---|
| `works/phases/active/P33/phase.md` | 6 (7 after the install-commit rebuild) | 6 |
| `docs/versions/decisions/v0043_…proposal.md` | 44 | 44 |
| `works/events.jsonl` | 272 | 272 |

On the host side, `git log --follow payload/claude/skills/commit/SKILL.md` = 3 (the 2 pre-move commits + the rename), so source history follows through `git mv`.

**How the install joins the history [O, both ways tried].**

- "History first, install over it" is **refused**: preflight needs `workflow/` empty (only `.git` is allowed).
- "Install first, merge the history in" with `--allow-unrelated-histories` would conflict on every generated file.
- **What works: install first (fresh), overlay the state, then attach the history with `reset --soft`.** On the fresh install's unborn branch:

```
git -C workflow fetch -q <hist> main && git -C workflow reset -q --soft FETCH_HEAD
```

  Then `rebuild`, and `git add -A`. The single commit on top of the extracted tip carries only:
  - `A .agentic-nested.json`, `CLAUDE.workspace.md`, `scripts/workflow.py`;
  - `M docs/README.md` (nested paths), `executors.toml` (two comment lines get the `workflow/` prefix), `works/.workspace-version.json` (installer's v57 marker over the stale v1), `works/templates/phase.md` (nested rewrite), the generated files (the `## Slices` header now says `python3 workflow/scripts/workflow.py rebuild`, plus timestamps), and `P35/phase.json` (anchor stamp);
  - plus whatever the conversion slice itself wrote. Proven: the uncommitted probe line appended to the root `P35/phase.md` before the switch arrived in the nested commit.

  The result is linear, with no merge.

**Overlay rules** (from the stash of the root state into `workflow/`):
- take the history's `works/{backlog.md,deferred,deferred.md,events.jsonl,index.json,phases,state.json}` and `docs/{current,versions,index.json}`;
- keep the installer's `works/templates/*`, `works/.workspace-version.json`, `docs/README.md`, `.agentic-nested.json`, `CLAUDE.workspace.md` and `scripts/workflow.py`;
- for `executors.toml`, take the **live** root file with `s#python3 scripts/workflow.py#python3 workflow/scripts/workflow.py#`. That keeps the operator's `[claude.cheap]` row: `executor-route` shows `cheap mid haiku high executors.toml`, identical to the at-root table, and `agent files: in sync`.
- A dead end: uncommenting the seed's cheap block with a global `sed` also uncommented two other `# effort = "high"` example lines. Never edit it with a line-global `sed`.

**`phase/P33-…` and D57 [O].**
- No `phase/*` branch exists locally (`git branch -a`) or on origin (`git ls-remote origin 'refs/heads/*'` → only `main`).
- P33's commits are in `main` through the merge, which the extraction keeps.
- P33's `execution` block (`mode: parallel, branch: phase/P33-…, worktree: null`) moves unchanged. The nested `next` prints the same `parallel_phases_elsewhere=P33:…` line as at-root today.
- D57's fix (S2: the in-flight filter) clears it, independently of the conversion. Nothing to carry or delete.

**The host's past history keeps `works/`** (no rewrite, no force-push). This matches intent item 4 ("leave this repo's tracked tree"). Note that the unpushed local commits (origin/main = `8ea3b7b`) that carry P35 state will become public at the next push, as today.

## (d) The install

**Run [O]** with `sh <host>/bootstrap_agentic_workspace.sh <host>`, from the converted clone's own byte-identical build, after the host commit. It reported:
- "no name clashes with the host's own skills, commands or agents" (no `wf-` renames);
- "18 skills in .claude/skills/ … 4 agents … settings.local.json, and CLAUDE.local.md importing the contract -- all untracked";
- "hidden by .git/info/exclude, verified".

**Exclude block [O].** The block between `# BEGIN/END agentic-workspace (nested)` holds `/workflow/`, `/CLAUDE.local.md`, `/.claude/settings.local.json`, the 18 `/.claude/skills/<n>/` lines and the 4 `/.claude/agents/<f>` lines. The existing `.claude/worktrees/` line is kept.

**`CLAUDE.local.md` [O]** is written: a managed block with `@workflow/CLAUDE.workspace.md` and the nested rules.

**`settings.local.json` merge [O].**
- The operator's file had 5 allows. Merged, it has 15 allows, plus `hooks` (PreCompact/SessionStart → `workflow/scripts/workflow.py`) and `autoCompactWindow`.
- `deny` carries `Bash(git push --force:*)` and `Bash(rm -rf:*)`, so this session's safety denials survive the removal of the tracked `settings.json`.

**Nested engine [O]**, run from the host root:
- `next`: `current_phase=P35`, `current_slice=P35.S3`, `slice_path=workflow/works/phases/active/P35/slices/P35.S3`, `next_slice=P35.DECOMP2`, the same `parallel_phases_elsewhere=P33` and `consolidation_owed=P32, P33, P34` as at root, plus `nested_host=` and `host_commit_convention=UNCONFIRMED (inferred: Conventional Commits …; Co-Authored-By trailers in 48/50)`.
- `validate`: passed, with the same warnings as at root.
- `docs`: all 11 docs, `workflow/docs/current/*`, with the same STALE marks (architecture, decisions, operations, qa).
- **`phase-scope P35`** at first: `mode=nested`, `creation_commit=none (phase.json carries no host_anchors.created …) -- pass --base <host-sha>`. At root, the engine finds the creation commit in its own repo; in nested it needs the anchor. After stamping `host_anchors.created = 8ea3b7bf…` (the **parent** of the at-root creation commit `d3e85b2`, so that commit's own edits count, matching at-root `base=`): `range=8ea3b7b..<head> commits=6`, `product_files=1013 (added 2, modified 5, deleted 976, renamed 30)`. The 976 deletions are the state that moved. The REVIEW should classify them as one class, not file by file.
- `nested-convention --confirm --text "…" --trailers allowed` → `host_commit_convention=confirmed (coauthor_trailers=allowed)`.

**`--update` [O]**: "machinery updated: 0 file(s) … host side … updated 0, added 0, unchanged 43; verified". The host is clean; in the nested repo it changes only the marker, generated files and the version marker (commit them). The banner's step 2 says to re-run `sync-agents` (already in sync).

**The install refuses when the relocation is staged but not committed [O, `repo2` first attempt].** It wrote everything, then `nested_verify_clean` exited 1 with "the host's git can see these paths". The reason: `git status -- .claude/…` lists the staged `D .claude/agents/*.md`, `D .claude/settings.json`, … **The host commit must precede the install.** That repo was rolled back (see g) and re-run in the right order.

## (e) The upstream CI after the conversion

Both run on the converted `repo`, which has no root `works/`. **[O]**
- `python3 installer/build.py --check` → `OK … in sync`.
- `bash tests/retrofit_smoke.sh`, as the only command in its Bash call → `ALL RETROFIT SMOKE TESTS PASSED`, 292 PASS / 0 FAIL. That equals the baseline at `pre-nested-conversion`, and the PASS lists are identical.

## (f) Order of operations

**The constraint that shapes it [O]:**
1. The host commit must land before the install.
2. Once the host commit lands, there is no root engine (`scripts/workflow.py` moved) until the nested install exists.
3. An executor never commits, in any git root.

So the conversion **cannot** be a pure executor slice that the orchestrator commits once at the end. Its tail interleaves commits in two repos, with no engine in between. Splitting it into two committed slices fails as well: after a "relocation only" commit, the root engine (needed for `finish-slice`), the agents (needed to dispatch the next slice) and the contract are already gone. Copying instead of moving would lose `git log --follow` on the product sources. Hence the Operator Question on who runs the switch.

**The recommended sequence** (`gate` mode, operator present):

0. **Preconditions and backup.** No commit.
   - All earlier slices are committed and `git status` is clean. `git worktree list` shows only `main`, and there are no `phase/*` branches.
   - `git tag pre-nested-conversion`, `git bundle create <outside-repo>/bootstrap-pre-nested.bundle --all`, and `cp .claude/settings.local.json <backup>/`.
   - Don't push the host until the gate clears.
1. `start-slice P35.Sx` (root engine). Commit `chore(P35): start …`.
2. **Executor (high)**, working tree only:
   - `git mv` each source into `payload/`, using the layout in (a) and `git mv executors.toml payload/executors.toml` after copying the live file to the stash dir;
   - apply the `build.py`/hook/smoke/CI edits, the new root `CLAUDE.md`, the `.gitignore` comment and the README/installer-README text;
   - validate: the artifact is byte-identical (`git diff --quiet bootstrap_agentic_workspace.sh` after `build.py`), `build.py --check` passes, and the smoke suite **alone** matches the baseline PASS count;
   - write `result.md` and `phase.md` (still in the root `works/`).

   Return. No engine call is needed after this point.
3. **Orchestrator: stash the state, then commit the host.**
   - `cp -R works executors.toml docs/{current,versions,index.json,README.md} <stash>/`;
   - `git rm -r -q --cached works docs/current docs/versions docs/index.json docs/README.md` (`executors.toml` is already moved);
   - move those paths out of the tree (with `mv`, never `rm -rf`);
   - commit the host: `refactor: convert to the nested layout (sources to payload/, workspace state to workflow/)`. The hook runs `--check`.
4. **Extract the history** from `HEAD~1` (the start-slice commit) with the `filter-branch` block in (c), in a clone outside the repo.
5. **Install:** `sh bootstrap_agentic_workspace.sh .` (nested, default). Check the banner says no clashes.
6. **Overlay** the stash into `workflow/` per (c)'s rules. Then:
   - stamp P35's `host_anchors.created = <parent of P35's creation commit>` (`8ea3b7bf…`);
   - `git -C workflow fetch <hist> main && git -C workflow reset --soft FETCH_HEAD`;
   - `python3 workflow/scripts/workflow.py rebuild` and `validate`;
   - `nested-convention --confirm … --trailers allowed`;
   - nested commit: `git -C workflow add -A && git -C workflow commit -m "chore(P35): install the agentic workspace (nested) over the extracted history"`.
7. `python3 workflow/scripts/workflow.py finish-slice P35.Sx --outcome …`, then a nested commit.
8. Set the phase/slice `pending` and **STOP**. The operator **restarts Claude Code at the repo root**: the session's loaded contract, skills, agents and hooks are the at-root ones, and the tracked `settings.json` hooks now point at a missing `scripts/workflow.py`. They are guarded by `|| true`, so harmless, but don't let the session compact before the restart [I].
9. In the new session: `python3 workflow/scripts/workflow.py next`, then the remaining slices (v58 release, if ordered after; see b) and the gated `P35.REVIEW`. Every workflow-state commit goes to `git -C workflow`, and product commits go to the host.

**Where P35 lands [O]:** `workflow/works/phases/active/P35/` (slice path `workflow/works/phases/active/P35/slices/<id>`).

**Auto memory [D]:** the project memory dir "is derived from the git repository, so all worktrees and subdirectories within the same repo share one auto memory directory" (code.claude.com/docs/en/memory). The host path and repo are unchanged, so `~/.claude/projects/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/memory` is unaffected. Sessions start at the host root; `workflow/` is never the cwd.

**Commit attribution after the conversion [O + rule].**
- **Host product commits** follow the convention confirmed with `nested-convention` (Conventional Commits `type(scope): summary`, trailers `allowed`, so `Co-Authored-By` stays). The managed `CLAUDE.local.md` rule also says host commits and PRs carry **no phase/slice IDs**, which ends today's `docs(P35): …` host subjects. See the Operator Question.
- **Nested commits** keep the contract's `type(scope)` with `P<N>` scopes and the trailer.

## (g) Rollback

**Backup:** step 0's tag, `--all` bundle and `settings.local.json` copy.

**From any step** (only `mv`; nothing is deleted):
1. If `workflow/` exists: `mv workflow <backup>/workflow.rolled-back`. It holds any post-switch state.
2. Undo the host side:
   - `mv CLAUDE.local.md <backup>/`;
   - move each `/.claude/skills/<n>/` and `/.claude/agents/<f>` path listed between the exclude markers into `<backup>/` (loop over the `sed -n '/BEGIN agentic-workspace (nested)/,/END …/p' .git/info/exclude` lines);
   - restore `.claude/settings.local.json` from the backup;
   - strip the managed block from `.git/info/exclude` (a `re.sub` over `# BEGIN agentic-workspace \(nested\)\n.*?# END agentic-workspace \(nested\)\n`, with DOTALL).
3. `git reset --hard pre-nested-conversion` (host; safe only if unpushed).
4. If anything was written after the switch, copy it back from `<backup>/workflow.rolled-back/works/phases/active/P35/` (and any doc versions), then run `python3 scripts/workflow.py rebuild` and commit `chore(P35): roll back the nested conversion`. Before the host commit (step 3 of f), the stash holds the only copy of the slice's uncommitted `result.md`/`phase.md` delta, so copy it back first.

**Proven twice [O]:**
- `repo`, from the fully converted state (3 host commits, 4 nested commits on the extracted history): `git status` clean, `.claude/{agents,settings.json,settings.local.json,skills}` back, at-root `next` → `current_phase=P35 current_slice=P35.S3`, `validate` passed, `build.py --check` OK, HEAD `5d6a7f8`.
- `repo2`, from a half-done install (the refused one above, with the state stashed and nothing committed): the same result, `validate` passed.

## Proposed cut for DECOMP2 (the conversion part)

The order relative to S2's cut: S2 slices 1-6 (the worktree build at the root layout) → **C1** → **C2** → **REVIEW**. Moving S2's slice 7 (the v58 release) to C2 is recommended.

- **C1: `implementation/high`.** Convert this repo to the nested layout. Triggers: **deletion and history** (state leaves the tracked tree; the nested repo's history is built by rewrite) and **wide blast radius** (build, hook, smoke and CI, which every release passes through).
  - The executor does step 2 of (f).
  - The orchestrator runs steps 3-8 inline, pending the Operator Question.
  - Validation:
    - the artifact is byte-identical after the move;
    - `build.py --check`;
    - smoke alone = the baseline PASS count;
    - the hook refuses a stale `payload/` edit;
    - after the switch: host `git status` is clean and the host tracks no `works/`, `scripts/`, `executors.toml`, `.gitattributes`, `.claude/`;
    - nested `next`/`validate`/`docs`/`phase-scope P35` (anchor stamped);
    - nested `rev-list --count` ≥ extracted count, plus one `log --follow` spot check;
    - `executor-route` table unchanged.
  - Ends `pending` for the restart.
  - Doc impact notes: decisions (the at-root line superseded; done), architecture (this repo's layout: `payload/`, nested-driven), operations (the upstream dev loop: `payload/` → build → `--update .`; the conversion runbook as history).
- **C2: `implementation/low`.** The v58 release in the new layout:
  - bump `WORKSPACE_VERSION` + the CHANGELOG (Migration notes) + rebuild;
  - drop or reword the shipped contract's "Upstream repo only" bullet;
  - trim the adopter CI seed's upstream-only steps (optional);
  - then `sh bootstrap_agentic_workspace.sh --update .` and commit in `git -C workflow`. This is the first real dogfood of the release path.
  - Validation: `build.py --check`, smoke alone, `--update` output "machinery updated: N", nested `validate`.
- **REVIEW** (gated, in the new session): reads `phase-scope P35`, with the 976 state deletions as one class.

Not needed: a `pip install`, a migration command (Decision 4), or any glide-ilab write.
