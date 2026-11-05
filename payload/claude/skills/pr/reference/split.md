# Splitting a PR over the size flag

Size never splits a phase. When a recorded branch's `pr-check` prints `size_status=flag` (over 1,000 counted lines: generated files, lockfiles and whole-file deletions excluded, tests counted), the review's PR drafting may split **the PRs**, with the ≤400 target steering where the cuts fall. The other answer is a **named exception** in `## Review` with its reason. Offer both at the stop; the operator chooses.

## Within one repo: a GitHub-native stack

Cut at **slice-commit boundaries** on the phase branch: each slice commit is a coherent, already-validated step, so it is a natural seam. Pick the commits that leave each part near the target and reviewable alone.

1. For each part 1..k-1, at its last commit `<sha>` (the orchestrator runs these; they write):
   - `git branch <b>-<n> <sha>`
   - `git switch <b>-<n>`
   - `python3 scripts/workflow.py pr-branch <P> --name <b>-<n> --base <previous part, or the default branch for part 1>` (it records the checked-out branch)
   - switch back to `<b>`.
2. **The phase branch stays the top part.** Re-record its base onto part k-1: `python3 scripts/workflow.py pr-branch <P> --name <b> --base <b>-<k-1>`.
3. **Each part gets its own body and its own `pr-check`** (`--branch <b>-<n>`), each with the series line `> Part n/k of <feature> · merges after <repo>#<n-1>`.
4. **Open them bottom-up** on `push`. Use `gh stack` only if it is already installed; otherwise the PRs open chained (each based on the one below) and the operator clicks GitHub's "Create stack" banner. A native stack rebases and retargets the parts itself when the bottom one merges, in squash-only repos too.
5. **Without a native stack** (no banner clicked, or GitHub Enterprise Server): after each parent merges, the next part needs a rebase onto the default branch and `gh pr edit <n> --base <default>`. Print those lines; never run them unasked.

## Across repos: a series

Native stacks cannot span repos. Instead:

- **The series line** opens every PR: `> Part k/n of <feature> · merges after <repo>#<n> · index: <link>`. A part that is safe to merge out of order says so there.
- **One wave index** lives in the series' first PR (the bottom dependency): a table of repo · PR · merges after · state. Update it on each `push` of the series, in the same word.
- **Merge order is dependency order.**

## Independent pieces

Pieces that do not depend on each other go as **separate small PRs to the trunk**, each with its own body, instead of a stack. A stack is for dependent steps only.
