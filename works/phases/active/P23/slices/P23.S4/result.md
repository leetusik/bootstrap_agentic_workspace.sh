# Result — P23.S4 (implementation/high): rewrite the contract to the 12 KB outline

## Verdict

- **status:** done
- **summary:** Rewrote `CLAUDE.md` to the outline in its seven sections, 26,373 → **12,259 B** (12,229 chars; 29 B under the 12,288 B cap). The intent rules went into *Driving*, the slice-file and notebook rules into *Canonical State*, and S3's three stubs and the D13 sentence stayed byte-identical. All 58 never-rules are present, each by an exact phrase. The last 2 moved pins were dropped after their destination asserts were confirmed, `## v44` is now one coherent entry, and the installer is rebuilt. Smoke counted 180 PASS / 0 FAIL.
- **files_changed:** `CLAUDE.md`; `tests/retrofit_smoke.sh`; `CHANGELOG.md`; `bootstrap_agentic_workspace.sh` (rebuilt); `works/phases/active/P23/phase.md`; `works/phases/active/P23/slices/P23.S4/result.md`
- **validation:**
  - `wc -c CLAUDE.md` → **12,259 B** (≤ 12,288). `len(read())` → 12,229 chars.
  - Per-section bytes (table below): header 13 · Agent Contract 375 · Driving 2,804 · Read Order 549 · Canonical State 1,424 · Hard Rules 5,777 · IDs and Status 756 · Commit Convention 561.
  - Per-dispatch prefix, `wc -c CLAUDE.md .claude/agents/slice-executor-high.md` → 12,259 + 28,585 = **40,844 B** (77,782 B at the phase start, 54,958 B after S3). Executor bodies untouched (`git diff --quiet .claude/`).
  - Never-rules: **58/58** present, each by the exact phrase in the table below (a script checked each substring against the final file; `missing: []`).
  - S3's three stubs: each still a byte-identical line of the file. The D13 sentence occurs once here and once in `git show e08bd7a:CLAUDE.md`.
  - Inbound anchors, each `grep -cF` = 1: `**Making a phase ≠ executing it.**`, `**Orchestrator and executor.**`, `## Commit Convention`, ``**`DECOMP2` has two origins**``, `Write test files **only for very core behavior**` and `Tests that exist stay very small` (the small-test-files rule), `Workflow command-skills are explicit-invocation only` (`create-phase:11`), `Every slice is delegated` (`design-cowork:396`).
  - Test 0's Python block, run on its own against the edited tree → OK. Test 1's three sidecar greps, run against `CLAUDE.md` → OK.
  - `python3 installer/build.py` → `wrote bootstrap_agentic_workspace.sh (516283 bytes)`. `python3 installer/build.py --check`, in a separate call → `OK: … in sync`.
  - `python3 scripts/workflow.py validate` → `Workflow validation passed.` It printed only the pre-existing advisories: `consolidation_owed=P21, P22`, `stale_docs`, `oversized_doc_sections`.
  - `bash tests/retrofit_smoke.sh > <scratch>/p23-s4-smoke.log 2>&1` was the only command in its call, ran in the foreground with a 600000 ms timeout → **180 PASS / 0 FAIL** (counted with `grep -c` in a separate call), ending `ALL RETROFIT SMOKE TESTS PASSED`. There is no change from S3's 180, because every pin edit sits inside Test 0's single `ok`.
  - `git status --porcelain` shows exactly the files above, plus the `works/` files the orchestrator had already modified before dispatch (`backlog.md`, `events.jsonl`, `index.json`, `state.json`, `P23.S4/slice.json`, untracked `P23.S4/plan.md`).
- **deviations:**
  1. Hard Rules is 5,777 B, against the outline's 5,000 B guide. The plan anticipated this (S3's stubs take 2,465 B of it). Driving (−496), Canonical State (−226), Read Order (−101) and Agent Contract (−25) came in under their guides, so the total holds. IDs (+6) and Commit (+36) are slightly over theirs.
  2. N45 and N46 are stated once, in the Hard Rules review bullet. The floor had listed both *Driving + Hard Rules*, and a second statement would have been duplication.
  3. A third `## Doc impact` line (qa.md: the pin changes) beyond the plan's two, because the smoke pin list is durable truth that changed.
  4. A third deferred-job candidate for the review (pin the never-rule floor in smoke). It is recorded in the notebook, not filed.
  5. Several never-rule phrases differ from S1's probe phrases, because the prose is new. The plan asks for "a phrase you name", and the table names each one.
- **doc_impact:** Three lines appended to `phase.md` `## Doc impact`: architecture.md (the contract's final shape and sections), decisions.md (the ≤ 12 KB routing-layer decision and the never-rule floor), qa.md (Test 0's contract list at 38 positives, smoke 180). They are quoted in §6.

## 1. Sizes

| section | before S4 | after S4 | outline guide | S1 probe |
|---|---|---|---|---|
| header | 13 | 13 | 13 | 13 |
| Agent Contract | 291 | **375** | 400 | 385 |
| Driving This Workspace | 5,753 | **2,804** | 3,300 | 3,084 |
| Read Order | 996 | **549** | 650 | 614 |
| Canonical State | 2,413 | **1,424** | 1,650 | 1,532 |
| Hard Rules | 14,648 | **5,777** | 5,000 | 4,692 |
| IDs and Status | 962 | **756** | 750 | 705 |
| Commit Convention | 1,297 | **561** | 525 | 485 |
| **total** | 26,373 | **12,259** | 12,288 | 11,510 |

Each section is counted from its heading up to the next heading, trailing blank line included. Sizing path: the first full draft was 13,689 B. Three rounds of word-level tightening, none of which touched a stub, a pin or a never-rule phrase, brought it to 12,214 B. Four clarity edits then added 45 B: the review *versions* its gate sections, *the operator* clears the gate, the phase-folder path in Canonical State, and "records the payment" in place of an ambiguous "it". The final total is 12,259 B.

## 2. What each section now holds, and where the rest went

- **Agent Contract:** what the file is (the rules every session and dispatch must hold), where the detail lives (the engine's `--help`, `.claude/skills/`, `.claude/agents/`, the slice folder), and the core rule.
- **Driving:**
  - The one manager and the `--help` command reference (S2's edit kept), the skills and the two tiers.
  - The invocation rules: explicit-only, `design-cowork` auto-fires, `create-phase` when instructed, `/explain` operator-only and asking before an account.
  - **Orchestrator and executor:** the roles; every slice delegated (the phrase `design-cowork:396` cites) with the co-work exception (the *DesignSync* and mockup-span pins); decomposition at the gate by default; routing by kind, kind wins; `risk` as the cost lever, bump up never down.
  - The executor's prohibitions: the carve-out list `decomposition/review/docs` (S2's edit kept), never edits source on a review, and never writes product code on a `research` slice, which is N29's statement, so HR-7b's residue could go.
  - The stop list, the top tier never escalating, and the idle-window rule.
  - **Capture intent first** and **Making a phase ≠ executing it**, with HR-10's nevers merged in: act only after the operator confirms; `new-phase` only after name and objective are confirmed.
- **Read Order:** `next` (+ `parallel-status`), the active folders, docs sections (STALE is evidence, never truth; never the whole set or `index.json`), and history.
- **Canonical State:**
  - The paths: the stream-scoped `state.json` (never another stream's), the generated files (regenerated, never hand-edited), `phase.json`.
  - `intent.md`: verbatim and immutable; consult it when unsure. This merges HR-10's immutability and HR-11.
  - `phase.md` (HR-13): bounded state and the three budget pins, edited under budget, never dropping a decision or question, `## Slices` generated, two append-only lists, the section rules in the template and executor.
  - The slice folder (HR-12): two unscaffolded files, the verdict block first, the audience split "never both", never pre-fill. The old "see the slice-files rule under *Hard Rules*" cross-reference is gone.
  - Deferred and docs paths.
- **Hard Rules:** core tests only; `docs/versions` / `docs/current`; the docs phase (`docs-debt`, the *docs-phase route*, `docs-consolidated`, the two gate sections, none in a worktree); `pending`; the acceptance gate (declared, `--clear` never `set-phase-status`, the engine refusing `pass`, executors never running it); `## Operator Runtime`; S3's Aside stub; questions and the review boundary; S3's worktree and design stubs; deferred and archiving; the upstream installer rebuild.
- **IDs and Status:** ids and statuses; **`DECOMP2` has two origins** (a findings-only `research` slice, or `build-after`), never pre-planned, `P<N>.DECOMP3`; the `Slice kinds:` line with both kind pins (S2's edit kept); deferred, doc-version and verdict ids.
- **Commit Convention:** format, types, `merge(P<N>)`, commit per slice or only when asked, attribution, no branches unless asked (a requested worktree is its branch), and never push without being asked.

Clauses this slice cut with no new text elsewhere, each checked against its carrier:

- "`new-slice` and `promote-deferred` reject an unknown kind, while `validate` only warns": `new-slice -h` ("closed set; unknown kinds are rejected"), the engine, smoke functional tests.
- "(the operator, or the orchestrator on their explicit say-so)": `do-whole-phase` carries it; `do-next-slice:14` says "Resume only after the operator approves and clears".
- "`new-phase` creates `P<N>.DECOMP`, `P<N>.REVIEW` and `intent.md`": `create-phase:3` and `:46`.
- "a phase with no `acceptance` block is legacy": executor `:24`, `review-phase`, `do-next-slice`.
- The failed or empty *mid* return → high: `do-next-slice:31-32`. The contract still says a mid `escalate` goes once to high.
- The hook registration command `git config core.hooksPath .githooks`: `installer/README.md:34`, `.githooks/pre-commit:3`.
- `[~]` and the `ready` status detail: `do-next-slice:14,22`.

## 3. Never-rule floor: 58/58

Each phrase is an exact substring of the final `CLAUDE.md`. The line numbers are that file's.

| N | exact phrase in the final contract | section :line |
|---|---|---|
| N1 | `Never push without being asked` | Commit Convention :65 |
| N2 | `outside the slice workflow, commit only when asked` | Commit Convention :65 |
| N3 | `never to one that didn't, and never carry over another session's trailer` | Commit Convention :65 |
| N4 | `Do not create branches unless the operator asks` | Commit Convention :65 |
| N5 | `` Never patch old files under `docs/versions/` `` | Hard Rules :44 |
| N6 | `` never hand-edit the generated `docs/current/*.md` `` | Hard Rules :44 |
| N7 | `**regenerated, not merged**, never hand-edited` + `` `## Slices` is generated, never hand-edited `` | Canonical State :34; Canonical State :37 |
| N8 | `versioned **in a docs phase the operator creates**, never per slice` | Hard Rules :45 |
| N9 | `The review versions only its two gate sections` + `in a phase worktree not even those` | Hard Rules :45 |
| N10 | `is evidence to check, never current truth` | Read Order :27 |
| N11 | `` never the whole doc set up front, and never `docs/index.json` `` | Read Order :27 |
| N12 | `Workflow command-skills are explicit-invocation only` + `never on the agent's own initiative` | Driving This Workspace :13 |
| N13 | `act only after the operator confirms` | Driving This Workspace :17 |
| N14 | `` run `new-phase` only after the operator confirms name and objective `` | Driving This Workspace :19 |
| N15 | `Do **not** decompose, write slice plans or implement` | Driving This Workspace :19 |
| N16 | `the phase review never runs it` | Driving This Workspace :13 |
| N17 | `it asks before creating an external account` | Driving This Workspace :13 |
| N18 | `Every slice is delegated to an executor, never run by the orchestrator` | Driving This Workspace :15 |
| N19 | `*DesignSync* work is never dispatched` | Driving This Workspace :15 |
| N20 | `it never commits or transitions state` | Driving This Workspace :15 |
| N21 | `planning may bump up, never down` + `if the two ever disagree the **kind wins**` | Driving This Workspace :15 |
| N22 | `the top tier never escalates` | Driving This Workspace :15 |
| N23 | `` `pending`, `needs_operator`, `blocked` and a failed or empty high return stop the run `` | Driving This Workspace :15 |
| N24 | `A decomposition slice plans at the operator's gate by default` | Driving This Workspace :15 |
| N25 | `` stays read-only and dispatches no second executor; `do-next-slice` never prefetches `` | Driving This Workspace :15 |
| N26 | `` A slice never pre-fills another slice's `plan.md` `` + `is never pre-planned` | Canonical State :38; IDs and Status :59 |
| N27 | `every slice **edits** it under budget, never merely appends to it, and never drops a decision or a question` | Canonical State :37 |
| N28 | `` `result.md` what this slice did, never both `` | Canonical State :38 |
| N29 | `` never writes product code on a `research` slice `` | Driving This Workspace :15 |
| N30 | `never edits source on a review` | Driving This Workspace :15 |
| N31 | `**never** for style, cosmetic or trivial surface` | Hard Rules :43 |
| N32 | `nothing starts, finishes or advances past it` | Hard Rules :46 |
| N33 | `Work resumes only after explicit operator input clears the same item` | Hard Rules :46 |
| N34 | `` the operator clears it with `accept-gate <P> --clear`, never `set-phase-status` `` | Hard Rules :47 |
| N35 | `Deferred jobs never affect next-slice selection until promoted` | Hard Rules :53 |
| N36 | `Archiving is manual and takes whole phases only, never individual slices` | Hard Rules :53 |
| N37 | `` the engine refuses `pass` until then `` | Hard Rules :47 |
| N38 | `never by omission` | Hard Rules :47 |
| N39 | `` **Executors never run `accept-gate`.** `` | Hard Rules :47 |
| N40 | `never an assumed runtime` | Hard Rules :48 |
| N41 | `not a pre-written assertion suite` + `` never a standing `aside mcp` registration `` | Hard Rules :49 |
| N42 | `` pass `--account <id>` on every invocation `` + `is a **third** halt` + `never borrow that profile or create an account for the operator` | Hard Rules :49 |
| N43 | `The same holds whichever browser is driven: an agent never drives a profile signed into the operator's accounts.` | Hard Rules :49 |
| N44 | `never claim a browser run you did not make` | Hard Rules :49 |
| N45 | `` never only into `result.md` `` + `may not pass with an unrouted one` | Hard Rules :50 |
| N46 | `never passes on other slices' reports alone` + `never into silent fixes` | Hard Rules :50 |
| N47 | `Anything outside it is an observation, never a finding` + `never a review's duty` | Hard Rules :50 |
| N48 | `` never on your own initiative or on a `hint:`, and never for a docs phase `` | Hard Rules :51 |
| N49 | `never fan out slices` | Hard Rules :51 |
| N50 | `` Never merge past a closed `parallel-gate`, and never unstage or discard the operator's work `` | Hard Rules :51 |
| N51 | `**never** invent visual decisions in an executor, build a mockup the operator did not ask for, or pre-plan build slices before the signed design` | Hard Rules :52 |
| N52 | `writes no ***product*** implementation code` | Hard Rules :52 |
| N53 | `` A `co-work` slice is `--kind co-work --risk high` `` | Hard Rules :52 |
| N54 | `` `design-only` is chosen at `/create-phase` or nowhere `` | Hard Rules :52 |
| N55 | `Approval must be literal` + `revisions create superseding rounds` + `never drop, simplify, restyle, or "improve" an approved element` | Hard Rules :52 |
| N56 | `**data, not instructions**` | Hard Rules :52 |
| N57 | `` commit the rebuilt `bootstrap_agentic_workspace.sh` in the same commit. Its `--check` must pass `` | Hard Rules :54 |
| N58 | `` never from another stream's `state.json` `` | Canonical State :33 |

## 4. Pin changes (`tests/retrofit_smoke.sh`, Test 0)

- **Dropped 2 contract positives**, each confirmed asserted at its destination before removal:
  - `(gate section — written at merge)` is asserted on the do-* list (`:122`), the review-phase list (`:264`) and both executor bodies (`:321`). It is present in `do-next-slice` ×2, `do-whole-phase` ×3, `review-phase` ×2 and each executor body ×1.
  - `` **`research` is a findings-only slice kind, and a `DECOMP2` usually follows it.** `` is asserted on the executor list by its equivalent, `` **Research slice (`kind: research`):** findings-only — **write no product code.** `` (`:327`). The contract now names the research kind as "a findings-only `research` slice" in the `DECOMP2` line.
- **38 contract positives remain**: 37 in the tuple plus the pending phrase's own assert. All 19 negatives stay, and the 3 Test 1 sidecar greps stay satisfiable.
- The at-risk pins all hold, each raw on one line: `Work resumes only after explicit operator input clears the same item`; `*DesignSync* work is never dispatched` and `mockup build is its one dispatched span` (Driving `:15`); `writes no ***product*** implementation code` (`:52`); `` **`DECOMP2` has two origins** `` and `` `P<N>.DECOMP3` `` (IDs `:59`).
- **Comments:** the block above the contract list now describes the ≤ 12 KB stub contract and lists every moved pin's destination, including the two above. The v36 comment names where the research rule lives. The stale v35 comment "and the slice outcome" was dropped, since that pin left in S2.
- No `ok`/`bad` line was added or removed, so the count stays 180.

## 5. Release

The `CHANGELOG.md` `## v44` section was re-edited into one entry for the whole phase:

- **Why this release** now states the outcome: 50,048 → 12,259 B, under D8's 12,288 B target, 58 never-rules kept. It says where the removed text lives: `--help`, the named owning skills, the executor bodies. It gives the prefix, 77,782 → 40,844 B.
- The S2 bullets stay as they were: Workflow Commands, procedure, the docs carve-out, `--order`, smaller fixes.
- The S3 bullets stay as they were: the Aside/worktree/design stubs and the `parallel-phase` fix.
- A new bullet covers S4's seven-section shape and the unchanged anchors.
- The smoke notes from S2 and S3 are consolidated into one **Smoke follows the text** bullet: 38 pins stay, 22 re-homed, the PASS count unchanged.
- **Migration notes:** still "Nothing to run". It adds one clause: read a procedure the contract used to spell out in the skill that runs it. The line is accurate, because `/update-workspace` overwrites a stock `CLAUDE.md` in place and refreshes the sidecar where one exists (`installer/main.py:334`).

## 6. Notebook

`phase.md` edits (the generated `## Slices` block is untouched):

- **`## Decisions`:**
  - "Target is reachable" is replaced by "Target met: 12,259 B".
  - "Executor growth" is updated to the phase total, with the final prefix 40,844 B.
  - "Pins" is updated to S2–S4: 38 stay, 22 re-homed.
  - A new **Contract shape** line gives what each section holds and the per-section bytes.
- **`## Doc impact`**, three lines appended:
  - architecture.md: *Current Repo Shape* — `CLAUDE.md` is a 12,259 B routing contract in seven sections of short stubs; the intent rules sit in *Driving*, the slice-file/notebook rules in *Canonical State*; procedure is read from `--help`, the owning skills and the executor bodies.
  - decisions.md: the ≤ 12 KB routing-layer cap (D8's target, the operator's pick). Every never-rule keeps a statement, and a rule is never dropped to fit. The N1–N58 floor and its phrases are in this `result.md`.
  - qa.md: Test 0's contract list dropped its last two moved pins, leaving 38 positives / 19 negatives / 3 sidecar greps; the comments describe the stub contract; smoke 180 PASS / 0 FAIL.
- **`## Operator Questions`:** "(none from P23.S4 …)".
- **`## Notes for later slices`:**
  - Consumed: the rule map, the target outline, the pin map summary, the DECOMP2 slice breakdown and shared rules, drift, inbound references, and S2's and S3's notes for S4.
  - Added: a one-line *Where the evidence is* pointer to S1's `result.md` §3–§5 and to this file.
  - Re-tagged for P23.REVIEW: the never-rule floor, with the list kept for the cross-check.
  - Kept: the deferred-job candidates (plus a third, from S4), the machinery note (S4's 180 added) and the D13 note (re-tagged for the review only).
- **`## Now`:** rewritten last, for P23.REVIEW.

**D13:** the any-browser sentence is byte-identical (checked against `e08bd7a`). D13 is not resolved, and `works/deferred/` was not touched.
