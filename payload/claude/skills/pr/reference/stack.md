# A phase stacked on an open PR

A phase that depends on another phase's open PR branches from it: `pr branch <P> --name <b> --base <lower branch>` (a branch name; `create-phase` proposes it), and its body opens with `> merges after #<n>`. **Its close waits:** accepting it while the base is unmerged defers its B step until the lower PR merges and the steps below ran.

`next` prints `pr_stack=<P> <label> base=<lower> lower=merged|gone|moved -- <steps>` when the lower PR moved. Run the steps in the checkout holding the branch:

- **`lower=merged` or `lower=gone`:** `git fetch origin`; `git merge --no-ff origin/<default>` (never a rebase: identical changes merge cleanly, after a squash too); `git push`, never `--force`; `gh pr edit <n> --base <default>`; `python3 scripts/workflow.py pr branch <P> --name <b> --base <default>`; drop the series line, `pr check`, `gh pr edit <n> --body-file <body>`.
- **`lower=moved`** (fix commits on the lower PR): `git fetch origin`, `git merge --no-ff origin/<lower>`, `git push`.
- **A merge conflict stops** for the operator (`--stop-kind decision`); never a rebase to dodge it.

A dependent PR is retargeted before its lower branch is deleted; the close deletes a merged head branch only when no open PR targets it (`close.md`). A GitHub-native stack (`split.md`) manages itself.
