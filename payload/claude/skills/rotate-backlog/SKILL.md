---
name: rotate-backlog
description: "Archive every done phase that owes nothing, after syncing the open PRs; a phase still owing old doc debt or an open PR stays active and is reported. It creates and runs no phase. The word archive-only keeps the plain archive-and-report sweep."
argument-hint: "[archive-only]"
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Glob, Grep, Bash
disable-model-invocation: true
---

# rotate-backlog

Archives the done phases that owe nothing and reports the rest. Doc consolidation is retired: nothing is created or run here to pay doc debt, and a phase still carrying old doc debt stays active until the engine stops counting it (the operator may `archive-phase <P> --force`). Archiving is whole-phase only and never `--force` on the operator's behalf.

**First, sync the open PRs (both paths).** For each phase on a `pr_open=` line of `next`, `python3 scripts/workflow.py pr-sync <P>` (read-only on GitHub; it updates that phase's `pr` record). A failure writes nothing: relay its line, the phase stays held. Commit the changed `phase.json` files, naming each path.

1. **`archive-only`:** `python3 scripts/workflow.py rotate-backlog --archive-only`, relay its report, STOP.
2. **Otherwise** `python3 scripts/workflow.py rotate-backlog`, reading stdout before the exit code. Its first line is `rotate=<branch>`:
   - **`refused`** (a parallel stream): relay it; run `/rotate-backlog` from the main checkout. Nothing was written.
   - **`archive`:** relay the sweep report.
   - **`create`, `resume` or `replace`** (the engine still proposes a phase to pay old doc debt): relay its lines and create, reorder or run nothing; a `replace` has already removed the unstarted phase folders it names, so commit that removal.
   - **`stop_midflight`** or **`stop_uncommitted`:** relay the running items or uncommitted paths and STOP.
   Relay every `archived=` and `parked=` line; never touch a parked item.
3. **Commit** what the run wrote, naming its paths (`git add -- <paths>`, `git commit -- <paths>`, never `git add -A`, never a parked phase's folder): `chore(works): archive <ids> with rotate-backlog`. In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions are the workflow's history. Product commits are unchanged. In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`; run `mark-committed <slice>` after its product commit (with no product change, right after its finish).
4. **Report** what was archived, every phase still active and why (owed debt, `pr_open=`, parked), each with the engine line that says so.
