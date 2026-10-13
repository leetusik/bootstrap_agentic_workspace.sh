# P35.S8 — plan: skills, installer and text for nested parallel and the host custom

## Context

S4-S7 built the engine side of nested parallel worktrees: the paired start, the teardown, the hook redirect and the Streams view. This slice makes everything an operator or orchestrator **reads** match it, and implements the operator's PR policy as text (`../../phase.md` Decisions 18-19, 22-23, the `(from P35.DECOMP2, for P35.S8)` Note and its `(from P35.S4)` / `(from P35.S5)` addenda; `../../intent.md` Clarifications).

The policy the text must carry:
- **The engine is policy-neutral in nested.** It never pushes, opens a PR or merges into the host's default branch.
- **The host's custom lives in `nested-convention`'s text,** whose scope broadens from commits to **commits, branches and PRs**.
- **The orchestrator proposes the host branch name** from that custom and the **operator confirms** it.
- **The host base defaults to the host default branch.** The orchestrator, never the engine, fetches first when the custom says to.
- **At integration the host side follows the custom:** one PR per phase, or a ticket's phases folded onto one branch by rebase, with the checks re-run on the combined commit. Nothing is pushed, opened or merged without the operator's word.
- **At-root installs keep today's flow.**

The operator's own words: "this repo is not only for my use case." So write for any host and any team custom, with glide-ilab's per-ticket custom as one example at most.

## Changes

1. **`installer/main.py` `_nested_local_block`** (the managed `CLAUDE.local.md` block, ≈887-911):
   - Replace `- No parallel worktrees: the parallel-* commands refuse in a nested install.` with a rule like this (keep the block's terse voice):

     > **Parallel phases, only on the operator's word:** `{cmd} parallel-start <P> --host-branch <name> [--host-base <ref>]` cuts a pair: a host worktree under `.claude/worktrees/` on the host branch, with the nested worktree at its `workflow/`. Propose the branch name from the host's recorded custom and let the operator confirm it. The host side follows that custom; the engine never pushes, opens a PR or merges into the host's default branch.
   - Broaden "in the host's commit convention, which `{cmd} nested-convention` prints" to the host's conventions for **commits, branches and pull requests**.
   - In the `host_commit_convention=UNCONFIRMED` line, confirm the host's conventions (commits, branches, PRs). **Keep the `host_commit_convention=` key name**, which `next` prints and tools may parse.
2. **`installer/main.py` exclude entries** (≈1053): add `"/.claude/worktrees/"` to `exclude_entries`, so a fresh install and `--update` both carry it. S4's engine also ensures it at start; both forms count.
3. **A nested `workflow/.gitattributes`**: the nested repo gets the same `.gitattributes` payload the at-root install writes (`works/events.jsonl merge=union` and the generated-file notes), with the same line-merge write policy, targeted at the nested repo root, on install and `--update`. Find how at-root writes it (`build.py` embeds `.gitattributes`; `main.py` has its write policy) and reuse that path.
4. **The engine** (`scripts/workflow.py`):
   - `nested-convention`'s argparse help and `--text` help, plus the strings `cmd_nested_convention` prints: "commit convention" becomes "the host's conventions for commits, branches and pull requests". The `--text` help names what belongs in it: commit subjects and trailers; branch naming and base ("from fresh main"); PR shape, one per ticket or per phase, and who merges.
   - `phase-scope`'s stale labels (S4's note): `creation_commit=… (the host HEAD at new-phase)` and `base=… (the host HEAD when the phase was created…)` gain "…, or the host worktree's base after `parallel-start`".
   - Nothing else in the engine.
5. **`.claude/skills/parallel-phase/SKILL.md`:**
   - l.24 "the nested worktree home" becomes "the in-repo worktree home (`.claude/worktrees/`)".
   - **§1 rule 2 (Where):** add the nested form: `<host>/.claude/worktrees/P<N>-<slug>` on the operator-confirmed host branch, with the nested worktree at its `workflow/` on `phase/P<N>-<slug>`. The engine adds `/.claude/worktrees/` to the host's `info/exclude`.
   - **§1 rule 5:** the nested refusals: no `--host-branch`; the host branch checked out elsewhere; an unresolvable base.
   - **§1 rule 6:** `EnterWorktree` with the printed **host** worktree path. `CLAUDE.local.md` is copied in; skills, agents and settings read through from the main checkout; never create `<host-wt>/.claude/`.
   - **§2 (start, nested):**
     1. read `nested-convention`;
     2. propose a branch name in the host's custom, never with workspace IDs;
     3. the operator confirms;
     4. the base defaults to the host default branch (the resolution order); `--host-base <ref>` covers stacking on another phase's branch;
     5. when the custom says "branch from fresh main", the orchestrator runs `git -C <host> fetch` first;
     6. run `parallel-start <P> --host-branch <name> [--host-base <ref>]`.
   - **§3 (work):** product commits go to the host branch in the host worktree (the host's convention, no workspace IDs); workflow commits run `git -C workflow` there. Add the caveat line: **a worktree isolates files only; docker containers, ports, local databases and caches stay shared, so coordinate them across streams.**
   - **§5 (integrate, nested):**
     1. `parallel-gate`;
     2. `ExitWorktree keep`;
     3. in the main checkout: `git -C workflow pull --ff-only` only if it tracks a remote, then the same staged/uncommitted STOP rule, then `git -C workflow merge --no-ff phase/P<N>-<slug> -m "merge(P<N>): <name>"`;
     4. `parallel-merge-finish`;
     5. the tagged gate-section notes (`doc-new-version` + `rebuild-docs`);
     6. `git -C workflow commit`;
     7. **the host side, by the recorded custom:**
        - (a) **one PR per phase:** push the host branch and open its PR only on the operator's word;
        - (b) **a ticket's phases folded into one PR:** rebase or cherry-pick each phase's commits onto the ticket branch (no merge commits: squash-merging hosts publish every branch subject); re-run the host's pre-merge checks on the combined commit; keep each phase's host branch until the PR merges (its review recorded host commit ranges by sha).

        Never merge into the host's default branch, and never push, open or merge without the operator's word; where the custom is silent, ask;
     8. `parallel-teardown <P>` (S5's text: checks first in one report, `--discard-ignored`, nested then host, the host branch kept unless engine-created and empty, a re-run resumes);
     9. `git -C workflow commit`.
   - **Guardrails:** add the no-host-merge and no-push lines for nested.
6. **`.claude/skills/do-whole-phase/SKILL.md`** (the opening worktree paragraph and the integration bullet ≈l.53) and **`do-next-slice/SKILL.md`** (≈l.39):
   - In a nested install, the `worktree` or "in parallel" word runs `parallel-start <P> --host-branch <name>` after proposing the name from the host's custom and the operator confirming it;
   - `EnterWorktree` goes to the printed host worktree path;
   - integration follows `parallel-phase` §5's nested form.

   Keep each edit to the sentence or two the paragraph needs.
7. **`.claude/skills/commit/SKILL.md`** (≈l.15): "the convention `… nested-convention` prints" becomes "the host's conventions (commits, branches, PRs) …".
8. **The READMEs** (`README.md` ≈59, 128, 211-212, 407-408; `README.en.md` ≈111-112, 244, 325-327, 546-547):
   - Remove every "parallel worktrees only on an `--at-root` install" or "off in nested" claim.
   - Add one short "In a nested install" paragraph to each "Phase worktrees (on request)" section covering:
     - the pair;
     - `--host-branch` (proposed from your recorded custom, you confirm);
     - the base default;
     - the host side follows your team's custom (record it with `nested-convention`), and the workspace never pushes or merges;
     - teardown keeps your host branch.
   - Korean in `README.md`, English in `README.en.md`, each in its file's voice.
9. **Seeing every run (S7):** in `parallel-phase` (§3 or §5) and in each README's worktree section, add one line: `works/backlog.md`'s `## Streams` table lists the default stream and every in-flight worktree phase, read live from its branch (with the host branch in nested); `parallel-status` gives the detail.
10. **Rebuild:** `python3 installer/build.py`. No version bump.

## Doc impact (append to phase.md)

- `operations.md`: the nested parallel runbook. Start: propose and confirm `--host-branch`, the base default, fetch per the custom. Integration: `git -C workflow` merge; the host side by the recorded custom (one PR per phase, or fold by rebase and re-check); never push or merge without the operator's word. The worktree caveat about shared docker, ports and DBs (P35.S8)
- `architecture.md`: the nested install writes `/.claude/worktrees/` into its exclude block and a `workflow/.gitattributes`; `nested-convention`'s scope is commits, branches and PRs (P35.S8)

## Verification

1. `python3 installer/build.py --check`.
2. **A scratch nested install** from the rebuilt artifact (session scratchpad; no `claude -p`; `rm -rf` is denied, so leave scratch):
   - `.git/info/exclude`'s managed block lists `/.claude/worktrees/`;
   - `workflow/.gitattributes` has the union line;
   - `CLAUDE.local.md` carries the new parallel rule and the broadened convention wording;
   - `python3 workflow/scripts/workflow.py nested-convention --help` shows the broadened scope.
3. **`--update` over an install from the pre-S8 artifact.** Before editing, save it with `git show HEAD:bootstrap_agentic_workspace.sh > <scratch>/pre-s8.sh` and install a scratch host from it; then `--update` it with the rebuilt artifact. The update:
   - adds the exclude line and `workflow/.gitattributes`;
   - keeps a confirmed convention;
   - rewrites the managed block.
4. `grep -n "at-root\|--at-root" README.md README.en.md`: no line still says parallel worktrees need `--at-root`.
5. **`bash tests/retrofit_smoke.sh` as the only command in its Bash call.** Any assertion pinned to the old `CLAUDE.local.md` text or the "parallel off" wording is updated to the new text, each change listed in `result.md`. Record the PASS count before and after.
6. `python3 scripts/workflow.py validate`.

## Must not

Change engine behavior (only help text, printed wording and the two `phase-scope` labels), the hooks, the backlog or the teardown/start logic; write the S9 tests; bump the version; commit; or move workflow state.

## Dispatch

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
