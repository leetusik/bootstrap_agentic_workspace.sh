---
name: commit
description: Group pending changes by topic into focused conventional commits.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git reset:*), Bash(git commit:*), Bash(git -C workflow status:*), Bash(git -C workflow diff:*), Bash(git -C workflow log:*), Bash(git -C workflow add:*), Bash(git -C workflow reset:*), Bash(git -C workflow commit:*)
disable-model-invocation: true
---

# commit

Inspect pending changes, group them by topic, and make one focused commit per group.

**The convention:** `type(scope): summary`, imperative, no trailing period; the types are `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`. A phase branch merges as `merge(P<N>): <phase name>`. Attribute each commit to the model that did the work: `Co-Authored-By: <its name> <noreply@anthropic.com>`, never another session's trailer.

Never push, force-push, use `git add -A`, or skip hooks unless explicitly asked. A phase's pushes are the `pr` skill's, never this skill's: the draft opening when its review passes, the close's solo landing, and a fix round's or a stack merge's push to an open PR's branch.

**Product files committed outside a phase** (no slice is active): end the report with a line saying they have not been read, and that `/read-code` reads them before a push.

**A nested host** (`workflow/.agentic-nested.json` exists): commit the product repo first, then the workflow state.
- product changes go to their repo on the phase's branch (`pr-branch`; before `DECOMP`'s end or outside a phase, the current branch), in that repo's conventions (`python3 scripts/workflow.py nested-convention [--repo <name>]`): `Co-Authored-By` only where it says `allowed`, and no phase or slice IDs, `workflow/` paths or workspace files in the message. On a multi-repo host (`nested-repos` lists repos) the host folder gets no commit: check `git -C <repo> status --porcelain` for each repo and commit each one that changed with `git -C <repo> …`;
- state changes go to `git -C workflow …`, in the convention above. In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions are the workflow's history. Product commits are unchanged. In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`; run `mark-committed <slice>` after its product commit (with no product change, right after its finish).
- never stage `workflow/`, `CLAUDE.local.md` or the workspace's `.claude/` files into any repo.
