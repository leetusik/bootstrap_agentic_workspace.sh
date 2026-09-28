# Plan — P24.S5 (docs): bring README.md and README.en.md in line with P21–P23

## Context

P24 is the operator's docs phase. S1–S4 have landed new versions of architecture, operations, qa and decisions, and the orchestrator has recorded `docs-consolidated` for P21, P22 and P23. This slice does the other half of the operator's ask ("for the doc consolidation include readme.md", confirmed as **both** READMEs; see `works/phases/active/P24/intent.md`): bring the repo's two READMEs in line with the same P21–P23 changes.

- `README.md` is **Korean** and the shorter, friendlier landing page. `README.en.md` is the full English reference. They are twins, so a user-facing fact that changes in one changes in the other, at each file's own depth.
- Neither is versioned (there is nothing under `docs/versions/` for them) and neither is embedded in `installer/`. So you edit them **directly**: no `doc-new-version` and no `build.py` rebuild.
- Read `phase.md` `## Decisions` (*READMEs are direct edits*) and the S5 note.

**Source of truth:** the four new doc versions in `docs/current/` are architecture v0008, operations v0035, qa v0010 and decisions v0042; confirm the ids with `python3 scripts/workflow.py docs`. Also `CLAUDE.md`, the 12,259 B routing contract. Read only the sections you need. Operations' new `## Durable-doc consolidation — a docs phase the operator creates` section is the main one.

## What changed (P21–P23) that a README reader must see

1. **Durable docs are no longer versioned at the review** (v38).
   - A slice that changes durable truth leaves a one-line `## Doc impact` note in `phase.md`.
   - A passing review only **verifies** that list and writes its two gate sections (`## Regression Checklist`, `## Operator Runtime`). The phase is stamped as **owing** consolidation.
   - The operator starts a **docs phase** when they choose, e.g. `/create-phase consolidate the docs`. It versions each doc once, and `docs-consolidated <P>` pays each phase's debt.
   - An owing phase stays in `active/` and can't be archived until paid.
2. **The debt and staleness are visible** (v38–v39).
   - `next` prints `consolidation_owed=<phases>`.
   - `validate` warns: `consolidation_owed=`, `stale_docs=` and an oversized-section advisory, all with exit 0.
   - `docs-debt` prints the worklist.
   - `docs` shows each doc's last-updated marker (date / source / commit) and flags a doc outrun by an owed note as **STALE**. The read-order doctrine is that a STALE doc is evidence to check against the notes, never current truth.
3. **The notebook budget** is a soft 400 KB byte cap (v39), warning-only. The READMEs only say "under a size budget", so change nothing unless a number appears.
4. **Testing posture is core-only** (v39). Test files exist only for very core behavior, and cosmetic/trivial surface is verified live. Mention it only where a README already talks about tests; don't add a new section.
5. **`CLAUDE.md` is a ~12 KB routing contract** (v44).
   - It holds short rule stubs, one statement per rule.
   - Procedure lives in `python3 scripts/workflow.py --help`, the owning skills and the executor bodies.
   - `--help` is the command reference; the READMEs already say that at `README.en.md:266`, so keep it.

## Known drift to fix (confirm each; line numbers from planning)

**`README.en.md`**
- `:44`–`:46` *Review gates*: "checks it against the phase's objective and consolidates its doc versions". Replace it with verify-and-hand-off: the review checks the phase against its objective and verifies its doc-impact list, and the docs themselves are consolidated later in a docs phase you start.
- `:317`–`:319`, the tier paragraph under *The same operations as Agent Skills*: "validating the phase and — only on a pass — consolidating its doc versions". Fix it the same way.
- `:259` command table, `doc-new-version --doc backend --summary … --source P1.S1`: change the example source to `P1.REVIEW`, the docs-phase convention. Add compact rows for:
  - `docs` (list docs with their last-updated marker and STALE flag)
  - `docs-debt` (the docs phase's worklist)
  - `docs-consolidated <P>` (record that a phase's doc debt is paid)
- **Add a short subsection** under `## How it works`, e.g. `### Durable docs: a docs phase you start`, placed after *Read order* and before *Phase worktrees*. In ≤ ~12 lines, cover points 1 and 2: notes → review verifies → owed debt shows in `next` → `docs-debt` → "consolidate the docs" via `/create-phase` → one version per doc → `docs-consolidated`. Also say that it always runs on the default stream, never in a worktree; `:370`–`:372` already says this, so link to it rather than duplicating.
- `### Read order` (`:332`–`:342`), item 3: add the STALE clause. A doc `workflow.py docs` flags **STALE** is evidence to check, never current truth.
- `## ⭐ How I work with coding agents`:
  - Habit 2 (`:432`–`:436`) "decisions land in versioned docs": make it "… land in versioned docs when you consolidate them in a docs phase", or similar. Keep the voice.
  - Habit 4 (`:444`–`:446`) "each new version carries the slice that produced it": since v38–v39 a version carries its **source** (the reviews whose notes it consolidates) and the **commit** it was cut at. Fix the claim.
- `## Contributing` (`:483`–`:510`):
  - Add a step 4, or a short line after step 3: the phase leaves its doc debt, and you consolidate when you choose with a docs phase.
  - The house rule "Create a new version with `doc-new-version` instead" gets a clause: "… in a docs phase".
- `## Project structure` (`:398`–`:399`): `CLAUDE.md  # the compact routing contract` is fine. Optionally add "(~12 KB)". Nothing else there changes.
- Grep `README.en.md` for `consolidat`, `doc-new-version` and `review` wording that states the pre-v38 rule, and fix any other hit.

**`README.md` (Korean)**
- It has no English-style review-consolidates claim, but it also never explains the docs phase except in the worktree section (`:240`–`:249`).
- Add a short subsection that mirrors the English one at the Korean README's depth, in its existing register (**합니다체**, the same terms: phase, slice, `docs phase`, `docs-debt`, `STALE`). Place it after `## 두 종류의 에이전트: 계획과 실행`, or as a short `### 문서 통합: docs phase` inside `## 사용 예시`; choose whichever reads naturally.
  - It covers: slices leave notes → the review verifies → `next` shows `consolidation_owed=` → say "consolidate the docs" / `/create-phase 문서 통합` → one version per doc.
  - Keep it to ≤ ~8 lines.
- `## 왜 필요한가요?`, bullet 2 (`:133`–`:136`), "노트(`phase.md`)와 버전 문서에 기록해서": fine. Adjust it only if the new subsection makes it contradictory.
- `## ⭐ 에이전트와 일하는 6가지 습관`, habit 4 (`:267`–`:268`), "문서를 고쳐 쓰지 않고 새 버전을 추가합니다": still true; leave it unless your English habit-4 edit changes a fact the Korean one states.
- The worktree section's docs-phase sentence (`:240`–`:243`) is already correct.

**Both files**
- Don't restate the workflow in full. The READMEs point at the docs and the contract.
- Don't touch anything outside P21–P23's changes. If you notice **other** drift, list it in `result.md` as observations (deferred-job candidates) rather than fixing it. The exception is a factual error in a sentence you are already rewriting.
- Keep existing links and anchors working. `README.md` links `README.en.md#phase-worktrees-on-request` and `#contributing`; don't rename those headings.

## Steps

1. Read the named README passages and the operations docs-phase section (`docs/current/operations.md`; grep the heading, then do an offset read).
2. Edit `README.en.md`, then `README.md`, as above.
3. Check:
   - `grep -n "consolidat" README.en.md README.md`: every hit agrees with the v38 rule.
   - Check that every relative link you added resolves (`ls` the target paths).
   - `python3 scripts/workflow.py validate` exits 0. The READMEs are not validated, so this only checks that nothing else moved.
4. Write `result.md`, **verdict block first**. Then add:
   - a list of each change (file:line → gist)
   - the observations list
   - the before/after byte sizes of both files
5. Edit `phase.md` under its budget:
   - Remove the S5 note, which this slice consumes.
   - Rewrite `## Now` as the handoff to REVIEW.
   - Add no `## Doc impact` line.

## Out of scope

- Durable docs.
- `CLAUDE.md`.
- Skills.
- Code.
- `docs/retrofit-guide.md`.
- `installer/README.md`.

Executor: `slice-executor-high` (`docs / high`, two files, Korean prose).
