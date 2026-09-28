# Plan — P24.S4 (docs): consolidate the P21–P23 notes into decisions

## Context

P24 is the operator's docs phase. This slice pays the **seven decisions notes** that P21, P22 and P23 owe by cutting **one** new version of the decisions doc. It is the last of the four doc slices. After it lands, the orchestrator runs `docs-consolidated` for P21, P22 and P23; you don't. Read these parts of `works/phases/active/P24/phase.md` first: `## Decisions` (especially *Merge, don't append*, *Version source* and *No doc restructuring*) and the S1–S4 and S4 notes. They bind this slice.

This is a `docs` slice in an operator-created docs phase on the default stream. Under the executor's docs-slice carve-out you may run `doc-new-version` and `rebuild-docs` for the notes below, and you edit **only** the returned `edit_path`. You never run `docs-consolidated`, never touch `docs/current/*.md` or older versions by hand, and never commit.

The current decisions doc is `docs/current/decisions.md`: v0041, source v43, **269,799 B**. **Never read it whole.** Run `grep -n '^## \|^### '` on the `edit_path` and use offset reads. At planning, measured on `docs/current` (the version file keeps the same offsets):
- `## Status` `:13`. Its first paragraph starts "**Current in v43: forty-two decisions.**"
- `## Purpose` `:38`
- `## Decision Log` `:42`, **newest first**:
  - v43 entry `:44`
  - v42 worktree entry `:103`
  - v42 mockup entry `:202`
  - P20/v37 entry `:279`
  - …
  - the v35 notebook entry `:522`, whose budget bullet is at `:557`
- `## Superseded Decisions` `:1622`

**Entry format** (copy it from the v43 entry at `:44`):
- a `### <imperative title> (phase P<N>, workspace v<NN>)` heading
- `- Date:`
- `- Status: accepted` (plus any supersedes clause)
- `- Context:`
- `- Decision:`
- then consequence/detail bullets as that entry does

Keep each new entry **compact**, well under 6 KB each. The rationale detail lives in the owing phases' `result.md` files, so point at them by path rather than copying them.

## The seven notes

These are verbatim from each phase's `## Doc impact`. Read them in full there.

1. **P21.S2**: why consolidation left the review (90–97 % of its read budget), and why the review keeps a two-section carve-out (`## Regression Checklist`, `## Operator Runtime`).
2. **P21.REVIEW**: the v38 entry must also carry S3–S5's decisions:
   - the advisory-only debt line behind one knob (`CONSOLIDATION_DEBT_MIN_PHASES`)
   - the docs-phase entry route with its one-slice-per-doc default
   - `DOC_SECTION_WARN_BYTES` = 10 KB as visibility, not surgery
3. **P22.S1**: the v35 bounded-notebook decision's budget clause is partly superseded. The dual (lines, bytes) ceiling is now bytes-only at 400 KB, with P21's measurement (byte half 92 %, line half 69 %) as the reason.
4. **P22.S2**: v39 declined the docs cadence and took explicit staleness instead:
   - `CONSOLIDATION_DEBT_MIN_PHASES` stays 1.
   - The stale line is deliberately not gated on it.
   - Pre-v39 shas are not backfilled.
   - The doctrine is that a doc outrun by an owed note is stale evidence to check against those notes, never current truth. This is now in the `CLAUDE.md` read order and Hard Rules, and in both executor agent bodies.
5. **P23.S2**: why the contract slimmed (50,048 B / 49,646 chars, over Claude Code's 40k-char per-file warning, loaded on every session and dispatch) and where its cut text lives: `workflow.py --help`; the do-*, review-phase, design-cowork, archive-phase and parallel-phase skills; the executor bodies; and the engine. The unit-by-unit carrier map is §3 of P23.S1's `result.md`, and the S2 cut list is in P23.S2's `result.md`.
6. **P23.S3**: why the Aside, worktree and design bullets, and the design-styles tail of the decomposition rule, left the contract: they restated `design-cowork` / `parallel-phase` almost verbatim. Also what each stub keeps: every never-rule, and the dedicated-profile rule with its any-browser clause byte-identical, which is D13's scope. D13 itself stays open.
7. **P23.S4**: the contract is capped at ≤ 12 KB (12,288 B by `wc -c`, D8's target, which the operator picked) as a routing layer. Every one of the 58 never-rules keeps a statement in it, and a rule is never dropped to fit; an overshoot goes to the operator instead. The never-rule floor N1–N58, and the phrase that carries each, are in P23.S4's `result.md`.

## What to write

- **New v44 entry at the top of `## Decision Log`**, above the v43 entry. Title it along the lines of *Slim the always-loaded contract to a ≤ 12 KB routing layer — never-stubs, and procedure read from its owners (phase P23, workspace v44)*. Date 2026-09-28. It carries notes 5, 6 and 7.
  - Status: accepted. It **adds to, and does not supersede**, the decisions whose rules moved; the rules themselves are unchanged, only where they are stated.
  - Mention the **docs-slice carve-out** (P23 OQ1, operator-approved) in one line, as it is a v44 decision too: a `docs` slice may run `doc-new-version` / `rebuild-docs` for its planned notes, and `docs-consolidated` stays the orchestrator's.
- **New v39 entry, then the v38 entry below it**, both placed **between** the v42 mockup entry (`:202`) and the P20/v37 entry (`:279`), so the log stays newest first.
  - **v39** (phase P22, 2026-09-02) carries notes 3 and 4. Title it like *Make doc staleness explicit instead of scheduling consolidation, and relax the notebook budget to one soft byte cap (phase P22, workspace v39)*. It supersedes part of v35's budget clause, and its Status says so.
  - **v38** (phase P21, 2026-09-01) carries notes 1 and 2. Title it like *Take durable-doc consolidation out of the review — an operator-created docs phase pays a stamped debt (phase P21, workspace v38)*.
    - It supersedes the review-consolidates half of earlier decisions. Check which ones: at least the v21 *Take auto-explain out of the phase review* framing "review = validate + consolidate", and the P8 one already in Superseded. Grep `consolidat` within `## Decision Log` headings and Status lines to find what it narrows.
    - Record that in its Status and add a `## Superseded Decisions` bullet.
- **The v35 entry (`:522`)**:
  - Amend its `- Status:` line to say its budget clause is **partly superseded by v39** (bytes-only, 400 KB).
  - Leave its body as history; don't rewrite the `PHASE_MD_BUDGET = (200 lines, 16 KB)` bullet at `:557` in place.
  - Add a `## Superseded Decisions` bullet in that section's existing style: which decision, which sub-part, which later decision supersedes it, and why (P21's measurement: byte half 92 %, line half 69 %).
- **`## Superseded Decisions`**: add the v35-budget bullet and the v38 review-consolidation bullet at the **top** of the section, since it is newest first too, in the section's existing style.
- **`## Status` (`:13`)**:
  - Update the lead to "**Current in v44: forty-five decisions.**" Count first: grep the `### ` entries in `## Decision Log` before and after, and use the real count. At planning there were 42 `### ` headings in the whole doc; confirm what the "forty-two" counts.
  - Add a short lead summary of v44, and one sentence each for v38 and v39, placed where the Status narrative walks back through versions.
  - Keep it short, because `## Status` is already 15 KB (over the advisory; don't split it).

Where a note is ambiguous, read the owing phase's `result.md` (P21.S2, P21.S3–S5, P22.S1, P22.S2, P23.S1–S4) or its `phase.md` `## Decisions`, and never re-derive from scratch. If a note contradicts v40–v43 text, report it in `result.md`.

## Steps

1. `python3 scripts/workflow.py doc-new-version --doc decisions --summary "P21-P23: docs phases pay the doc debt, explicit staleness, and the 12 KB routing contract" --source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`, run once. Record the `edit_path` and ignore the split hint (Decision *No doc restructuring*).
2. Edit only that `edit_path`, as above.
3. `python3 scripts/workflow.py rebuild-docs`
4. `python3 scripts/workflow.py validate` must exit 0. The existing advisories are expected.
5. Check the placement: `grep -n '^### ' docs/current/decisions.md | head -8` shows v44 first, then v43, v42, v42, v39, v38, v37.
6. Write `result.md`, **verdict block first**. Then add a table of the seven notes with their landing entry or section, the new decision count, and the before/after byte size.
7. Edit `phase.md` under its budget:
   - Remove the S4-only note and the S1–S4 procedure notes, which this slice consumes last.
   - Rewrite `## Now` as the handoff to S5, noting that the orchestrator pays the debt in S4's commit.
   - Add no `## Doc impact` line.

## Out of scope

- Splitting sections.
- Any other doc, README, code or machinery.
- `docs-consolidated`.

The executor tier is `slice-executor-mid` (`docs / low`). If this turns out to need anything beyond the one `edit_path`, return `escalate` with the findings.
