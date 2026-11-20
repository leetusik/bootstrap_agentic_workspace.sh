# Verdicts, escalation and the commit

**Trust the verdict.** Read the returned block and the head of `result.md` (its durable copy; read further only on a verdict other than `done`), then `python3 scripts/workflow.py validate` (state only; never re-run the slice's tests). The fields you read: `status`, `route`, `model`, `effort`, `summary`, `files_changed`, `validation`, `claims`, `deviations`, plus the playbook's own (`parallel`, `notebook`, `review_verdict`, `walkthrough`, `pr_bodies`, `code_read`, `explain`, a cycle's `item_verdict`).

- `done` → `finish-slice <slice_id> --outcome "<summary>"`, `validate`, commit.
- `needs_operator` → `set-slice-status <slice_id> pending --stop-kind decision|operator-action --on-words "<its operator_need>"`, report, STOP.
- `blocked` → record the blocker, report, STOP.
- `escalate`, or a failed or empty return from the mid row → append `## Escalation: mid → high` to `plan.md` with its findings, `executor-route <slice_id> --retry`, pin, re-dispatch, `record-dispatch … --attempt 2`. Once per slice; in `gate` mode the revised plan is approved first.
- a failed or empty return from the high row → the slice is not done: STOP.

**An over-budget notebook** (`next` prints `notebook_over_budget=`): run each `notebook_move=` line under it, prefixed `python3 scripts/workflow.py`, between dispatches (in a wave, at a return), then re-run `next`. The advisory form only names a remedy. Executors never act on it.

**The commit**, at every clean slice boundary, by the `commit` skill's convention: the slice's product changes on the phase's branch (`pr-branch`, recorded at `DECOMP`'s end), then its workflow state; in a nested pair the product repo first, the workflow state right after, so a `done` slice whose `slice.json` is uncommitted always marks a commit that waits. Attribute it to the model that did the work: `Co-Authored-By: <attribution> <noreply@anthropic.com>`, the `attribution=` line of the dispatch that finished it; your own commits carry the session's model. In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions are the workflow's history. Product commits are unchanged. In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`; run `mark-committed <slice>` after its product commit (with no product change, right after its finish).

**The only pushes are the draft opening when the review passes** (the `pr` skill), **the close's solo landing, and a fix round's or a stack merge's `git push` to an open PR's branch**: the operator's run of the phase, and their `accept` or `close`, are the word. Never a force-push, never a team repo's merge, never a reviewer requested unasked.
