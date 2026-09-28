# Intent — P21

- Captured at: 2026-09-01T03:05:00+09:00
- Origin: operator

## Original Input (verbatim)

> go and in p20, also consider token saving strategy for this workspace. I mean, maybe executor validaiton, test file, and review slice etc.. maybe there are some token leak. investigate and research changple5, changple_web, Mijual, and arb_upbit_1 for real usage of this workspace. you can split the phase though. /create-phase

> I choose one. and here is my thoughts:  for leak 1: maybe we should retire doc rewrite. IT will be handled dedicated phase. when operator create one.  2. phase.md budget is ignored bcs I think they are exists before the budget. but Idk if 16kb is enough. I saw compaction jobs are executed during the phase run is it ok? and if a orchestrator wants to see a what a slice done would current plan.md and result.md, audit.md enough? 3. well I pretty sure there some archived phases. I `/rotate-backlog` time to time. isn't it do archive?

## Confirmed Intent (refined + clarified)

One phase, research-first (the v36 `research` → `DECOMP2` pattern): measure where this workspace actually spends context across the four live adopting repos — changple5 (v36, 65 active + 56 archived phases, ~790 slices), changple_web (v35, 20 archived), Mijual (v36, 7 archived), arb_upbit_1 (v35, 0 archived) — then close only the leaks the measurement justifies. Split from P20 on the operator's explicit say-so.

**Confirmed leak, with the operator's proposed remedy to research first:** per-review durable-doc consolidation rewrites whole docs that only grow — changple5's backend.md is at v0054, 420 KB, and every review rewrites it. The operator proposes **retiring the doc rewrite from the review slice**: durable-doc consolidation would happen in a dedicated docs phase, created by the operator when they want one. The research slice weighs this (what a review still records, where "Doc impact" notes go, what happens to the parallel-mode deferred-consolidation path) before DECOMP2 cuts it as machinery.

**Open questions the research must answer:**
- Is 16 KB the right `phase.md` budget? Post-v35 notebooks ride within bytes of the ceiling (changple5 P88: 16,375 of 16,384). Mid-phase compaction is by design and the operator accepts it in principle — the question is whether compaction under that pressure drops decisions the review then has to catch.
- Is `plan.md` + `result.md` sufficient as the orchestrator's post-slice record? (Operator floated `audit.md`; adopters carry essentially none — 1 stray + 12 legacy `brief.md` across ~1,140 slices — so the default answer is "the two files suffice, verdict-block-first"; research confirms or refutes rather than adding a third file.)
- What may the review slice read instead of every `result.md`? (changple5: 772 result.md files, 9.3 MB total, largest 69 KB.)
- Executor validation cost — what does a dispatched executor re-read or re-run that it does not need?
- Where does keep-tests-small need teeth? changple5 has 494 test files / 6.3 MB while the other three comply (44 / 32 / 10 files).

**Retracted suspects (measured, not leaks):** archiving works — `rotate-backlog` archives to `works/phases/archived/` and the operator runs it routinely (56/20/7); the notebook budget is respected since v35 — over-budget notebooks are pre-budget phases.

**Scope boundary:** machinery and doctrine in this repo only. The four adopter repos are read as evidence; any remediation they need ships as a documented procedure or a workflow.py command they run themselves — never edits from here.

## Clarifications Resolved

- Q: One phase research-first, two phases (measure then fix), or engine-only scope? — A: **One phase, research-first** ("I choose one").
- Q: Is the doc-rewrite leak real, and what remedy? — A: Real; operator proposes retiring the per-review doc rewrite in favour of dedicated operator-created docs phases.
- Q: Is the phase.md budget ignored? — A: No — over-budget notebooks predate the budget (operator's read, confirmed by measurement). Open sub-questions: is 16 KB enough, and is mid-phase compaction (which the operator has watched happen) acceptable/lossless enough.
- Q: Are phases really never archived? — A: Wrong measurement (checked `archive/`, real dir is `archived/`); the operator rotates routinely. Retracted.

## Notes

- Measurements taken 2026-09-01 from this machine; the research slice should re-measure rather than trust these numbers, and record method + numbers in phase.md.
- P20 (Aside doctrine, v37) is the sibling split from the same operator request; this phase should coordinate its workspace version number with P20's at review time.
