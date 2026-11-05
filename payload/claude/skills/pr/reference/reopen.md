# Updating an open PR, and reopening a done phase

## The update step (any fix round on an open PR)

A fix round whose PR is already open (failures the operator reported on GitHub before the pass, from the close's step A.5, or a team's review after it) updates that PR at its next would-pass:

1. Push the fix commits: `git push`, never `--force`.
2. Rewrite the body if the fix changed what it says, re-run `python3 scripts/workflow.py pr-check <P> [--repo <name>] [--branch <b>]`, and replace it: `gh pr edit <n> --body-file <body>`.
3. Answer each review thread in at most five lines, linking the fixing commit. A longer answer becomes a body edit or a repo doc.

Never a second `gh pr create`.

## Team-reported changes after the phase is done

The operator's word reopens the phase (a team asked for changes on a Ready PR):

1. `python3 scripts/workflow.py pr-sync <P>` first: merged state is only as fresh as the last sync, and the engine refuses a phase whose every PR reads `state=merged`.
2. `python3 scripts/workflow.py reopen-phase <P> --note "team-reported: <what>"`. It sets the phase `in_progress` with `changes_requested`, re-opens a required gate, and starts the phase's own worktree on its existing PR branch: `reopened=<P> branch=<label> worktree=<path>`. The one word covers both, so a phase running at the time never waits. The orchestrator runs it.
3. **The fix round:** read the team's review (`gh pr view <n> --json reviews,comments`), cut fix slices on the same branch in that worktree, then a re-review.
4. **At its would-pass:** the update step above.
5. **Then the gate, if required, and the close again** (`reference/close.md`). A team repo's PR is already Ready, so the close's step B leaves it for the team.
