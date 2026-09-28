# Result — P21.S1 (research: measure context spend across four live adopters)

- **status:** done
- **summary:** Measured context spend across changple5 / changple_web / Mijual / arb_upbit_1
  (1,137 slice folders, 88 phases, 619 doc versions). The confirmed doc-rewrite leak is far bigger
  than any other candidate: per-review doc consolidation is **90–97 % of the review slice's read
  budget** even under the most generous cost model, and changple5 has paid ~9.8 M tokens of prior-doc
  reading across 65 consolidations. Every other suspect measured small or clean: executor validation
  is compute, not context (validation blocks median 1,032 B); `plan.md` + `result.md` suffice
  (verdict-block-first is **100 % adopted** in every phase created on/after 2026-08-29, 0 % before;
  9 ad-hoc third files in 1,137 slices); the review's "read every `result.md`" costs 9–15 % of what
  doc consolidation costs; mid-phase compaction **is not losing decisions** in the sampled tight
  notebooks. Two leaks the intent did not name were found: the **16 KB notebook budget spends 37 %
  of itself on content the slice may not compress**, and **`CLAUDE.md` + the executor agent file have
  grown 5× in two months** to ~16.3 k tokens of fixed cost on every dispatch.
- **files_changed:**
  - `works/phases/active/P21/slices/P21.S1/result.md` (this file, new)
  - `works/phases/active/P21/phase.md` (findings, decisions, notes for DECOMP2, operator questions, Now)
- **validation:**
  - `python3 scripts/workflow.py validate` → passed (see §9)
  - all measurement commands are transcribed in §1 and are re-runnable read-only
- **deviations:** two, both additive — see §8.
- **doc_impact:** none (research slice: no durable-truth change to this repo's product; the
  workspace-doctrine changes this research argues for are DECOMP2's remedy slices to make)

Findings that the next slices need are in
[`works/phases/active/P21/phase.md`](../../phase.md) (`## Decisions`, `## Notes for later slices`,
`## Operator Questions`). This file is the log: method, raw tables, dead ends.

---

## 1. Method

All measurements taken 2026-09-01 from this machine, read-only, against the four adopter
repositories at their then-current checkouts. Nothing in those repositories was modified; the only
writes this slice made are the two files listed above.

**Repos and their shape (`ls`, `works/phases/{active,archived}`):**

| repo | active phases | archived phases | total | slice folders | docs/versions files |
|---|---|---|---|---|---|
| changple5 | 9 | 56 | 65 | 791 | 368 |
| changple_web | 4 | 20 | 24 | 167 | 66 |
| Mijual | 4 | 7 | 11 | 129 | 117 |
| arb_upbit_1 | 8 | 0 | 8 | 50 | 68 |
| **total** | **25** | **83** | **108** | **1,137** | **619** |

> **Correction to `intent.md`.** It records changple5 as "65 active + 56 archived". The real split is
> **9 active + 56 archived = 65 total**; the 65 was the total, not the active count. `~1,140 slices`
> and `83 archived` were right (1,137 and 83). This does not change any conclusion — it only means
> changple5's *active* working set is small and its history is well rotated, which reinforces the
> already-retracted archiving suspect.

**Token estimates** use 4 characters ≈ 1 token throughout. Every "~N tok" figure in this document
is `bytes // 4`. This is deliberately crude and applied uniformly, so ratios between line items are
sound even where absolute values drift.

**Commands.** Every number below came from one of these (run with `cd <repo>` or absolute paths):

```bash
# repo shape
ls <repo>/works/phases/active | wc -l ; ls <repo>/works/phases/archived | wc -l
find <repo>/works/phases -mindepth 4 -maxdepth 4 -type d -path '*/slices/*' | wc -l

# doc version census + growth curve
for doc in <repo>/docs/versions/*/; do ls "$doc" | wc -l; done
wc -c <repo>/docs/versions/backend/*            # growth curve
diff <repo>/docs/versions/backend/v00NN_* <repo>/docs/versions/backend/v00NN+1_* \
  | grep -c '^>'                                # novelty per version

# consolidation cost, per review source, from docs/index.json `source` fields
#   (python: for each version, cost = size(prior) [+ size(new)]; grouped by source)

# notebook budget
wc -c -l <repo>/works/phases/*/*/phase.md
git log -p -- works/phases/active/P88/phase.md  # compaction audit (changple5)

# slice files
find <repo>/works/phases -path '*/slices/*' -maxdepth 5 -type f \
  ! -name slice.json ! -name plan.md ! -name result.md
head -20 <path>/result.md                       # verdict-block-first check

# tests (glob stated verbatim in §7)
#   ^test_.*\.py$ | .*_test\.py$ | .*\.test\.(ts|tsx|js|jsx)$ | .*\.spec\.(ts|tsx|js|jsx)$
#   excluding .git node_modules .venv venv __pycache__ .next dist build
#             .pytest_cache works docs .ruff_cache .mypy_cache
git log --diff-filter=A --format=%ad --date=short -- <testfile>   # attribution

# machinery growth (this repo)
git log --format='%h|%ad' --date=short --reverse -- CLAUDE.md \
  | while IFS='|' read h d; do echo "$d $(git show $h:CLAUDE.md | wc -c)"; done
```

The per-source consolidation cost, the section-granularity floor, the notebook-section breakdown and
the test attribution were computed by short throwaway Python scripts run inline (`python3 - <<EOF`).
They read only; none were saved, and none touched a repo.

---

## 2. Leak 1 — the doc-rewrite leak (confirmed; it is the whole ballgame)

### 2.1 Version census

| repo | docs | versions | latest set | all versions on disk | cumulative read+write across all versions |
|---|---|---|---|---|---|
| changple5 | 11 | 368 | 1,853,525 B | 40,886,225 B | 79,918,925 B ≈ **19.98 M tok** |
| changple_web | 11 | 66 | 269,752 B | 1,387,469 B | 2,505,186 B ≈ 0.63 M tok |
| Mijual | 11 | 117 | 528,624 B | 3,701,785 B | 6,874,946 B ≈ 1.72 M tok |
| arb_upbit_1 | 11 | 68 | 234,007 B | 1,086,742 B | 1,939,477 B ≈ 0.48 M tok |

changple5's worst docs: `backend` 54 versions / latest **420,395 B** / 10.7 MB on disk;
`frontend` 53 versions / 392,662 B / 11.2 MB; `api` 47 / 185,774 B; `qa` 46 / 184,106 B.

### 2.2 The growth curve, and how little of a new version is new

`docs/versions/backend/` in changple5, every version's size and delta (abridged; the full 54-row
table came from `wc -c docs/versions/backend/*`):

| version | bytes | Δ | | version | bytes | Δ |
|---|---|---|---|---|---|---|
| v0001 | 684 | +684 | | v0040 | 309,942 | +1,736 |
| v0010 | 47,493 | +5,266 | | v0045 | 340,949 | +10,533 |
| v0020 | 129,695 | +4,780 | | v0050 | 397,988 | +15,956 |
| v0030 | 198,466 | +5,401 | | v0053 | 412,492 | +3,566 |
| v0038 | 293,117 | +10,655 | | **v0054** | **420,395** | **+7,903** |

Monotone. It has never shrunk. Novelty per version (`diff` of adjacent versions, added lines as a
share of the new version's total lines):

| window | n | mean new-line % | median |
|---|---|---|---|
| all 53 adjacent pairs | 53 | 8.1 % | 4.2 % |
| **last 16 pairs (v0038→v0054)** | 16 | **2.7 %** | 2.5 % |

The newest version, `v0054`, is **5,458 lines / 420,395 B of which 104 lines (1.9 %) are new.**

### 2.3 What one consolidation costs

Two bounds, because the engine already pre-copies the prior body into the new file
(`new_doc_version()` in `scripts/workflow.py:302`, `write_text(dest, frontmatter + base_body)`), so a
surgical `Edit` avoids re-emitting the document:

- **Model A — read the prior version whole, edit surgically.** The realistic upper bound of the
  reading leg.
- **Model B — read the prior whole and re-emit the new one whole.** The naive bound.

| repo | consolidations | model A total | mean/consolidation | model B total | worst single consolidation (model A) |
|---|---|---|---|---|---|
| changple5 | 65 | **9,758,175 tok** | 150,125 | 19,979,731 tok | `P80.REVIEW` 16 versions ≈ **810,595 tok** |
| Mijual | 13 | 793,290 tok | 61,022 | 1,718,736 tok | `P10.REVIEW` 25 versions ≈ 288,413 tok |
| changple_web | 17 | 279,429 tok | 16,437 | 626,296 tok | `P25.REVIEW` 9 versions ≈ 101,525 tok |
| arb_upbit_1 | 9 | 213,183 tok | 23,687 | 484,869 tok | `P8.REVIEW` 6 versions ≈ 43,703 tok |

A single review consolidation in changple5 has exceeded a 1 M-token context window
(`P80.REVIEW` model B ≈ 1.63 M tok; `P90.REVIEW` ≈ 1.48 M tok).

**Writing a new version of the 420 KB `backend.md`:** model A ≈ **103 k tokens** to read
`v0053` (412,492 B); model B ≈ **208 k tokens** (read 412,492 + emit 420,395). The change it records
is 104 lines.

A review consolidates **6.2 docs on average in changple5** (54 REVIEW sources → 336 versions) and
**10.4 in Mijual** — so the per-consolidation figures above are the per-*review* figures.

### 2.4 The honest floor: how much *must* be read

Model A assumes the executor reads the whole prior document. A capable executor `grep`s to the
sections it changes. So I measured the floor: for each version, split old and new into `## ` H2
sections, and sum only the sections whose text actually changed (old + new).

| review | versions | ceiling (whole prior) | **floor (changed sections only)** | floor as % of ceiling |
|---|---|---|---|---|
| changple5 `P90.REVIEW` | 12 | 734,422 tok | **74,236 tok** | 10.1 % |
| changple5 `P88.REVIEW` | 10 | 545,255 tok | **99,050 tok** | 18.2 % |
| Mijual `P10.REVIEW` | 25 | 288,413 tok | **240,438 tok** | 83.4 % |
| arb_upbit_1 `P8.REVIEW` | 6 | 43,703 tok | **62,580 tok** | 143.2 % |

Section granularity only helps where a doc is large *and* finely sectioned. changple5's
`backend.md` has 43 H2 sections, so changing 2 of them means reading 7 % of the file. Mijual's
`frontend.md` has 11 and arb_upbit_1's `decisions.md` has 3 — there, "the changed sections" is
most of the document, and the floor can exceed the ceiling (both old and new copies of a big
section are read/written).

### 2.5 The number that decides it

Even at the **floor**, doc consolidation dominates the review slice:

| review | all `result.md` in full | verdict-block heads only | `phase.md` | docs (floor) | **docs share of (heads + notebook + docs)** |
|---|---|---|---|---|---|
| changple5 `P90` | 47,871 tok | 3,847 | 4,085 | 74,236 | **90 %** |
| changple5 `P88` | 43,611 tok | 6,644 | 4,093 | 99,050 | **90 %** |
| Mijual `P10` | 64,051 tok | 3,770 | 3,751 | 240,438 | **97 %** |
| arb_upbit_1 `P8` | 13,170 tok | 1,175 | 4,009 | 62,580 | **92 %** |

Under model A (whole-prior reads) the same column reads 97–99 %. **The conclusion is robust to the
cost model: doc consolidation is 90–97 % of what a review reads, and everything else the phase
review does is a rounding error beside it.** The operator's instinct is correct, and by roughly an
order of magnitude over the next-largest candidate.

### 2.6 Two extra savings deferral buys, beyond getting off the review's critical path

**(a) Batching collapses rewrites.** Because consecutive phases keep touching the same docs, one
consolidation covering N phases writes far fewer versions than N consolidations:

| repo | versions today | every 3 phases | every 5 phases | every 10 phases |
|---|---|---|---|---|
| changple5 | 368 | 158 (2.3×) | 111 (**3.3×**) | 62 (5.9×) |
| Mijual | 117 | 43 (2.7×) | 32 (3.7×) | 21 (5.6×) |
| changple_web | 66 | 33 (2.0×) | 27 (2.4×) | 19 (3.5×) |
| arb_upbit_1 | 68 | 26 (2.6×) | 19 (3.6×) | 11 (6.2×) |

**(b) Re-review rounds stop re-consolidating.** A `changes_requested` → fix → re-review cycle
consolidates the same docs again today. Those duplicate `(phase, doc)` versions are **11 % of all
changple5 versions and 23 % of Mijual's** (39 and 27 versions respectively). Deferral removes them
outright: a docs phase sees only the final state.

Combined with (2.5), deferring consolidation out of the review is worth roughly
**3× fewer doc versions × the 90–97 % of the review's read budget it currently occupies.**

### 2.7 What a consolidation actually does (this constrains the remedy)

Read from `P88.REVIEW/result.md` §5 and `P90.REVIEW/result.md` §3. Consolidation is **not** an
append. The reviews describe:

- adding a new H2 section per phase topic (*"new *The 총 비용 표 in chat (P88)* section"*);
- **superseding a known-wrong line in place** (*"the P28 'no cost-secrecy handling in chat
  retrieval' line marked superseded in place"*, *"the P70/P89 'one place to add a tier filter'
  expectation superseded in place (there is no tier predicate in `candidates.py`, and adding one
  would be a regression)"*);
- retitling and correcting existing sections (*"the deploy section retitled…"*);
- appending `## Regression Checklist` rows (*"11 new rows"*).

So any remedy that turns docs into append-only deltas would lose the in-place correction the
current design allows, and the docs would accumulate contradictions instead of bytes. **Deferring
*when* consolidation runs preserves this; changing *what* a version is does not.** That is the main
technical argument for the operator's proposal over the sectioned/delta alternative.

### 2.8 Second-order damage the same root cause has already done

`docs/current/*.md` is what every slice reads "the sections the work touches" from. Because docs
only grow and sections are never split, the *section* is no longer a small unit:

| | changple5 | changple_web | Mijual | arb_upbit_1 |
|---|---|---|---|---|
| H2 sections | 275 | 136 | 106 | 90 |
| median section | 3,898 B | 215 B | 2,258 B | 933 B |
| p90 section | 14,743 B | 5,366 B | 11,028 B | 4,656 B |
| largest section | **112,619 B** | 13,640 B | 51,583 B | 42,387 B |

Across all four repos, **10.0 % of sections exceed 10 KB and 2.1 % exceed 30 KB**. The worst:

| bytes | ~tok | where |
|---|---|---|
| 112,526 | 28,131 | changple5 `backend.md` `## Content Agent v2 (content/agent_jobs/, P54 + P72 + P73 + P74 + P77 …)` |
| 76,803 | 19,200 | changple5 `frontend.md` `## Content Agent v2 — the Operator Workspace as It Is Now` |
| 51,905 | 12,976 | changple5 `qa.md` `## Test Commands` |
| 51,571 | 12,892 | Mijual `decisions.md` `## Decision Log` |
| 51,490 | 12,872 | changple5 `frontend.md` `## The Applied Operator Console (P55)` |

`decisions.md` is the worst-shaped: changple5 has 35,163 B in **3** H2 sections and arb_upbit_1 has
44,236 B in **2**. "Read the section" there means "read the doc". The read-order rule
("`docs/current/` **sections**, never the whole doc set") is sound but is silently degrading as the
sections outgrow it.

---

## 3. Leak 2 — `phase.md` budget pressure (the budget holds; its *shape* is wrong)

### 3.1 Distribution

`PHASE_MD_BUDGET = (200, 16 * 1024)` (`scripts/workflow.py:50`); `validate` warns (never errors) and
skips `done` phases (`scripts/workflow.py:839-846`).

| repo / set | n | median bytes | max bytes | median lines | max lines | over budget | within 5 % of the byte ceiling |
|---|---|---|---|---|---|---|---|
| changple5 active | 9 | 69,820 | 179,086 | 876 | 1,915 | 6 | 3 |
| changple5 archived | 56 | 65,854 | 335,623 | 740 | 4,120 | 50 | 0 |
| changple_web active | 4 | 44,858 | 104,021 | 514 | 1,268 | 3 | 1 |
| changple_web archived | 20 | 24,006 | 165,919 | 195 | 1,642 | 11 | 1 |
| Mijual active | 4 | 13,107 | 235,031 | 145 | 2,637 | 1 | 0 |
| Mijual archived | 7 | 106,265 | 291,452 | 1,276 | 3,267 | 7 | 0 |
| arb_upbit_1 active | 8 | 15,015 | 16,354 | 137 | 195 | **0** | 3 |

The retracted suspect stays retracted, and the cut is sharp and dated. Every notebook belonging to a
phase created **on or after 2026-08-29** is under budget (11,208–16,395 B); every one created before
is over, often by 10–20×. arb_upbit_1, whose whole history is post-budget, is 8-for-8 compliant.

### 3.2 The 15 budget-era notebooks: where the 16,384 B goes

`P87 P88 P89 P90` (changple5), `P25` (changple_web), `P10 P11` (Mijual), `P1`–`P8` (arb_upbit_1):

| section | mean bytes | mean % of the 16 KB ceiling |
|---|---|---|
| `## Slices` (**engine-generated**, must not be hand-edited) | 3,096 | **18.9 %** |
| `## Decisions` | 4,100 | 25.0 % |
| `## Doc impact` (**append-only**) | 2,966 | **18.1 %** |
| `## Operator Questions` (append-only) | 1,848 | 11.3 % |
| `## Notes for later slices` | 717 | 4.4 % |
| `## Now` | 1,355 | 8.3 % |
| (objective, intent link, headings, blank lines) | ~2,300 | 14.0 % |

**Two findings.**

1. **The byte ceiling binds; the line ceiling never does.** Mean occupancy is **92 % of 16,384 bytes
   but only 69 % of 200 lines**. At the observed mean density (118 B/line), 200 lines would need
   23,503 B — 1.4× the byte ceiling. changple5 `P88` stopped at **98 lines / 16,375 B**: it ran out
   of bytes with 51 % of its line allowance unused. The dual budget reads as "200 lines *or* 16 KB"
   but is in practice a byte budget with a decorative line number beside it.
2. **37 % of the ceiling is spent on content the slice may not compress.** `## Slices` is generated
   by `rebuild` and explicitly off-limits to the executor; `## Doc impact` is append-only by rule.
   Together they average **6,062 B = 37 %** of the budget. The slice is charged for both and can
   compress neither, so the pressure that produces compaction falls entirely on `## Decisions`,
   `## Notes` and `## Now`. In changple5 `P89` the `## Doc impact` list alone reached 5,601 B (34 %).

Note the coupling: changple5 `P90`'s `## Doc impact` is only 834 B because the review *compressed it
to one line per consolidated doc after consolidating* (`P90.REVIEW/result.md` §3). Today, doc
consolidation is what releases that budget.

### 3.3 Is mid-phase compaction losing decisions? — **No, in the notebooks I could audit.**

Instrument: `git log -p -- <phase.md>`, tracking each `## Decisions` bullet by its identifier across
every revision, then chasing anything that disappeared.

| phase | revisions of `phase.md` | distinct decision ids ever | in the final notebook | ids that vanished |
|---|---|---|---|---|
| changple5 `P88` | 22 | 23 | 19 | 4 |
| changple5 `P90` | 14 | 18 | 17 | 1 |
| changple5 `P87` | 13 | 35 (heuristic ids) | 12 | 23 (see caveat) |

Naive line-level diffing suggests 9–18 "drops" per revision, but that is an artifact: decisions are
**re-worded in place** as they are compressed, so exact-string matching counts a compression as a
loss. Tracking by identifier, then chasing each survivor:

- **`P88` D9** ("slice shape: S1→S2→S3, design round S4, then DECOMP2") — deliberately retired, and
  the notebook says so in the line that replaced it: *"**D9 is spent** — the `## Slices` table is the
  record."* Not a loss; a correct consumption.
- **`P88`** the three contract sub-bullets (`At rest:`, `Frame:`, `Rehydration is the reader's job:`)
  — folded into their parent decision D6, whose final form is marked *"stream + persistence contract,
  FINAL. LOCKED."* Not a loss; a compression.
- **`P90` D6** (Fernet key = `urlsafe_b64encode(sha256(SECRET_KEY).digest())`) — dropped from the
  notebook after `P90.S1` consumed it. It survives in **two** places: `P90.DECOMP/result.md:117` and,
  durably, `docs/current/security.md:1316`. Not a loss.
- **`P87`** the 23 apparent drops are almost all heuristic artifacts (bold-lead decisions with no
  stable id, re-worded each revision) plus recommendation lines superseded by `DECOMP2`'s actual cut.
  The `§7.x` / `§8.x` cross-references that survive in the final notebook resolve to
  **`works/phases/active/P87/audit.md`** (53,515 B / 803 lines, still present at the phase root) —
  see §4.2. Not a loss either.

**The one real cost I found is not a decision.** `P87.S5/result.md` records: *"the restatement
tokenizer had to be re-derived because the audit's script is gone."* A throwaway script, not a
notebook decision — the notebook did its job.

Caveat, stated plainly: this is a 3-notebook sample from one repo (49 revisions), chosen as the
tightest post-budget notebooks per the plan. It shows the mechanism working under pressure; it is
not proof that no compaction anywhere has ever lost anything. The existing safety net — the review's
notebook-vs-logs cross-check — visibly ran and reported in both `P88.REVIEW` and `P90.REVIEW`
(*"Every decision a `result.md` records survives in `phase.md`. D1–D14 are all present"*).

---

## 4. Leak 3 — are `plan.md` + `result.md` sufficient? — **Yes. Do not add a third file.**

### 4.1 Stray-file census (all 1,137 slice folders, both active and archived)

| repo | slice folders | stray files in slice folders | what they are |
|---|---|---|---|
| changple5 | 791 | 32 | `brief.md` ×12, `review.md` ×12 (**legacy**), `dossier.md`, `decomp-notes.md`, `proposal.md`, `chat-render-sample.png`, `evidence/` ×3, `smoke/` |
| changple_web | 167 | **0** | — |
| Mijual | 129 | 1 | `recommendation.md` |
| arb_upbit_1 | 50 | **0** | — |

The 24 `brief.md` / `review.md` are confined to **two** archived phases
(`…P15_repopulate_versioned_doc-set`, `…P16_disable_diagnosis_mode`), i.e. the two oldest in the
tree, from when the workspace still had per-slice brief and review files. Excluding those legacy
artifacts, **9 ad-hoc third files exist across 1,137 slices = 0.8 %**, and 4 of the 9 are evidence
directories (screenshots, smoke output), not prose.

### 4.2 The one instructive counter-example

`works/phases/active/P87/audit.md` — **53,515 B / 803 lines at the phase root**, not in a slice
folder. `P87.DECOMP` produced a production audit far larger than a 16 KB notebook could hold, so it
invented a phase-level file, and its own `result.md` names the split explicitly:
*"## Root cause — the one finding worth repeating outside `audit.md`"*. The notebook then referenced
it by section number (`§7.1`, `§7.2`, `§7.3`, `§2/§8.5`), and those references still resolve today.

This is the *exact* need the v36 **`research` slice kind** now formalises (findings → `phase.md`,
log → `result.md`, and a `DECOMP2` to re-cut from them). `P87` predates it and improvised the same
shape. So the evidence says: the operator's `audit.md` instinct correctly identified a real pressure,
and the workspace has **already** answered it with a slice kind rather than a file. Adding
`audit.md` as a standard third file would re-solve a solved problem and add a file to every slice to
serve 0.8 % of them.

### 4.3 Verdict-block-first — total, immediate adoption

Detector: `status`, `summary`, and (`files_changed` or `validation`) all within the first 20 lines.

| repo | phases created **≥ 2026-08-29** | phases created before |
|---|---|---|
| changple5 | `P87` 8/8, `P88` 10/10, `P89` 8/8, `P90` 11/11 — **100 %** | `P77`–`P86`: **0/108** |
| changple_web | `P25` 10/10 — **100 %** | `P11`–`P24`: **0/92** |
| Mijual | `P10` 11/11, `P11` 7/7 — **100 %** | `P1`–`P9`: **0/93** |
| arb_upbit_1 | all 8 phases 50/50 — **100 %** | — |

**63/63 post-cutoff slices comply; 0/1,074 before.** No partial adoption, no drift, no repo lagging.
The cost of reading a verdict block is a **mean of 1,341 B (~335 tok)** for the first 20 lines.

Conclusion: the two-file record with a machine-readable head is working exactly as designed. The
orchestrator can read a slice's outcome for ~335 tokens instead of the ~3 k (median 10–13 KB) a full
`result.md` costs.

---

## 5. Leak 4 — what may the review read instead of every `result.md`? — real, but small

| repo | phases | every `result.md` in full | heads only (20 lines each) | heads as % |
|---|---|---|---|---|
| changple5 | 64 | 9,276,200 B ≈ 2,319,050 tok | 1,045,471 B ≈ 261,367 tok | **11.3 %** |
| changple_web | 24 | 1,446,448 B ≈ 361,612 tok | 213,271 B ≈ 53,317 tok | 14.7 % |
| Mijual | 10 | 1,639,218 B ≈ 409,804 tok | 152,054 B ≈ 38,013 tok | 9.3 % |
| arb_upbit_1 | 8 | 744,429 B ≈ 186,107 tok | 79,139 B ≈ 19,784 tok | 10.6 % |

Worst individual phases (full read of every `result.md`): changple5 `P53` 41 results / 179,892 tok;
`P50` 37 / 117,021 tok; `P56` 29 / 110,833 tok. `result.md` sizes: changple5 median 10,128 B, max
**69,521 B**; Mijual median 12,461 B; arb_upbit_1 median 12,903 B.

For a budget-era phase, `phase.md` + heads costs **12–35 %** of reading every `result.md` in full
(changple5 `P90`: 7,932 tok vs 47,871 — 17 %). So the saving is real: **3–8× on that leg.**

**But put it next to §2.5:** on changple5 `P90` the *entire* saving available from never opening a
`result.md` again is ~44 k tokens, against 74 k–734 k for doc consolidation in the same slice.
Optimising the review's reading of `result.md` is worth **≈ 5 %** of the review's cost. It is a nice
tidy-up, not a leak.

There is also a correctness argument against going heads-only by default, and the adopters
articulate it themselves. `P90.REVIEW/result.md` §3 records: *"One `result.md` observation had no
notebook home and is carried forward here (S5 left it for the review on purpose)."* That finding
existed **only** in the body of a `result.md`. Heads-only would have dropped it. The right framing
for `DECOMP2` is therefore "heads first, bodies where the head or the notebook points", not
"heads only".

---

## 6. Leak 5 — executor validation cost — **it is compute, not context**

83 post-cutoff implementation/`fix` slices (excluding `DECOMP`/`DECOMP2`/`REVIEW`):

| what the validation block contains | slices | % |
|---|---|---|
| `workflow.py validate` | 80 | 96 % |
| a scoped test run | 47 | 57 % |
| **a whole-suite test run** | 36 | **43 %** |
| a browser / live check | 35 | 42 % |
| lint | 25 | 30 % |
| typecheck | 19 | 23 % |
| container build + roll | 9 | 11 % |

Whole-suite runs are large: `uv run pytest -q` → **1,097 passed** (changple5 `P87.S2`);
`npx vitest run` → **185 files / 1,393 tests** (`P88.S5`); `pytest content/tests/` → **694 passed in
72.87 s** (`P90.S1`). Nine slices rebuilt and rolled Docker images.

**But the recorded validation block has a median size of 1,032 B (mean 1,390 B, max 7,282 B).** A
passing `-q` run costs a line of context. So per-slice validation is expensive in **wall-clock and
CI minutes** and nearly free in **tokens** — it is not a context leak, and trimming it would trade
away real safety for no context saving. (The one context-relevant risk is a *failing* verbose run
dumping output, which I could not measure from the record: `result.md` files record outcomes, and
only passing ones survived to be written.)

Where an executor's tokens actually go, from the same slices:

| item | cost |
|---|---|
| `CLAUDE.md` (read every dispatch) | 34,419–39,796 B ≈ **8.6–10.0 k tok** |
| the executor agent file | 25,437 B ≈ **6.4 k tok** |
| `phase.md` | ≤ 16,384 B ≈ 4.1 k tok |
| `plan.md` | median 6,807 B ≈ 1.7 k tok (changple5), max 34,895 B |
| `docs/current` sections the work touches | median ~3.9 k B ≈ 1.0 k tok, **p90 14.7 k B, worst 112.6 k B ≈ 28 k tok** |
| the validation it records | ≈ 0.3 k tok |

**The fixed machinery overhead is the single largest line item before any work begins: ~16.3 k
tokens per dispatch (`CLAUDE.md` + agent file), and it is growing.** In this repo:

| date | `CLAUDE.md` | `slice-executor-high.md` | fixed total |
|---|---|---|---|
| 2026-06-10 | 6,684 B | — | — |
| 2026-07-02 | ~15,272 B | 6,439 B | ~21,711 B ≈ 5.4 k tok |
| 2026-08-13 | 33,085 B | 11,395 B | 44,480 B ≈ 11.1 k tok |
| 2026-08-14 | 27,233 B (**the one compaction**) | 11,367 B | 38,600 B ≈ 9.7 k tok |
| 2026-08-29 | 30,312 B | 15,598 B | 45,910 B ≈ 11.5 k tok |
| **2026-09-01 (v37)** | **39,796 B** | **25,437 B** | **65,233 B ≈ 16.3 k tok** |

`CLAUDE.md` is **6× its June size**; the executor agent file is **3.9× its July size** and grew 61 %
on 2026-09-01 alone (P20's Aside doctrine). Both have exactly the same shape as the doc-rewrite leak
— a monotonically growing document paid on every single read — except that these are paid **per
dispatch** rather than per review. At 1,137 slices across the four adopters, the `CLAUDE.md` +
agent-file overhead alone is on the order of **18 M tokens**, comparable to changple5's entire doc
consolidation bill.

I am flagging this, not prescribing it: unlike the doc rewrite, the contract's completeness is
load-bearing, and shrinking it trades tokens for behaviour. That makes it an operator call (§10, OQ2).

---

## 7. Leak 6 — where does keep-tests-small need teeth?

Glob (stated for reproducibility): `^test_.*\.py$`, `.*_test\.py$`, `.*\.test\.(ts|tsx|js|jsx)$`,
`.*\.spec\.(ts|tsx|js|jsx)$`; excluding `.git node_modules .venv venv __pycache__ .next dist build
.pytest_cache works docs .ruff_cache .mypy_cache` and dotfolders.

| repo | test files | test bytes | mean/file | source files | source bytes | **test : source** |
|---|---|---|---|---|---|---|
| **changple5** | **494** | **6,322,518** | 12,798 | 1,189 | 15,063,242 | **0.42** |
| changple_web | 44 | 159,403 | 3,622 | 245 | 1,399,159 | 0.11 |
| Mijual | 32 | 300,095 | 9,377 | 263 | 2,551,467 | 0.12 |
| arb_upbit_1 | 10 | 99,143 | 9,914 | 46 | 781,156 | 0.13 |

The other three cluster at **0.11–0.13**; changple5 is **0.42 — 3.5× the compliant band.** The
intent's counts are confirmed exactly (494 / 44 / 32 / 10).

**Where it concentrates** (changple5):

| bytes | directory |
|---|---|
| 2,458,847 | `apps/web/src/test` |
| 1,260,454 | `apps/agent/tests` |
| 1,055,081 | `apps/backend/content/tests` |
| 408,109 | `apps/backend/ingestion/tests` |
| 309,803 | `apps/backend/conversations/tests` |
| 256,851 | `apps/web/tests/browser` |

| bytes | worst files | added by |
|---|---|---|
| 117,952 | `apps/backend/content/tests/test_agent_jobs_scaffold.py` | `P54.S10` |
| 97,491 | `apps/web/src/test/miracle-agent-allocation.test.tsx` | `P72.S23` |
| 82,493 | `apps/agent/tests/test_content_drafts.py` | `P30.S2` |
| 78,773 | `apps/web/src/test/operator-miracle-agent-route.test.tsx` | `P30.S3a` |
| 53,296 | `apps/backend/content/tests/test_agent_jobs_chat.py` | `P54.S7` |

**All five worst files were written by workspace slices.** Attribution across the whole tree
(`git log --diff-filter=A` on each file; workspace installed 2026-06-09, the rule landed in
changple5's `CLAUDE.md` on 2026-06-22 via `f822eb3c`, upstream 2026-06-19 via `5872c99`):

| cohort | files | bytes | mean | median | files > 20 KB |
|---|---|---|---|---|---|
| pre-workspace (< 2026-06-09) | 218 | 2,858,727 | 13,113 | 11,865 | 44 |
| workspace, pre-rule (06-09…06-22) | 2 | 21,840 | 10,920 | 10,920 | 0 |
| **post-rule (≥ 2026-06-22)** | **274** | **3,441,951** | **12,561** | 8,908 | **40** |

**The rule has no measurable teeth in changple5.** Post-rule mean file size (12,561 B) is
statistically indistinguishable from the pre-workspace inheritance (13,113 B); the median improved
(8,908 vs 11,865) but **40 files over 20 KB were written after the rule landed**, and 55 % of the
repo's test bytes are post-workspace.

Two honest qualifications:

1. **Half the sprawl is inherited.** 218 files / 2.86 MB predate the workspace. changple5 had a
   heavy-tests culture the rule then failed to bend; the other three repos are workspace-native and
   never acquired one. So the rule may be doing its job in greenfield repos and simply lacking the
   force to reverse an existing culture — which is a different problem from "the rule is wrong".
2. **This is only weakly a context leak.** Test files enter context when an executor writes or edits
   one; a 118 KB test file is ~30 k tokens to open. But they are not read per dispatch the way docs
   and `CLAUDE.md` are. The stronger cost is wall-clock (§6) and the ongoing maintenance surface.

So: teeth are needed **in exactly one place** — changple5 — and the fair lever is a measurable one.
The `test : source` ratio separates the compliant band (0.11–0.13) from the outlier (0.42) far more
cleanly than any per-file byte cap would, and it does not punish a large product for having many
tests. A per-file soft ceiling (~20 KB, the level 40 post-rule files breached) is the secondary
lever. Both are advisory-warning shaped, like the notebook budget — which §3.1 shows *does* work.

---

## 8. Deviations from `plan.md`

1. **Two cost models instead of one.** The plan asked me to "estimate the context an executor pays to
   *write* a new version of a 400 KB doc (it must read the prior version whole)". I found that
   `new_doc_version()` pre-copies the prior body on disk (`scripts/workflow.py:302`), so the *write*
   leg can be surgical and the parenthetical premise is an upper bound rather than a fact. I reported
   the ceiling the plan asked for **and** measured a section-granularity floor (§2.4), then showed
   the conclusion survives both (§2.5). Additive; nothing was skipped.
2. **Two unnamed leaks reported.** §3.2 (37 % of the notebook budget is incompressible by the slice)
   and §6 (`CLAUDE.md` + agent file, 5× growth to 16.3 k tok per dispatch) are not on the intent's
   list. Both fell directly out of the measurements the plan did ask for, and the second is the
   largest fixed line item in the whole system, so suppressing them would have made the findings
   misleading. Neither is scope for this slice — both are handed to `DECOMP2`/the operator as
   candidates, not decisions.

## 9. Validation

| command | outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **PASS** — no errors, no warnings |

```
$ python3 scripts/workflow.py validate
Workflow validation passed.
$ echo $?
0
```

`P21`'s notebook is well under budget after this slice's edit (see the size line printed by
`finish-slice`), and no warning was raised for any active phase.

No product code was written. The only writes this slice made anywhere are this file and
`works/phases/active/P21/phase.md`. All throwaway Python probes were run inline via heredoc and
never saved.

Adopter repositories, verified with `git -C <repo> status --porcelain` after the measurements:
changple5 **clean**, Mijual **clean**, arb_upbit_1 **clean**. changple_web shows two modified files
(`works/index.json`, `works/state.json`) — these are **pre-existing and not from this slice**: the
diff is a `last_rebuilt_at` / `updated_at` timestamp bump only, and both files have an mtime of
2026-09-01 03:26, roughly six hours before this slice started (03:26 is the operator's own
pre-slice measurement run, the one `intent.md` records at 03:05). Recorded here so a later reader
does not attribute it to this research.

## 10. Answers, one line each

| # | question | answer |
|---|---|---|
| 1 | Is the doc-rewrite leak real? | **Yes, and it is the dominant leak**: 90–97 % of a review's read budget at the floor, 97–99 % at the ceiling; changple5 has spent ~9.8 M tok on prior-doc reads across 65 consolidations (§2.5) |
| 2 | Retire `doc-new-version` from the review? | **Measurement supports it.** It also buys 3.3× fewer versions via batching and removes the 11–23 % of versions that are re-review duplicates (§2.6). The blast radius is small because parallel mode already implements the deferral (§11) |
| 3 | Is 16 KB the right notebook budget? | The budget **works** (every post-2026-08-29 notebook complies), but its **shape** is wrong: the byte ceiling binds at 92 % occupancy while lines sit at 69 %, and 37 % of the ceiling is content the slice may not compress (§3.2). Whether to raise it is an operator call (OQ1) |
| 4 | Is mid-phase compaction losing decisions? | **No** in the 3 tightest notebooks audited across 49 revisions — every apparent drop was a reword, an explicitly-spent decision, or a decision already landed in `result.md` and `docs/current` (§3.3) |
| 5 | Do `plan.md` + `result.md` suffice; add `audit.md`? | **They suffice; do not add a third file.** 9 ad-hoc third files in 1,137 slices (0.8 %); verdict-block-first is 63/63 post-cutoff; the one real `audit.md` is the pressure the v36 `research` kind already answers (§4) |
| 6 | What may the review read instead of every `result.md`? | Heads-first is worth 3–8× **on that leg** but only ~5 % of the review's total cost, and heads-**only** would have dropped a real `P90` finding — so "heads first, bodies where pointed", low priority (§5) |
| 7 | Executor validation cost? | **Not a context leak** — 43 % run a whole suite, but validation blocks are a median 1,032 B. It is a wall-clock cost; trimming it buys safety loss for no tokens (§6) |
| 8 | Where does keep-tests-small need teeth? | **changple5 only** (test:source 0.42 vs 0.11–0.13); the rule made no measurable difference there (post-rule mean 12,561 B vs pre-workspace 13,113 B; 40 post-rule files > 20 KB) (§7) |

## 11. Remedy analysis — retiring `doc-new-version` from the review

The plan asks four concrete questions. Answers, from the machinery as it stands in this repo at v37:

**(a) What does a passing review still record?** Everything except the versions. Its
`## Doc impact` verification (already a required step in parallel mode, `review-phase/SKILL.md:30`),
its slice-validation sweep, its notebook-vs-logs cross-check, its `## Operator Questions` routing,
the gate stages and the `walkthrough`, and `review_verdict` + `explain:`. The only thing that leaves
is `doc-new-version` / `rebuild-docs` and the `doc_versions` return field, which becomes
`none — deferred to a docs phase`. **A passing review's report of record already exists for this
shape** — parallel mode returns exactly that string today.

**(b) Where do `## Doc impact` notes accumulate and survive archiving?** They survive fine but
become unfindable. `_archive_one()` (`scripts/workflow.py:2019`) is a `shutil.move` of the whole
phase folder, so `phase.md` and its `## Doc impact` section land intact in
`works/phases/archived/<ts>_<P>_<slug>/phase.md`. But there is **no index of un-consolidated notes**,
and changple5 already has 56 archived directories. Two further pressures, both measured:
the section averages **2,966 B = 18 % of a 16 KB notebook** and is **append-only** (§3.2), so
notes that must now survive several phases instead of one will squeeze `## Decisions`; and today it
is the review's consolidation that *licenses* compressing that list (changple5 `P90`: 5,601 B →
834 B). A remedy must therefore say where the notes live *between* phases and what may compress them.

**(c) What happens to the parallel-mode deferred path?** Nothing breaks — **it becomes the general
case.** That path already has every piece the remedy needs:

| piece | where | what it does |
|---|---|---|
| per-phase state | `phase.json` `execution.consolidation: pending\|done` | tracks the debt |
| a to-do dashboard | `parallel-merge-finish` (`workflow.py:1649-1669`) | lists phases awaiting consolidation and prints the exact per-note commands |
| a completion command | `parallel-consolidated <P>` (`workflow.py:1673`) | flips `pending` → `done` |
| an archiving guard | `_phase_blockers` (`workflow.py:2013-2015`) | refuses to archive a phase that still owes docs |
| a wrong-place guard | `new_doc_version` (`workflow.py:310-315`) | refuses consolidation from the wrong stream |

So the minimal machinery change is **generalisation, not invention**: lift `consolidation:
pending|done` out of the `execution` block into every phase, generalise the `parallel-merge-finish`
listing into a plain "which phases owe docs" command, keep `parallel-consolidated` (renamed or
aliased), and keep the archiving guard. The parallel path then stops being a special case and
becomes the only path. This is by far the strongest argument that the operator's proposal is cheap:
**the workspace has already been running the deferred design in production, on one code path, since
v24.**

**(d) What breaks, and what is the minimal change?** The blast radius, enumerated:

| file | what must change |
|---|---|
| `CLAUDE.md` | the "Durable docs are versioned once per phase, at the review slice" hard rule; the parallel-mode exception (folds into the general rule); the *Read Order* / *Canonical State* mentions |
| `.claude/agents/slice-executor-{mid,high}.md` | step 5, the review-slice paragraph in step 1, and the `doc_versions` return field (4 sites × 2 files) |
| `.claude/skills/review-phase/SKILL.md` | line 10 (framing), line 19, line 30, **line 51** (the consolidation step) |
| `.claude/skills/do-next-slice/SKILL.md` | lines 41, 49 |
| `.claude/skills/do-whole-phase/SKILL.md` | lines 37, 39, 44 |
| `.claude/skills/parallel-phase/SKILL.md` | lines 98, 157 — the special case collapses into the general one |
| `scripts/workflow.py` | generalise `execution.consolidation`; generalise the `parallel-merge-finish` listing; keep the `_phase_blockers` guard; relax the stream refusal in `new_doc_version` |
| a new docs-phase entry point | the operator-created docs phase needs an obvious way to start (a `create-phase` variant or a documented recipe) |
| `installer/build.py` | rebuild `bootstrap_agentic_workspace.sh` (upstream rule) |

**Two couplings that are the real design work, and neither is optional:**

1. **The acceptance gate writes through the retired path.** `review-phase/SKILL.md:51` states that
   *"the stage-4 smoke-list append rides the same consolidation"*. Gate stage 4 re-runs the whole
   `## Regression Checklist` in `qa.md` **and appends this phase's rows**; `## Operator Runtime` in
   `operations.md` is the manifest every browser-verifying slice depends on. If the review stops
   versioning docs, those two sections stop being updated at review time — the checklist would lag
   the product by however many phases the operator batches. Measured, a carve-out is cheap: the two
   sections are **748–11,732 tok** and **381–1,308 tok** respectively (worst case together ~13 k tok,
   against the 74 k–734 k the remedy saves), and `doc-new-version` pre-copies the body so a
   section-scoped edit needs only that section in context. **Recommendation: let the review keep a
   narrow, named write to exactly these two sections; defer everything else.**
2. **Doc staleness becomes operator-paced.** `docs/current/*.md` is item 3 of the *Read Order* — the
   durable truth every slice reads. Today it is never more than one phase stale. Under the remedy it
   is stale until the operator runs a docs phase, and the `## Doc impact` list becomes the only
   record of the delta. That is a genuine trade, not a bug — but it argues for the debt being
   **visible** (a `next` / `validate` line: "N phases owe doc consolidation") rather than silent.

**The alternative (sectioned / delta doc versions), weighed and not recommended as primary.**
§2.4 shows section granularity would cut the reading leg to 10–18 % in changple5 but **83–143 %** in
the small-doc repos — it helps exactly one repo and hurts three. And §2.7 shows consolidation
routinely *supersedes lines in place*; an append-only delta format would accumulate contradictions
instead of bytes, trading a size problem for a correctness problem. Sectioning is worth keeping as a
**secondary, independent** remedy for §2.8 (the 112 KB H2 section that any reader must swallow), but
it is not a substitute for deferral.

## 12. Dead ends

- **Line-level diffing of `phase.md` history to detect lost decisions.** Produced 9–18 apparent drops
  per revision, essentially all false: decisions are re-worded as they are compressed. Only
  identifier-keyed tracking plus manual chase of each survivor gave a usable answer (§3.3). Anyone
  re-running this should key on the decision id, never the line text.
- **Grepping for the `P87` audit's `§7`/`§8` sections in slice folders and `docs/current`.** Returned
  nothing and briefly looked like a real compaction loss; the sections are in
  `works/phases/active/P87/audit.md` at the **phase root**, which my slice-folder census had scoped
  out. The stray-file census had to be run at both levels.
- **Reading `intent.md`'s "65 active" at face value.** The re-measure the notebook demanded caught it
  (9 active + 56 archived); see §1.
- **Trying to measure real token spend.** Not recoverable — no per-dispatch token log exists in any
  adopter. Every figure here is a byte-derived estimate at 4 chars/token, which is why §2.5 is framed
  as a ratio that holds under both cost models rather than as an absolute.
- **Trying to attribute changple5's test sprawl to executor behaviour alone.** 55 % of test bytes are
  post-workspace, but 218 pre-existing files at a mean 13,113 B show the culture predates the rule,
  so "executors sprawl" overstates it (§7).
