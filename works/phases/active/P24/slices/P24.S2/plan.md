# Plan — P24.S2 (docs): consolidate the P21–P23 notes into operations

## Context

P24 is the operator's docs phase. This slice pays the **eight operations notes** that P21, P22 and P23 owe by cutting **one** new version of the operations doc. Read these parts of `works/phases/active/P24/phase.md` first: `## Decisions` (especially *Merge, don't append*, *Version source* and *No doc restructuring*) and the S1–S4 and S2 notes. They bind this slice.

This is a `docs` slice in an operator-created docs phase on the default stream. Under the executor's docs-slice carve-out you may run `doc-new-version` and `rebuild-docs` for the notes below, and you edit **only** the returned `edit_path`. You never run `docs-consolidated`, never touch `docs/current/*.md` or older versions by hand, and never commit.

The current operations doc is `docs/current/operations.md`: v0034, source v43, 117,990 B. **Never read it whole.** Run `grep -n '^## \|^### '` on the `edit_path` and use offset reads. The line numbers below are from `docs/current/operations.md` at planning; the new version file has 10 frontmatter lines in the same place, so the offsets hold, but re-grep to be sure.

## The eight notes

These are verbatim from each phase's `## Doc impact`. Take only the operations half of any note that also names qa.

1. **P21.S2** — Durable docs are consolidated in an operator-created docs phase (`doc-new-version` per note → `rebuild-docs` → `docs-consolidated <P>`), never at the review. An owing phase stays in `active/`.
2. **P21.S3** — The consolidation debt is no longer silent: `next` prints `consolidation_owed=<phases>` and `validate` warns (advisory only, exit 0).
3. **P21.S4** — How a docs phase starts: the `docs-debt` worklist plus the `create-phase` docs-phase route.
4. **P21.S5** — `validate` and `doc-new-version` warn (advisory, exit 0) when a `docs/current` H2 section passes `DOC_SECTION_WARN_BYTES` (10 KB), naming the doc, section and size.
5. **P22.S1** — The notebook-budget bullets in the v35 runbook (`PHASE_MD_BUDGET = (200 lines, 16 KB)` and the `finish-slice` size print `(budget 200 / 16384)`) are superseded by v39's single soft byte cap: 400 KB (~100k tokens), with the line ceiling dropped. Both numbers are still printed, but only bytes are judged, and it is still warning-only.
6. **P22.S2** — The `docs` listing now prints a per-doc last-updated marker (date / consolidating source / commit) and flags docs outrun by an unconsolidated `## Doc impact` note as **STALE**. `validate` carries the same shared `stale_docs=` line as a warning beside `consolidation_owed=`. It is advisory, exits 0, and stays silent when nothing is owed.
7. **P23.S2** — Installer build/release: workspace **v44** opened (`WORKSPACE_VERSION` 44, CHANGELOG `## v44`). `new-slice`, `promote-deferred` and `new-phase` gained `--order` help (fractional values insert between neighbors) and `--depends-on` help (advisory; `validate` checks existence only).
8. **P23.S2** — The executor's **docs-slice carve-out** (OQ1, operator-approved): a `docs` slice in an operator-created docs phase, on the default stream, may run `doc-new-version` / `rebuild-docs` for the `## Doc impact` notes its plan names, editing only the returned `edit_path`. `docs-consolidated <P>` stays the orchestrator's.

## The stale text this replaces (the orchestrator's read; confirm and fix every one)

The v40–v43 versions never consolidated P21's change, so the doc still says in several places that **the review consolidates the docs on a pass**. Since v38 that is false for **every** phase: a passing review only **verifies** the `## Doc impact` list, returns `doc_versions: none — deferred to a docs phase`, writes only its two named gate sections (`## Regression Checklist` in qa, `## Operator Runtime` in operations, and on a branch not even those), and the engine stamps `consolidation: pending` on the phase.

- `:68` (`## Status`, the long "Running the workflow" paragraph): "Durable docs are versioned **once per phase, at the review slice** — the executor consolidates … on a passing review", and "that consolidation is explicitly **pass-only work**". Rewrite these clauses as history ("until v38 …"), with a pointer to the new section. Keep the v21 no-explainer part.
- `:70` (`## Status`, the v35 paragraph): "under a 200-line / 16 KB budget that `validate` warns about and `finish-slice` prints". This is note 5. Replace it with the v39 cap.
- `:593`–`:599` (`## The phase notebook …`): the `PHASE_MD_BUDGET = (200 lines, 16 KB)` bullet and the `(budget 200 / 16384)` print. Replace both with the v39 single soft byte cap. Leave `:646`–`:649`, the historical measurement prose, but check that it doesn't read as the current rule.
- `:658`–`:686` (`## The phase review …`):
  - The **On `pass`** bullet currently says to consolidate. It becomes *verify* the Doc impact list (an incomplete list is a finding), write only the two gate sections, and return `doc_versions: none — deferred to a docs phase`. The engine stamps `consolidation: pending`.
  - The **On `changes_requested` / `blocked`** bullet: "the docs stay unversioned until a later passing re-review consolidates the whole phase" becomes "… until the docs phase".
  - The worktree bullet stays, with its v42 gate-section recording. Just make sure it no longer contrasts with a default-stream review that consolidates.
  - Update the section's heading only if it names consolidation; it doesn't at planning.
- `:766` (`## The operator acceptance gate …`): "judges, consolidates docs on a pass". Drop "consolidates docs".
- `:795`–`:796`: "Doc consolidation does **not** move: it stays in the review's pass path, *before* the gate opens, and the smoke-list append rides it". Rewrite: the review's pass path writes only the two gate sections (the `## Regression Checklist` append is one of them), before the gate opens, and consolidation is the docs phase's.
- `:951`–`:953` (worktrees): "a phase whose `execution.consolidation` is still `"pending"` cannot be archived". Since v38 the debt is a **top-level** `phase.json` `consolidation` field for every phase, with the `execution` block's copy read only as the v24–v37 fallback. The archiving gate applies to every owing phase: `archive-phase` refuses, `archive-all` lists it, and `rotate-backlog` leaves it active.
- Grep the version file for any remaining `consolidat` hit that states the pre-v38 rule, and fix it. The hits at `:107` and `:900` ("never ask for a worktree on a docs phase") are already correct.

## Where the new content lands

- **New H2 section, `## Durable-doc consolidation — a docs phase the operator creates (since v38)`**, placed right after `## The phase review …`, covering notes 1–4, 6 and 8 as a short runbook:
  - **Why:** the review used to consolidate. P21 measured that as 90–97 % of the review's read budget, so the work moved to a phase the operator creates. Keep this to one sentence and point at decisions for the rest.
  - **The debt:** a passing review stamps a top-level `consolidation: "pending"` in `phase.json`. An owing phase validates but stays in `active/`, and archiving refuses it until paid.
  - **Surfacing:** `next` prints `consolidation_owed=<phases>` and `validate` warns, both advisory with exit 0. The engine knob is `CONSOLIDATION_DEBT_MIN_PHASES`, which is 1; check `scripts/workflow.py` for its current value and meaning.
  - **Staleness:**
    - The `docs` listing prints a per-doc last-updated marker (date / consolidating source / commit).
    - It flags a doc outrun by an unconsolidated note as **STALE**.
    - `validate` carries the shared `stale_docs=` line beside `consolidation_owed=`: advisory, exit 0, silent when nothing is owed.
    - The doctrine is that a STALE doc is evidence to check against the notes, never current truth.
  - **Starting one:** `docs-debt` prints the worklist, which lists each owing phase, its notes, the docs they touch, and the pay command. The operator starts the phase through `create-phase`'s docs-phase route. It is an ordinary phase with the same confirmation gate, and it always runs on the default stream, never in a worktree.
  - **Running one:**
    - `DECOMP` cuts one `docs` slice per doc.
    - Each slice runs `doc-new-version --doc <doc> --summary … --source <P>.REVIEW`, edits only the returned `edit_path`, then runs `rebuild-docs`. That is the executor's **docs-slice carve-out** (note 8, operator-approved at P23 OQ1).
    - The orchestrator records `docs-consolidated <P>` per covered phase, or `parallel-consolidated <P>` for a merged parallel phase, which also unblocks archiving.
    - A docs phase leaves no `## Doc impact` notes of its own, and its acceptance gate is normally waived.
  - **Section-size warning (note 4):** `validate` and `doc-new-version` warn (advisory, exit 0) when a `docs/current` H2 section passes `DOC_SECTION_WARN_BYTES` (10 KB), naming the doc, section and size. `doc-new-version` adds that any split belongs in the new version file, never in `docs/current`.

  Aim for ≤ 6 KB. This section must stay well under the 10 KB warning.
- **`## Status`**: add one short "As of **v38** / **v39** / **v44**" paragraph after the v43 paragraph, in the doc's existing style. It should cover consolidation moving to a docs phase (v38), explicit staleness plus the 400 KB notebook cap (v39), and the slimmed 12 KB routing contract with `workflow.py --help` as the command reference plus the docs-slice carve-out (v44), with pointers to the sections. Keep it short, because `## Status` is already 13.7 KB, over the advisory.
- **Note 7 → `## Building and releasing the installer` (`:1206`)**:
  - Add one bullet or line for the v44 release: `WORKSPACE_VERSION` 44 and CHANGELOG `## v44`, plus the `--order` / `--depends-on` help. Match how earlier releases are recorded there, and check how v43 is recorded.
  - `--order` takes a fractional value to insert between neighbors. `--depends-on` is advisory, and `validate` checks only that the named slice exists.
  - Also check `WORKSPACE_VERSION` in `installer/main.py` for the current value; it is 44 per the note.

Where a note is ambiguous, read the named code or skill (`scripts/workflow.py`, `.claude/skills/create-phase/SKILL.md` *The docs-phase route*, `.claude/agents/slice-executor-mid.md` *Do*). Never re-derive a note's facts from scratch. If a note contradicts v40–v43 text, report it in `result.md`.

## Steps

1. `python3 scripts/workflow.py doc-new-version --doc operations --summary "P21-P23: docs phases pay the doc debt, explicit staleness, the 400 KB notebook cap and v44" --source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`, run once. Record the `edit_path`, and ignore its split hint (Decision *No doc restructuring*).
2. Edit only that `edit_path`, as above. Replace superseded statements rather than stacking new ones next to them. Keep the doc's voice and wrap width.
3. `python3 scripts/workflow.py rebuild-docs`
4. `python3 scripts/workflow.py validate` must exit 0. The existing advisories are expected. The **new** docs-phase section must not appear in `oversized_doc_sections`.
5. `grep -n "consolidat" docs/current/operations.md`: every remaining hit must agree with the v38 rule.
6. Write `result.md`, **verdict block first**. Then add:
   - a table of the eight notes, each with its landing section
   - a list of each stale passage you replaced, as old line → new wording gist
   - the before/after byte size of the doc
7. Edit `phase.md` under its budget:
   - Remove the S2-only note (*Replace the v35 budget line*), which this slice consumes.
   - Rewrite `## Now` as the handoff to S3.
   - Add no `## Doc impact` line.

## Out of scope

- Splitting sections.
- Any other doc, README, code or machinery.
- `docs-consolidated`.

The executor tier is `slice-executor-mid` (`docs / low`). If this turns out to need anything beyond the one `edit_path`, return `escalate` with the findings.
