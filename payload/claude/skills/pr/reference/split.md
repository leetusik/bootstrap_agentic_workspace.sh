# Splitting a PR over the team's size limit

Size never splits a phase, and there is no default limit. When the team sets one and `pr check … --limit <n>` prints `size_status=over` (generated files, lockfiles and whole-file deletions excluded), the review picks a split (only where the cuts are clean) or a named exception in `## Review`, and the report lists the pick as "decided as drawn". A split is cut before the drafts open; with no team limit, only when the operator asks.

**Within one repo, a GitHub-native stack**, cut at slice-commit boundaries:

1. For each part 1..k-1 at its last commit `<sha>` (the orchestrator runs these): `git branch <b>-<n> <sha>`, `git switch <b>-<n>`, `python3 scripts/workflow.py pr branch <P> --name <b>-<n> --base <part n-1, or the default branch>` (a branch name; a sha or tag is refused), switch back to `<b>`.
2. The phase branch stays the top part: `pr branch <P> --name <b> --base <b>-<k-1>`.
3. Each part gets its own body and `pr check --branch <b>-<n>`, with `> Part n/k of <feature> · merges after <repo>#<n-1>`.
4. Open them bottom-up; use `gh stack` only if installed, else the operator clicks GitHub's "Create stack" banner. Without a native stack, each part follows its `pr_stack=` steps (`stack.md`) after its parent merges.

**Across repos, a series:** every PR opens with `> Part k/n of <feature> · merges after <repo>#<n> · index: <link>`; one wave index (repo · PR · merges after · state) lives in the first PR and is updated whenever the series' drafts open or change; merge in dependency order.

**Independent pieces** go as separate small PRs to the trunk, never a stack.
