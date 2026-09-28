# Plan — P21.S1 (research: measure context spend across four live adopters)

## Context

Read `works/phases/active/P21/phase.md` (whole) and `works/phases/active/P21/intent.md` (whole) first — the notebook's tagged notes for P21.S1 are your agenda and your boundaries. This is a **findings-only** slice: no product code, no edits to the four adopter repos ever (read-only evidence). Throwaway probe scripts in the session scratchpad are fine.

Evidence repos (read-only):
- /Users/sugang/projects/personal/changple5 (v36, largest)
- /Users/sugang/projects/personal/changple_web (v35)
- /Users/sugang/projects/personal/Mijual (v36)
- /Users/sugang/projects/personal/arb_upbit_1 (v35)

## What to measure (method + numbers, reproducible — record every command)

Per repo, and in this repo where relevant:

1. **Doc-rewrite leak (confirmed; quantify it).** For each repo: docs per `docs/versions/<doc>/`, version counts, byte size of latest vs earliest version, growth curve (size per version — a small table for the worst doc), and how much of a new version is actually new (e.g. `diff` two adjacent versions of the worst offender and measure changed vs total lines). Count how many versions each review-slice consolidation produced (git log or `docs/index.json` sources). Estimate the context an executor pays to *write* a new version of a 400 KB doc (it must read the prior version whole).
2. **phase.md budget pressure.** Distribution of `phase.md` sizes (bytes + lines) across active and archived phases per repo; how many sit within 5% of 16,384 bytes; for 2–3 of the tightest post-v35 notebooks in changple5, spot-check whether compaction lost decisions — compare the notebook's `## Decisions` against the phase's slice `result.md`s / review findings for decisions that vanished mid-phase (git history of phase.md is the instrument: `git log -p -- <phase.md>` on a sampled phase).
3. **plan.md + result.md sufficiency.** Count stray third files across all slice folders (anything beside slice.json/plan.md/result.md — e.g. audit.md, brief.md, notes). Distribution of result.md sizes; whether verdict-block-first is actually being honored (head -20 of a sample) so an orchestrator can read heads only.
4. **Review read cost.** Per repo: result.md count and total bytes per phase (worst phases); what review-slice plan.md/result.md in the adopters say the review actually read (sample 2–3 review results in changple5); compute the context cost of "read every result.md" vs "read phase.md + verdict blocks (heads) only".
5. **Executor validation cost.** Sample recent implementation-slice result.md validation sections in changple5: what gets re-run per slice (full test suites? builds?), typical command sets, repeated re-reads (do executors re-read whole docs/current sections?). Also measure `docs/current/*.md` section sizes per repo — what a slice pays to "read the sections the work touches".
6. **keep-tests-small teeth.** Test file count + total bytes per repo (state the glob used); in changple5 identify where the sprawl concentrates (top directories / worst files) and whether it traces to executor-written tests (git blame/log a few) vs pre-existing product tests — the rule may only need teeth in one place.

## What to weigh (the remedy analysis)

- **Retiring `doc-new-version` from the review slice** in favour of dedicated operator-created docs phases (the operator's proposal). Answer concretely: what does a passing review still record? Where do `## Doc impact` notes accumulate and survive phase archiving? What happens to the parallel-mode deferred-consolidation path (`parallel-merge-finish` → `doc-new-version` → `parallel-consolidated`) if reviews no longer version docs? What breaks in `workflow.py` / CLAUDE.md / the review skill if the review stops consolidating, and what is the minimal machinery change? Also weigh the alternative the measurement may suggest (e.g. sectioned/delta doc versions) but do not invent scope: the operator's proposal is the primary candidate.
- For each of the five open questions: a clear answer or a stated "cannot be settled by measurement — operator call", with the evidence line that supports it.

## Deliverables

- `result.md` in this slice's folder: structured verdict block first, then method (commands), raw tables, per-question analysis, dead ends.
- `phase.md` edits, under budget: what the findings **settle** into `## Decisions`; a compact findings summary + proposed remedy list (each with target files, expected risk rating, and confidence) as tagged notes **(from P21.S1, for P21.DECOMP2)**; anything that is a genuine operator call into `## Operator Questions`; rewrite `## Now`. Consume (remove) the three notes tagged "for P21.S1". Big tables stay in result.md, referenced by path.
- Run `python3 scripts/workflow.py validate` at the end.

## Boundaries

- No edits outside this repo; inside it, only this slice's files + phase.md.
- No `workflow.py` state transitions, no commits, no doc-new-version.
- Do not pre-fill P21.DECOMP2's plan.md — hand it findings, not a plan.
