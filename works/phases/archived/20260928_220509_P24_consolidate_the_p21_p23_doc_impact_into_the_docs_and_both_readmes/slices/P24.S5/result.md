# Result — P24.S5 (docs): bring README.md and README.en.md in line with P21–P23

- **status:** done
- **summary:** Brought both READMEs in line with P21–P23. The review no longer "consolidates the docs" in `README.en.md`, and each README gained a short docs-phase subsection. `README.en.md` also got the STALE read-order clause, the `docs` / `docs-debt` / `docs-consolidated` command rows, and fixes to habits 2 and 4, Contributing, and the archive rows. Direct edits only, with no doc version and no installer rebuild.
- **files_changed:** `README.en.md`, `README.md`, `works/phases/active/P24/slices/P24.S5/result.md`, `works/phases/active/P24/phase.md`
- **validation:**
  - `grep -n "consolidat" README.en.md README.md`: PASS. Every hit agrees with the v38 rule, and no line says the review consolidates.
  - Relative-link and anchor check (a Python pass over both files using GitHub-style heading slugs): PASS, `links OK`. The new anchor `#durable-docs-a-docs-phase-you-start` resolves from both files. `#phase-worktrees-on-request` and `#contributing` are unchanged.
  - `ls docs/current/ docs/index.json`: PASS.
  - `python3 scripts/workflow.py validate`: PASS, exit 0. Its only advisory is the existing `oversized_doc_sections=7`. It shows no `consolidation_owed=` and no `stale_docs=`, because the debt is already paid.
- **deviations:**
  - The `archive-phase` and `rotate-backlog` rows in the skill table were also adjusted. They described pre-v38 archiving; an owing phase now stays active. That is a P21 change a README reader must see, and it was caught by the plan's step to grep for other pre-v38 wording.
  - Otherwise none.
- **doc_impact:** none. The READMEs are not versioned docs, and a docs phase adds no notes of its own.

## Changes (file:line → gist, post-edit line numbers)

**`README.en.md`** (30,191 B → 32,375 B)
- `:44–48` *Review gates*: "checks it against the phase's objective and consolidates its doc versions" becomes "checks it against the phase's objective and verifies its list of doc changes; the docs themselves are consolidated later, in a [docs phase you start](#durable-docs-a-docs-phase-you-start)".
- `:261–264` command table:
  - The `doc-new-version` example source changes from `P1.S1` to `P1.REVIEW`, and the row adds "(in a docs phase)".
  - New rows: `docs` (last-updated marker, STALE flag), `docs-debt` (a docs phase's worklist) and `docs-consolidated P1` (record the doc debt as paid).
- `:289–290` skill table:
  - `archive-phase` now archives "review-passed phases whose doc debt is paid".
  - `rotate-backlog` now archives "every currently-done phase with no doc debt, leaving the rest active".
- `:323–325` tier paragraph: "only on a pass — consolidating its doc versions" becomes "only on a pass — verifying its doc-impact list and writing its two gate sections, leaving the docs themselves to a docs phase".
- `:346–348` *Read order* item 3 gains the clause: a doc that `workflow.py docs` flags **STALE** is evidence to check against the notes that outran it, never current truth.
- `:351–364` new `### Durable docs: a docs phase you start` (12 body lines), between *Read order* and *Phase worktrees*. It covers:
  - Ordinary slices leave `## Doc impact` notes, and a passing review only verifies the list beyond its two gate sections.
  - The phase then owes consolidation and stays in `active/`, unarchivable until paid.
  - `next` shows `consolidation_owed=`, and `validate` warns (`consolidation_owed=`, `stale_docs=`, sections past 10 KB) with exit 0.
  - `docs` shows the date/source/commit marker and the STALE flag.
  - "consolidate the docs" / `/create-phase consolidate the docs` → scoped from `docs-debt` → one slice and one version per doc → `docs-consolidated <P>`.
  - It runs on the default stream and links to `#phase-worktrees-on-request` rather than repeating the worktree rule.
- `:420` project tree: `CLAUDE.md # the compact routing contract (~12 KB)`.
- `:457–460` habit 2: "decisions land in versioned docs when I consolidate them in a docs phase".
- `:466–469` habit 4: "each new version carries the slice that produced it" becomes "each new version records its source (the phase reviews whose notes it consolidates) and the commit it was cut at".
- `:520–522` Contributing: new step 4. A passing phase leaves notes it owes; a docs phase you start ("consolidate the docs") versions each touched doc once and pays the debt, with a link to the new subsection.
- `:535` house rule: "Create a new version with `doc-new-version` instead, in a docs phase."

**`README.md`** (18,266 B → 19,314 B)
- `:201–212` new `## 문서 통합: docs phase` (9 body lines, 합니다체), placed after `## 두 종류의 에이전트: 계획과 실행` and before `## 자주 쓰는 명령`. It covers:
  - Ordinary slices leave `## Doc impact` notes.
  - The review checks the list but does not consolidate.
  - A passed phase carries a doc **빚** (debt) and is not archived until paid.
  - `next` shows `consolidation_owed=`, and `docs` marks lagging docs **STALE**.
  - "문서 통합해 줘" / `/create-phase 문서 통합` → a docs phase built from `docs-debt` → one new version per doc → `docs-consolidated <P>`.
  - It always runs on the default stream (`main`), and it links to the English subsection.
- Nothing else changed:
  - *왜 필요한가요?* bullet 2 does not contradict the new section.
  - Habit 4 states no fact the English habit-4 edit changed.
  - The worktree section's docs-phase sentence was already correct.

## Items the plan named, checked and left unchanged

- **Testing posture (point 4):** neither README talks about tests (the only hit is the `test` commit type), so there is nothing to add, as the plan says.
- **Notebook budget (point 3):** both READMEs say only "under a size budget" / "크기 제한 안에서" and give no number, so nothing changed.
- **`--help` as the command reference (point 5):** kept at `README.en.md:271` and in the Korean `## 자주 쓰는 명령`.
- **`## Contents` in `README.en.md`:** it lists H2s only, and the new English subsection is an H3, so there is nothing to add.

## Observations (other drift, not fixed; deferred-job candidates)

1. **`doc-new-version` skill example source.** `.claude/skills/doc-new-version/SKILL.md:10` still gives `--source P1.S1` as its example, while the docs-phase convention is `<P>.REVIEW`.
   - This is embedded machinery (it would need an installer rebuild) and a skill, so it is out of scope here.
   - Trigger: the next phase that touches the skill set.
2. **Tier routing is described as risk-only.** The *slice-executor* paragraph in `README.en.md` (`:319–325`) says tiers are "picked by each slice's risk". The Korean tier table (`README.md:183`) lists `DECOMP` and `REVIEW` but not `research`.
   - The contract routes decomposition, `research` and review by **kind** first.
   - This predates P21 and is outside this phase's changes.
   - Trigger: the next README pass.
3. **`design-cowork` has no row in the English skill table.** The table has 15 rows, and `explain` is covered by the blockquote under it. `design-cowork` is covered only by *Visual work*, so the "17 Agent Skills" heading and the table disagree by one row.
   - This predates P21. Trigger: the next README pass.
4. **Read order item 1 is out of step with the contract.** In `README.en.md:342` it reads "`works/state.json` and `next`". `CLAUDE.md` now words it as "`next`: this checkout's pointer (`parallel-status` shows every stream)".
   - Minor and pre-existing (the v43 stream scoping). Trigger: the next README pass.

## Notes

- Instrument: none needed. This is a docs-only slice with no browser claim.
- Workflow commands run: only `docs`, `next`, `--help` (read-only) and `validate`. No `doc-new-version`, no `rebuild-docs`, no `build.py`, no state transitions and no commits.
- `phase.md`: the S5 note in `## Notes for later slices` was removed, and `## Now` was rewritten as the handoff to REVIEW. No `## Doc impact` line and no operator question were added.
