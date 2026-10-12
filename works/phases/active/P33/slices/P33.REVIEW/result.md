# Result: P33.REVIEW (phase review, gated, parallel mode)

## Verdict

- status: done
- tier: high
- review_verdict: **pass**
- summary: P33 ships what its intent asked for. One `/rotate-backlog` now checks the doc debt first and the engine prints a `rotate=` decision as its first line. The skill creates the docs phase on the invocation, runs it in `auto`, and archives last. v54 is built and in sync. I re-ran every engine branch myself in a scratch copy outside git, and diffed `--archive-only` against the pre-P33 engine: identical. Smoke is 247 PASS / 0 FAIL. Both operator questions and three wording nits go to the walkthrough as decisions.
- files_changed: works/phases/active/P33/phase.md (`## Doc impact` +3 lines: one list cross-check and the two gate-section notes; consumed `for P33.REVIEW` notes replaced by one merge note; `## Now` rewritten), works/phases/active/P33/slices/P33.REVIEW/result.md (new)
- validation:
  - `bash tests/retrofit_smoke.sh` (the only command in its call, foreground): **ALL RETROFIT SMOKE TESTS PASSED, 247 PASS / 0 FAIL** (tallied from the log)
  - `python3 installer/build.py --check`: pass (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`)
  - `python3 scripts/workflow.py validate`: pass, exit 0. Warnings were the expected ones only: `consolidation_owed=P33`, `stale_docs=architecture, decisions, operations, qa`, `oversized_doc_sections=8`
  - `python3 scripts/workflow.py --help` and `rotate-backlog --help`: both read correctly (the five branches, `refused` non-zero, `--archive-only` "unchanged since v51")
  - `python3 scripts/workflow.py phase-scope P33`: range `0d4f751..96f6a54`, 6 commits, 13 product files
  - live branch walk in a `cp -R` copy outside git (instrument: live CLI runs, as `## Operator Runtime` prescribes; no browser applies): every branch passed (details below)
- deviations: none from the plan. I ran no writing engine command in this worktree; `git status` is the same as at dispatch apart from my two files.
- doc_versions: none — deferred to post-merge consolidation (parallel mode)
- walkthrough: see *Walkthrough* below (also returned in full)
- deferred jobs to file: one, conditional on decision D3 (see *Deferred-job candidates*)
- explain: not written — run /explain for this phase

## Validation, all slices together

| Slice | Its validation | Re-run here |
|---|---|---|
| P33.DECOMP | `validate` | pass |
| P33.S1 | smoke 247/0, `build.py --check`, `validate`, scratch walk of every branch | smoke 247/0; `--check` OK; `validate` pass; every branch re-walked independently (below) |
| P33.S2 | `build.py` + `--check`, smoke, `validate`, frontmatter by eye, skill read against *Engine (landed in P33.S1)* | `--check` OK; smoke 247/0 (Test 0 skill metadata and Test 6 dual-apply of `rotate-backlog/SKILL.md` PASS); `validate` pass; frontmatter re-read (description and argument-hint double-quoted, no inner `"`); skill re-read line by line against the engine output I produced |

## Judgment against the intent

| Intent point | Verdict | Evidence |
|---|---|---|
| 1. Debt first, nothing archived while it stands | met | In copy C, a clean done P40 and an owing P41 gave `rotate=create`, and P40 stayed in `active/`. The P35/P36/P37 run archived nothing until all debt was paid. |
| 2. Create on the invocation, proposal still printed | met | `create` prints the full proposal and a runnable `create:` line. The skill runs it as printed with no pause. `create-phase` l.11 and CLAUDE.md l.13/l.19 name the exception for this route only. |
| 3. Run in `auto`, `gate` opt-in, normal stops | met | Skill `resume` step 2. CLAUDE.md l.15 carve-out ("an explicit `auto`, which a `/rotate-backlog` run is for its docs phase") agrees with `do-whole-phase`'s v40 carve-out. |
| 4. Archive every done phase last, docs phase included | met | `rotate=archive` after the docs phase passed archived P35, P36 and P37 together and left P32/P33/P34. |
| 5. Archive right away when nothing owes; `archive-only` kept | met | Unchanged state gives `rotate=archive`. `--archive-only` output equals the pre-P33 engine's on an identical tree (timestamps normalised), with the same archived set. |
| Queue jump when other slices are at a boundary | met | `--order 0` ahead of P32 (1). Running the printed line made `next` give `current_phase=P36`. Negative and fractional orders round-trip (`--order -3.7` ran as printed; `validate` passes). |
| Stop and report when mid-flight | met | P32.DECOMP `in_progress`, `pending`, `in_review`, `blocked` and `changes_requested` each gave `rotate=stop_midflight midflight=P32.DECOMP:<status>`. `ready` / `todo` did not stop. P34 `pending` / `blocked` / `in_review` stopped, P34 `in_progress` did not. Parallel P33.REVIEW `in_progress` was never counted. |
| Resumable | met | `resume` before and after the docs phase's own DECOMP went `in_progress` and the phase went `pending`. A paid but unreviewed docs phase resumed. `docs_debt_waiting=` names new uncovered debt. |
| v54 + CHANGELOG Migration notes | met | `WORKSPACE_VERSION = 54`. `## v54 — 2026-10-12` has a Migration notes line. Smoke confirms that the installer, the top heading and the fresh marker agree. |

### Engine read (`git diff 0d4f751..96f6a54 -- scripts/workflow.py`)

- **Precedence:** refused → archive → stop_midflight → resume → create, as `## Decisions` records. `--archive-only` returns before the stream check, so it is never refused; that is unchanged and documented.
- **Mid-flight set:** `ROTATE_BOUNDARY_SLICE_STATUSES = (todo, ready, done)` and `ROTATE_MIDFLIGHT_PHASE_STATUSES = (pending, blocked, in_review)`. The check covers default-stream phases only and skips the live docs phases with their slices.
- **Live-docs-phase key:** a not-`done` default-stream phase whose `consolidates` is non-empty. This is keyed directly, so a paid but unreviewed docs phase still resumes (verified).
- **Order arithmetic:**
  - The jump is `_clean_order(round(min(open default-stream orders) - 1, 6))`.
  - A tie counts as not first: the `0 → -1` case was verified.
  - Fractions and negatives work: `-1 → -3.7` against P32 at `-2.7`.
  - A missing order counts as 999999, which matches `phase_dirs`.
  - `resolve_current` takes the first non-done phase by order, so the jump really does select the docs phase.
- **`resume` write path:** one `phase.json` write, a `phase_reordered` event (old/new/reason) and `rebuild_index_and_state()`. A second run writes nothing (verified).
- **`refused`:** a unit-style call patched `git_current_branch` to P33's branch. It printed `rotate=refused stream=…` and raised `SystemExit("<message>")` (exit 1, message on stderr). The sha of `works/` and `docs/` was unchanged.
- **Untouched:** `archive-all`, `archive-phase`, `_phase_blockers`, `_phase_blocker_kinds`, `_debt_only`, `_archive_one` and the manifest are not in the diff. The sweep body moved into `_rotate_sweep` verbatim, with only the `propose` calls removed. The one change outside rotate is the `review-phase` pass message line.

### Texts

- **`rotate-backlog` skill:**
  - Every line it names exists in exactly that form in the engine output I produced (`rotate=refused stream=`, `docs_phase_elsewhere=`, `midflight=`, `stopped_before=`, `docs_phase_order=`, `docs_phase_covered=`, `docs_debt_waiting=`, the proposal block, `docs_phase=none`).
  - Every engine branch has a skill branch.
  - The "one docs phase per invocation" stop is real. With P37's debt appearing while P36 ran, the post-`done` re-run printed `rotate=create`, and P35/P36 waited in `active/` until the next step. That is the documented archive-last rule.
  - `allowed-tools` covers what the default path runs (engine, Read/Edit/Write, Bash for commits, Agent for executors). The `gate` word routes into `do-whole-phase`'s plan-mode loop, which uses `EnterPlanMode` / `ExitPlanMode`; those are not listed (nit N1). `allowed-tools` pre-approves rather than restricts, so the cost is at most a permission prompt.
- **`create-phase` l.11 and the docs-phase route, `archive-phase`, `do-whole-phase` l.53, `do-next-slice` l.45, `review-phase` l.85, `CLAUDE.md` l.13/15/19/53, `README.en.md` row, CHANGELOG v54:** accurate, minimal, and consistent with each other and with the engine. The Korean `README.md` has no such row (confirmed by grep). Two wording nits:
  - **N2:** `CLAUDE.md` l.17 *Capture intent first* ("act only after the operator confirms. This holds at every phase") is not amended, though l.13 and l.19 are. A literal reader could pause before the `create:` line, which the skill forbids.
  - **N3:** the docs-phase route's "Steps 2–4 below still hold, with the operator's confirmation at step 3 for a docs phase made by hand" reads as if the route's propose/narrow/confirm/STOP steps also apply under `/rotate-backlog`.
- None of N1–N3 changes behaviour. All three go to the operator as decision D3 rather than a `changes_requested`.

### Notebook vs logs

- Every decision and deviation in `P33.DECOMP`, `P33.S1` and `P33.S2` `result.md` is in `## Decisions`:
  - the archive-before-midflight departure;
  - the uncovered-only archive condition and `docs_phase_elsewhere=`;
  - the extra informational lines;
  - `--archive-only` not refused;
  - the 6-place rounding;
  - the `review-phase` message;
  - one docs phase per invocation;
  - the release rule;
  - the P32/P34 overlap.
- S2's two judgment calls (the `archive-phase` third-sentence clause and the `create-phase` two-sentence exception) are text-level and are reflected in the files.
- Nothing was dropped.
- `## Operator Questions`: both entries are routed (D1, D2 in the walkthrough).

### `## Doc impact` completeness

The six S1/S2 notes cover operations (the consolidation section, the v51 release note, the pre-v51 migration line), architecture (~l.31, ~l.400), decisions (both halves of the decision superseding v0043) and the qa smoke baseline. Two passages in operations.md still describe the v51 proposal and were named by no note:

- ~l.1439, the parallel-mode archiving bullet: "`rotate-backlog` leaves it active and proposes the docs phase that pays it, v51";
- ~l.859, the model-invocable skill paragraph, which lists the `create-phase` "when instructed" exception.

Following the P15/P21/P28 review precedent, **I appended one cross-check line** (tagged `P33.REVIEW, list cross-check`) instead of opening a fix slice. It is bookkeeping, not product, and is named here so the orchestrator can overrule it. The qa.md l.239 description of "P30's rotate asserts" is covered by S1's qa note (Test 5's rotate block rewritten).

## Gate stages

1. **Manifest:** `## Operator Runtime` in `docs/current/operations.md` (~l.1817) is filled, not `UNFILLED`. The product is a CLI with no browser surface, the instrument is "none: live CLI runs", and mutating commands run in `cp -R` copies or fresh installs. No Aside account is needed or used.
2. **I opened the product myself.** I made a `cp -R` of this checkout in the session scratchpad and removed its `.git` pointer, so the copy is outside git and is the default stream. P33's `execution` block kept P33 on "another stream". I staged each state with engine commands and ran `rotate-backlog`. I also made copies A/B/C for the `--archive-only` diff (A ran the pre-P33 engine from `git show 0d4f751:scripts/workflow.py`) and for `docs_phase_elsewhere=`. The transcript excerpts are under *Live walk*. Against this worktree I ran only the smoke suite (it works in its own temp dirs), `validate`, `phase-scope`, `next` and `--help`.
3. **Fresh eyes:**
   - The skill names every outcome an operator can hit and what to do next. Thin spots:
     - (a) `stop_midflight` says "re-run once those clear" but not how to clear them (finish the slice with `/do-next-slice`, or wait for the operator item).
     - (b) An unexpected non-zero exit other than `refused` (for example a broken state) is not mentioned. It is caught by "every stop is reported with the exact engine line".
     - (c) A first-time operator may be surprised that clean done phases are **not** archived while any debt stands. `/rotate-backlog archive-only` is the escape hatch, and the skill and CHANGELOG say so.
   - The CHANGELOG v54 entry reads well for an adopter. The Migration notes line says what happens to a v51–v53 docs phase and that a hand-edited skill copy is overwritten.
   - N1–N3 above go to the operator as D3.
4. **Regression Checklist inside the boundary:** see the table below. All 14 existing lines are inside, the outside count is 0, and one line (P30's l.347) is now false by design and is rewritten in the gate-section note.
5. **Operator questions:** both are routed as D1 and D2.
6. **Walkthrough:** below.

### Regression Checklist classification (`docs/current/qa.md` `## Regression Checklist`, 14 lines)

The boundary files are `scripts/workflow.py` (the shared engine, which feeds every `engine:` line), `installer/main.py` and the rebuilt `bootstrap_agentic_workspace.sh` (every `installer:` line), and `CLAUDE.md` plus six skills (the `machinery text:` line). That puts all 14 lines inside; the outside count is **0**, and `phase-scope P33`'s file list is the proof.

| Block | Line | In/out | Re-run result |
|---|---|---|---|
| installer | fresh install validates and stamps the current `workspace_version` (P16) | inside | pass: smoke "fresh install exits 0", "fresh workspace validates", "release version agrees across installer, top changelog heading, and fresh marker" (v54) |
| engine | undeclared/uncleared gate refuses `review-phase --verdict pass` (P16) | inside | pass: smoke "review-phase --verdict pass refuses an undeclared acceptance gate" |
| machinery text | Test 0 invariants incl. tier body parity (P16) | inside | pass: smoke Test 0 |
| engine | `## Slices` renders and `finish-slice --outcome` fills its row (P18) | inside | pass: smoke Test 8-area asserts |
| engine | marker-less notebook byte-identical; repeated `next` does not dirty dashboards (P18) | inside | pass: smoke "a marker-less phase.md is left byte-identical", "two next calls leave the dashboards byte-identical" |
| engine | `new-slice --kind research` and the closed-set error (P19) | inside | pass: smoke |
| installer | bare install into a new dir `git init`s and nests (P29) | inside | pass: smoke Test 16 |
| installer | `--at-root` installs the at-root layout and validates (P29) | inside | pass: smoke Test 5 |
| installer | bare `--update` detects the layout (P29) | inside | pass: smoke Test 16 |
| installer | bare install over at-root exits 1, nothing written (P29) | inside | pass: smoke Test 16 |
| engine | `rotate-backlog` archives the clean phases, then prints a read-only proposal (P30) | inside | **now false by design**: v54 checks the debt first and archives nothing while it stands. Rewritten in the qa gate-section note. |
| engine | `--archive-only` prints exactly the pre-v51 output, no `docs_phase` line (P30) | inside | pass: live diff against the pre-P33 engine (identical) plus smoke |
| engine | after the `create:` line runs, the next rotate prints `docs_phase_covered=` and no second proposal; `--consolidates` refuses a non-owing phase (P30) | inside | pass: live (`rotate=resume docs_phase=P36` / `docs_phase_covered=P36 (pays P35)`) plus smoke |
| engine | `docs-debt` prints `paid by: <P> (<status>)` (P30) | inside | pass: live (`paid by: P36 (planned)`) |

Appended (as a gate-section note, written at merge): the rewritten P30 line plus seven P33 lines covering archive, the `--order` jump, resume and its re-assert, stop_midflight, archive last, refused with `--archive-only` unchanged, and smoke 247. The exact text is in `phase.md` `## Doc impact`.

### Live walk (scratch copy, outside git)

```
# unchanged state
rotate=archive
no done phases to rotate; 3 phase(s) still active: P32, P33, P34
docs_phase=none                                    (exit 0)
--archive-only -> no done phases to rotate; 3 phase(s) still active: P32, P33, P34

# P35 done with one Doc impact note, review pass -> consolidation pending
rotate=create
docs_phase_proposal=P35 / phase=P36 / name=… / objective=…
create: python3 scripts/workflow.py new-phase --phase P36 --name "Consolidate the doc impact of P35" --objective "…" --order 0 --consolidates P35
scope: … / proposal only: nothing was created -- /rotate-backlog runs the create: line as is …
(sha of works/ + docs/ unchanged; exit 0)

# mid-flight, before create
P32.DECOMP in_progress|pending|in_review|blocked|changes_requested -> rotate=stop_midflight midflight=P32.DECOMP:<status> / stopped_before=create owing=P35
P32.DECOMP ready -> rotate=create
P34 in_progress -> rotate=create ; P34 pending|blocked|in_review -> rotate=stop_midflight midflight=P34:<status>

# create line run as printed
created phase P36 … consolidates=P35 ; "order": 0 ; next -> current_phase=P36
rotate=resume docs_phase=P36 / docs_phase_covered=P36 (pays P35) ; docs-debt -> paid by: P36 (planned)
P36.DECOMP in_progress + P36 pending -> still rotate=resume
P32.DECOMP in_progress -> rotate=stop_midflight midflight=P32.DECOMP:in_progress / stopped_before=resume docs_phase=P36

# order re-assert
P32 order 0 (tie)  -> docs_phase_order=P36 0 -> -1 ; second run: no order line
P32 order -2.7     -> docs_phase_order=P36 -1 -> -3.7 ; phase_reordered events logged ; next -> P36 ; validate passes

# new debt while the docs phase is live
P37 owing -> rotate=resume … / docs_debt_waiting=P37 (no docs phase pays it yet; rotate-backlog proposes one once P36 is done)
docs-consolidated P35 -> still rotate=resume (paid, unreviewed)
P36 review pass -> rotate=create (P37), nothing archived  [the skill's one-docs-phase stop]
docs-consolidated P37 -> rotate=archive / rotated 3 done phase(s): P36, P35, P37 / left 3 phase(s) active: P32, P33, P34 / docs_phase=none

# --archive-only, pre-P33 engine (copy A) vs v54 engine (copy B), same tree (clean done P40 + owing P41)
both: rotated 1 done phase(s) to archived: - P40: … / left 4 phase(s) active: P32, P33, P34, P41   -> identical, same archived set
# copy C, v54 default: rotate=create for P41, P40 NOT archived (debt first)
# copy C, docs phase P42 stamped onto another stream: rotate=archive, P40 archived, docs_phase_elsewhere=P42 (pays P41; on another stream, not resumed here), docs_phase=none
# create line with a negative fractional order (--order -3.7) ran as printed; next -> the docs phase

# refused (unit-style: git_current_branch patched to P33's branch, main(["rotate-backlog"]))
rotate=refused stream=phase/P33-one-shot_rotate-backlog_consolidate_the
SystemExit: "rotate-backlog wrote nothing: … run it from the main checkout, not this phase's worktree"   (tree sha unchanged)
```

## Walkthrough

Run it in a throwaway copy, outside git, as the CLI manifest says. Expected first lines are given.

```sh
D=$(mktemp -d); cp -R /Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/worktrees/P33-one-shot_rotate-backlog_consolidate_the "$D/ws"; cd "$D/ws"; rm -f .git
W="python3 scripts/workflow.py"
```

1. **Nothing owed:** `$W rotate-backlog` prints `rotate=archive`, then `no done phases to rotate; 3 phase(s) still active: P32, P33, P34`, and ends `docs_phase=none`.
2. **Stage an owing phase:**
   ```sh
   $W new-phase --phase P35 --name Probe --objective x
   python3 -c "p='works/phases/active/P35/phase.md';s=open(p).read();open(p,'w').write(s.replace('\n## Operator Questions','\n- architecture.md: probe (P35.S1)\n\n## Operator Questions',1))"
   $W accept-gate P35 --waive --note probe
   $W set-slice-status P35.DECOMP done
   $W set-slice-status P35.REVIEW done
   $W review-phase P35 --verdict pass
   ```
3. **Create branch:** `$W rotate-backlog` prints `rotate=create`, then the proposal and `create: … --order 0 --consolidates P35`. Nothing is created and nothing is archived.
4. **Mid-flight stop:**
   - `$W set-slice-status P32.DECOMP in_progress`
   - `$W rotate-backlog` prints `rotate=stop_midflight midflight=P32.DECOMP:in_progress`, then `stopped_before=create owing=P35`.
   - Undo it: `$W set-slice-status P32.DECOMP todo`.
5. **Queue jump:** paste the printed `create:` line (`created phase P36`), then `$W next`: `current_phase=P36`, ahead of P32.
6. **Resume:** `$W rotate-backlog` prints `rotate=resume docs_phase=P36`, then `docs_phase_covered=P36 (pays P35)`.
7. **Order re-assert:**
   - In `works/phases/active/P36/phase.json`, set `"order": 5`.
   - `$W rotate-backlog` prints `rotate=resume docs_phase=P36`, then `docs_phase_order=P36 5 -> 0`.
   - Run it again: no `docs_phase_order=` line.
8. **Paid, not reviewed:** `$W docs-consolidated P35`, then `$W rotate-backlog`: still `rotate=resume docs_phase=P36`, and P35 stays in `active/`.
9. **Archive last:**
   ```sh
   $W set-slice-status P36.DECOMP done
   $W accept-gate P36 --waive --note docs
   $W set-slice-status P36.REVIEW done
   $W review-phase P36 --verdict pass
   $W rotate-backlog
   ```
   Expected: `rotate=archive`, then `rotated 2 done phase(s) to archived:` (P36, P35), then `left 3 phase(s) active: P32, P33, P34`, then `docs_phase=none`.
10. **`archive-only`:** `$W rotate-backlog --archive-only` prints the plain report only, with no `rotate=` line.
11. **Optional, refused:** in the P33 worktree itself, `python3 scripts/workflow.py rotate-backlog` prints `rotate=refused stream=phase/P33-…` and exits 1. It writes nothing; I verified that by unit call, not in the worktree.
12. **Optional, the real chain:** in a fresh copy after step 2, type `/rotate-backlog` in Claude Code. It should show the proposal, create P36 without asking, and run it in `auto` through its DECOMP, docs slices and review, then archive P35 and P36. It writes doc versions in the copy only.

**Decisions to take:**

- **D1, v54 collision with P34:** whichever of P33/P34 lands on `main` second renumbers to v55 at its merge. Confirm, or name the phase that keeps v54.
- **D2, mid-flight edge statuses:** `in_review`, `blocked` and `changes_requested` slices, and `blocked` / `in_review` phases, stop the run (verified live). Confirm, or name which the docs phase may jump past.
- **D3, three wording nits:** none of them changes behaviour.
  - N1: `rotate-backlog` `allowed-tools` lacks `EnterPlanMode` / `ExitPlanMode`, which the `gate` word uses.
  - N2: `CLAUDE.md` l.17 *Capture intent first* is not amended for the rotate route.
  - N3: create-phase's "Steps 2–4 below still hold" is ambiguous.

  Choose one: fix now (fix slice `P33.F1`, risk `high` because S2 ran at `tier: mid`), defer (file the job below), or accept as is.

## Deferred-job candidates (for the orchestrator to file; I never run `defer-job`)

- **Only if D3 = defer:** *Tighten the one-shot rotate-backlog wording*.
  - Reason: N1 (add `EnterPlanMode` / `ExitPlanMode` to `rotate-backlog` `allowed-tools`), N2 (amend `CLAUDE.md` l.17 for the `/rotate-backlog` route), N3 (reword the create-phase docs-route "Steps 2–4" sentence as the by-hand path). Behaviour is unaffected.
  - Trigger: the next phase that edits the `rotate-backlog` or `create-phase` skill or `CLAUDE.md`, or the first `/rotate-backlog gate` run that hits a plan-mode permission prompt.
- **Outside the boundary:** no observations worth filing.

## Merge notes (also in `phase.md` `## Notes for later slices`)

- Write the two gate-section notes on the default stream after `parallel-merge-finish`. `## Operator Runtime` is verified unchanged, so it gets no version.
- Put CHANGELOG `## v54` above P32's `## v53`.
- Apply D1. The renumber locations are in `phase.md` `## Now`.
- On rebase over P32/P34, keep both texts in `do-whole-phase` l.53, `do-next-slice` l.45 and `CLAUDE.md` l.13/15/19/53. Then rebuild with `python3 installer/build.py` and re-run `--check` and the smoke.

## phase.md edits

- `## Doc impact`: three appended lines. One is the operations.md list cross-check; the other two are the gate sections (qa.md Regression Checklist rewrite + 7 lines; operations.md Operator Runtime verified unchanged), both tagged `(gate section — written at merge)`.
- `## Notes for later slices`: the two `for P33.REVIEW` notes were consumed and replaced by one `for the merge` note.
- `## Now`: rewritten.
- `## Decisions` and `## Operator Questions`: unchanged. The questions are routed here, not edited.

explain: not written — run /explain for this phase
