---
name: retrofit
description: Non-destructively adopt this agentic workspace into the current existing repository.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash
disable-model-invocation: true
---

# retrofit

Adopt the workspace into the current repo, non-destructively and **team-visibly** (its files land in the repo's tree). For private use in a repo you don't own, run the default bare install instead (`sh <path>/bootstrap_agentic_workspace.sh <host-root>`; README, "Private use in a repo you don't own"). Full policy: `docs/retrofit-guide.md`.

1. `git rev-parse --is-inside-work-tree`; a dirty tree is reported, committing first recommended. `works/state.json` already present: STOP, the workspace is here. Ask the operator for the installer's path (or the README's `curl` line); never fabricate one.
2. `sh <path>/bootstrap_agentic_workspace.sh . --into-existing --name "<project>" --summary "<one sentence>"`. It skips files you have, merges `.claude/settings.json` and `CLAUDE.md` additively (a marked block plus the `CLAUDE.workspace.md` sidecar), installs `docs/` and `works/` only if absent, aborts on a foreign `scripts/workflow.py`, and creates no phase.
3. An existing `CLAUDE.md`: fold the sidecar's contract into it, the project's rules winning. Make sure `__pycache__/` and `*.pyc` are ignored.
4. `python3 scripts/workflow.py check`, then `next` ("no active slice" is the empty start). Pass on the `team PR rules:` / `PR-rules conflict:` lines; `/update-workspace`'s team PR rules step settles them.
5. Summarize what was created, skipped and merged; show `git status`. Commit only when the operator says so. The first real task goes through `/create-phase`; create no phase yourself.
