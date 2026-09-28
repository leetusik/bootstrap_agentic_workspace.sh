# Result — P23.REVIEW (review): phase review

## Verdict

- **status:** done
- **review_verdict:** **pass**
- **summary:** P23 did what it set out to do. `CLAUDE.md` went from 50,048 B to **12,259 B** (12,229 chars), under the 12,288 B cap. All 58 never-rules are still stated. My own sweep of the pre-P23 contract covered 166 prohibition and obligation clauses and found none whose only carrier was the old contract and which now appears nowhere. Every inbound reference still resolves. Validation passes across the phase (smoke counted 180 PASS / 0 FAIL). The `## Doc impact` list is complete, and OQ1 is answered and landed. Five deferred-job candidates are listed for the orchestrator to file, and none of them blocks the pass.
- **files_changed:** `works/phases/active/P23/slices/P23.REVIEW/result.md` (new); `works/phases/active/P23/phase.md` (Decisions, Doc impact, Operator Questions, Notes for later slices, Now; the generated `## Slices` block was not touched)
- **validation:** each command ran in its own Bash call.
  - `python3 scripts/workflow.py validate`: exit 0, `Workflow validation passed.` The only warnings were the three pre-existing advisories: `consolidation_owed=P21, P22`; `stale_docs=architecture, decisions, operations, qa`; `oversized_doc_sections=7`.
  - `python3 installer/build.py --check`: `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`.
  - `wc -c CLAUDE.md`: **12,259 B**, which is ≤ 12,288. `len(read())` gives 12,229 chars.
  - `wc -c .claude/agents/slice-executor-*.md`: high 28,585 B, mid 28,568 B. A frontmatter-stripped compare gives `BODIES_IDENTICAL` (28,157 B each).
  - Per-dispatch prefix is 12,259 + 28,585 = **40,844 B** (77,782 B at the phase start).
  - Smoke: `bash tests/retrofit_smoke.sh > <scratchpad>/p23-review-smoke.log 2>&1`, run once as the only command in its call, in the foreground, with a 600000 ms timeout. Counted in a separate call: **PASS=180, FAIL=0**. The last line is `ALL RETROFIT SMOKE TESTS PASSED`.
  - `phase-scope P23`: range `58d30a5..6e06311`, 7 commits, 13 product files, all modified. This matches the plan.
  - Two more checks outside `phase-scope`, which excludes `works/` and `docs/`: `git diff --stat 58d30a5..HEAD -- works/templates docs` shows `works/templates/phase.md` (1 line, D-6) and `docs/index.json` (the `last_rebuilt_at` stamp only).
- **deviations:** none from `plan.md`. The notes below record where I added checks the plan did not name.
  - The sweep's keyword set was widened on a second pass to `not`, `no`, `without`, `instead`, `always`, `each` and `every`, which added 48 clauses.
  - I also checked the engine's `--help` against the contract, since P23 made `--help` the command reference. That is where deferred-job candidate 4 comes from.
- **doc_versions:** none — deferred to a docs phase. The gate is waived, and neither gate section (`## Regression Checklist`, `## Operator Runtime`) changed.
- **walkthrough:** none. `acceptance.required` is `false` ("machinery and doctrine only; no operator-visible running product"), so the gate stages were skipped.
- **explain:** not written — run /explain for this phase
- **findings:** none that block. One item is inside the boundary but pre-existing and non-blocking: the one-line `new-slice` help string (candidate 4 below). I route it as a deferred job, not a fix slice, and give the reason in §9.
- **deferred jobs to file** (the orchestrator files them; title / reason / trigger in §9):
  1. Slim the executor bodies.
  2. Match the contract's smoke pins whitespace-normalized.
  3. Pin the never-rule floor in smoke.
  4. Correct two stale one-liners: `new-slice`'s help and `executors.toml`'s tier comment.
  5. A running phase stays `planned`, so the engine's `in_progress` readers never see it.
- **D13:** its trigger ("whenever the Aside doctrine is next edited") fired in P23.S3. The any-browser sentence is byte-identical to the pre-P23 text: `grep -cF` gives 1 in `CLAUDE.md:49` and 1 in `git show e08bd7a:CLAUDE.md`. D13 is left **open** for the operator, and `works/deferred/` was not touched.
- **On pass, for the orchestrator:** record `review-phase P23 --verdict pass`. The phase carries 12 `## Doc impact` notes, so the engine stamps `consolidation: pending`. File the five jobs, and drop D8 ("resolved by P23"), as the notebook's *D8 closes at review-pass time* decision says.

## 1. Validation detail

| check | result |
|---|---|
| `validate` | pass; only the three pre-existing advisories |
| `build.py --check` | in sync |
| `CLAUDE.md` | 12,259 B / 12,229 chars. Per section: header 13 · Agent Contract 375 · Driving 2,804 · Read Order 549 · Canonical State 1,424 · Hard Rules 5,777 · IDs 756 · Commit 561 (matches S4's table) |
| executor bodies | identical below the frontmatter; +851 B each over the phase (27,734 → 28,585 / 27,717 → 28,568), against a 37,789 B contract shrink |
| smoke | 180 PASS / 0 FAIL, counted; log is `<scratchpad>/p23-review-smoke.log` (195 lines) |
| `WORKSPACE_VERSION` | `installer/main.py:38` = 44 |
| CHANGELOG | exactly one `## v44 — 2026-09-28` section, on top |
| `git status` | only the orchestrator's pre-dispatch `works/` changes, plus this slice's two files |

Each slice's own validation commands (`validate`, `build.py --check`, sizes, identical bodies, smoke) are the commands above. The DECOMP and DECOMP2 checks (bare folders) still hold: every S2–S4 folder had only `slice.json` until its own plan landed.

## 2. No load-bearing rule lost

### 2a. S4's 58-row table against the *Never-rule floor* note

A script parsed S4's §3 table and checked every backticked phrase against the final `CLAUDE.md`:

- **58 rows**, N1–N58, none missing and none extra.
- **Every phrase is an exact substring** (`missing: []`).

I then read each phrase against the floor entry it claims. Each one *states* its rule rather than just matching a string. There are two borderline cases, and both are sound:

- **N26** (never pre-fill; REVIEW / DECOMP2 / paired apply never pre-planned). The contract states "A slice never pre-fills another slice's `plan.md`" (`:38`) and "`DECOMP2` … is never pre-planned" (`:59`).
  - REVIEW and the paired apply slice are not named in the contract. The old contract never stated them as a rule either: they appeared only in the idle-window skip list.
  - Their never-pre-plan rule is carried where the orchestrator plans: `do-next-slice:25` and `do-whole-phase:20` ("Stop before anything whose plan depends on something that has not landed yet"), and `do-whole-phase:31` ("never pre-planned").
- **N37** (a gated pass only after the operator cleared the gate). The phrase "the engine refuses `pass` until then" (`:47`) refers back to the operator's `accept-gate <P> --clear`. It is enforced by `_require_acceptance_cleared`.

### 2b. Independent sweep of the pre-P23 contract (`git show e08bd7a:CLAUDE.md`, 50,048 B)

**Method.**

- A script split every line of the old contract into sentences and printed each sentence carrying `never`, `do not`, `don't`, `only when`, `only after`, `must`, `may not`, `STOP`, `refuse`, `cannot` or `only`. That gave **118 clauses**.
- A second pass over the remaining sentences, keyed on `not`, `no`, `without`, `instead`, `rather than`, `halt`, `block`, `require`, `always`, `exactly`, `each` and `every`, added **48**.
- The old *Workflow Commands* section (`:90-116`) was read whole for per-command rules.
- For each clause I looked for its statement in the new contract. Where there was none, I looked for the named carrier (skill, executor body, engine or `--help`) and grepped it present.

**Result: every clause lives somewhere, and none is orphaned.** The clauses that left the contract, grouped by where each lives now:

| old clause (old line) | where it lives now |
|---|---|
| `auto` default; gated modes copy the harness plan byte-exact (:18) | `do-whole-phase:18-19`, `do-next-slice:23-25` |
| a `ready` slice dispatches from its approved plan, re-planning only on visible drift (:18, :71) | `do-next-slice:22`; `do-whole-phase:18-19`; engine `validate` errors on `ready` without `plan.md` |
| orchestrator trusts `done`, re-runs only `validate`; background Agent task (:22, :67) | `do-next-slice:26-28`, executor "trusts your `done` verdict" |
| failed or empty *mid* return → high (:22, :67) | `do-whole-phase:18`, `do-next-slice:31-32`; the contract keeps the mid `escalate` → high and "the top tier never escalates" |
| review completes judgment before branching; non-pass stops before pass-only steps (:22) | executor review bullet; `review-phase` "Form the verdict from the complete picture" |
| `create-phase` "by an approved plan or a direct operator instruction" (:24) | `create-phase:11`; the contract keeps "**when instructed**, never on the agent's own initiative" |
| `new-phase` creates only DECOMP + REVIEW + `intent.md` (:28, :59, :62) | `create-phase:3,:46`; engine `new-phase`; `new-phase --help` |
| "Do not read every historical slice or old doc version by default" (:38) | contract `:26` ("the active slice folder only") and `:29` ("Archived phases and old doc versions are history"); same meaning |
| `validate` warns and never errors on the budget (:45) | contract `:37` "warning-only"; engine |
| Keep `backlog.md` / `deferred.md` lean (:54) | moot: both are generated and never hand-edited (contract `:34`) |
| tests: "no fixture or scaffolding sprawl" (:55) | the contract keeps "Tests that exist stay very small"; the detail is a gloss |
| stale-doc staleness recording (:58) | engine (`docs`, `validate`); the contract keeps "never current truth" (`:27`) |
| review gate sections "editing only that section" (:58) | executor step 5, `review-phase` (b) |
| worktree review writes nothing and records tagged notes (:58) | executor step 5, `review-phase`, do-* (pinned `(gate section — written at merge)`) |
| DECOMP bare folders; `--risk` deliberately (:59) | executor decomposition bullet; `do-whole-phase:35`, `do-next-slice:37`; the contract keeps the cost-lever rule (`:15`) |
| three design styles; build inventory; style asked at DECOMP, stopping `pending` (:59) | `design-cowork:69-136`, `create-phase:19-27`, `do-next-slice:39`; build inventory in both executor bodies (S3) |
| a `DECOMP` executor may not run `new-phase` (:59) | executor *Never* list (`new-phase`); the contract keeps "`design-only` is chosen at `/create-phase` or nowhere" |
| research: findings land in `phase.md`, rated `high` (:60) | executor research bullet (pinned); `new-slice --kind` help; the contract keeps "kind wins" |
| slice files: persisted just in time; no per-slice brief or review files (:65) | `do-*` (plan persistence); the contract keeps "exactly two context files, neither scaffolded" |
| notebook section rules: replace decisions, drop consumed notes, `## Now` last (:66) | executor step 4; `works/templates/phase.md` (contract `:37` points there) |
| idle window: never delays N's return, discarded on non-`done`, scratch only, "the gate still does not move", the skip list (:68) | `do-whole-phase:30` (limits) and `:31` (skip list); the contract keeps read-only, no second executor, and `do-next-slice` never prefetches |
| `depends_on` advisory; fractional `--order` (:69) | executor decomposition bullet (MOVE, S2); `new-slice` / `promote-deferred` / `new-phase` `--help` |
| `pending` shown `[~]`; the say-so clause; design slice PENDING #1/#2 (:70) | `do-next-slice:14`, `do-whole-phase:16`, `design-cowork` |
| `changes_requested` / `blocked` never refused; pass does not archive (:73) | engine; `do-next-slice:43-46`, `do-whole-phase:40-45`, `review-phase` |
| archiving blocked while `consolidation` is pending (:58, :73) | engine `workflow.py:2805-2812` (every archive path); `archive-phase:18,:32`; `do-next-slice:45` |
| gate declared right after `finish-slice <P>.DECOMP` and committed with it; undeclared pass refused (:74) | `do-next-slice:39`, `do-whole-phase:35`; engine; the contract keeps "right after `DECOMP`, never by omission" |
| **a design phase's gate follows its mockup** (:74) | `do-next-slice:39` (whole rule, fixed waive note, re-declare, style answer lands first); `design-cowork:350-355` |
| operator clears → pass recorded without re-dispatch; failure → `changes_requested` (:74) | `do-next-slice:43`, `do-whole-phase:40`, `review-phase` *After a passing review* |
| legacy phase (no `acceptance` block) (:74) | executor input 4, `review-phase`, engine |
| Aside rationale, two surfaces, MCP cost and escape hatch, instrument/runtime axis, `aside account use` (:76) | `design-cowork:482-550` (pinned); executor implementation bullet (the runtime rule, `--account`, third halt, fallback "at the same viewports") |
| questions: the review executor lists and the orchestrator files (:77) | executor *Never* (`defer-job`); `review-phase` stage 5 |
| gated review: fresh-eyes walk, not judged against the record, checklist re-run inside the boundary, outside lines counted with the diff (:77) | executor review bullet (stages 1–6); `review-phase` |
| worktree rules 1–8: `.git/info/exclude` never `.gitignore`, stamp commit, refusals, `ExitWorktree keep` never removes, never a marker file, merge sequence incl. "STOP and ask", v42 pin, stamped phase enters "without asking again" (:78) | `parallel-phase:36-78` (pinned list, S3), engine refusals, `do-*` (b)/(c) |
| **push → PR → CI remote variant only when asked; the `git push:*` deny note; permission prompt** (:78, :122) | `parallel-phase:70,:266`, `do-next-slice:35,:45`, `do-whole-phase:38`; the contract keeps "Never push without being asked" |
| design procedure: numbered cards, SIGNOFF, handoff, "authors no canvas mirror", only two sanctioned DesignSync writes, functional sweep contents (:79) | `design-cowork:34-35,:396,:405,:462,:316` |
| upstream: "inert in adopting workspaces"; `git config core.hooksPath` (:80) | contract "(where `installer/` exists)"; `installer/README.md:34`, `.githooks/pre-commit` |
| `DECOMP2`: `design-only` / `paired` have none (:85) | `design-cowork`; executor decomposition bullet ("**no `DECOMP2`**") |
| WC: unknown `--kind` hard error, `validate` warns; `doc-new-version` on the default stream only; `parallel-start` only when asked; `sync-agents` after editing `executors.toml` / an update | `new-slice --help` + engine; engine `:390` + contract `:51` + executor carve-out "on the default stream"; contract `:51`; `executors.toml` header + `update-workspace:61` |
| Commit Convention: merges locally by default; a phase nobody asked into a worktree has no branch (:122) | `parallel-phase`, do-* step 7; the contract keeps "(a worktree they asked for is its branch)" |

**The plan's six extra-attention items**, one line each:

- **REVIEW / DECOMP2 / paired apply never pre-planned:** held (§2a N26).
- **`ready` dispatches from its approved plan:** held (`do-next-slice:22`, `do-whole-phase:18-19`).
- **A design phase's gate follows its mockup:** held (`do-next-slice:39` carries all four clauses, verbatim in substance).
- **Push only when asked:** held; the contract states it without any exception.
- **The consolidation debt blocks archiving:** held (the engine guard on every archive path, plus `archive-phase` and do-*).
- **Idle-window limits:** held (`do-whole-phase:30-31` carry all of them).

In each case the reader who needs the rule (the orchestrator) runs the skill that carries it.

### 2c. The executor bodies against the new contract

- Both bodies are byte-identical below the frontmatter.
- **The three carve-outs read coherently:**
  - the opening paragraph ("Three carve-outs, each tied to one kind");
  - step 5's heading ("… except by that phase's own `docs` slices") and its new bullet;
  - the *Never* may-run list ("`docs` slice, the notes its plan names");
  - the *Never* versioning bullet ("version docs outside the review and `docs`-slice carve-outs").
- The contract's `:15` "(except the decomposition/review/docs command carve-outs)" agrees with them.
- **The docs-slice bullet matches the operator-approved OQ1 text** in `slices/P23.DECOMP2/plan.md:13` word for word. The only difference is the lowercase "a" after the bullet's colon.
- The contract's rules the executor depends on all agree with the body: STALE docs are evidence; never `docs/index.json`; the notebook's append-only lists; never pre-fill; the Aside runtime and profile halts; no product code on a research slice; no source edits on a review.
- No contract section that the body names is gone (the body cites only `CLAUDE.md` as a whole, at `:27` and `:61`).

## 3. Inbound references

I grepped `.claude/` (skills and agents), `works/templates/`, `installer/` and all three READMEs for `CLAUDE.md`, "the contract" / "contract's", and every section heading and bold lead. Each hit checks out:

| reference | points at | resolves and still true? |
|---|---|---|
| `create-phase:9` *Making a phase ≠ executing it* in the contract | `CLAUDE.md:19` | yes: bold lead present, still says never decompose |
| `create-phase:11` the contract's "workflow command-skills are explicit-invocation only" | `:13` | yes |
| `create-phase:31` "Per the contract, do **not** run `new-phase` until the operator confirms" | `:19` "run `new-phase` only after the operator confirms name and objective" | yes |
| `design-cowork:91` `DECOMP2` two origins, "see `CLAUDE.md`" | `:59` **`DECOMP2` has two origins** | yes |
| `design-cowork:396` the contract's "every slice is delegated" | `:15` "Every slice is delegated to an executor" | yes |
| `design-cowork:447` the gate stages and walkthrough "live in the `review-phase` skill and the contract" | `:47` (walkthrough, gate) | yes |
| `design-cowork:571` the contract's small-test-files rule | `:43` | yes |
| `design-cowork:177,:189` "the contract" | the card contract, not `CLAUDE.md` | n/a |
| `do-next-slice:35`, `do-whole-phase:38`, `parallel-phase:250` "the Commit Convention" | `## Commit Convention` | yes; the heading is kept |
| `do-next-slice:10`, `do-whole-phase:10`, `review-phase:22`, executor `:27`/`:61` "read `CLAUDE.md`" / its safety rules | whole file | yes |
| `parallel-phase:31` "The contract (`CLAUDE.md`) carries only the rules; the detail lives here" | the worktree stub `:51` | yes, and truer than before |
| `retrofit:27,:31`, `update-workspace:12`, `installer/main.py` (`_merge_contract`, update branch), `installer/build.py` / `installer/README.md` (`CLAUDE_HDR`) | the file and its `# CLAUDE.md\n\n` header | yes: header unchanged, and `build.py` asserts it |
| `README.en.md:266,:389`, `README.md:215-216` "command list/reference" | `python3 scripts/workflow.py --help` (re-pointed by S2) | yes: `--help` lists all 32 subcommands |
| `README.en.md:30,:170,:398,:426,:456-457,:503,:510`, `README.md:257,:277` "compact (routing) contract" / "how they're enforced" | whole file | yes: all six README principles are still enforced by stubs (decompose, notebook, plan/result/review, versioned docs, deferred jobs, commits) |
| `docs/current/operations.md:384` "contract's design rule" | the design stub `:52` | yes (outside `phase-scope`; checked because it cites the contract) |

The other items the plan named were grepped too: `Hard Rules`, `Driving This Workspace`, `Orchestrator and executor`, "slice-files rule", "see `CLAUDE.md`" and `Workflow Commands`. None of them is referenced anywhere else in `.claude/`, `works/templates/` or the READMEs. The old "see the slice-files rule under *Hard Rules*" lived inside the contract itself and is gone (S4). **No dangling or now-false reference.**

## 4. Intent coverage (`intent.md` steps 1–5 and the scope boundary)

1. **Research first.** P23.S1 mapped 166 units before any cut, and DECOMP2 cut S2–S4 from that map at the operator's gate.
2. **Workflow Commands cut, pins re-homed.** S2 cut the section. The closed `--kind` set moved to *IDs and Status*, where both `--kind` pins stay. `finish-slice --outcome` and the `phase-scope` synopsis are asserted on the do-*, review-phase and executor lists and functionally in Tests 9 and 11.
3. **Skill-owned detail moved to its owner.**
   - Worktree procedure is in `parallel-phase`; design and Aside in `design-cowork`; the gate and the review boundary in `review-phase` and the executor. Each carried the text already, and S1 §3 names every carrier.
   - Only two MOVEs wrote new text, both into the executor (the docs-slice carve-out and fractional `--order` / advisory `depends_on`), plus S3's build-inventory clause. Nothing went into a skill that an executor needs.
4. **Every never-rule kept:** 58/58 (§2a), with none orphaned (§2b). The intent's named examples all hold: never push; never patch `docs/versions/`; never hand-edit generated files; the confirmation gates; operator-only commands (`accept-gate`, the worktree start); and the dedicated-browser-profile rule.
5. **Shipped as a release.**
   - The pins are re-pointed, with 38 contract positives and 19 negatives. The installer is rebuilt, `WORKSPACE_VERSION` is 44, and there is one `## v44` section.
   - **The Migration notes line is accurate for an adopter:** `/update-workspace` overwrites a stock `CLAUDE.md` in place and refreshes the `CLAUDE.workspace.md` sidecar where one exists (`installer/main.py:331-340`). The only habit that changes is where to read commands and procedure.

**Scope boundary.**

- Executor growth is +851 B per body, against a 37,789 B contract shrink.
- The executor files changed only to receive moved rules and the docs carve-out. Wider slimming is candidate 1.
- The only product files touched are this repo's 13 (`phase-scope`), so no adopter was edited.
- There is no new loading mechanism: `CLAUDE.md` has no `@import` lines, and there is no `.claude/rules/`.
- D8's target is met; it closes at pass.

## 5. Doc impact coverage

The list has 12 notes (S2 ×6, S3 ×3, S4 ×3), plus three `none` lines. Against the phase's diff:

| durable-truth change | note |
|---|---|
| contract shape: no Workflow Commands, `--help` is the reference, `--kind` set in IDs | architecture (S2) |
| contract final shape, seven sections, where procedure lives | architecture (S4) |
| Aside, worktree and design rules are stubs; build inventory in the executor | architecture (S3); decisions (S3) |
| why it slimmed, where the text went | decisions (S2) |
| the ≤ 12 KB cap and the never-rule floor | decisions (S4) |
| the executor docs-slice carve-out (and the contract's `decomposition/review/docs` lists) | operations (S2) |
| `--order` / `--depends-on` help | operations (S2) |
| workspace v44 | operations (S2) |
| template note tag + `PHASE_MD_TEMPLATE_FALLBACK` | architecture (S2) |
| smoke pin lists (contract, parallel-phase, design-cowork, review-phase, executor), Test 0 labels, 180 baseline | qa (S2, S3, S4) |

**The smaller skill edits change no durable truth:**

- **D-3** (`parallel-phase`: "relay a hint, run nothing"). The docs already say it: `docs/current/operations.md:104,:963` and `decisions.md:73`. S3 recorded the same judgment.
- **D-4** (do-* list `research` among the delegated kinds). `operations.md:404` already says `research` routes to `slice-executor-high` by kind.
- **README pointers.** The READMEs are not durable docs, and the fact they now point at is covered by the S2 architecture note.

**The list is complete.** The review adds no note of its own (`(none from P23.REVIEW …)` appended).

## 6. Notebook against the logs

Every decision a `result.md` records is either in `## Decisions` or was consumed on purpose:

- DECOMP's six decisions: research-first, target, scope, release, D8 at review, gate waived.
- S1: destination classes; target reachable, since replaced by *Target met*; executor growth; pins; OQ1.
- DECOMP2: the S2 → S3 → S4 cut (in *Research-first cut*) and *OQ1 answered*.
- S2:
  - the carve-out lists naming docs (the OQ1 line);
  - the measured growth (the executor-growth line);
  - HR-7b's N29 sentence (consumed: S4 moved N29 into *Driving*, and the floor note records it).
- S3: *The design family …* and the stub sizes.
- S4:
  - *Contract shape*;
  - N45/N46 stated once (in the floor note);
  - *Target met*.

The drift items D-1 to D-7 were consumed by S2–S4, each closed in its own `result.md`: D-1 landed, D-2 cut, D-3/D-4/D-6 fixed, D-5 no edit, D-7 held.

One judgment was recorded only in a log: S3's "D-3 owes no operations.md line". §5 confirms it, and this review writes it into `## Decisions` together with the D-4 judgment. There is no dropped decision.

## 7. Operator Questions

- **OQ1** is routed. It was answered at the DECOMP2 plan gate (2026-09-28), and the notebook records that on its own line. P23.S2 landed it in both executor bodies, in the approved wording (§2c).
- The other entries are `(none from …)` lines. **No unrouted entry.**
- This review raises no question.

## 8. D13

- The trigger fired in P23.S3, when the Aside bullet collapsed to its stub.
- The sentence "The same holds whichever browser is driven: an agent never drives a profile signed into the operator's accounts." occurs once in `CLAUDE.md` (`:49`) and once in `e08bd7a:CLAUDE.md`. It is byte-identical.
- D13's scope description is still true: the clause lives in the contract and `design-cowork`, and the executor bodies and `review-phase` stay Aside-only.
- D13 is **not resolved** and stays open for the operator's decision. `works/deferred/` was not touched.

## 9. Deferred-job candidates (the orchestrator files these; I ran no `defer-job`)

1. **Slim the executor bodies.**
   - *Reason:* each body is 28.6 KB and is now 70% of the 40,844 B per-dispatch prefix. The review bullet (`:36`, 4,113 B) restates `review-phase`. The implementation and mockup bullets (`:32`–`:33`, ~4.1 KB) restate `design-cowork`'s Aside and runtime text. Any cut needs a rule-to-reader map like P23.S1's, because an executor cannot invoke a skill (it can only Read one).
   - *Trigger:* the next phase that edits either executor body for content, or when the operator next targets per-dispatch cost.
2. **Match the contract's smoke pins whitespace-normalized.**
   - *Reason:* Test 0 asserts the 38 contract pins as raw substrings, so each must sit on one line. Every future rewrap of a stub risks a false failure. The design-cowork and parallel-phase lists already flatten whitespace.
   - *Trigger:* the next time a contract pin breaks on a line wrap, or together with job 3.
3. **Pin the never-rule floor in smoke.**
   - *Reason:* by phrase overlap, about **44 of the 58** never-rules have no contract pin. Examples: N1 never push, N5 `docs/versions/`, N35 deferred jobs, N39 executors never run `accept-gate`, N57 the installer rebuild. A later edit could drop one silently. P23.S4's `result.md` §3 is a ready list of phrases.
   - *Trigger:* the next edit of `CLAUDE.md`, or when job 2 re-points the contract pins.
4. **Correct two stale one-liners: `new-slice`'s help and `executors.toml`'s tier comment.**
   - *Reason:*
     - `workflow.py --help` lists `new-slice` as "Create a new slice folder with slice.json + markdown files". It writes only `slice.json` (`workflow.py:1446`), and the contract says neither context file is scaffolded (`CLAUDE.md:38`). P23 made `--help` the command reference, so the stale line now carries more weight.
     - The seeded `executors.toml` header says `high` takes "decomposition, the phase review, and essentially all code writing" and omits `research`.
     - The engine behaves correctly and the contract states the rule correctly, so neither line misleads an agent that reads the contract. That is why this is a deferred job and not a fix slice.
   - *Trigger:* the next edit of `workflow.py`'s argparse help or of `executors.toml`, or the next docs phase.
5. **A running phase stays `planned`, so the engine's `in_progress` readers never see it.**
   - *Reason:* `start-slice` never promotes the phase, and no skill runs `set-phase-status <P> in_progress`. P22 and P23 both ran every slice with `phase.json` at `planned` (the backlog shows `[ ] planned`). Three places read `in_progress` and cannot see a live default-stream phase:
     - `new-phase`'s hint (`workflow.py:1411`);
     - `next`'s worktree hint (`:2399`);
     - `parallel-gate`'s "default stream is quiet" check (`:2074`, `BUSY_PHASE_STATUSES`), which could report a quiet default stream while a phase is mid-execution there.
   - This is outside P23's boundary: P23 changed only argparse help in `workflow.py`. So it is an observation, not verified further.
   - *Trigger:* before the next `parallel-start` or `parallel-gate` on a real phase, or the next edit of `start_slice` / `parallel_start_hint`.

## 10. Considered and not findings

- **Push wording.** The contract now says only "Never push without being asked", while `parallel-phase:70,:266` keeps the remote variant "when the operator asks or repo policy requires". The old contract carried that same pair, so nothing new was introduced, and the contract side is the stricter one. Each push still passes the permission prompt.
- **`accept-gate --clear`.** The contract says "the operator clears it" and drops "or the orchestrator's on their explicit say-so". The do-* skills still carry the say-so. The two do not contradict each other.
- **"the doctrine's demands".** The phrase is pinned in the stub, but its old definition (type into it and wait, watch a timer tick, catch the browser defaults) now lives in `design-cowork:462,:538-544`. The stub still reads cleanly ("another real browser runs the same sweep"), and the executor gets the sweep through its plan.

## 11. Notebook edits (`phase.md`)

- **`## Decisions`:** added one *Review* line (the pass basis, the doc-impact completeness, and the D-3/D-4 no-durable-truth judgment).
- **`## Doc impact`:** added `(none from P23.REVIEW …)`.
- **`## Operator Questions`:** added `(none from P23.REVIEW; OQ1 routed …)`.
- **`## Notes for later slices`:** consumed all five entries addressed to the review, which leaves one placeholder line: the evidence pointer, the never-rule floor list (S4's `result.md` §3 remains the record), the deferred-job candidates (now §9 here), machinery discipline and D13.
- **`## Now`:** rewritten last.
- The generated `## Slices` block was not touched.
