# Plan — P24.DECOMP (decomposition)

## Context

P24 is the operator's docs phase. It pays the consolidation debt of P21, P22 and P23 and brings both READMEs in line with the same changes. Read `works/phases/active/P24/intent.md` in full, because it is the confirmed intent and the scope. It already fixes the shape of this cut through its *What `DECOMP` will cut* paragraph: **one `--kind docs` slice per durable doc, plus one README slice.** Nothing needs researching first, since `docs-debt` has already recorded the whole worklist. So this is a single-pass decomposition with no `research` slice and no `DECOMP2`.

The facts below were measured at planning (2026-09-28). Re-check any of them you rely on.

- `python3 scripts/workflow.py docs-debt` reports `docs_debt=P21, P22, P23 (3 phase(s), 29 note(s), 4 doc(s))`:
  - architecture: 6 notes
  - decisions: 7 notes
  - operations: 8 notes
  - qa: 9 notes
  - (unassigned): 2 notes. These are the `**Verified at P21.REVIEW …**` and `**Verified at P22.REVIEW …**` lines. They carry no doc content.
- `docs` flags all four docs **STALE**. Their latest versions and sources:
  - architecture v0007 (v43)
  - decisions v0041 (v43)
  - operations v0034 (v43)
  - qa v0009 (v42)
- **The v40–v43 versions were written after P21/P22 but did not consolidate their notes.** `grep v38\|v39` finds nothing in any of the four docs. The only surviving v35 text is `PHASE_MD_BUDGET = (200 lines, 16 KB)`, at `docs/current/operations.md:593` and `docs/current/decisions.md:557`, and P22 superseded it. So each doc now holds newer content than the owed notes, and the notes have to be *slotted in*, not appended at the end.
- `decisions.md`'s `## Decision Log` is **newest first**: the v43 entry is at `:44`, the two v42 entries at `:103` and `:202`, and the P20/v37 entry at `:279`.
- `doc-new-version --source` takes one free string, and the staleness logic keys off each phase's `consolidation` flag, never off `source`.
- Oversized H2 sections (the `DOC_SECTION_WARN_BYTES` 10 KB advisory):
  - decisions `## Decision Log`: 236,975 B
  - decisions `## Superseded Decisions`: 16,903 B
  - decisions `## Status`: 15,375 B
  - operations visual-design runbook: 21,161 B
  - operations phase-worktrees section: 16,834 B
  - operations `## Status`: 13,673 B
  - qa verification doctrine: 12,853 B
- Whole-file sizes: decisions.md is 269,799 B and operations.md is 117,990 B.
- `README.md` (Korean) and `README.en.md` are this repo's own READMEs. `installer/` does not embed them, so editing them needs no `build.py` rebuild.

## What to do

1. Read `intent.md`, the seeded `phase.md`, and the executor body's *docs-slice carve-out* (`.claude/agents/slice-executor-high.md`, *Do*).
2. Create exactly five middle slices as **bare folders**. Never pre-fill a `plan.md`.
   - `python3 scripts/workflow.py new-slice --phase P24 --slice P24.S1 --name "consolidate the P21-P23 notes into architecture" --kind docs --risk low --order 1`
   - `python3 scripts/workflow.py new-slice --phase P24 --slice P24.S2 --name "consolidate the P21-P23 notes into operations" --kind docs --risk low --order 2`
   - `python3 scripts/workflow.py new-slice --phase P24 --slice P24.S3 --name "consolidate the P21-P23 notes into qa" --kind docs --risk low --order 3`
   - `python3 scripts/workflow.py new-slice --phase P24 --slice P24.S4 --name "consolidate the P21-P23 notes into decisions" --kind docs --risk low --order 4`
   - `python3 scripts/workflow.py new-slice --phase P24 --slice P24.S5 --name "bring README.md and README.en.md in line with P21-P23" --kind docs --risk high --order 5 --depends-on P24.S4`
   - REVIEW stays at 9999.
3. Seed `phase.md`. Edit around the generated `## Slices` block and never inside it. The budget is the soft 400 KB cap.
   - `## Decisions`: the decisions below, one line each, tagged `(P24.DECOMP)`.
   - `## Doc impact`: exactly one line: `(none — a docs phase pays P21–P23's notes and creates no durable truth of its own; the READMEs are not versioned docs) (P24.DECOMP)`.
   - `## Operator Questions`: `(none from P24.DECOMP)`.
   - `## Notes for later slices`: the tagged notes below.
   - `## Now`: write it last, in ≤ 15 lines, as the handoff to S1.
4. Run `python3 scripts/workflow.py rebuild`, then `python3 scripts/workflow.py validate`. Both must pass. The `consolidation_owed=` and `stale_docs=` warnings are expected at this point.
5. Write `result.md` with the **structured verdict block first**. Reference `phase.md` for the rationale rather than restating it.

You never run `accept-gate`, `start-slice`, `finish-slice`, `docs-consolidated` or `defer-job`, and you never commit.

### Decisions to record

1. **Cut: one slice per doc, one new version per doc.**
   - Why: `doc-new-version` works per doc, and every doc collects notes from all three phases. Cutting per doc gives each doc exactly one new version, never one version per note.
   - Order: architecture → operations → qa → decisions. Decisions goes last so its entries can name the versions the other three just cut.
   - Tiers: S1–S4 are `docs/low` → `slice-executor-mid`, because each edits one `edit_path` and nothing else. S5 is `docs/high`, because it edits two files and one of them is prose in Korean.
2. **Version source.** Every doc slice runs `doc-new-version --source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`. That is the `<P>.REVIEW` convention, listing all three owing phases because each doc takes notes from all three. The `--summary` is a short headline of what landed, because its slug becomes the filename.
3. **Merge, don't append.**
   - Each note is folded into the section it names, and **every statement it supersedes is replaced**, never stacked. For example, the v35 notebook budget becomes v39's 400 KB soft cap, and the smoke baseline becomes the last counted value.
   - Where a later note supersedes an earlier one (P21 → P22 → P23), the doc states the latest truth and keeps the history only where that doc's own convention keeps history, as decisions' Superseded section does.
   - The v40–v43 text already in each doc stays. Check that no owed note contradicts it, and if one does, report it rather than silently choosing.
4. **Notes are the input, reviewed truth.** The review of each owing phase verified its list. A doc slice reads the code only to resolve an ambiguous note, and never re-derives a note's facts from scratch.
5. **The two unassigned notes are consolidated by no slice.** They are the P21 and P22 reviews' "verified; no version created" stamps and carry no doc content. `docs-consolidated` clears them along with their phases.
6. **No doc restructuring.** The oversized sections listed in *Context* are **not split** in this phase. P21.S5's rule is that the 10 KB warning is visibility, not surgery, and the confirmed scope is the notes. `doc-new-version` will print the split hint; ignore it and mention the sizes in `result.md`.
7. **Payment.** When S4 finishes, the four doc slices have covered every assigned note. The orchestrator then runs `docs-consolidated P21`, `docs-consolidated P22` and `docs-consolidated P23` in S4's commit, since the README slice is not part of the debt. After that, `docs-debt` names no owing phase and `docs` shows no STALE flag, and the review checks both.
8. **READMEs are direct edits** to `README.md` and `README.en.md`, done together in S5 so the two stay in step. The READMEs are not versioned and not embedded, so there is no `doc-new-version` and no installer rebuild. S5's plan is written at its turn, from S1–S4's landed versions.
9. **Acceptance gate: waive.** This is a docs phase: four new durable-doc versions and README edits, with no running product surface for the operator to walk. The orchestrator declares it right after `finish-slice P24.DECOMP`.
10. **Out of scope: D17 and D21.** Both name "the next docs phase" as a trigger, but both edit embedded machinery: `stale_docs_line()` for D17, and `workflow.py` help text plus the `executors.toml` comment for D21. A docs phase changes no machinery, so both stay deferred, and the orchestrator relays their triggers to the operator.

### Notes to record (tag each `**(from P24.DECOMP, for …)**`)

- **For P24.S1–S4: the per-slice procedure.**
  - Take your doc's notes from `python3 scripts/workflow.py docs-debt`. That output truncates multi-line bullets, so read each note in full in `works/phases/active/P2{1,2,3}/phase.md` under `## Doc impact`.
  - When a note names several docs (for example, P21.S3's `operations.md: …; qa.md: …`), your slice takes only its own doc's half.
  - Then, once only:
    1. `doc-new-version --doc <doc> --summary "…" --source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`
    2. Edit only the returned `edit_path`.
    3. `rebuild-docs`
    4. `validate`
  - List every note you consolidated in `result.md`, with the section it landed in, so the review can tick the list off.
- **For P24.S1–S4: read sections, not files.**
  - Use `grep -n '^## \|^### '` on the `edit_path`, then offset reads. Never read decisions.md (270 KB) or operations.md (118 KB) whole.
  - If the doc keeps a `## Status` block describing its current version, update it too.
- **For P24.S2 (operations): replace the v35 budget line.** The `PHASE_MD_BUDGET = (200 lines, 16 KB)` bullet at current `:593`, and the `finish-slice` size-print text next to it, are superseded by v39's single soft byte cap: 400 KB (~100k tokens), with the line ceiling dropped and still warning-only. Replace them; don't add a second budget.
- **For P24.S3 (qa): the smoke baseline goes to the last count.**
  - The history is 140 → 152 (P21), then → 158 (P22), and **180 PASS / 0 FAIL counted** at P23.S2–S4.
  - The Test 0 pin state is P23's final one:
    - 38 contract positives
    - 19 negatives
    - 3 Test 1 sidecar greps
    - the new whitespace-normalized `parallel-phase` pin list
    - the design-cowork and review-phase additions
  - The testing posture becomes core-only (P22.S1).
- **For P24.S4 (decisions): entries go in version order, newest first.**
  - v44 (P23) goes on top.
  - v39 (P22) and v38 (P21) go between the v42 mockup entry (current `:202`) and the P20/v37 entry (`:279`).
  - The v38 entry carries P21.S3–S5's decisions as well, per P21.REVIEW's note.
  - P22.S1 partly supersedes the v35 entry's budget clause (current `:557`). Handle that the way this doc handles superseded clauses: mark it, and move it to `## Superseded Decisions` if that is the doc's convention.
- **For P24.S5: the known README drift** (from intake; a starting point, not the list):
  - `README.en.md:44–45` and `:317–318` still say the review *consolidates* the docs.
  - Neither README covers the docs-phase route: the `consolidation_owed=` line, `docs-debt`, the per-doc last-updated marker and **STALE** flag, and the 12 KB routing contract with `workflow.py --help` as the command reference.
  - S5 checks both files against S1–S4's new versions, and edits `README.md` in the existing Korean register (합니다체).

## Verification (what the DECOMP executor checks before returning)

- `python3 scripts/workflow.py rebuild` and `validate` both exit 0.
- `phase.md`'s `## Slices` lists DECOMP, S1–S5 and REVIEW. S1–S4 show `docs / low` and S5 shows `docs / high`.
- No `plan.md` exists under S1–S5.
- The verdict is `done`, and `files_changed` lists the five new slice folders, `phase.md`, `result.md` and the regenerated `works/` files.

## After the executor returns (orchestrator, not the executor)

1. `finish-slice P24.DECOMP --outcome "…"`
2. `accept-gate P24 --waive --note "docs phase: new versions of four durable docs plus README edits; no running product surface changes"`
3. `validate`
4. Commit `feat(p24): decompose the docs phase per doc and waive the acceptance gate`.
5. Continue the auto loop with S1.
