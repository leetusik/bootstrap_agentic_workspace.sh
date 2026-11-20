---
name: read-code
description: "Blind-read a product change made outside a phase before it is pushed: dispatch the code-reader on the range its step 1 resolves, or a named one, and report its findings for the operator to decide on."
argument-hint: "[<base>..<head> | <ref>]"
allowed-tools: Bash(python3 scripts/workflow.py executor-route:*), Bash(python3 scripts/workflow.py nested-repos), Bash(python3 scripts/workflow.py phase scope --pathspec), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git ls-files:*), Bash(git config --get:*), Read, Agent
disable-model-invocation: true
---

# read-code

A blind read of a change made **outside a phase** (a hotfix, a quick follow-up) before it is pushed. A phase's read comes from its review executor, never from here.

1. **The range: one base commit.** In each repo with changes (`python3 scripts/workflow.py nested-repos` lists them on a multi-repo host), find the upstream (`git rev-parse -q --verify '@{u}'`) and the default branch (`git symbolic-ref -q --short refs/remotes/origin/HEAD`, else the first of `origin/main`, `main`, `origin/master`, `master` that resolves). Then:
   - **no argument:** `bu = git merge-base <upstream> HEAD`, `bd = git merge-base <default> HEAD`; `base` is `bu` when `git merge-base --is-ancestor <bd> <bu>` exits 0, else `bd` (with one, that one). `head` is `working-tree`: the diff from `base` plus untracked, unignored files;
   - **`<base>..<head>`:** `base = git merge-base <base> <head>`, `head` its commit sha;
   - **one `<ref>`:** the default branch as base, `<ref>` as head.

   Nothing resolves, or no common commit: say which and ask for an explicit `<base>..<head>`; never guess. An empty read: say so and stop.
2. **The pathspec:** the `pathspec=` value `python3 scripts/workflow.py phase scope --pathspec` prints (on a multi-repo host, that repo's `repo=<name> pathspec=` line), verbatim; never one written by hand.
3. **Show what will be read**, one line per repo: the base (short sha, `bu`, `bd` or the given range), the commits (`git log --oneline --no-merges <base>..<head>`), and the uncommitted and untracked count. With no argument, a commit by another author (`git log --no-merges --format=%ae <base>..HEAD` against `git config --get user.email`) is a one-line question: read it as is, or give a range.
4. **Dispatch** from `python3 scripts/workflow.py executor-route --code`'s lines, in the background: the repo, `base`, `head`, the pathspec, one plain sentence on what the change is for (ask if nothing says), and an output path outside the repo, `${TMPDIR:-/tmp}/code-read-<branch>-<short sha>.md`. The prompt's first line is `read-code: <repo> <range>`, with no phase or slice id anywhere. In a session not in bypass mode its reproduction commands may ask your permission.
5. **Report:** its two-sentence read against the purpose, each finding in one line (id, lens, severity, confirmed or suspected, effect), its coverage. The operator decides: fix and `/read-code` again; push as it is (their push); or park it (`defer-job`, on their word).

Never push, commit, fix or edit anything; never substitute another agent when the session has no `code-reader` type (say a restart loads it, and stop).
