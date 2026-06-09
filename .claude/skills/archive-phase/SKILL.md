---
name: archive-phase
description: Archive review-passed phases — batched at the end via archive-all (single-phase is a manual escape hatch).
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# archive-phase

Archiving is **batched** and happens at the very end, never right after a single review. A passing review marks a phase `done` but leaves it in `active/`.

Default path — when every active phase is done (the last review slice across all active phases is complete), sweep them all to archived at once:

```sh
python3 scripts/workflow.py archive-all
```

`archive-all` refuses until every active phase is `done` with a passing review (use `--force` only for exceptional cleanup).

`python3 scripts/workflow.py archive-phase <P>` remains a manual escape hatch for archiving a single phase in exceptional cases. Archive only whole phases. Never archive one slice at a time.
