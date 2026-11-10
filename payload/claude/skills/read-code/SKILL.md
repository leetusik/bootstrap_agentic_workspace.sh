---
name: read-code
description: "Blind-read a product change made outside a phase before it is pushed: dispatch the code-reader on the range its step 1 resolves, or a named one, and report its findings for the operator to decide on."
argument-hint: "[<base>..<head> | <ref>]"
allowed-tools: Bash(python3 scripts/workflow.py executor-route:*), Bash(python3 scripts/workflow.py nested-repos), Bash(python3 scripts/workflow.py phase-scope --pathspec), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git ls-files:*), Bash(git config --get:*), Read, Agent
disable-model-invocation: true
---

# read-code

A blind read of a code change before it is pushed, for work made **outside a phase**: a hotfix on a PR branch, a quick follow-up. The `code-reader` agent reads the diff cold, as the change's first hostile reader, and reproduces what it suspects. Inside a phase the review runs the reader itself; this skill is for everything else.

1. **The range: one base commit, resolved here.** The reader never resolves a branch; it gets `base` as a commit sha. Run each command in the repo (on a multi-repo host, where `python3 scripts/workflow.py nested-repos` lists repos, in each listed repo: one read per repo that has changes) and read what it prints:
   - **the upstream:** `git rev-parse -q --verify '@{u}'` (nothing printed: no upstream);
   - **the default branch**, in the engine's order (`origin/HEAD`, `main`, `master`): `git symbolic-ref -q --short refs/remotes/origin/HEAD`, else the first of `origin/main`, `main`, `origin/master`, `master` for which `git rev-parse -q --verify '<ref>^{commit}'` prints a sha (the remote-tracking ref first: a stale local `main` would put teammates' commits into the read).

   Then, by argument (the pathspec is step 2's):
   - **none:** `base` is the fork point nearer `HEAD`, of two: `bu`, `git merge-base <the upstream> HEAD`, and `bd`, `git merge-base <the default branch> HEAD`. With both, `base` is `bu` when `git merge-base --is-ancestor <bd> <bu>` exits 0 (nothing from the default branch came in since the last push: the read is the unpushed work), else `bd` (the default branch was merged in or rebased onto since: the read is the branch's whole change, as its pull request shows it); with one, that one. `head` is `working-tree`: the commits since `base` plus the uncommitted changes, read as `git diff <base> -- <pathspec>` (committed, staged and unstaged) plus every untracked file that is not ignored, `git ls-files --others --exclude-standard -- <pathspec>`, each a new file;
   - **`<base>..<head>`:** `base` is `git merge-base <base> <head>`, `head` is `git rev-parse -q --verify '<head>^{commit}'`, and the read is `git diff <base>...<head> -- <pathspec>`: from the fork point, never a tip that moved after it;
   - **one `<ref>`:** the same, with the default branch as `<base>` and `<ref>` as `<head>`.

   A command that prints nothing where a ref is needed (neither `bu` nor `bd` resolves, a ref that does not resolve, a `merge-base` with no common commit): say which did not resolve and ask the operator for an explicit `<base>..<head>`; never guess, never pass an empty base. An empty read over the pathspec (no diff and no untracked file): say so and stop.

2. **The pathspec: the product files only**, never the workspace's own (at root its state and docs folders, nested its `workflow/` folder; a host folder named works or docs is product there). Run `python3 scripts/workflow.py phase-scope --pathspec` and pass the value after `pathspec=` verbatim: one line at root and in a nested install; on a multi-repo host, the `repo=<name> pathspec=` line of the repo you read (`repo=. (host)` for the host). It is the pathspec `phase-scope` reads a phase's files with; never write one by hand.

3. **The purpose, and what will be read.** One plain sentence saying what the change is for, taken from the operator's request in this session. If nothing says, ask the operator in one line before dispatching. Never a phase or slice id.

   **Show what will be read**, one line per repo, before the dispatch: the base (its short sha, and `bu`, `bd` or the range you were given), the commits `git log --oneline --no-merges <base>..<head>` prints (`HEAD` for `working-tree`; the count, and the subjects when there are five or fewer), and the count of uncommitted and untracked files, the lines `git status --porcelain -uall -- <pathspec>` prints. **With no argument, a foreign author is a question:** when `git log --no-merges --format=%ae <base>..HEAD` prints an address other than `git config --get user.email` (or that prints nothing), say how many commits and whose, and ask the operator in one line: read it as it is, or give `<base>..<head>`. Never drop a commit or pick a range yourself. Neither guard sees a branch stacked on the author's own unmerged branch: the list shows whether the read takes the parent's commits too, and `<parent>..HEAD` reads the child alone.

4. **The dispatch.** Run `python3 scripts/workflow.py executor-route --code` and dispatch the `code-reader` agent from its lines, as a background task: `subagent_type=`, plus `model` when `pass_model=yes` and `effort` when `pass_effort=yes`; relay any `warning=` line. The prompt gives the repo path, the range (`base`, a commit sha; `head`, a commit sha or `working-tree`), the pathspec, the purpose, and an output path **outside the repo**, `${TMPDIR:-/tmp}/code-read-<branch>-<short sha>.md`, since nothing here belongs to a phase. Its first line is `read-code: <repo> <range>`: no `slice:` line and no phase or slice id anywhere in the prompt, so the meter reads the span as the `code-reader` route and never pins it on a slice by name (it falls to the time window, else `unattributed`). **Its commands may ask you first:** the agent file sets `permissionMode: bypassPermissions`, which Claude Code honors only when this session already runs in bypass mode; in auto mode the reader runs under auto mode's checks, and in any other mode it runs in this session's mode, so its reproduction commands ask for your permission in this session (unless an allow rule covers them; in `dontAsk` mode they are denied).

5. **The report.** When the reader returns, read its file and relay: its two-sentence read of what the change does, against the purpose; each finding in one line (id, lens, severity, `confirmed` or `suspected`, its effect); its coverage (probed / read / not read). Then the operator decides:
   - **fix**: ordinary work, then `/read-code` again as a re-read, giving the reader its earlier output and the fix range;
   - **push as it is**: the operator's push, never this skill's;
   - **park it**: `python3 scripts/workflow.py defer-job`, on the operator's word.

## Never

- push, commit, fix or edit anything; the reader's file is the only thing written, and the reader writes it;
- substitute another agent when the session has no agent type the `subagent_type=` line names: say the type is missing from this session and a restart loads it (Claude Code uses a new agent file at the next delegation, except in a session started before `.claude/agents/` existed or with `--disable-slash-commands`, which sees it only after a restart), and stop;
- run the reader on a phase's own review: that dispatch is the review's.
