# A phase stacked on an open PR

A phase that depends on another phase's still-open PR branches from it and opens its draft against it.

## The cut

- `python3 scripts/workflow.py pr-branch <P> --name <b> --base <lower branch>`. `create-phase` proposes the base when a new phase depends on an open PR. Give the base as a branch name; the orchestrator runs it.
- The body opens with the series line, in `reference/split.md`'s form: `> merges after #<n>`.

## Following `pr_stack=`

`next` prints `pr_stack=<P> <label> base=<lower> lower=merged|gone|moved -- <steps>` when the lower PR has moved. Run the steps in the checkout holding the branch (the phase's worktree when it has one):

- **`lower=merged` or `lower=gone`:**
  1. `git fetch origin`
  2. `git merge --no-ff origin/<default>`. Never a rebase: identical changes merge cleanly, after a squash merge too.
  3. `git push`, never `--force`.
  4. `gh pr edit <n> --base <default>`
  5. `python3 scripts/workflow.py pr-branch <P> --name <b> --base <default>` re-records the base, with no branch switch.
  6. Drop the series line from the body, run `python3 scripts/workflow.py pr-check <P> [--repo <name>] [--branch <b>]`, then `gh pr edit <n> --body-file <body>`.
- **`lower=moved`** (fix commits landed on the lower PR): `git fetch origin`, `git merge --no-ff origin/<lower>`, then `git push`.
- **A merge conflict stops** for the operator (`--stop-kind decision`). Never a rebase to dodge it.

## Branch deletion

The workflow never deletes a branch. A dependent PR is retargeted before anyone deletes its lower branch. GitHub retargets dependent PRs on its own only when a merged PR's head branch is deleted; then `gh pr edit --base` is a no-op, and the re-record still runs.

A GitHub-native stack (`reference/split.md`) still manages itself.
