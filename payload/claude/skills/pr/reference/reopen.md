# Updating an open PR, and reopening a done phase

## The update step (any fix round on an open PR)

A fix round whose PR is already open updates that PR at its next would-pass. The round comes from a change request before the pass (the close's step A.5 on a required gate, `review-phase --verdict changes_requested`) or after it (a reopen below, team- or operator-reported):

1. Push the fix commits: `git push`, never `--force`.
2. Rewrite the body if the fix changed what it says, re-run `python3 scripts/workflow.py pr-check <P> [--repo <name>] [--branch <b>]`, and replace it: `gh pr edit <n> --body-file <body>`.
3. Answer each review thread in at most five lines, linking the fixing commit. A longer answer becomes a body edit or a repo doc.

Never a second `gh pr create`.

## Reopening a done phase (a change request after the pass)

**One rule.** A change request on a phase whose pass is recorded (its status is `done`, its PR still open) always reopens it with `reopen-phase`; the engine refuses `review-phase --verdict changes_requested` there and names the reopen. The note says whose request it is:

- `team-reported: <what>`: a team's review on the PR (a team repo's PR stays open, Ready, after the close);
- `operator-reported: <what>`: the operator's request at a close that finds the phase already `done` (a waived gate's `close`, a legacy phase, a pre-v93 draft: `reference/close.md` A.5), a red CI at its B.4, or a change asked for after Ready.

A change request **before** the pass (a required gate, between `accept-gate --clear` and the pass) is no reopen: it stays `review-phase --verdict changes_requested` (`reference/close.md` A.5).

The operator's word reopens the phase; the orchestrator runs it:

1. **The checkout first** (the `parallel-phase` skill's *A reopened phase* states the same):
   - **Nested install: the host's main checkout off the PR branch.** The phase ran there, so after the drafts opened (and after a team close) that checkout still holds the PR branch, and a branch lives in one worktree at a time. At a slice boundary run `git -C <host> switch <default>`; the engine refuses otherwise and names the same command. The phase's record lives in the nested repo, so the next steps run from the main checkout.
   - **At root: where the PR branch is checked out.** The PR branch carries the phase's own record; on the default branch it reads not yet `done`, so `pr-sync` finds no PR there and the reopen refuses. Run in place where that branch is checked out, switch to it at a slice boundary (`git switch <branch>`), or, with another phase running in the main checkout, `git worktree add <sibling> <branch>` and `cd` there.
2. `python3 scripts/workflow.py pr-sync <P>`: merged state is only as fresh as the last sync, and the engine refuses a phase whose every PR reads `state=merged`.
3. `python3 scripts/workflow.py reopen-phase <P> --note "<who>-reported: <what>"`. It sets the phase `in_progress` with `changes_requested` and re-opens a required gate, then:
   - **nested:** it cuts the phase's own worktree pair on its existing PR branch in one stamp commit, printing `reopened=<P> branch=<label> worktree=<path>`. A phase running at the time never waits;
   - **at root: in place.** No worktree is cut or claimed, no stamp, nothing committed (it prints `worktree=<that checkout>`). **At root, commit the reopen with the fix round's first commit**: the phase folder and `works/`, as the engine prints. Committed only with the pass, root `phase-scope` still reads the first pass and misses the fix.
4. **The fix round** in that checkout, on the same branch: read the request (a team's review: `gh pr view <n> --json reviews,comments`; an operator's: their words, or the failing checks), cut fix slices, then a re-review.
5. **At its would-pass:** the update step above.
6. **Then the gate, if required, and the close again** (`reference/close.md`). A team repo's PR is already Ready, so the close's step B leaves it for the team.
