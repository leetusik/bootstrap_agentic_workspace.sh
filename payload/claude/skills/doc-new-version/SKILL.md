---
name: doc-new-version
description: Create a new versioned durable doc instead of patching current docs.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit
disable-model-invocation: true
---

# doc-new-version

A slice that changes what the code cannot say updates that doc itself, here: run `python3 scripts/workflow.py doc-new-version $ARGUMENTS` (`--doc <product|architecture|operations|qa|decisions> --summary "<under ~100 chars>" --source <slice id>`). It creates `docs/versions/<doc>/v<yyMMddHHmm>_<slug>.md` (the UTC minute; never choose the number). Run it on the default stream: a version copies the doc's whole body and writes the one `docs/index.json`, so a phase worktree records its text in `result.md` for the merge instead.

Edit only the returned `edit_path`, then `python3 scripts/workflow.py rebuild-docs` and `validate`. An `oversized_doc_sections=` note: split the named section in this version. Never edit `docs/current/*.md` or an existing version.
