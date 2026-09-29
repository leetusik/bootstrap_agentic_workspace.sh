# Result — P26.S4: sweep the contract and orchestrator skills, ship v47

- status: done
- tier: mid
- summary: Swept `CLAUDE.md` (L15 and L52, 12,286 B), `do-whole-phase`, `do-next-slice`, `create-phase`, both executor bodies, the installer banner and both READMEs to the file loop and `design-drafter`, and moved the smoke pins with them. Released workspace v47 (`WORKSPACE_VERSION = 47`, a `## v47` CHANGELOG entry with the four migration notes). Installer rebuilt; smoke 195 PASS; `build.py --check` and `validate` pass.
- validation:
  - `python3 installer/build.py`: passed (593,489 B).
  - `bash tests/retrofit_smoke.sh` (own foreground call, 600 s timeout): `ALL RETROFIT SMOKE TESTS PASSED`, 195 PASS / 0 FAIL (baseline unchanged, since Test 0 is one assertion block and no `ok`/`bad` line was added or removed).
  - `python3 installer/build.py --check`: OK, in sync (run after the last embedded edit).
  - `python3 scripts/workflow.py validate`: passed (only the pre-existing oversized-doc-section warning, which is the docs phase's job).
  - Residual sweep (below): only allowed hits.
- deviations:
  - **Three small edits beyond the plan's list**, all prose with no behaviour change: `docs/retrofit-guide.md` (its design paragraph described the `DesignSync` loop and would have contradicted v47); one comment on `SLICE_KINDS` in `scripts/workflow.py` (it said `co-work` "means orchestrator-inline with DesignSync"; embedded, so covered by the planned rebuild); `README.en.md`'s `.claude/` list and file tree (they listed the executors and omitted the drafter).
  - **The per-round steps in `do-whole-phase` are four**, as in S3's note, with the mockup as the third case of step 4. `do-next-slice` carries the same content in its one long step-3 paragraph, as before.
  - **`review-phase` unchanged.** L41 (the orphaned mockup route check) and the gate stages 2 to 4 say nothing about the retired loop, so per the plan nothing was edited.
- doc_impact: appended to `phase.md` `## Doc impact`: operations (the routing rules, the per-round steps, v47 and its migration notes), decisions (the hard-rule reword as operator-confirmed), and qa (the Test 0 pin moves; baseline stays 195). Architecture is covered by S1/S2.

## What changed

- **`CLAUDE.md`** (12,286 B, under the 12 KiB cap; it was 12,287 B):
  - L15: "a `co-work` design slice runs inline, dispatching its drafting to `design-drafter` and its mockup build (only on request) to `slice-executor-high`; the round's lifecycle and the operator's words stay inline".
  - L52: opens "The design subagent drafts, the operator decides:". It kept "Approval must be literal", "literal operator signoff closes an immutable round", "writes no ***product*** implementation code", RESPECT THE DESIGN and data-not-instructions. It dropped "runs **inline**" (now in L15) and three "the" in its last sentence to stay under the cap.
  - L13 and L60 re-checked: no wording to change (`design-cowork` still fires by itself; the kind set is unchanged).
- **`do-whole-phase` and `do-next-slice`:**
  - Intro exception rewritten: the lifecycle and the operator's words stay inline, the drafting goes to `design-drafter`, and "the mockup build is the one span dispatched to a slice executor".
  - The `pending` paragraph now says "twice when a mockup was requested, and once more for each superseding round".
  - The co-work steps are S3's: `design-open` (plus `design-init`) and `handoff.md` with `new visual direction: yes|no`; the drafter dispatched in the background with only the round folder and the slice id (`needs_operator` and `blocked` handling); the inline read-back with `design-check` run by the orchestrator, with one re-dispatch for a failure the drafter can fix, otherwise `pending` and nothing signed; then the operator's words. Counts: literal approval is two commits and one stop (two `/do-next-slice` invocations); feedback adds one commit and one stop (and an invocation) per superseding round; a mockup makes it three commits and two stops (three invocations, was four commits).
  - The per-`pending` report content: card paths and how to open them (the files directly until `design-register`), the drafter's departures and `open_questions` as decisions, `frontend_design`, and what their words will do; PENDING #2 is unchanged.
  - `do-whole-phase` only: the delegation bullet and the idle-window sentence (the drafter span is a dispatched window, but short and followed by a stop, so rarely worth preparing for).
- **`create-phase` L27:** "the round closes on the operator's literal approval when they return to the drafted cards"; "built from the round's record". The style bullets and step 4.2 had no other Claude Design wording.
- **Executor bodies** (`slice-executor-mid.md` and `-high.md`, still identical apart from frontmatter):
  - The mockup span reads `build-prompt.md` and the round's record on disk (cards, `tokens.css`, `result.md`) and says "the drafting goes to `design-drafter`". The third `needs_operator` is unchanged.
  - The "Never" bullet now says the design subagent drafts a round's cards, the operator decides, and the lifecycle, read-back and words stay on the orchestrator. Handing an executor any of those returns `needs_operator`, and the mockup span stays legitimate.
- **Installer:** banner "Visual design" line (the file loop, the drafter, `design-register`); `WORKSPACE_VERSION = 47`.
- **`CHANGELOG.md`:** `## v47 — 2026-09-29`, seven bullets (the contract, the five commands, the drafter, the loop rewrite, the optional bundle import, the hard-rule reword, where it landed) and a Migration notes bullet covering (1) in-flight Claude Design rounds, (2) `_ds_manifest.json` / a repo's own `design/` tree / `rounds/<NN>/output/` records moving to schema 1 with `design-init` and a `@dsCard` line 1, (3) `sync-agents` after `--update`, (4) `design-register` once per repo with `$AGENTIC_DESIGN_REGISTRY` and its default path.
- **READMEs:** the visual-design paragraph in `README.md` (Korean) and `README.en.md` rewritten in each file's voice: the drafter drafts and you decide, the design lives in `docs/reference/design/`, no account or push, `design-register` lists the repo for a dashboard, and Claude Design remains an optional import. `README.en.md` also lists the drafter under `.claude/`.
- **Smoke (`tests/retrofit_smoke.sh`):**
  - do-* required list: dropped "never dispatched", "DesignSync", "mockup build is the one dispatched span"; added `` `design-drafter` ``, "mockup build is the one span dispatched to a slice executor", "lifecycle and the operator's words stay inline", "new visual direction", and the two `design-close` forms.
  - do-* negatives: `DesignSync`, `Claude Design`, `_ds_manifest`, `never dispatched`, `four commits, two`, `one dispatched span`, `Push the branch`.
  - create-phase: the new default phrase required; `Claude Design` and `DesignSync` gone.
  - Executor bodies: the "never dispatched, because you have no `DesignSync`" pin replaced by the drafter/decides phrase, "the one span of that slice dispatched to a slice executor" and "its record on disk"; `DesignSync` and "landed record" gone.
  - `CLAUDE.md`: "Claude Design", "DesignSync", "never dispatched", "*DesignSync* work is never dispatched" and "mockup build is its one dispatched span" removed from the list and added as negatives; three new phrases required.
  - The installer banner is pinned (names the drafter, the root and `design-register`; no Claude Design or DesignSync).
  - Test 1's sidecar check now greps `design subagent drafts, the operator decides`.

## Residual sweep

`grep -rn "DesignSync\|Claude Design" CLAUDE.md .claude installer/main.py README.md README.en.md docs/retrofit-guide.md scripts/workflow.py` leaves 14 hits, all allowed:

- optional bundle import: `design-cowork` L210, 211, 270, 272, 312, 832, 833; `design-drafter.md` L20; `README.md` L124; `README.en.md` L231 (10 hits);
- deliberate "no DesignSync" statements: `design-cowork` L283, 637, 831; `design-drafter.md` L40 (4 hits).

`CLAUDE.md`, `do-whole-phase`, `do-next-slice`, `create-phase`, `review-phase`, both executor bodies, the banner, the retrofit guide and `workflow.py` have none.

## Notes for the review

- The routed-question and gate checks are in `phase.md` `## Notes for later slices` (the `for P26.REVIEW` note). No deferred-job candidate was filed; one observation is listed there (no check that a design phase ends with no round left `open`).
- No tests were written beyond the pin moves: Test 0 is unchanged in shape, and no behaviour test was added, as planned.
