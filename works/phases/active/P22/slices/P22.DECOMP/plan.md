# Plan — P22.DECOMP (decomposition)

## Job

Decompose phase P22 ("make doc staleness explicit and right-size the notebook and test guardrails") into middle slices. Create bare slice folders with `python3 scripts/workflow.py new-slice ...` only — never pre-fill any slice's `plan.md` — and record the breakdown, findings, and notes in `works/phases/active/P22/phase.md` (edit under budget). Do not implement anything.

## Read first

- `works/phases/active/P22/intent.md` — the confirmed intent: three resolved operator decisions (D14/D15/D16). This is the source of truth for scope.
- `works/phases/active/P22/phase.md` — the notebook you will seed.
- `works/deferred/open/D14/deferred.json`, `D15/`, `D16/` — the measured evidence behind each decision (and `works/phases/active/P21/slices/P21.S1/result.md` §3.2 and §7 if you need the numbers).
- Relevant machinery: `scripts/workflow.py` (constants `PHASE_MD_BUDGET = (200, 16*1024)` at line ~59, the size printout in `finish-slice` and the `validate` warning around lines ~877/~1038/~1318; the `docs` command listing; `doc-new-version` / `rebuild-docs` and how `docs/index.json` + `docs/current/*.md` are generated), `CLAUDE.md` (doctrine: keep-tests-small rule, docs/read-order rules, notebook-budget mentions), `works/templates/phase.md` (seeded budget note, if any).

## Scope to cut (from intent.md — respect it exactly)

1. **D14 — doc staleness explicit, no cadence.** Every durable doc gets a last-updated marker (source commit, date, consolidating phase) recorded in `docs/index.json` and surfaced where agents read docs: the `workflow.py docs` listing and/or a generated header on `docs/current/*.md`. Plus doctrine (CLAUDE.md and wherever docs-reading is prescribed): a doc older than the owed `## Doc impact` notes is stale evidence, not truth. No cadence knob: leave consolidation operator-paced (note: `CONSOLIDATION_DEBT_MIN_PHASES` stays as-is unless something contradicts).
2. **D15 — notebook budget → soft ~100k-token cap.** Replace the 16 KB / 200-line `PHASE_MD_BUDGET` squeeze with a generous warning-only cap of ~100k tokens (~400 KB text). Keep the `finish-slice` size printout. Warning-only, never an error. Update every place the old budget is stated (workflow.py, CLAUDE.md, templates, agent files under `.claude/` if they mention it).
3. **D16 — keep-tests-small sharpened to core-only.** Doctrine edit: test files only for very core behavior; style/cosmetic/trivial surface verified live. Wherever the keep-tests-small rule lives (CLAUDE.md Hard Rules; executor agent files if they restate it).
4. **Close the debts:** the phase, when it passes, closes D14/D15/D16 — decide here whether each is dropped with `--reason "resolved by P22"` or promoted into a slice, and record the call in `phase.md` (executing the drop/promote is fine to assign to a slice or note for the orchestrator at review time; a `promote-deferred` binds a deferred job to a slice, a drop is recorded at any point — prefer drops recorded at review-pass time and say so in the notebook).

## Constraints and structure guidance

- This is the upstream bootstrap repo: **every slice that edits `scripts/workflow.py`, `CLAUDE.md`, `.claude/*`, or `works/templates/*` must run `python3 installer/build.py` and include the rebuilt `bootstrap_agentic_workspace.sh` in the same slice's changed files** (`--check` must pass). Put that in the notebook's Notes for later slices.
- Keep the count small — this is a well-understood, fully resolved scope; likely 2–4 middle slices. A sensible cut: one slice per decision, or D15+D16 (small doctrine/constant edits) merged into one. No `research` slice is warranted — the decisions are already made. No design/co-work — nothing visual. No `DECOMP2`.
- Set `--risk` deliberately: anything touching `scripts/workflow.py` logic (D14 marker plumbing, D15 budget mechanics) is `high`. A pure-doctrine few-line edit could be `low` → mid tier, but remember the installer rebuild makes even doctrine edits multi-file; weigh that (multi-file ⇒ `high` per the contract).
- Use `--order` so D14 (the biggest) lands where you judge best; `--depends-on` only if real.
- Also note in `phase.md`: workspace-version/CHANGELOG convention — P21 shipped v38; this phase opens v39 (check the CHANGELOG convention in the repo at execution time; likely one slice owns the version bump, or the last slice does).
- **Doc impact:** the changes here alter durable truth (docs machinery, budgets, test doctrine) — remind later slices via the notebook that each appends one-line `## Doc impact` notes; they never run `doc-new-version`.
- Seed the notebook fully: `## Decisions` (the three resolved decisions in compact form + the D14/D15/D16 closure call), `## Notes for later slices` (installer rebuild rule, PHASE_MD_BUDGET location, docs/index.json shape), `## Now` (≤15 lines, what the first middle slice must know).
- Acceptance gate: do NOT run `accept-gate` (orchestrator's job). But state in `phase.md` your read on operator-visible surfaces (this phase is machinery/doctrine + CLI output; the `docs` listing output and validate warnings change — advisory input for the orchestrator's require/waive call).

## Definition of done

- Middle slices exist as bare folders (`slice.json` only) with deliberate kind/risk/order.
- `phase.md` seeded as above, under budget (the current 16 KB budget still binds this phase's own notebook until D15 lands — stay comfortably inside).
- `result.md` written verdict-block-first in the DECOMP slice folder.
- `python3 scripts/workflow.py validate` passes.
