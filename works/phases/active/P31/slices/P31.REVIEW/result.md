- status: done
- tier: high
- summary: Reviewed P31 (gate waived) against its objective. All 52 P26-P30 notes landed in architecture v0010, operations v0037, qa v0013 and decisions v0043, and D50's `## Operator Runtime` is real. Every mechanical check passes. Verdict **changes_requested**: three false or stale statements survive in architecture v0010 and operations v0037, and S1's in-remit choices are missing from `## Decisions`. Two `docs / high` fix slices re-version those two docs.
- files_changed:
  - `works/phases/active/P31/slices/P31.REVIEW/result.md` (this file)
  - `works/phases/active/P31/phase.md` (`## Now` only)
- validation:
  - `python3 scripts/workflow.py validate`: PASS ("Workflow validation passed."; the only warning is `oversized_doc_sections=8`, which D25 covers)
  - `python3 scripts/workflow.py docs-debt`: PASS (`docs_debt=none`). P26-P30 `phase.json` `consolidation` = `done`
  - `python3 scripts/workflow.py docs`: PASS. No STALE flag. The latest versions are architecture v0010, operations v0037, qa v0013 and decisions v0043
  - `python3 installer/build.py --check`: PASS ("in sync")
  - `git diff dfd171c..HEAD --stat -- . ':!docs' ':!works'`: PASS (empty). `phase-scope P31` reports `product_files=0`, range `dfd171c..5645209`, 6 commits
  - per-slice commands: `docs-debt` and `validate` were re-run, as above. `docs` confirms that `docs/current/*.md` match the latest versions, so `rebuild-docs` was not re-run (it writes). `doc-new-version` was not re-run either, since it is not idempotent and the versions already exist
- deviations: none from `plan.md`. One scratch installer probe was denied by the permission system (see *Dead ends*). Finding 1 rests on the code read and P29's own recorded resolution instead.
- doc_versions: none. The review writes no gate section: the gate is waived, nothing operator-visible changed, and the Regression Checklist gains nothing.
- review_verdict: **changes_requested**
  1. **architecture v0010 and operations v0037 overstate the `workflow/`-target refusal.**
     - Where: architecture `## Nested Install`, *The default and its flags* (current lines 141-142), and operations `## Nested personal install`, *Install modes* (current line 745). Both say "any run on a nested install's `workflow/`" refuses.
     - The code: `resolve_layout()` in `installer/main.py` (lines 105-111) returns at-root for `--into-existing` before the marker check. It refuses on the marker only when `UPDATE or not AT_ROOT_FLAG`.
     - P29 already settled this. `works/phases/active/P29/phase.md:55` and P29.S2's `result.md` worded it as "a bare install or an `--update`", with `--at-root` and `--into-existing` not covered. decisions v0043's P29 entry states that narrower truth, so the three docs now disagree.
  2. **operations v0037 `## The operator acceptance gate` keeps a false clause in the paragraph S2 rewrote for D50.**
     - The text (current lines 1300-1302): "its phases are legacy-shaped or waived and the gate stages never fire here".
     - The facts: P29 and P30 declared `acceptance.required: true`. Their reviews ran gate stages 1-6 on the CLI, and the operator cleared both gates. qa's eight `(P29)`/`(P30)` checklist lines are those gated reviews' stage-4 appends.
     - D50 was raised (P30.REVIEW observation 5) because gated reviews here had no manifest for stage 1. The paragraph should say the manifest serves gate stage 1 for this repo's gated phases, not that gates never fire.
  3. **operations v0037 `## Visual-design runbook` still carries the pre-v47 "one `co-work` slice per round" model.**
     - The text: line 257, "In **every** style, how many rounds there are is decided at the opening `DECOMP` (one `co-work` slice per round)"; line 248, `paired`'s "the apply-slice count equals the round count"; line 238, `build-after`'s "the high-risk `co-work` rounds".
     - Why it is stale: P26.S3's note superseded it ("a new round in the same slice"), and the same runbook's *Close the round* now says so.
     - The other sources: `design-cowork` says "How many design slices there are is decided at the opening `DECOMP` … A slice's revisions are superseding *rounds* inside it" and "The apply-slice count equals the design-slice count". decisions v0043's P27 entry says there is no "one co-work slice per round".
     - This is a stale statement beside its replacement, plus a cross-doc contradiction.
  4. **Notebook: S1's in-remit choices are not in `phase.md` `## Decisions`.**
     - S2, S3 and S4 each recorded a "vNNNN shape" line. S1 recorded none, so its edits beyond the notes live only in `slices/P31.S1/result.md`:
       - the skill count 17 → 18 in two places, with an offer to revert it if the operator wants notes-only edits;
       - the narrowed "byte-identical across the at-root install modes" sentence;
       - "a fresh `--at-root` install".
     - The review judges all three correct (18 skills; `EXPECTED_SKILL_COUNT = 18` in `installer/build.py` and `installer/main.py`; CHANGELOG v49). They belong in `## Decisions`.

  Proposed fix slices (kind `docs` under the docs-slice carve-out, risk `high` because S1 and S2 ran on mid):
  - **P31.F1, architecture (docs / high).**
    - `doc-new-version --doc architecture`. In `## Nested Install` *The default and its flags*, replace "or any run on a nested install's `workflow/`, refuses" with the narrower truth: a bare install or an `--update` on a nested install's own `workflow/` refuses; `--at-root` and `--into-existing` are not covered. Match decisions v0043.
    - `rebuild-docs`.
    - Add an "Architecture v0010 shape (P31.S1)" line to `phase.md` `## Decisions` (finding 4).
  - **P31.F2, operations (docs / high).** `doc-new-version --doc operations`, then `rebuild-docs`. Three edits:
    - (a) the same `workflow/` narrowing in *Install modes*;
    - (b) rewrite the acceptance-gate paragraph's false clause: phases here that change CLI behaviour take a required gate (P29, P30), whose review reads `## Operator Runtime` at stage 1 and walks the CLI in scratch directories; the rest are waived;
    - (c) in the styles section, "design slices" decided at `DECOMP`, revisions as superseding rounds inside a slice, `paired`'s apply count equal to the design-slice count, and `build-after`'s "`co-work` design slices". Match `design-cowork` lines 257-260 and 287-291.

    Optional riders, since F2 re-versions operations anyway (not findings):
    - say that `--nested` still refuses beside `--at-root` or `--into-existing` (`bootstrap_agentic_workspace.sh` wrapper lines 88-89);
    - say that the mockup route's path also goes into the round's SIGNOFF at close (`design-cowork` lines 786-789).

  F1 and F2 touch different docs and can run in either order. After both, `docs` and `validate` should stay clean. No `docs-consolidated` is needed: P26-P30 are already recorded paid, and the fixes correct this phase's own versions.
- walkthrough: n/a (gate waived)
- explain: not written — run /explain for this phase
- deferred-job candidates (title · reason · trigger), for the orchestrator to file:
  1. *Bring decisions' and operations' executor-tier text and Status up to v45/v46* · no owed note covered v45 (`executor-mode`) or v46 (mid the default tier, real code in scope). Operations' tier table and v23 Status sentence still describe the pre-v46 mid, decisions' v23 tier entry is not marked superseded, and both Status rollups jump v44 → v47 (S2 observation 1 and S4 observation 5, merged) · the next docs phase
  2. *Recount Test 0's pins in qa* · `## Test Commands` keeps "38 positives, 19 negatives" as of P23.S4, while P26-P27 re-pointed and added pins without a recount (S3 observation 4) · the next docs phase, or the next Test 0 edit
  3. *Fill operations' `## Local Development` stub* · it is still the empty seed (Install/Run/Test/Build) beside the filled `## Operator Runtime`, which already names the engine, build and smoke commands (S2 observation 4) · the next docs phase
- deferred "next docs phase" triggers to relay to the operator (unchanged, out of P31's scope per DECOMP): D17 (`stale_docs=` aggregate wording), D21 (two stale one-line help descriptions), D23 (`doc-new-version` skill example, with D21), D24 (README drift), and D25 (splits: operations' runbook is now 41,295 B and decisions' Decision Log 274,613 B).

# P31.REVIEW result: docs phase review (gate waived)

## Boundary

`phase-scope P31` reports range `dfd171c..5645209` (6 commits) and `product_files=0`, because `docs/` and `works/` are excluded. No product or machinery file changed (`git diff --stat` is empty and `build.py --check` is in sync). The gate is waived (`acceptance.required: false`, note "docs phase: four durable-doc versions, no operator-visible surface"), so there are no gate stages, no Regression Checklist re-run and no walkthrough. The review's subject is the four versions, each diffed against its predecessor: architecture v0009 → v0010, operations v0036 → v0037, qa v0012 → v0013, decisions v0042 → v0043.

## Coverage of the 52 notes

I extracted the five `## Doc impact` sections (P26 19, P27 11, P28 12, P29 4, P30 6 = 52 lines) and read each against its target version's diff.

- **Every note landed.** The S1-S4 landing tables match the diffs.
- **The notes that name two docs** land in both:
  - P28.F1: architecture *The ignore guarantee* and operations *The ignore guarantee*;
  - P29.S1: architecture *The default and its flags* and operations *Install modes*, both carrying finding 1's overstatement.
- **Supersession chains:**
  - **Design loop P26 → P27:** stated as the drafter default plus the per-phase `claude-design` option, P26's governance winning, in all three docs. Finding 3 is a residue the chain should have removed.
  - **Install default P28 → P29:** nested is the default everywhere. Opt-in wording survives only as labelled history (operations' Status and release bullets, architecture's H2 subtitle, decisions' P28 entry and Superseded bullet).
  - **Nested marker:** current docs name only `.agentic-nested.json`. The one `nested.json` mention is the decisions P28 entry's "first drafted as `nested.json`, renamed", which is history.
  - **Card rule P26.F1 → P26.F2:** operations states F2's text as the rule plus F1's engine facts. Decisions states the final rule once and names F1's `#` reading as superseded.
  - **Smoke baseline 192 → 195 → 203 → 226 → 235 → 239:** one chronological clause in qa `## Test Commands`, with Status at 239 as of v51. The P28 "by subtraction 20" is labelled (203 + 20 + 3 = 226).
- **No notes of P31's own:** `phase.md` `## Doc impact` and `## Operator Questions` are both empty, so there is nothing to route.

## Leftover grep (current docs)

| Pattern | Hits | Verdict |
|---|---|---|
| "Claude Design + DesignSync" headings / "Claude Design plus the operator" | operations 192 (quoted as what v47 replaced); decisions 15, 291, 2080 (Status rollup, P26 Status, Superseded bullet) | history, kept on purpose |
| "180 PASS" | qa 246 (inside the "how it rose" chain); decisions 401 (P23 entry) | history |
| `--nested` as opt-in default | architecture 106 (H2 subtitle "opt-in in v49, default since v50"); operations 163, 1767 (v49 history); qa 227 (Test 15 really runs `--update --nested`, smoke line 1638); decisions 207, 2073 (P28 entry / Superseded) | history or accurate |
| `workflow/nested.json` | decisions 161 ("first drafted as `nested.json`, renamed") | history |
| "no such manifest" | none | replaced (but see finding 2) |

## D50: `## Operator Runtime`

operations v0037 `## Operator Runtime` follows the seeded shape (`installer/payloads/doc_bodies/operations.md`) field for field and adds a smoke-suite bullet. It has no `Status: UNFILLED` line. It records how this repo actually runs:

- the engine CLI and the built installer, rebuilt by `build.py`;
- no dev/prod split;
- no origin, no browser and no instrument, with Aside n/a;
- scratch directories (`cp -R` copies or `mktemp -d` installs) for mutating commands;
- `bash tests/retrofit_smoke.sh` run once, alone and in the foreground.

`works/deferred.md` shows D50 `promoted` → `P31.S2`. The section itself is correct. Finding 2 is about the gate paragraph that points at it.

## The slices' edits beyond the notes, judged

- **S1:**
  - skill count 17 → 18: correct (`ls .claude/skills` = 18, `EXPECTED_SKILL_COUNT = 18`, CHANGELOG v49 "The 18 skills"; `executor-mode` arrived in v45);
  - the byte-identical sentence narrowed to the at-root modes: correct;
  - "fresh `--at-root` install": correct;
  - "nested `--update`": correct;
  - the facts taken from code all exist with the stated meaning: `DESIGN_LEGACY_DIR`, the register deck hint from `$AGENTIC_DESIGN_DECK_URL`, and the `_phase_blocker_kinds` kinds `slices`/`review`/`consolidation`. So do the other helpers: `_parallel_branch_merged` is used in `parallel_merge_finish`; `consolidation_cover` skips `done` phases; `next_phase_id` counts active and archived.
  - The forward reference to decisions holds: the v0043 P28 entry carries the rewrite and the clash map.
  - Missing from `## Decisions`: finding 4.
- **S2:**
  - (1) 17 → 18 in the inventory: correct.
  - (2) replacing "no such manifest": the right call, but the rewrite kept a false clause (finding 2).
  - (3) "nested has no worktrees": correct (the engine's refusal string exists).
  - (4) the new `## Nested personal install` H2: justified, since operations had no nested content and it is a new topic, not a split.
  - (5) "`sync-agents` after every `--update`" and the drafter in the install-behaviour subsection: correct.
  - (6) mockup route path recorded in "the slice's `result.md` and `phase.md`": matches the executor body. `design-cowork` says `phase.md` and the round's SIGNOFF, which the SIGNOFF bullet elsewhere in v0037 also carries. Not false; an optional F2 rider.
  - Other runbook facts checked:
    - the commit counts per tool: drafter 2/3, claude-design 2/4 (`design-cowork` lines 126-205);
    - `design-register`: refuses an id held by a live root and replaces a vanished one (`workflow.py` lines 4255-4272);
    - `design-migrate`'s with and without `design.json` move sets (docstring at line 4293);
    - `design-init` refuses a legacy root (line 4081);
    - `/update-workspace`'s collapsed `(nested)` variants;
    - the rotate-backlog skill's `allowed-tools` and `disable-model-invocation`.
  - Plain omission, not a finding: P28.S2's "`--nested` refused with `--into-existing`" was dropped (S2 observation 3), though the wrapper still refuses it (line 89). Offered as an F2 rider.
- **S3:**
  - The DesignSync-pin resolution is correct. `design-cowork`'s `allowed-tools` carries `Agent, DesignSync`. `create-phase` has no `DesignSync` (smoke line 111 asserts it). `design-drafter`'s `tools:` line has none (smoke line 812).
  - "By subtraction" is labelled and arithmetically right.
  - The P30 asserts sit inside Test 5 (Test 5 runs lines 765-1122).
  - Tests 0-16 exist (smoke lines 70-1670).
  - The Regression Checklist is byte-identical to v0012.
- **S4:**
  - Additions: the P27.F3 cookie sentence is correct (`# -*- coding: utf-8 -*-` at artifact line 109). The Superseded bullet naming the v34 (2026-08-29, P17) and v42 (2026-09-13) entries' Claude Design mechanics is correct, and the titles and dates match.
  - Contradiction resolutions, all correct:
    1. the rewrite covers the seed `executors.toml` and `docs/README.md` (`installer/main.py` lines 960-961);
    2. the narrower `workflow/` refusal, which is the truth architecture and operations missed (finding 1);
    3. F1/F2 stated once;
    4. the P29 refusal stands (P29 `acceptance.note`).
  - "Fifty decisions" = 50 `###` entries under `## Decision Log`.

## Cross-doc pointers

The pointers into decisions hold. architecture *Nested Install* says the rewrite and clash map are "pinned in `decisions.md`", and v0043's P28 entry has both in full. Every cite in decisions names a section that exists: architecture v0010's `## Design Record and Design Subagent`, `## Nested Install` and `## Docs Phase Marker and the Rotate Proposal`; operations v0037's `## Visual-design runbook` and `## Nested personal install`; qa v0013's `## Known Fragile Areas`. Operations' internal pointers (*Starting one*, *Nested personal install*, *Executor tiers*) all resolve. The inconsistencies are findings 1 and 3 above.

## Notebook cross-check

- `## Decisions` carries the DECOMP cut and the S2, S3 and S4 shape lines. S1's is missing (finding 4).
- `## Operator Questions` is empty, and no `result.md` holds an unrouted operator question. S1's "revert if the operator prefers" is an offer, which the review answers by judging the edit correct. S4 records the P29 question as already routed.
- The three `(for P31.REVIEW)` notes in `## Notes for later slices` are consumed by this review. They can go when the fix slices are planned.
- P31's `phase.json` `status` still reads `planned`. That is open deferred job D22 (start-slice never moves a phase to `in_progress`), and P30 showed the same. It is not a P31 finding.

## Dead ends

- A scratch installer probe was denied by the permission system. It would have nested-installed into the scratchpad, then run `--into-existing --dry-run` and `--update` against the nested `workflow/`. Finding 1 rests instead on `resolve_layout()` (`installer/main.py` lines 98-129) and P29's own recorded resolution (`works/phases/active/P29/phase.md:55`, P29.S2 `result.md` item 2).
- A grep pattern containing `**` failed to parse once and was re-run with `-E`. Nothing changed.
