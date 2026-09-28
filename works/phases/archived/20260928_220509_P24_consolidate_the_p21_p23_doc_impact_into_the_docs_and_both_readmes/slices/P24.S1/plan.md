# Plan — P24.S1 (docs): consolidate the P21–P23 notes into architecture

## Context

P24 is the operator's docs phase. This slice pays the **six architecture notes** that P21, P22 and P23 owe by cutting **one** new version of the architecture doc. Read these parts of `works/phases/active/P24/phase.md` first: `## Decisions` (especially *Merge, don't append*, *Version source* and *No doc restructuring*) and the S1–S4 notes. They bind this slice.

This is a `docs` slice in an operator-created docs phase on the default stream. Under the executor's docs-slice carve-out you may run `doc-new-version` and `rebuild-docs` for the notes below, and you edit **only** the returned `edit_path`. You never run `docs-consolidated`, never touch `docs/current/*.md` or older versions by hand, and never commit.

The current architecture doc is `docs/current/architecture.md`: v0007, source v43, 20,500 B. Its sections at planning time were:
- `## Status` `:13`
- `## Current Repo Shape` `:27`
- `## Installer Source Tree` `:48`
- `## Execution Streams …` `:94`
- `## Operator Acceptance Gate …` `:215`
- `## System Shape` `:292`
- `## Boundaries` `:300`
- `## Cross-Cutting Constraints` `:307`
- `## Open Questions` `:311`

The doc is small enough to read whole.

## The six notes

These are verbatim from each phase's `## Doc impact`. Re-read them there if you need the full text.

1. **P21.S2** — `phase.json` carries a top-level `consolidation` debt (pending/done; absent = none); the parallel deferred path is now every phase's path; new `docs-consolidated <P>`.
2. **P22.S2** — `docs/index.json` version entries gain a `commit` field: the HEAD sha at write time, `null` where git cannot answer, and **absent** on pre-v39 entries. The version frontmatter gains the matching `commit:` line, which `rebuild_docs` copies verbatim into `docs/current`.
3. **P23.S2** — *Current Repo Shape*: `CLAUDE.md` no longer carries a `## Workflow Commands` list. `python3 scripts/workflow.py --help` (and `<command> -h`) is the command reference, and the closed `--kind` set sits in the contract's *IDs and Status*.
4. **P23.S2** — the phase-notebook template (`works/templates/phase.md` and `PHASE_MD_TEMPLATE_FALLBACK`) tags notes `**(from <slice>, for <slice>)**`, which is the executor's form.
5. **P23.S3** — *Current Repo Shape*: `CLAUDE.md`'s Aside, worktree and design Hard Rules are never-stubs.
   - `parallel-phase` is the only full statement of the eight worktree rules.
   - `design-cowork` is the only full statement of the Aside surfaces, the MCP cost/escape hatch, the instrument/runtime axis, the three design styles and the design slice's stops.
   - Both executor bodies carry the decomposition's **build inventory** rule.
6. **P23.S4** — *Current Repo Shape*: `CLAUDE.md` is a 12,259 B routing contract in seven sections of short stubs, one statement per rule. The sections are Agent Contract, Driving This Workspace, Read Order, Canonical State, Hard Rules, IDs and Status, and Commit Convention. The intent rules sit in *Driving* and the slice-file/notebook rules in *Canonical State*. Procedure is read from `workflow.py --help`, the owning skills and the executor bodies.

## Where each note lands (the orchestrator's read; confirm against the file)

- **Notes 3, 5, 6 → `## Current Repo Shape`, the `CLAUDE.md` bullet (`:29`).** It currently says only "the compact routing contract — the only one" plus the `AGENTS.md` clause.
  - Rewrite it to state the v44 shape: the size, the seven sections, one statement per rule, and where procedure is read instead (`workflow.py --help`, the owning skills, the executor bodies). Keep the `AGENTS.md` clause.
  - Add the never-stub/owner mapping from note 5, either in the same bullet or as a short sub-list under it.
  - The `scripts/workflow.py` bullet (`:40`) may add that its `--help` is the command reference.
  - Current size: `wc -c CLAUDE.md` = 12,259 at planning, which matches the note.
- **Note 4 → `## Current Repo Shape`**, as a short bullet or clause for `works/templates/` (there is no templates bullet today). Say that the phase-notebook template, together with its in-engine fallback `PHASE_MD_TEMPLATE_FALLBACK`, tags each `## Notes for later slices` entry `**(from <slice>, for <slice>)**`. Put it where it reads naturally, for example after the `works/phases/archived/` bullet.
- **Note 2 → the `docs/index.json` bullet (`:32`)** and/or next to *Doc versioning stays serial by construction* (`:201`). State the `commit` field (HEAD sha, `null` when git cannot answer, absent on pre-v39 entries) and the matching frontmatter `commit:` line that `rebuild_docs` copies into `docs/current`. That copy is what makes the per-doc last-updated marker readable where a doc is opened. Keep it to one or two sentences.
- **Note 1 → `## Execution Streams`, where the `execution` block's `consolidation` field is described (`:106`–`:146`, the JSON example at `:111`–`:117`, and the `consolidation` bullet at `:144`).** The current text describes consolidation as a field **inside the parallel `execution` block**, which is v24–v37 truth. Since v38 the engine reads it as a **top-level** `phase.json` field for **every** phase:
  - A passing review stamps `"consolidation": "pending"`.
  - `docs-consolidated <P>` records `"done"`, and a parallel phase's `parallel-consolidated <P>` does the same.
  - Absent means nothing is owed.
  - The block's `consolidation` is read only as a backward-compatible fallback; see `phase_consolidation()` in `scripts/workflow.py`, whose docstring states exactly this.
  - A `done` + `pass` + `pending` phase validates but cannot be archived, and this now holds for every phase, not only merged ones.

  Fix the example and the bullet so they no longer imply the field lives only in the parallel block, and add a short paragraph or bullet naming the top-level field. Also check `:280` ("Only doc consolidation is deferred, exactly as before") and `:201`–`:214` for wording that implies only parallel phases defer consolidation. Since v38, **every** phase defers it to an operator-created docs phase. The review writes no versions except its two gate sections, and a branch review writes not even those.
- **`## Status` (`:13`)**: add one clause saying that since v38 every phase's durable-doc consolidation is deferred to an operator-created docs phase and tracked as a top-level `phase.json` debt, and that v44 slimmed `CLAUDE.md` to a routing contract. Keep the paragraph's shape.

Where a note is ambiguous, read the named code: `phase_consolidation()` and `new_doc_version()` in `scripts/workflow.py`, and `works/templates/phase.md`. Never re-derive a note's facts from scratch. If a note contradicts v40–v43 text already in the doc, report it in `result.md` rather than silently choosing.

## Steps

1. `python3 scripts/workflow.py doc-new-version --doc architecture --summary "P21-P23: top-level consolidation debt, doc commit markers, and the 12 KB routing contract" --source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`, run once. Record the printed `edit_path`.
2. Edit only that `edit_path`, as described above. Replace superseded statements rather than stacking new ones next to them. Keep the doc's existing voice and wrap width (~100 columns).
3. `python3 scripts/workflow.py rebuild-docs`
4. `python3 scripts/workflow.py validate` must exit 0. The advisory `consolidation_owed=` / `stale_docs=` / `oversized_doc_sections=` warnings are expected. Architecture should not newly appear in `oversized_doc_sections`, because no architecture section may pass 10,240 B. If one would, report it.
5. `python3 scripts/workflow.py docs` shows architecture at the new version with `source=P21.REVIEW, P22.REVIEW, P23.REVIEW` and a commit sha. It stays STALE until the orchestrator pays the debt after S4, which is expected.
6. Write `result.md`, **verdict block first**. After the verdict block, add a table of the six notes, each with the section it landed in, so the review can tick it off. Also give the before/after byte size of the doc.
7. Edit `phase.md` under its budget:
   - Remove nothing but the parts of the S1–S4 notes that this slice consumed. The notes are shared with S2–S4, so leave them unless they are S1-only.
   - Rewrite `## Now` as the handoff to S2.
   - Add no `## Doc impact` line, because a docs phase creates none.

## Out of scope

- Splitting sections.
- Any other doc, README, code or machinery.
- `docs-consolidated`.

The executor tier is `slice-executor-mid` (`docs / low`). If the notes turn out to need machinery changes or cross-file edits beyond the one `edit_path`, return `escalate` with the findings.
