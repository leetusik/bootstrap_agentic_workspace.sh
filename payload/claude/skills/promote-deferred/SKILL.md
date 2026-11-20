---
name: promote-deferred
description: Promote a deferred job into an active phase or slice.
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# promote-deferred

Run `python3 scripts/workflow.py promote-deferred $ARGUMENTS` (`92 --phase 46 --slice S2 --name "…"`, or `--create-phase --phase-name "…" --phase-objective "…" --slice S1` with no `--phase`, so the engine mints it). Ids take any brief form (`92`, `D92-x4`, `46`, `P46-k2`); a number two ids share is refused with both listed. It moves the job to `works/deferred/promoted/` and carries its context into the new slice.
