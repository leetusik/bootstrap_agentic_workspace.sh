---
name: read-code
description: "Blind-read a product change made outside a phase before it is pushed: dispatch the code-reader on the unpushed range (or a named one) and report its findings for the operator to decide on."
argument-hint: "[<base>..<head> | <ref>]"
allowed-tools: Bash(python3 scripts/workflow.py executor-route:*), Bash(python3 scripts/workflow.py nested-repos), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Read
disable-model-invocation: true
---

# read-code

A blind read of a code change before it is pushed, for work made **outside a phase**: a hotfix on a PR branch, a quick follow-up. The `code-reader` agent reads the diff cold, as the change's first hostile reader, and reproduces what it suspects. Inside a phase the review runs the reader itself; this skill is for everything else.

1. **The range.** No argument: `working-tree`, the current branch's unpushed commits plus its uncommitted changes (against its upstream, else the default branch). An argument: `<base>..<head>`, or one ref, read against the default branch (`origin/HEAD`, else `main`). On a multi-repo host (`python3 scripts/workflow.py nested-repos` lists repos), one read per listed repo that has changes, against that repo's default branch. An empty diff over the pathspec: say so and stop.

2. **The pathspec: the product files only**, never the workspace's own. At root, the whole repo except the workspace's state and docs folders (`. :!works :!docs`). In a nested install, the host repo except the nested `workflow/` folder (`. :(exclude)workflow`): a host folder named works or docs is product there. On a multi-repo host, each listed repo whole (`.`), and the host itself minus `workflow/` and every listed repo's folder. The same rule `phase-scope` reads a phase's files with.

3. **The purpose.** One plain sentence saying what the change is for, taken from the operator's request in this session. If nothing says, ask the operator in one line before dispatching. Never a phase or slice id.

4. **The dispatch.** Run `python3 scripts/workflow.py executor-route --code` and dispatch the `code-reader` agent from its lines, as a background task: `subagent_type=`, plus `model` when `pass_model=yes` and `effort` when `pass_effort=yes`; relay any `warning=` line. The prompt gives the repo path, the range, the pathspec, the purpose, and an output path **outside the repo**, `${TMPDIR:-/tmp}/code-read-<branch>-<short sha>.md`, since nothing here belongs to a phase. Its first line is `read-code: <repo> <range>`: no `slice:` line and no phase or slice id anywhere in the prompt, so the meter reads the span as the `code-reader` route and never pins it on a slice by name (it falls to the time window, else `unattributed`).

5. **The report.** When the reader returns, read its file and relay: its two-sentence read of what the change does, against the purpose; each finding in one line (id, lens, severity, `confirmed` or `suspected`, its effect); its coverage (probed / read / not read). Then the operator decides:
   - **fix**: ordinary work, then `/read-code` again as a re-read, giving the reader its earlier output and the fix range;
   - **push as it is**: the operator's push, never this skill's;
   - **park it**: `python3 scripts/workflow.py defer-job`, on the operator's word.

## Never

- push, commit, fix or edit anything; the reader's file is the only thing written, and the reader writes it;
- substitute another agent when the session has no agent type the `subagent_type=` line names: a new agent file loads only in a fresh session, so say so and stop;
- run the reader on a phase's own review: that dispatch is the review's.
