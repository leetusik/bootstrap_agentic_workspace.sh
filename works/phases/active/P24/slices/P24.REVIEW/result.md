# Result — P24.REVIEW (review)

## Verdict (re-review after P24.F1 / P24.F2)

- **status:** done
- **review_verdict:** `pass`. The first pass's one finding is resolved, and this pass found nothing new.
  - Finding 1 is fixed in architecture v0009 and operations v0036, and both now agree with the v44 engine.
  - The two fixes changed only the corrected passages and the frontmatter.
  - Every whole-phase cheap check passes again.
- **summary:** Re-reviewed P24 after F1 (architecture v0009) and F2 (operations v0036). Both docs now match the engine: `parallel-start` stamps the in-block `execution.consolidation`, `set_phase_consolidation()` mirrors later writes, and `phase_consolidation()` reads the top-level key first and then the in-block field. A passing review stamps the debt only when `## Doc impact` has real notes. The version diffs show no other change. Validation is clean apart from the pre-existing `oversized_doc_sections=7`, `docs_debt=none`, nothing is STALE, P21–P23 stay paid, P24 owes nothing, and no machinery changed.
- **files_changed:**
  - `works/phases/active/P24/slices/P24.REVIEW/result.md` (this file; the first pass is kept below).
  - `works/phases/active/P24/phase.md`: one `## Decisions` bullet recording the fix-slice cut (see *Notebook*), and `## Now` rewritten as the closing state.
  - `docs/index.json`: `rebuild-docs` changed only `last_rebuilt_at`.
  - No doc, README or source edits.
- **validation:** all passed. The commands and their output are under *Whole-phase cheap checks* below.
  - `validate` exits 0 with only `oversized_doc_sections=7`.
  - `docs-debt` prints `docs_debt=none`, and `docs` shows no STALE flag.
  - After `rebuild-docs`, `git status --short docs/` shows only `docs/index.json`, which differs by `last_rebuilt_at`.
  - `cmp` of each doc's latest version against `docs/current`: all four are equal.
  - `diff` v0008→v0009 and v0035→v0036: only the corrected passages and the frontmatter changed.
  - No section newly crossed 10,240 B.
  - `installer/build.py --check`: OK. The machinery `git diff --stat d80e9a0..HEAD` is empty.
  - P21, P22 and P23 carry `consolidation: "done"`, and `phase_doc_impact_notes(P24)` is `[]`.
- **deviations:** none from the re-review plan.
  - The one addition is a notebook curation: a `## Decisions` bullet for the fix-slice cut (F1/F2 as `docs / low`, `--source P24.REVIEW`). Without it, `phase.md`'s *Version source* decision ("every doc slice runs `--source "P21.REVIEW, P22.REVIEW, P23.REVIEW"`") would disagree with the two fix versions. This is recorded here, not made silently.
- **doc_versions:** none — deferred to a docs phase.
  - P24 *is* the docs phase. S1–S4 cut its four versions, and F1/F2 cut v0009 and v0036 under the docs-slice carve-out.
  - The review wrote no gate section, because the phase changed neither `## Regression Checklist` nor `## Operator Runtime`.
  - P24's `## Doc impact` is still the "(none …)" line, so the pass stamps no debt.
- **walkthrough:** n/a (gate waived)
- **explain:** not written — run /explain for this phase
- **deferred-job candidates:** none new. D23–D26 were already filed from the first pass. The three observations below are wording and size notes that do not need a job of their own.
- **relay (unchanged from the first pass):** D17's and D21's "next docs phase" triggers fire on this phase. Both stay deferred because both touch machinery (Decision 10).

## Re-review detail

### Finding 1 is resolved: each engine fact against the corrected text

The engine was re-read at `scripts/workflow.py` for this pass, and an in-memory probe (throwaway, no file written) confirmed the behaviour.

| Engine fact (v44) | Where in the engine | architecture v0009 | operations v0036 |
|---|---|---|---|
| `parallel-start` stamps `execution.consolidation: "pending"`, with no top-level key | `parallel_start` `:1900` | JSON example `:115–120` carries `"consolidation": "pending"` again. The paragraph `:152–153` says "`parallel-start` also stamps `"pending"` inside the parallel `execution` block at the stamp, before any review". | *The debt* `:784–785`, and the archiving bullet `:1043–1044` |
| `set_phase_consolidation()` writes the top-level key and mirrors it into a parallel block | `:705–711`. Callers: review pass `:1570`, `parallel-consolidated` `:2164`, `docs-consolidated` `:2250` | `:153–155` | *The debt* `:786–787`, and the archiving bullet `:1044–1045` ("every write mirrors it there too") |
| `phase_consolidation()` reads the top-level key first, then falls back to the in-block field | `:677–702` | `:156–158`: "covers both a parallel phase stamped but not yet reviewed and v24-v37 files — nothing is migrated" | `:787–788`, and `:1045–1047` |
| A passing review stamps only when `## Doc impact` has real notes | `review_phase` `:1565–1570`, gated on `phase_doc_impact_notes(pdir)` | `:150–152`: "when the phase's `## Doc impact` list has real notes (a `- (none ...)` placeholder stamps nothing)" | `:782–783`: "when the phase's `## Doc impact` list has real notes" |

**What the probe showed:**
- A dict shaped exactly as `parallel_start` writes it has top-level `None`, and the reader returns `pending`.
- A review-stamp `set_phase_consolidation(d, "pending")` gives `pending` / `pending`.
- A `parallel-consolidated` `set(..., "done")` gives `done` / `done`, and the reader returns `done`.
- A default-stream dict with no key reads `None`. After a set it carries only the top-level key.

Every sentence in both corrected passages matches this.

**Every grep hit agrees:**
- `grep -n "consolidat\|fallback" docs/current/architecture.md`: 18 hits, each read in context (2 of them in the frontmatter).
  - The former "only for pre-v38 `phase.json` files … which is why the JSON example above no longer shows it" clause is gone.
  - The remaining hits agree with the table: the `## Status` `:25–26`, the `mode` bullet `:131`, *Doc versioning stays serial* `:218–220`, and *Parallel mode composes* `:297`. The `works/templates/` hit `:40` is about the notebook template's fallback and is unrelated.
- `grep -n "fallback\|execution.consolidation\|review stamps\|mirror" docs/current/operations.md`: the two facts-bearing hits (`:782–788` and `:1040–1048`) are corrected. The other hits concern unrelated fallbacks and mirrors: the design instrument, the offline API, and the `.agents/` skill mirror.
- `grep -n consolidat docs/current/operations.md` gives 42 hits. None still calls the in-block field pre-v38-only.
- The same grep over `decisions.md`, `qa.md`, `README.md` and `README.en.md` turns up no claim about the in-block field. That confirms the first pass's scoping: the error was only ever in architecture and operations.

### The fixes did not regress anything

- **`diff` v0008 → v0009** (architecture) has three hunks:
  - the frontmatter (version, created_at, commit `34cc39d`, source `P24.REVIEW`, summary, previous);
  - the JSON example (`"worktree": "…",` plus the new `"consolidation": "pending"` line);
  - the one paragraph, 9 lines → 14.
  
  Nothing else changed.
- **`diff` v0035 → v0036** (operations) also has three hunks:
  - the frontmatter (commit `859917b`, source `P24.REVIEW`);
  - *The debt*, 4 lines → 9;
  - the archiving bullet, 4 lines → 6.
  
  Nothing else changed: the *Seven commands* table, the default-stream wording and `## Status` are untouched.
- **Section sizes.** `h2_sections()` was run on each version pair; the H2 sets are identical in both.

  | Section | Before | After | Over 10,240 B? |
  |---|---|---|---|
  | architecture *Execution Streams* | 9,688 B | 10,182 B | no, 58 B under |
  | operations *Durable-doc consolidation* | 3,945 B | 4,363 B | no |
  | operations *Phase worktrees* | 17,137 B | 17,355 B | already over |

  `oversized_doc_sections()` lists the same 7 sections as at the first pass. None is new.
- **Current equals latest.** After `rebuild-docs`, `git status --short docs/` shows only ` M docs/index.json`, and `git diff` shows only `last_rebuilt_at`. `cmp` of the latest version file against `docs/current/<doc>.md` is equal for architecture v0009, operations v0036, qa v0010 and decisions v0042.
- **`docs/index.json` over `628270d..HEAD`** is additive only: two new entries (each with its `commit` sha and `source: P24.REVIEW`) and two `latest` pointers.
- **Files outside `works/` changed since the first review's base `628270d`:** the two new version files, the two regenerated `docs/current` files and `docs/index.json`. No README changed, and nothing else.

### Whole-phase cheap checks, re-run

| # | Command | Outcome |
|---|---|---|
| 1 | `python3 scripts/workflow.py validate` | Exit 0, `Workflow validation passed.` The only warning is `oversized_doc_sections=7`. No `consolidation_owed=` and no `stale_docs=`. |
| 2 | `python3 scripts/workflow.py docs-debt` | `docs_debt=none (no active phase owes durable-doc consolidation)` |
| 3 | `python3 scripts/workflow.py docs` | No STALE flag. architecture v0009 `source=P24.REVIEW commit=34cc39dfb690`, operations v0036 `source=P24.REVIEW commit=859917b0148c`. qa v0010 and decisions v0042 are unchanged (`source=P21.REVIEW, P22.REVIEW, P23.REVIEW`). |
| 4 | `rebuild-docs`, `git status --short docs/`, and `cmp` ×4 | Clean apart from `last_rebuilt_at`. All four are equal. |
| 5 | `git diff --name-status d80e9a0..HEAD -- docs/versions` | 6 `A` lines: v0008, v0009, v0035, v0036, qa v0010 and decisions v0042. No older version was modified. |
| 6 | `python3 installer/build.py --check` | `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| 7 | `git diff --stat d80e9a0..HEAD -- scripts .claude installer works/templates CLAUDE.md bootstrap_agentic_workspace.sh tests`, and the same without a range (working tree) | Both empty. |
| 8 | `consolidation` in P21, P22 and P23's `phase.json` | `done`, `done`, `done`. No `execution` block on any of them. |
| 9 | `phase_doc_impact_notes(works/phases/active/P24)` | `[]`. The notebook still holds only the "(none …)" line, so the pass stamps no debt. |

### Boundary and checklist: unchanged

`phase-scope P24` gives `range=d80e9a0..da5f712`, 10 commits, and `product_files=2`: `M README.en.md` and `M README.md`. That is the same product list as at the first pass; F1 and F2 touched only `docs/` and `works/`. The qa `## Regression Checklist` still has 6 lines, and 0 of them are inside the boundary. The reasoning is the first pass's: no README or doc version feeds the installer, the gate refusal, Test 0, the `## Slices` rendering, the marker-less notebook or `--kind research`, and the machinery diff is empty. The outside count is 6, and the smoke suite was not run.

### Notebook

- `phase.md`'s `## Slices` table shows F1 and F2 `done`, with outcomes that match their `result.md`.
- `## Notes for later slices` is empty. F2 removed the consumed REVIEW → F1/F2 note, correctly.
- `## Doc impact` is still "(none …)". F1 and F2 each report `doc_impact: none` because they correct owed wording rather than add durable truth. That is right: no note is owed for a fix to a docs phase's own versions.
- `## Operator Questions` has none, so none is unrouted.
- **Curated this pass:**
  - **What was missing.** The fix-slice cut decided after the first pass was not in `## Decisions`. The cut made F1/F2 `docs / low`, one `edit_path` each, with `--source P24.REVIEW`, and needed no `docs-consolidated`. It is recorded in the first pass's proposal, in F1/F2's `plan.md` and in both `result.md` files.
  - **Why it matters.** Without it, the *Version source* decision reads as if every P24 version carries `P21.REVIEW, P22.REVIEW, P23.REVIEW`.
  - **What changed.** I added one `## Decisions` bullet tagged `(P24.REVIEW)`. It supersedes no line, so no existing line was edited.
- Every other decision still matches the slice logs.

### Observations (not findings; no job proposed)

1. **"Every write goes through `set_phase_consolidation()`"** (architecture `:153–154`, operations `:786`) and "every write mirrors it there too" (operations `:1044–1045`) are slightly loose.
   - `parallel_start`'s own stamp (`:1900`) is a direct write into the block that sets no top-level key. Only the later writes (review, `docs-consolidated`, `parallel-consolidated`) go through the setter.
   - Both docs say in the next sentence that the fallback read covers "a parallel phase stamped but not yet reviewed". That only makes sense if the stamp left the top-level key absent, so the text is self-consistent and does not mislead.
   - The first pass's proposed wording was "every *later* write". Adding "later" would make it exact, at the next version of either doc.
2. **operations `## Status` `:114` and the review's *On `pass`* bullet `:691`** still say the engine "stamps a top-level `consolidation: "pending"`" without the has-real-notes condition.
   - Both were left untouched from v0035 (the first pass accepted the default-stream wording and made the qualifier optional).
   - The runbook section (*The debt*) now states the condition, and both lines are summaries that point to it.
   - Polish only.
3. **architecture *Execution Streams* is at 10,182 B, 58 B under the 10,240 B advisory.** The next edit of that section will add it to `oversized_doc_sections`. That is relevant to whoever runs D25 (judge the oversized sections), and needs no job of its own.

Observations 1 and 2 could ride on D24 (its trigger includes the next docs phase, and it already carries an operations part), or on the next docs phase that versions architecture or operations. Whether to append them to D24's brief is the orchestrator's call.

## First pass (changes_requested)

_The first pass's record, kept verbatim with its headings demoted one level. Finding 1 below is resolved by P24.F1 and P24.F2 (see the re-review above), and its J1–J4 were filed as D23–D26._

### Verdict

- **status:** done
- **review_verdict:** `changes_requested`. One finding, in two docs. Everything else passes: validation, coverage of all 27 notes, merge-not-stack for budget, baseline and review-consolidates, both READMEs, scope, and the notebook.
  1. **Architecture v0008 and operations v0035 misstate where a parallel phase keeps its consolidation debt.** They describe the in-block `execution.consolidation` field as a pre-v38 relic that is read only as a fallback for old files. The v44 engine still writes that field on every new parallel phase and mirrors it on every write. This is P21's recorded decision ("`execution.consolidation` stays readable and is mirrored on write, so `parallel-*` is unchanged", `P21/phase.md:35`). Detail is under *Finding 1* below.
- **proposed fix slices** (both `--kind docs --risk low` → `slice-executor-mid`, one `edit_path` each, per Decision 1's one-slice-per-doc cut):
  - `P24.F1`: **architecture v0009.** In `## Execution Streams`, put `"consolidation": "pending"` back into the parallel JSON example (`docs/current/architecture.md:115–119`). Rewrite the paragraph at `:147–155` to say:
    - `parallel-start` stamps `execution.consolidation: "pending"` at the stamp.
    - Every later write goes to the top-level key and is mirrored into a parallel block (`set_phase_consolidation`).
    - `phase_consolidation()` reads the top-level key first, then the in-block field. That is how a parallel phase owes from its stamp, and how pre-v38 files still read.
    - A passing review stamps `pending` only when its `## Doc impact` list is non-empty.
  - `P24.F2`: **operations v0036.** Make the same correction in two places:
    - the parenthetical in *Durable-doc consolidation* → **The debt** (`docs/current/operations.md:782–784`, "a v24–v37 phase's copy … read only as a fallback");
    - the archiving-gate bullet in *Phase worktrees* (`:1035–1041`, "read only as a fallback for phases stamped before v38").
    - Optionally add "when its `## Doc impact` list is non-empty" to the first sentence of **The debt**.
  - Both must be `docs` kind: the docs-slice carve-out, which is what lets a slice run `doc-new-version`, covers `docs` slices only, not `fix` slices.
  - `docs-consolidated` is not needed again. P21–P23 stay paid, and P24 has no notes.
  - No README changes: neither README describes the in-block field.
  - Suggested `--source`: `P24.REVIEW`, the finding they pay. The orchestrator decides.
- **summary:** All slices were validated together. `validate` is clean apart from the pre-existing `oversized_doc_sections=7`. `docs-debt` prints none, no doc is STALE, `docs/current` equals the latest versions, and the phase added four `A` files under `docs/versions` and changed no machinery. Every one of the 27 notes was spot-checked in the doc itself, and both READMEs agree with operations v0035 and `CLAUDE.md`. One landing is wrong: S1 (architecture) and S2 (operations) describe the parallel `execution.consolidation` field as pre-v38-only, which contradicts the engine, the `parallel-phase` skill and P21's decision. That makes the verdict changes_requested, with two small `docs` fix slices.
- **files_changed:** `works/phases/active/P24/slices/P24.REVIEW/result.md` (this file), `works/phases/active/P24/phase.md` (`## Notes for later slices`, `## Now`). Also `docs/index.json`: running `rebuild-docs` for validation step 3 changed only its `last_rebuilt_at` timestamp. No doc, README or source edits.
- **validation:** all passed. The full list with output is under *Validation* below.
  - `validate`: exit 0.
  - `docs-debt`: `docs_debt=none`.
  - `docs`: no STALE flag; all four docs carry `source=P21.REVIEW, P22.REVIEW, P23.REVIEW` and a commit sha.
  - `rebuild-docs`: `docs/current/*.md` unchanged.
  - `cmp` of current against the latest version: all 4 equal.
  - `git diff --name-status d80e9a0..HEAD -- docs/versions`: 4 `A`.
  - `installer/build.py --check`: OK.
  - Machinery `git diff --stat`: empty.
  - P21, P22 and P23 carry `consolidation: "done"`.
  - Link and anchor check: 0 bad.
  - `phase_doc_impact_notes(P24)`: `[]`.
- **deviations:** none from the plan.
  - `rebuild-docs` necessarily re-stamps `docs/index.json` `last_rebuilt_at`. That is the only diff it left, and the `rebuild` at `finish-slice` rewrites it anyway.
  - The slices' `doc-new-version` commands were not re-run, since each one would cut a new version. Their products were checked in place instead.
- **doc_versions:** none — deferred to a docs phase. This phase *is* the docs phase: its four versions were cut by S1–S4, and the review writes no gate section because it changed neither `## Regression Checklist` nor `## Operator Runtime`. On `changes_requested` the pass-only step is skipped in any case.
- **walkthrough:** n/a (gate waived)
- **explain:** not written — run /explain for this phase
- **deferred-job candidates** (for the orchestrator to file; full text under *Deferred-job candidates*):
  - J1: fix the `doc-new-version` skill's `--source P1.S1` example (machinery; could fold into D21).
  - J2: README drift outside P21–P23: kind-first tier routing and `research`, the missing `design-cowork` row, read-order item 1 (also `operations.md:68`).
  - J3: split decisions.md's 247 KB `## Decision Log` and judge the other six oversized sections.
  - J4: correct `phase_consolidation()`'s docstring (the machinery root of Finding 1).

### Validation

Every completed slice's validation, re-run together where it can be re-run:

| # | Command | Outcome |
|---|---|---|
| 1 | `python3 scripts/workflow.py validate` | exit 0, `Workflow validation passed.`. The only warning is `oversized_doc_sections=7`. No `consolidation_owed=` and no `stale_docs=`. |
| 2 | `python3 scripts/workflow.py docs-debt` | `docs_debt=none (no active phase owes durable-doc consolidation)` |
| 2b | `python3 scripts/workflow.py docs` | No STALE flag anywhere. architecture v0008 `commit=86c404b1ef0c`, operations v0035 `commit=0bc827a5d50d`, qa v0010 `commit=ed6bd7dd2445`, decisions v0042 `commit=0cc7721f21dd`. All four have `source=P21.REVIEW, P22.REVIEW, P23.REVIEW`, and each sha is HEAD at cut time (the previous slice's commit). |
| 3 | `python3 scripts/workflow.py rebuild-docs`, then `git status --short docs/` | `docs/current/*.md` is clean. `docs/index.json` differs only in `last_rebuilt_at`. |
| 3b | `cmp <latest version> docs/current/<doc>.md` for all four | All equal. |
| 3c | `git diff --name-status d80e9a0..HEAD -- docs/versions` | Exactly 4 `A` lines, and no older version touched. `docs/index.json` over the range is additive only (4 new entries and 4 `latest` pointers). |
| 4 | `python3 installer/build.py --check` | `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| 4b | `git diff --stat d80e9a0..HEAD -- scripts .claude installer works/templates CLAUDE.md bootstrap_agentic_workspace.sh tests` | Empty. |
| 5 | `phase.json` for P21, P22 and P23 | `consolidation: "done"`. Over the range the only change in each file is `pending` → `done`. |
| S5 | `grep -n consolidat README.md README.en.md` | 13 hits (`README.md:206,209`; `README.en.md:46,263,264,356–362,393,458,467,520–521`), and every one agrees with v38. |
| S5 | Link and anchor check (scratchpad Python, GitHub slug rules) | 0 bad. `README.en.md#durable-docs-a-docs-phase-you-start`, `#phase-worktrees-on-request` and `#contributing` all resolve from both files. |
| extra | `phase_doc_impact_notes(P24)` via the engine | `[]`: the pass will stamp no new debt. P21 has 9 notes, P22 8 and P23 12, for 29 in all (27 doc-bearing plus 2 verified-stamps). |
| extra | H2 heading sets, `d80e9a0` against HEAD, for all four docs | No section split. The only new H2 is operations' planned `## Durable-doc consolidation …`. |
| extra | `grep -c '^### '` in decisions (whole doc, and inside `## Decision Log`) | 45 in both, matching "**Current in v44: forty-five decisions.**" (it was 42 at v43). |
| extra | In-memory engine probe (throwaway, no file written) | A dict shaped exactly as `parallel_start` writes it (`execution.consolidation: "pending"`, no top-level key) gives `phase_consolidation()` = `pending`. `set_phase_consolidation(d, "done")` writes both keys. |

**Regression checklist.** 0 of 6 lines are inside the boundary, and none was re-run. The boundary is `phase-scope P24`: range `d80e9a0..628270d`, 7 commits, `product_files=2` (`M README.en.md`, `M README.md`). The four doc versions are excluded as `docs/`, but they were reviewed as the phase's substance. The six lines cover:
- installer fresh install;
- acceptance-gate refusal;
- Test 0 invariants;
- `## Slices` rendering;
- marker-less notebook;
- `--kind research`.

None of those surfaces is fed by a README or a doc version:
- The installer references `README*` only as target-repo markers (`installer/main.py:49`) and embeds neither README.
- `tests/retrofit_smoke.sh` pins no text from this repo's `docs/` or READMEs.
- Nothing changed under the machinery paths (4b).

So the outside count is 6, with that diff as proof. The smoke suite was not run.

### Judgment against the objective

#### Coverage: all 27 notes landed, each spot-checked in the doc

The notes were read verbatim in `P21/phase.md`, `P22/phase.md` and `P23/phase.md` `## Doc impact`, then checked against the S1–S4 tables and **in the doc itself** by grep or offset read. All 27 are present. The ones most likely to be missed:

- **architecture (6/6):**
  - The top-level `consolidation` field is at `:147–155`, plus the `## Status` sentence at `:25–27`, `:212–214` and `:291`.
  - The `commit` field and frontmatter `commit:` line are in the `docs/index.json` bullet at `:34`.
  - The `CLAUDE.md` bullet at `:31` carries the no-`## Workflow Commands` / `--help` / closed `--kind` note, the never-stubs note (P23.S3), and the 12,259 B seven-section contract. `wc -c CLAUDE.md` is 12259 and its seven H2s match.
  - The `works/templates/` tag bullet is at `:40` (the template and `PHASE_MD_TEMPLATE_FALLBACK` exist, and the tag is at `works/templates/phase.md:29`).
  - *One landing is wrong in its detail: see Finding 1.*
- **operations (8/8):**
  - The new `## Durable-doc consolidation` section (`:775–826`) has Why, The debt, Surfacing, Staleness, Starting one, Running one (the docs-slice carve-out) and Section-size warning.
  - The `## Status` v38/v39/v44 paragraph is at `:111–126`.
  - The v44 release bullet is at `:1361–1368` (`WORKSPACE_VERSION = 44` is at `installer/main.py:38`, and `CHANGELOG.md:12` has `## v44 — 2026-09-28`).
  - `PHASE_MD_BUDGET` (`:610–619`) says v35's pair was replaced by `400 * 1024`. The `finish-slice` print `(budget 409600 bytes)` and the ` — OVER BUDGET` suffix both match `scripts/workflow.py:1477–1478`.
  - `grep -n consolidat` gives 39 hits, and each was read in context. Every former "review consolidates" passage (`:68`, `:684–701`, `:879`) now states the v38 rule. The one past-tense mention (`:777`, "Through v37 …") is framed as history.
- **qa (9/9):**
  - `## Status` states the core-only posture and `180 PASS / 0 FAIL` as of v44.
  - `## Testing Philosophy` has the "Core-only (since v39)" bullet.
  - `## Test Commands` says "Tests 0-12" (`== Test 0` … `== Test 12` exist in `tests/retrofit_smoke.sh`). It has the 180 baseline with its 152/158 history, the pin state (38 positives / 19 negatives / 3 Test 1 sidecar greps, the `parallel-phase` whitespace-normalized list, and the ≤ 12 KB stub comments), and the three advisory lines on the Workspace-state bullet.
  - No stale baseline is stated as current anywhere (`grep -n 'PASS\|baseline'`).
- **decisions (7/7):**
  - The v44 entry is at `:44`, then v43, v42, v42, v39 at `:318`, v38 at `:356`, then v37. That is newest-first, and the dates (09-28 / 09-17 / 09-13 / 09-02 / 09-01) match the phases' `completed_at`.
  - The v38 entry carries P21.REVIEW's S3–S5 decisions.
  - The v35 entry's `- Status:` is amended (`:644–646`), and its body is kept as history.
  - `## Superseded Decisions` opens with the v35-budget bullet and the v38 narrowing bullet, newest first.
  - The `## Status` count (45) equals the `### ` headings.

#### Finding 1: the parallel `execution.consolidation` field is described as pre-v38-only (architecture v0008, operations v0035)

**What the docs now say:**
- `architecture.md:147–155`: "**The `consolidation` debt is top-level, not part of this block (since v38).** … `phase_consolidation()` reads that top-level key first and falls back to the identically-named field inside a parallel `execution` block **only for pre-v38 `phase.json` files** that still carry it there — **which is why the JSON example above no longer shows it**."
  - S1 removed `"consolidation": "pending"` from the parallel JSON example (`:115–119`).
  - S1 also removed v0007's bullet "`consolidation` — `"pending"` from the stamp until the post-merge step records `"done"`", which was correct.
- `operations.md:782–784`: "a v24–v37 phase's copy inside its `execution` block is read only as a fallback, never migrated".
- `operations.md:1037–1040`: "the v24–v37 `execution.consolidation` copy is read only as a fallback for phases stamped before v38, never migrated".

**What is true at v44:**
- `parallel_start` still writes `data["execution"] = {"mode": "parallel", …, "consolidation": "pending"}` (`scripts/workflow.py:1900`).
- `set_phase_consolidation` mirrors every write into a parallel block (`:705–711`).
- `parallel-consolidated` says so itself: "expected 'pending' (set by parallel-start, or by its passing review)" (`:2163`).
- The `parallel-phase` skill says the same (`.claude/skills/parallel-phase/SKILL.md:116`).
- P21 decided exactly this (`P21/phase.md:35`: "`execution.consolidation` stays readable and is mirrored on write, so `parallel-*` is unchanged").

**Consequences the doc now gets wrong for a parallel phase:**
- It owes from its stamp, before any review, through the fallback read. The probe above confirms this.
- A top-level key that is absent does **not** mean nothing is owed.
- A branch review with an empty `## Doc impact` list still leaves the in-block `pending`, which only `parallel-consolidated` clears.

The default-stream statements are all correct. The error is confined to parallel mode, which is opt-in and rare, so the severity is low. It is still a durable-truth error introduced by this docs phase, and it contradicts a recorded decision. Two one-`edit_path` `docs` slices on the default stream fix it now, cheaper than any later moment.

**Root cause.** S1 and S2 each read `phase_consolidation()`, whose docstring (`:688–691`) says "v24-v37 stamped the identical debt inside the parallel `execution` block, so that field is the fallback". It never mentions that `parallel_start` still stamps it. S1's `result.md` *Detail* shows it saw the mirror-write and chose not to describe it. The docstring is machinery, so it becomes deferred job J4.

A related imprecision, which F1/F2 can fix in the same paragraphs: architecture `:149` and operations `:782` say "a passing review stamps `pending`" with no qualifier. The engine stamps only when the phase's `## Doc impact` list is non-empty (`scripts/workflow.py:1565–1570`), and decisions v38 states that condition correctly.

#### Merge, not stack

- **Budget:**
  - operations `:70` and `:610–619` state v39's 400 KB cap and frame v35's `(200 lines, 16 KB)` as history.
  - decisions keeps v35's body as history, with the Status line amended and a `## Superseded Decisions` bullet.
  - architecture and qa state no budget.
- **Baseline:** the only current count is 180 (qa `:17`, `:208`). The 140, 152 and 158 figures in decisions are per-entry history.
- **Review-consolidates:**
  - No doc states it as current.
  - The one line in each of operations `:68` / `:777` that mentions it is framed as "Until v38" / "Through v37".
  - In decisions, the pre-v29 rollup is explicitly "retained as historical context", and the 2026-06-29 and P11 entries are narrowed through v38's Status line and the new Superseded bullet.

#### READMEs (S5)

- `README.en.md` *Review gates* (`:44–48`), the tier paragraph (`:320–325`) and `### Durable docs: a docs phase you start` (`:351–364`) agree with operations v0035 *Durable-doc consolidation* and with CLAUDE.md's Hard Rules and Read Order on each of these points:
  - the review verifies and writes two gate sections;
  - an owing phase stays in `active/` and cannot be archived;
  - `consolidation_owed=` / `stale_docs=` / 10 KB are advisory, and `validate` exits 0;
  - `docs` shows the date/source/commit marker and the STALE flag;
  - the "consolidate the docs" route matches `create-phase` SKILL `:29`/`:70`, and it runs `docs-debt` → one slice per doc → `docs-consolidated <P>`;
  - it runs on the default stream only.
- The Korean `## 문서 통합: docs phase` (`README.md:201–211`) says the same thing at its own depth: notes, review checks without consolidating, debt blocks archiving, `consolidation_owed=`, STALE, "문서 통합해 줘" → `docs-debt` → one version per doc → `docs-consolidated <P>`, `main` only, and a link to the English subsection. It omits only the English section's detail on the two gate sections and the `validate` lines.
- S5's unplanned edit to the `archive-phase` / `rotate-backlog` rows is **correct against the engine**. `_phase_blockers` (`scripts/workflow.py:2795–2811`) blocks on `consolidation == "pending"`. `archive-phase` refuses, and `rotate-backlog` archives only phases with no blocker and leaves the rest active.
- The other README edits check out:
  - the `docs` / `docs-debt` / `docs-consolidated` rows;
  - `--source P1.REVIEW`;
  - the STALE read-order clause, which matches `CLAUDE.md:27`;
  - habits 2 and 4, Contributing step 4 and the house rule;
  - the `(~12 KB)` tree comment (`CLAUDE.md` is 12,259 B).

#### Scope

- No section was split: the H2 sets are unchanged apart from operations' one planned new section.
- P24's `## Doc impact` holds only the "(none …)" line, and the engine reads it as `[]`.
- No machinery changed (4b), and `build.py --check` passes.
- `docs/retrofit-guide.md` and `installer/README.md` contain no consolidation wording, so there was nothing out of scope to flag there.

#### Notebook

- `phase.md`'s ten `## Decisions` match DECOMP's result and every slice's `result.md`, and no result records a phase-level decision the notebook dropped.
- `## Operator Questions` has none (none were raised), so none is unrouted.
- The "Payment" decision was carried out: all three `phase.json` files read `done`.

#### Minor observations (not findings; no fix proposed)

- **decisions `## Status`, v35 sentence** ("under a warned 200-line / 16 KB budget … supersedes nothing"). It lacks the in-place "since partly superseded by v39" note that the same section gives v42 and v36. The v39 sentence above it does state the supersession, so this is only polish for a future decisions consolidation.
- **decisions v39 entry, "now in `CLAUDE.md`'s read order and Hard Rules".** This was true at v39 (`3418c17:CLAUDE.md:58`). Since v44 the STALE doctrine sits only in the contract's Read Order (`CLAUDE.md:27`) and in both executor bodies. As a dated decision record it reads as history.
- **qa `## Test Commands`.** "Test 0's current pins" lists "Test 1's 3 sidecar greps" as a bullet. That is faithful to P23.S4's note, which groups them the same way, but the heading is slightly loose.
- **qa `## Status`.** It states the core-only posture twice, in paragraph 1 and in "As of v39 …". Redundant, not contradictory.
- **S4's `result.md`** says `oversized_doc_sections` "rose from 5 (at S3's landing) to 7". DECOMP, S1, S2 and S3 all recorded 7. The error is in the log only and has no effect on any doc.
- **D22 is visible here.** `P24/phase.json` still reads `status: "planned"` with six slices done, which is the known D22 behaviour (P23 did the same). It needs no new job.
- **D17 and D21 triggers fire now** ("the next docs phase") and stay deferred because both touch machinery (Decision 10). Since a docs phase can never change machinery, the orchestrator might suggest to the operator, when relaying them, that the triggers be reworded to "the next phase that edits `workflow.py`". As written, they fire on every docs phase and are declined by every docs phase.

### Deferred-job candidates (the orchestrator files them; this review runs no `defer-job`)

1. **J1: Fix the `doc-new-version` skill's `--source P1.S1` example.**
   - Reason: `.claude/skills/doc-new-version/SKILL.md:10` still shows `--source P1.S1`. Since v38 a version's source is the owing phase's `<P>.REVIEW`, and S5 already fixed the README's copy of this example. The file is embedded machinery and needs an installer rebuild, so it is out of reach for a docs phase. It is the same kind of stale one-liner as D21, and **folding it into D21 is the natural merge**.
   - Trigger: the next phase that edits the skill set or `workflow.py`'s help text (D21's trigger).
2. **J2: README drift outside P21–P23: kind-first tier routing, the `design-cowork` row, read-order item 1.**
   - Reason, three items, all predating P21 and all outside P24's confirmed scope:
     - (a) Both READMEs describe executor routing as risk-only and never name `research` (`README.en.md:320–325`, `README.md:177–183`), while the contract routes decomposition, `research` and review **by kind** first. The same risk-only phrase is in `operations.md:68` ("risk-routed by the orchestrator").
     - (b) The English skill table has 15 rows, plus `explain` in a blockquote, under a "17 Agent Skills" heading, and has no `design-cowork` row.
     - (c) `README.en.md` read-order item 1 ("`works/state.json` and `next` — the pointer") predates v43's stream scoping. The contract now says "`next`: this checkout's pointer (`parallel-status` shows every stream)", and `README.md`'s *왜 필요한가요?* first bullet carries the same pre-v43 framing.
   - Trigger: the next phase that edits either README, or the next docs phase (the `operations.md:68` part needs a docs-phase version).
3. **J3: Split decisions.md's 247 KB `## Decision Log`, and judge the other six oversized sections.** This one **does deserve a job**.
   - Reason: `validate` prints `oversized_doc_sections=7` on every run and tells "the next consolidation (a docs phase)" to split. P24 declined by Decision 6 because its confirmed scope was the notes, so without a job the advisory has no owner and every docs phase will decline it again.
   - Sizes: decisions `## Decision Log` is 246,694 B, about 12× the next largest. The other six are operations *Visual-design runbook* 21 KB, decisions `## Superseded Decisions` 19 KB, operations *Phase worktrees* 17 KB, decisions `## Status` 16.7 KB, operations `## Status` 15.7 KB and qa *Verification doctrine* 12.9 KB.
   - Not urgent: the Decision Log's `### ` entries can still be read by offset, one entry at a time.
   - Trigger: the next docs phase whose operator-confirmed scope includes restructuring, or the first time a slice has to read more than one Decision Log entry to do its job.
4. **J4: Correct `phase_consolidation()`'s docstring: `parallel-start` still stamps `execution.consolidation`.**
   - Reason: the docstring (`scripts/workflow.py:688–691`) presents the in-block field as the v24–v37 stamp kept only as a fallback. `phase_execution`'s docstring (`:652`) still lists the field. `parallel_start` (`:1900`) writes it on every new parallel phase, and `set_phase_consolidation` mirrors it. The misleading docstring led S1 and S2 into Finding 1. This is machinery (installer rebuild).
   - Trigger: the next edit of `phase_consolidation` / `parallel_start` / `set_phase_consolidation`, or together with D22.

Relay to the operator, not a new job: D17's and D21's "next docs phase" triggers fire now and both stay deferred (machinery). See the trigger-wording note above.
