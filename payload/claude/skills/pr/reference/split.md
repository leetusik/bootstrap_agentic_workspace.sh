# Splitting a PR over the team's size limit

Size never splits a phase, and there is no default size limit. When the team's rules set one and a recorded branch's `pr-check … --limit <n>` prints `size_status=over` (counted lines: generated files, lockfiles and whole-file deletions excluded, tests counted), the review's PR drafting may split **the PRs**, with the team's limit steering where the cuts fall. The other answer is a **named exception** in `## Review` with its reason. The drafts open with no stop, so the review picks one in its body step (a split only where the cuts are clean), the split is cut before the drafts open, and the report (the gate's walkthrough, or the pass report on a waived gate) lists the pick under "decided as drawn". With no team limit there is nothing to pick; a split is still cut when the operator asks for one (a stack, say).

## Within one repo: a GitHub-native stack

Cut at **slice-commit boundaries** on the phase branch: each slice commit is a coherent, already-validated step, so it is a natural seam. Pick the commits that leave each part within the team's limit (or the size the operator asked for) and reviewable alone.

1. For each part 1..k-1, at its last commit `<sha>` (the orchestrator runs these; they write):
   - `git branch <b>-<n> <sha>`
   - `git switch <b>-<n>`
   - `python3 scripts/workflow.py pr-branch <P> --name <b>-<n> --base <previous part, or the default branch for part 1>` (it records the checked-out branch). Give the base as a branch name (`<b>-<n-1>`, `main`); a remote-tracking ref such as `origin/main` is recorded as `main`, and a sha or tag is refused
   - switch back to `<b>`.
2. **The phase branch stays the top part.** Re-record its base onto part k-1: `python3 scripts/workflow.py pr-branch <P> --name <b> --base <b>-<k-1>`.
3. **Each part gets its own body and its own `pr-check`** (`--branch <b>-<n>`), each with the series line `> Part n/k of <feature> · merges after <repo>#<n-1>`.
4. **Open them bottom-up** when the drafts open. Use `gh stack` only if it is already installed; otherwise the PRs open chained (each based on the one below) and the operator clicks GitHub's "Create stack" banner. A native stack rebases and retargets the parts itself when the bottom one merges, in squash-only repos too.
5. **Without a native stack** (no banner clicked, or GitHub Enterprise Server): after each parent merges, the next part follows its `pr_stack=` steps (`reference/stack.md`): merge the default branch in (never a rebase), push, `gh pr edit <n> --base <default>`, and re-record its base.

## Across repos: a series

Native stacks cannot span repos. Instead:

- **The series line** opens every PR: `> Part k/n of <feature> · merges after <repo>#<n> · index: <link>`. A part that is safe to merge out of order says so there.
- **One wave index** lives in the series' first PR (the bottom dependency): a table of repo · PR · merges after · state. Update it each time the series' drafts open or change, in the same step.
- **Merge order is dependency order.**

## Independent pieces

Pieces that do not depend on each other go as **separate small PRs to the trunk**, each with its own body, instead of a stack. A stack is for dependent steps only.
