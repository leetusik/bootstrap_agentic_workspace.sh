---
name: parallel-phase
description: "Run a phase in its own git worktree when the operator asks for one: start it, add a repo, see every stream; it integrates back by the pr skill's close checklist (gate, local merge, teardown)."
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash
disable-model-invocation: true
---

# parallel-phase

A phase can run on its own branch in its own git worktree, driven from the session that started it, while the default stream keeps `main` free for another phase. **Since v43 this is opt-in: a phase runs on the current checkout unless the operator asks.** Asking is one of:

- the **`worktree` mode word** on `/do-next-slice` or `/do-whole-phase` (or "in a worktree", "in parallel", "on its own branch"), on a phase still `planned`;
- **`parallel-start <P>` run by the operator's own hand**; execution then enters the stamped worktree without asking again;
- an explicit instruction to run two phases at once.

A linked checkout (`next` prints `store=cloud`) refuses `parallel-start` and the other stream commands: run its phases on the default stream.

**One exception: an explain phase (v86).** `create-phase`'s explain route starts every explain phase in its own worktree unless its `## Explain` says `worktree: no`; its one confirmation is the word. Its branch touches only its phase folder and `works/`, so it merges back by itself after its pass (below).

The unit of worktree parallelism is the **phase**; slices inside it run one at a time, or together as `do-whole-phase`'s wave in the phase's own checkout. This skill covers start, adding a repo and status; **integration is the close's, stated once in `.claude/skills/pr/reference/close.md`** (*A worktree phase: integrate*).

## 1. Worktree rules

1. **When — only when asked**. `do-next-slice` / `do-whole-phase` run `parallel-start <P>` when told to, never on their own initiative; `create-phase` never does (bar its explain route). A phase already stamped is entered without asking again.
2. **Where.** `<repo>/.claude/worktrees/P<N>-<slug>` on branch `phase/P<N>-<slug>` (`--worktree`, `--slug` override); the engine puts `.claude/worktrees/` in `.git/info/exclude`, never `.gitignore`. **Nested:** a pair, the host worktree at that path on the operator-confirmed host branch (an explain: detached at the host base), with the nested worktree at its `workflow/` on `phase/P<N>-<slug>`.
3. **The stamp commit.** The engine's one commit, `chore(works): opt <P> into parallel execution`, holds exactly the phase folder and the six generated `works/` files (`git commit --only -- <paths>`), stamping `execution: {mode: "parallel", branch, worktree, consolidation: "pending"}`; the branch is cut from it so both sides carry the stamp.
4. **A dirty tree does not block it.** Everything else stays uncommitted in the default checkout; the worktree starts from the stamp commit.
5. **What refuses**, before any write: not `planned`; an `execution` block; no git; a parallel stream; a merge or rebase in progress; the branch or path taken. Nested, also: no `--host-branch` on a non-explain phase, the host branch checked out elsewhere, an unresolvable host base.
6. **Enter.** `EnterWorktree` with the printed path (nested: the host worktree), re-run `next` (`stream=phase/…`), work there. Membership is the current branch against the stamped `execution.branch`. Skills, agents and settings read through from the main checkout (never create `<host-wt>/.claude/`), and Claude Code reads the main checkout's `.claude/settings.local.json` from a worktree session, so its allow rules apply there.
7. **The merge** is the close's integration (`.claude/skills/pr/reference/close.md`), after `parallel-gate <P>` opens.
8. **Staying on `main` needs nothing.** `parallel-skip <P>` and `new-phase --on-main` are **retired no-ops** (v43) that write nothing. A phase still pinned with v42's `execution: {"mode": "default"}` keeps it, and `parallel-start` refuses it; delete the block by hand to un-pin.

**The two hints.** `new-phase` (another phase `in_progress` here) and `next` (a later phase `planned` behind the current one) may print `hint: … parallel-start <P>`. **Relay a hint to the operator; never act on it.** When `next` prints one, the do-* skills relay it and run nothing.

## 2. Start

Run `python3 scripts/workflow.py parallel-start <P>` from the default stream, before the phase's first `start-slice`, on the operator's word, then enter the printed path.

**Nested:** read `nested-convention`; propose a host branch name in that custom with no phase or slice IDs (the `Branches:` line `create-phase` confirmed, when there is one); the operator confirms it; it is the phase's PR branch (`pr-branch` records it at `DECOMP`'s end). The base defaults to the host's default branch (`--host-base <ref>` to stack); `git fetch` first when the custom says fresh main (the engine never fetches). Then `parallel-start <P> --host-branch <name> [--host-base <ref>]`.

**An explain phase needs no host branch (v86).** With no `--host-branch` it cuts a detached host worktree at the host base (`host_branch=-`); it has nothing to integrate on the host.

## 3. Work

Slice work is unchanged. `parallel-status` shows every stream and writes nothing; `next` covers only this checkout's stream, and a `pending` stop halts only its own. A worktree's state changes rerun the default checkout's `rebuild` (v67), leaving those files uncommitted there.

**A worktree isolates files only:** containers, ports, databases and caches stay shared, so coordinate them. Do not merge or rebase against `main` mid-phase unless asked. Nested: product commits go to the host branch in the host's convention, workflow commits `git -C workflow …`. Generated files are **regenerated, not merged**; in `phase.md` only the `## Slices` block is (take a side, `rebuild`), and every other section and `topics/*.md` merge by hand, entry by entry.

## 4. Review on the branch

The review runs as `review-phase` says. A branch review versions no doc: the sections a default-stream review writes itself (`## Regression Checklist`, `## Operator Runtime`) go in its `result.md` under `## Gate sections (written at merge)`, verbatim, and the integration writes exactly those. The acceptance gate opens and clears on the branch before the pass, so an open `parallel-gate` already means the operator accepted the work.

## 5. Integrate

By the close (`.claude/skills/pr/reference/close.md`). This skill carries no second PR procedure. What the gate reads: `GATE OPEN` needs the branch's phase `done` with a `pass` and a quiet default stream (no phase there `in_progress`, `in_review`, `pending` or `blocked`). A busy main means wait, **unless the engine exempts the branch (v86):** it diffs the branch since its merge-base and prints `exemption=phase-folder-only (<n> paths)` when every path is the phase folder, the six `works/` files, or added under `works/deferred/open/` or `works/agenda/`; then the busy reasons become a `note:`. The branch-side reasons are never exempt. CI's seed re-runs the gate on `phase/*` PRs (`--branch-ref HEAD --main-ref origin/<base>`).

**A phase with no debt settles itself (v86):** a pass with no `## Doc impact` note flips a worktree phase's `consolidation` to `"done"`, so it archives normally.

### An explain phase merges back by itself

Right after its pass, with no stop: `parallel-gate <P>` (a busy stream does not close it under `exemption=phase-folder-only (<n> paths)`), the close's merge steps (no host side for a detached host worktree), then `parallel-teardown <P> --discard-ignored` nested (it deletes the `pages/` cache) or plain at root, then commit. **When it cannot merge** (a closed gate, something staged, a conflict outside the generated files): leave the branch `done` and unmerged, say so, and never unstage or discard; `next` on the default stream then prints `merge_ready=<P>:<branch>`, and whoever drives that stream integrates it at its next slice boundary.

### A loop phase lands at its checkpoints

A loop phase (`run-loop`) reaches the default branch at each **passing checkpoint**, never only at the end:

1. `next` on the default stream prints `merge_ready=<P>:<sha7>` (nested: `host=<sha7>` too): the checkpoint's commit, **not the branch tip**.
2. At a slice boundary, `parallel-gate <P>`: it prints `merge_commit=<sha>`, and its exemption also covers the charter's `outputs` (nested: the host diff must stay in them; merge the named host commit first, in the host's conventions).
3. Commit this checkout's `works/` first, then `git merge <merge_commit>` (take a side of a generated conflict, regenerate), `parallel-merge-finish`, and `parallel-consolidated <P>` when that checkpoint stamped a debt. From here the loop words only queue in the loop's `loop/control.json`.
4. The loop worktree takes the default branch back at its next cycle boundary: `git merge --no-ff <default>`, `parallel-merge-finish`.
5. `parallel-teardown <P>` only after the loop's final REVIEW passes.

### A reopened phase — a change request on its open PR

On the operator's word (also the worktree word), by `.claude/skills/pr/reference/reopen.md`: `reopen-phase <P> --note "team-reported: <what>"` or `--note "operator-reported: <what>"`. **Nested:** `git -C <host> switch <default>`, `pr-sync <P>`, `reopen-phase` (a pair on the existing PR branch); run the fix round and re-review there; the teardown keeps the host branch for its open PR. **At root:** in place, on the PR branch (stay, `git switch <branch>` at a slice boundary, or `git worktree add <sibling> <branch>`). Then `pr-sync <P>` there (the default branch's record is stale), then `reopen-phase`: no worktree, nothing to integrate; commit the reopen with the fix round's first commit.

## 6. A multi-repo host: a set

When `nested-repos` lists repos, a phase worktree is a **set**: the host worktree, the nested worktree at its `workflow/`, and one worktree per repo the phase changes at `<host worktree>/<repo>/`. Each repo follows its own custom; the engine never fetches, pushes or merges into a repo's default branch.

- **Start:** per repo, read `nested-convention --repo <name>`, propose a branch name (no IDs), the operator confirms; the base is the registry's `default_branch` (local; `--repo-base <name>=<ref>` to stack; fetch first if the custom says so). `parallel-start <P> --host-branch <name> --repo <name>=<branch> [--repo-base <name>=<ref>] ...`. An existing branch checked out nowhere is reused; one checked out anywhere is refused.
- **Add a repo** later, from inside the set: `parallel-add-repo <P> --repo <name>=<branch> [--repo-base <ref>]` (never re-run `parallel-start`); `--adopt` stamps a repo worktree already at `<host worktree>/<repo>/`.
- **Not in the set:** `phase-scope` prints `not in this worktree set` and never reads that repo's main checkout; `phase-scope <P> --repo <name> --base <ref>` reads it anyway.
- **Work:** product commits go to each repo's branch (`git -C <repo> …` from the host worktree), never to the host folder; `pr-branch --repo <name>` records each, one draft PR each.
- **Teardown** (the close's step) refuses uncommitted work, ignored worktree-only files (unless `--discard-ignored`) and detached commits, then removes the repo worktrees, the nested, the host. **A worktree the stamp does not name is refused, always**, `--discard-ignored` included: remove it after integrating its branch (`git -C <repo> worktree remove <path>`), or `--adopt` it.

## Guardrails

- Never merge a parallel phase whose `parallel-gate` is closed, and never two phases into one quiet point at once; never merge from inside the worktree.
- `parallel-merge-finish` and `parallel-consolidated` run on the default stream, after the merge, never from a phase worktree.
- Never hand-edit a generated file's conflict: take a side and regenerate.
- Never `parallel-start` a phase the operator did not ask about (an explain phase's confirmation is the asking), nor a pinned or in-flight one; never enter a path the engine did not print.
- Pushes are the `pr` skill's alone (the draft, the close's landing, a fix round's push to an open PR); never push, open a PR or merge into any repo's default branch beyond them without the operator's word.
