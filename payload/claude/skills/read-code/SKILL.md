---
name: read-code
description: "Blind-read a product change made outside a phase before it is pushed: dispatch the code-reader on the unpushed range (or a named one) and report its findings for the operator to decide on."
argument-hint: "[<base>..<head> | <ref>]"
allowed-tools: Bash(python3 scripts/workflow.py executor-route:*), Bash(python3 scripts/workflow.py nested-repos), Bash(python3 scripts/workflow.py phase-scope --pathspec), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git ls-files:*), Read, Agent
disable-model-invocation: true
---

# read-code

A blind read of a code change before it is pushed, for work made **outside a phase**: a hotfix on a PR branch, a quick follow-up. The `code-reader` agent reads the diff cold, as the change's first hostile reader, and reproduces what it suspects. Inside a phase the review runs the reader itself; this skill is for everything else.

1. **The range: one base commit, resolved here.** The reader never resolves a branch; it gets `base` as a commit sha. Run each command in the repo (on a multi-repo host, where `python3 scripts/workflow.py nested-repos` lists repos, in each listed repo: one read per repo that has changes) and read what it prints:
   - **the upstream:** `git rev-parse -q --verify '@{u}'` (nothing printed: no upstream);
   - **the default branch**, in the engine's order (`origin/HEAD`, `main`, `master`): `git symbolic-ref -q --short refs/remotes/origin/HEAD`, else the first of `origin/main`, `main`, `origin/master`, `master` for which `git rev-parse -q --verify '<ref>^{commit}'` prints a sha (the remote-tracking ref first: a stale local `main` would put teammates' commits into the read).

   Then, by argument (the pathspec is step 2's):
   - **none:** `base` is `git merge-base <the upstream, else the default branch> HEAD`, and `head` is `working-tree`: the current branch's unpushed commits plus its uncommitted changes, read as `git diff <base> -- <pathspec>` (committed, staged and unstaged) plus every untracked file that is not ignored, `git ls-files --others --exclude-standard -- <pathspec>`, each a new file;
   - **`<base>..<head>`:** `base` is `git merge-base <base> <head>`, `head` is `git rev-parse -q --verify '<head>^{commit}'`, and the read is `git diff <base>...<head> -- <pathspec>`: from the fork point, never a tip that moved after it;
   - **one `<ref>`:** the same, with the default branch as `<base>` and `<ref>` as `<head>`.

   A command that prints nothing where a ref is needed (no upstream and no default branch, a ref that does not resolve, a `merge-base` with no common commit): say which did not resolve and ask the operator for an explicit `<base>..<head>`; never guess, never pass an empty base. An empty read over the pathspec (no diff and no untracked file): say so and stop.

2. **The pathspec: the product files only**, never the workspace's own (at root its state and docs folders, nested its `workflow/` folder; a host folder named works or docs is product there). Run `python3 scripts/workflow.py phase-scope --pathspec` and pass the value after `pathspec=` verbatim: one line at root and in a nested install; on a multi-repo host, the `repo=<name> pathspec=` line of the repo you read (`repo=. (host)` for the host). It is the pathspec `phase-scope` reads a phase's files with; never write one by hand.

3. **The purpose.** One plain sentence saying what the change is for, taken from the operator's request in this session. If nothing says, ask the operator in one line before dispatching. Never a phase or slice id.

4. **The dispatch.** Run `python3 scripts/workflow.py executor-route --code` and dispatch the `code-reader` agent from its lines, as a background task: `subagent_type=`, plus `model` when `pass_model=yes` and `effort` when `pass_effort=yes`; relay any `warning=` line. The prompt gives the repo path, the range (`base`, a commit sha; `head`, a commit sha or `working-tree`), the pathspec, the purpose, and an output path **outside the repo**, `${TMPDIR:-/tmp}/code-read-<branch>-<short sha>.md`, since nothing here belongs to a phase. Its first line is `read-code: <repo> <range>`: no `slice:` line and no phase or slice id anywhere in the prompt, so the meter reads the span as the `code-reader` route and never pins it on a slice by name (it falls to the time window, else `unattributed`).

5. **The report.** When the reader returns, read its file and relay: its two-sentence read of what the change does, against the purpose; each finding in one line (id, lens, severity, `confirmed` or `suspected`, its effect); its coverage (probed / read / not read). Then the operator decides:
   - **fix**: ordinary work, then `/read-code` again as a re-read, giving the reader its earlier output and the fix range;
   - **push as it is**: the operator's push, never this skill's;
   - **park it**: `python3 scripts/workflow.py defer-job`, on the operator's word.

## Never

- push, commit, fix or edit anything; the reader's file is the only thing written, and the reader writes it;
- substitute another agent when the session has no agent type the `subagent_type=` line names: a new agent file loads only in a fresh session, so say so and stop;
- run the reader on a phase's own review: that dispatch is the review's.
