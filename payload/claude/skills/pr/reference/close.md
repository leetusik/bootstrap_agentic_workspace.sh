# The close: Ready, and the merge in a solo repo

The close takes a phase's draft PR to Ready and, in a repo the operator owns alone, merges it. The orchestrator runs it; an executor never does. It runs on:

- the operator's `accept` at a required gate;
- the operator's word `close` for a waived-gate phase's draft (`pr_open=`'s hint names that word);
- a `pr_open=` line whose hint says the close is due ("the close is due", "the close's merge is due"): a close cut off midway resumes from its first unfinished step.

**The order.** On a required gate the re-read (A) runs after `accept-gate <P> --clear` and **before** `review-phase <P> --verdict pass`, so a change request found on GitHub can still become a fix round on the same, not-yet-done phase. Ready and the merge (B) run **after** the pass is recorded.

**Pass recorded or not.** A waived gate's pass was recorded when its drafts opened, a legacy phase (no `acceptance` block) recorded it straight away, and a phase done before v93 closes from its `pr_open=` hint: each reaches the close already `done`. Tell the two cases apart by the phase's status (`next`, or `phase.json`'s `status`):

- **Not `done`** (a required gate, between `accept-gate --clear` and the pass): a change request is `review-phase <P> --verdict changes_requested`.
- **`done`** (the pass is recorded): a change request, the operator's or the team's, always goes through `reopen-phase` (`reference/reopen.md`). The engine refuses that `review-phase` there and names the reopen.

## A. Re-read the draft

1. `python3 scripts/workflow.py pr-sync <P>`. It prints `pr_sync=<label> state=<s> base=<b> head=<sha7> review=<d|none> merged_at=<ts|none>` per URL. `state=merged`: nothing to close; record the pass (unless the phase is already `done`) and report. `state=closed`: stop and report (a closed PR holds archiving; the operator reopens it on GitHub or archives with `--force`). A `pr-sync` failure writes nothing: an `operator-action` stop naming its line.
2. Read the live PR: `gh pr view <n> --json title,body,commits,comments,reviews,headRefOid,isDraft,baseRefName`.
3. **An edited title or body.** Diff it against `topics/pr-body[-<repo>].md` and the title the draft was opened with.
   - The operator's version is the record: write the live body into the body file, then run `python3 scripts/workflow.py pr-check <P> [--repo <name>] [--branch <b>]`.
   - Check it: the budgets, the leaks, the details link, and whether it still matches the diff.
   - **A problem stops** (`--stop-kind decision`): report the lines `pr-check` printed and what no longer matches. Never overwrite the operator's words.
4. **New commits** (`headRefOid` is not the local branch tip):
   - `git fetch origin`, then fast-forward the local branch: `git merge --ff-only origin/<b>`. A non-fast-forward stops for the operator.
   - Re-run `pr-check`, and wait for the PR's checks (B.4's CI rule).
   - A failure stops; its fix is a change request, routed as in step 5.
5. **Comments and reviews.**
   - Skip the workspace's own details comment: its first line is `## Details for this PR`.
   - **Judge by content, never by author.** In a solo repo the operator and the PR's author are one login, so a comment or a review asking for a change counts by what it says.
   - **A change request is not an accept.** Stop the close and route it by the phase's status (*Pass recorded or not* above):
     - **Not `done`:** record `python3 scripts/workflow.py review-phase <P> --verdict changes_requested --note "operator-reported: <what>"`. The gate resets, so the pass waits for a re-clear. Cut the fix round on the same branch (the `do-*` review references own the fix-slice mechanics).
     - **`done`** (a waived gate's `close`, a legacy phase, a pre-v93 draft): never `review-phase`, which the engine refuses. Reopen by `reference/reopen.md`, its checkout first (a nested host's main checkout off the PR branch; at root, where the PR branch is checked out): `python3 scripts/workflow.py reopen-phase <P> --note "operator-reported: <what>"`.
     - Either way the PR is updated at the fix round's next would-pass by `reference/reopen.md`'s update step. Never a second PR.
   - A question, or nothing at all, does not stop the close.

## B. Ready and merge (after the pass is recorded)

1. `gh pr ready <n>`. The operator's `accept` (or `close`) is the authority for it. Ready notifies the team, so it never runs before that word.
2. **Solo or team.** Read it with `python3 scripts/workflow.py pr-team [--repo <name>]`: `pr_team=<label> recorded=<solo|team|none> detected=<solo|team|unknown> evidence="…"`.
   - **Recorded:** use it.
   - **Unrecorded:** the walkthrough's "decided as drawn" line for the detection is what the `accept` signed. Record it: `python3 scripts/workflow.py pr-team --record solo|team [--repo <name>] --evidence "…"`.
   - **Nothing was signed** (a waived gate) **or detected `unknown`:** ask first (`--stop-kind decision`); never guess.
3. **Team:** leave the PR open for the team's merge. Print, never run unasked, one `gh pr edit <n> --add-reviewer <login>` line per name in the body's `## Review`. Report the URL. Never merge a team repo's PR.
4. **Solo, CI first.** `gh pr checks <n>` must be green:
   - every check `pass` or `skipping`: green;
   - pending: wait with `gh pr checks <n> --watch --fail-fast`;
   - `fail` or `cancel`: stop and report the failing checks. The phase is `done` by now, so the fix goes through a reopen on the operator's word, by `reference/reopen.md`: `reopen-phase <P> --note "operator-reported: CI red: <checks>"`. Never a second PR;
   - no checks reported: not red, so proceed, and the report says "no CI checks".
5. **Solo, then merge by the repo's own custom.**
   - **A stated custom** (the repo's `CLAUDE.md`, `AGENTS.md` or `CONTRIBUTING` landing text) wins. A repo that lands locally (a `--no-ff` merge plus its release step, then a push of the default branch) is merged that way, never with GitHub's merge button; the pushed default branch marks the PR merged.
   - **No stated custom:** `gh pr merge <n>` with the repo's only allowed method (`gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`), else `--merge`. The report names the method.
   - Never `--delete-branch` (a stacked PR may target the branch), never `--admin`, never a force-push.
6. `python3 scripts/workflow.py pr-sync <P>` records the end state. Report each URL and its state: merged, or Ready for the team.

**A change asked for after Ready** (the operator's, or a team's on a PR left Ready) is the same path: the phase is `done`, so on the operator's word reopen by `reference/reopen.md`: `reopen-phase <P> --note "operator-reported: <what>"` (or `"team-reported: <what>"`). Never `review-phase`, never a second PR.

## A stack or a series

Close bottom-up, one PR at a time. A dependent PR waits for its `pr_stack=` steps (`reference/stack.md`: merge the default branch in, retarget, re-record) before its own merge.

## Every step's limits

Every remote write (`gh pr ready`, `gh pr merge`, `gh pr edit`, `git push`) reaches the permission prompt; none is pre-allowed. Recording (`pr-sync`, `pr-team --record`, `review-phase`, `reopen-phase`) is the orchestrator's.
