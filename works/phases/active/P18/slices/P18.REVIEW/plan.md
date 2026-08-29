# Plan — P18.REVIEW: phase review

## Goal

Review P18 as a whole: validate every slice together, judge the result against `intent.md` and the notebook's `## Decisions`, apply the review's own new cross-check, decide a verdict, and — on `pass` only — consolidate the phase's `## Doc impact` list into new doc versions. The gate is **waived** (`acceptance.required: false`, see `phase.json`) and the phase is not in parallel mode, so no gate stages fire and consolidation happens here.

Read: `intent.md` (the confirmed spec — four parts, five clarifications), `phase.md` (bounded: `## Slices`, `## Decisions`, `## Doc impact`, `## Notes for later slices`, `## Now`), every completed slice's `slice.json` + `result.md` (verdict block first — read head-first, whole where needed), and this repo's `CLAUDE.md`. This is the first review to run on a v35 notebook: the `phase.md` ↔ `result.md` cross-check you are about to apply is one of the things this phase shipped.

## 1. Validate all slices together

Re-run each slice's validation from its `result.md` verdict block (DECOMP, S1–S5): `python3 scripts/workflow.py validate`; `bash tests/retrofit_smoke.sh` (expect 137 PASS / 0 FAIL); `python3 installer/build.py --check`; `python3 scripts/workflow.py sync-agents --check`; `diff <(tail -n +9 .claude/agents/slice-executor-mid.md) <(tail -n +9 .claude/agents/slice-executor-high.md)` empty; two consecutive `python3 scripts/workflow.py next` calls leave `works/backlog.md` and `works/deferred.md` unchanged in `git status --short`; `rebuild` twice leaves `works/phases/active/P18/phase.md` byte-identical; `grep -rn "## Doc Impact" .claude scripts CLAUDE.md` empty; `grep -n "WORKSPACE_VERSION = 35" installer/main.py`; `grep -c "^## v35" CHANGELOG.md` = 1. Also do a **fresh-install smoke**: run the rebuilt `bootstrap_agentic_workspace.sh` into a temp dir under the session scratchpad or `mktemp -d`, then there `git init`, `new-phase --phase P1 --name t --objective t`, `new-slice --phase P1 --slice P1.S1 --name t`, `finish-slice P1.S1 --outcome "x"`, and confirm `works/phases/active/P1/phase.md` renders the `## Slices` row with `x` and `validate` is clean. Complete every check before judging; never stop at the first failure.

## 2. Judge

- Does the shipped whole match `intent.md` parts 1–4 and honour the five clarifications (notebook + docs read-order scope; **no cache setting changed**; executor rewrites; warn-never-error; no third journal file)?
- **Cross-check (new rule):** every decision or deviation recorded in a `result.md` must appear in `phase.md`'s `## Decisions` (or be obviously slice-local); no `## Operator Questions` entry may be unrouted — the list is empty today; confirm no `result.md` raised one that never reached the list.
- **The open judgment call:** `CLAUDE.md` grew 1,036 bytes (34,419 vs. the 33,383 cap S4's plan set). Decide: accept (the new Read Order carries discipline the old pointers did not; the reclamation is D8's) or `changes_requested` with a fix slice. State the reasoning either way.
- Consistency: no file under `.claude/`, `CLAUDE.md`, or the READMEs still states the superseded protocol (`Findings & Notes`, `Open Questions` as a seed section, per-slice `works/backlog.md` re-reads, `docs/current/*.md` up front) except as intentional history — S3/S4 itemised their residue; spot-check it.
- Budget calibration: record the final notebook size (`finish-slice` printed 78 lines / 13,910 bytes after S5) beside the S1–S4 series, and say whether the 16 KB half looks calibrated for this repo's prose style — an observation for the record, not a change.

## 3. On `pass` only — consolidate docs (step 5 of your contract)

One version per affected doc, capturing the whole phase from the `## Doc impact` list:

- `operations.md` — a new `## The phase notebook and just-in-time reads (since v35)` section (place it near "The phase review" / "Persisting plans"): the template and section set, the generated `## Slices` block and its marker rule, `finish-slice --outcome`, `PHASE_MD_BUDGET` and the two warn-only checks, the dashboards' dropped timestamp, the executor and orchestrator read orders, the notebook edit protocol, the review cross-check, the v35 release and the migration notes for pre-v35 notebooks (preserved untouched; hand-migrate by adding the markers; the warning skips `done` phases). Also fold the old four-step Read Order reference wherever the doc restates it.
- `decisions.md` — one ADR in the `## Decision Log`: *phase notebook is bounded rewritten state, not an append-only log* — context (the ~40·N² re-read cost, P15's 819 lines with 82 % findings), the audience split with `result.md`, restorability (git + `result.md` by path), warn-never-error, executor-owned rewrite with the review cross-check as the safety net, and **no prompt-cache setting changed and why** (`intent.md` clarification 2). Mark nothing superseded unless an existing ADR actually is.
- `qa.md` — only if warranted: a one-line addition to `## Regression Checklist` is **not** appropriate (that list is the product smoke list and this repo has no product); instead, if `## Test Commands` or `## Verification doctrine` should mention Tests 9–10 and the 137-PASS baseline, add that; otherwise skip `qa.md` and say so.

For each: `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source P18.REVIEW`, edit only the returned `edit_path`, then `python3 scripts/workflow.py rebuild-docs` and `validate`. Never patch `docs/current/` or an old version.

## 4. Return

Write `result.md` (verdict block first): the validation table, the judgment, the doc versions, the calibration line. Edit `phase.md`: rewrite `## Now` as the phase's closing state (one paragraph), prune the `for REVIEW` notes you consumed. Verdict fields: `review_verdict`, `doc_versions`, `walkthrough: none` (waived gate), `explain: not written — run /explain for this phase`. On `changes_requested` or `blocked`: stop before step 3 and return numbered findings with proposed fix slices.
