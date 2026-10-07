# Plan — P31.REVIEW (docs phase review, acceptance gate WAIVED)

**Tier:** high (review, by kind). Review P31 against its objective and `works/phases/active/P31/intent.md`: pay the P26–P30 `## Doc impact` debt as one new version each of architecture, operations, qa and decisions, and fold in D50's `## Operator Runtime`, which the operator approved at DECOMP. Read `phase.md` in full: `## Decisions`, `## Notes for later slices` (several REVIEW notes) and `## Now`. Also read the five slice `result.md` files.

## Boundary

`python3 scripts/workflow.py phase-scope P31` reports range `dfd171c..HEAD`, 6 commits, and **0 product files**, because `docs/` and `works/` are excluded. This phase changed no product code and no machinery, so there is **no Regression Checklist re-run** (no checklist line's surface is fed) and no smoke run is needed. The gate is waived, so there are no gate stages and no walkthrough.

The review's subject is the four new doc versions:
- architecture v0010
- operations v0037
- qa v0013
- decisions v0043

Each is diffed against its predecessor (v0009, v0036, v0012, v0042).

## 1. Validate

1. `python3 scripts/workflow.py validate` passes.
2. `python3 scripts/workflow.py docs-debt` prints `docs_debt=none`.
3. `python3 scripts/workflow.py docs` shows no STALE flag.
4. `python3 installer/build.py --check` passes. It is a sanity check that no embedded file moved.
5. `git diff dfd171c..HEAD --stat -- . ':!docs' ':!works'` is empty, so no product or machinery file changed.

## 2. Judge the consolidation

- **Coverage.** P26–P30's notes are still in their `phase.md` `## Doc impact` sections; they are paid now, not deleted. Check each of the 52 notes against the version that should carry it, using the per-slice coverage in `## Decisions` *Cut*. Sample at least every note that names two docs, and every supersession chain:
  - design loop P26 → P27;
  - install default P28 → P29;
  - nested marker name;
  - card rule P26.F1 → P26.F2;
  - smoke baseline 192 → … → 239.

  A note with no landing is a finding.
- **Merge, not append.** No stale statement survives beside its replacement. Grep the current docs for false leftovers:
  - "Claude Design + DesignSync" headings;
  - "180 PASS";
  - an opt-in-only `--nested` as the default;
  - `workflow/nested.json`;
  - the "no such manifest" sentence.

  Leftovers kept on purpose as history in decisions' `## Superseded Decisions` are fine.
- **D50.** operations v0037 `## Operator Runtime` is real, with no `UNFILLED` line, and matches how this repo is actually run: CLI only, scratch directories for mutating commands, and the smoke suite run once and alone.
- **The slices' recorded edits beyond the notes and contradictions.** Judge each one:
  - S1's skill count 17 → 18, and its narrowing edits;
  - S2's six extras and its new `## Nested personal install` H2;
  - S3's DesignSync-pin resolution and its "by subtraction" count;
  - S4's two additions and its four contradiction resolutions.

  Spot-check each extra fact against the code or the skills, reading only what is needed. A false statement is a finding.
- **Cross-doc consistency.** Pointers between docs must hold. Example: architecture and operations point to decisions for the nested rewrite and the `wf-<name>` clash map, so check that v0043 carries them.
- **No `## Doc impact` notes of P31's own.**

## 3. Verdict

- **On a pass:**
  - `doc_versions: none — deferred to a docs phase`. This phase *is* the docs phase; its four versions are the slices' own work, and the review writes no gate section, because nothing operator-visible changed and the Regression Checklist gains nothing.
  - `explain: not written — run /explain for this phase`.
  - `walkthrough: n/a (gate waived)`.
- **On a non-pass:**
  - Finish validation and judgment first.
  - Then return numbered findings with proposed fix slices: kind `docs` if they re-version a doc under the carve-out (as P24's F1/F2 did), risk `high` because all four slices ran on mid.
  - Skip the pass-only steps.
- **Either way,** list deferred-job candidates (title · reason · trigger). The slices raised:
  - bring decisions' and operations' executor-tier text and Status up to v45/v46;
  - recount Test 0's pins;
  - fill operations' empty `## Local Development` stub.

  Merge these where they overlap. Add any others you find outside the notes' scope.

Write `result.md` with the verdict block first, and edit `phase.md` `## Now`. Do not commit. Do not run `review-phase`, `accept-gate`, `set-*-status`, `doc-new-version` or `docs-consolidated`. Edit no doc.
