# Updating an open PR, and reopening a done phase

## The update step (any fix round on an open PR)

At the fix round's next would-pass: `git push` (never `--force`); rewrite the body if the fix changed what it says, `pr check`, `gh pr edit <n> --body-file <body>`; re-record the draft's state, `pr record <P> --branch <b> --url <url>` (the same URL); answer each review thread in at most five lines, linking the fixing commit. Never a second `gh pr create`.

## Reopening a done phase

**One rule.** A change request on a phase whose pass is recorded (`done`, its PR open) always reopens it with `phase reopen`; the engine refuses `review --verdict changes_requested` there. The note says whose: `team-reported: <what>` (a team's review on a PR left Ready) or `operator-reported: <what>` (at a close that finds the phase `done`, a red CI at the close's `ci` step, a change after Ready). Before the pass it is no reopen: `review --verdict changes_requested` (`close.md`).

On the operator's word, the orchestrator:

1. **The checkout first.** Nested: the host's main checkout still holds the PR branch, and a branch lives in one worktree at a time: at a slice boundary run `git -C <host> switch <default>` (the engine refuses otherwise, naming it). At root: work where the PR branch is checked out (its record says not `done` on the default branch): stay there, `git switch <branch>` at a slice boundary, or `git worktree add <sibling> <branch>` and `cd` there.
2. `python3 scripts/workflow.py pr sync <P>` (the engine refuses a phase whose every PR reads `state=merged`).
3. `python3 scripts/workflow.py phase reopen <P> --note "<who>-reported: <what>"`: the phase goes `in_progress` with `changes_requested` and a required gate re-opens. Nested: it cuts the phase's worktree pair on the existing PR branch in one stamp commit (`reopened=<P> branch=<label> worktree=<path>`). At root: in place. No worktree is cut or claimed, no stamp, nothing committed. **At root, commit the reopen with the fix round's first commit**, or root `phase scope` misses the fix.
4. The fix round there, on the same branch (a team's request: `gh pr view <n> --json reviews,comments`; an operator's: their words or the failing checks), then a re-review.
5. At its would-pass, the update step; then the gate if required, and the close again (a team repo's PR is already Ready, so B leaves it for the team).
