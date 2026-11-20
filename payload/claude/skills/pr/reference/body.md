# The PR body

A reviewer reads the first screen, decides whether the change is safe and what they are asked to do, then opens the diff. The body serves that read; depth goes to the details comment or a repo doc.

## The skeleton

A repo with a team template keeps the team's headings in its order; map this content onto them and add exactly one section, `## Review`, after the summary. With no template:

1. **Series line**, only in a series: `> Part k/n of <feature> · merges after <repo>#<n> · index: <link>`.
2. **`## Summary`:** what changes and why, one paragraph, at most 60 words.
3. **`## Review`**, on the first screen, its parts kept apart: **Please decide** (at most 3, numbered, each to a named reviewer, plain name, never `@`), **Please check** (at most 3, a file or area each), **Risks** (at most 3, each with how it is contained), **Before merging** (only for a deploy, migration, secret, env or timing step).
4. **`## What is changed`:** grouped by idea, never file by file; a visual where the rule below asks; **Tested:** 2–3 lines on what ran, the result, and what did not run.
5. **`## Why`:** the background the diff cannot show (2–4 sentences, links) and at most 5 bold-lead decisions, each with the alternative and the reason.
6. **`## Related issue`:** `Closes #n`, `Refs …` or `None`, plus links to the details comment and any repo doc in the diff.

## Budgets (`pr-check` measures them)

First screen (before the first heading after `## Review`) at most 1,500 reading chars; visible text (outside `<details>`) at most 3,500; the whole source at most 6,000. Link URLs, HTML comments and Mermaid source do not count; each whitespace run is one char. Over a budget, move depth out; never squeeze words or drop the asks.

## The visual rule

- **Required** for a changed flow, a change across two or more components, or more than 400 changed lines: one Mermaid diagram or a before/after table, with a one-sentence prose caption that stands without it (Mermaid does not render in email or `gh pr view`).
- **A changed user surface** gets its screenshots, before and after where it helps, linked from the `pr-assets` branch (`close.md`). None for a phase with no user-visible change.
- Small fixes stay plain text.

## Prose rules

- One idea per paragraph; terms defined at first use; shorter wins. The subject, never the records: no work log, no "not run" walls.
- **No workspace leakage:** no phase or slice IDs, no workspace paths or file names; avoid "slice", "orchestrator" and "executor".
- Percentiles in lower case (`p95`); never spell a version `P<n>` (the ID check is case-sensitive, even in code spans).
- Language: the team's rule, else that of most of the team's recent PRs. A port PR says "port of <link>; review only these differences".
