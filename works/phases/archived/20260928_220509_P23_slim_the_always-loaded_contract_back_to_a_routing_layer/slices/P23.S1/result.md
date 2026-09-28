# Result — P23.S1 (research): map every contract rule to the reader that needs it

## Verdict

- **status:** done
- **summary:** Mapped all 166 `CLAUDE.md` rule units to their readers and carriers: 59 STAY, 37 SPLIT, 68 CUT, 2 MOVE. A measured throwaway probe holding all 58 never-rules came to 11,510 B, so the ≤ 12,288 B target is reachable. Recommended DECOMP2 cut: three `implementation/high` slices (derived cut + v44 → skill-owned bullets → rewrite to the outline).
- **files_changed:** `works/phases/active/P23/phase.md` (edited), `works/phases/active/P23/slices/P23.S1/result.md` (new)
- **validation:**
  - `python3 scripts/workflow.py validate` — passed, with the three pre-existing advisory warnings (P21/P22 `consolidation_owed`, `stale_docs`, `oversized_doc_sections`).
  - `bash tests/retrofit_smoke.sh` — one foreground run, the only command in its call, 600000 ms timeout — ended `ALL RETROFIT SMOKE TESTS PASSED`: 0 FAIL, **180 PASS** lines, with the count derived from the script as §8 explains.
  - `git status --porcelain` — shows only `phase.md`, this `result.md` and the files the orchestrator had already modified before dispatch.
  - The outline's section budgets add to 12,288 B.
- **deviations:**
  - (1) The PASS count comes from the script's structure, not from a grep of the run output. The single allowed run was piped to `tail -5`, which kept the final verdict but cut the count. The plan allows only one run, so there was no second one (§8).
  - (2) The throwaway contract probe (`/tmp/p23s1/proto5.md`, deleted at the end) goes beyond the plan's "budget from the words the stubs keep". It measures the outline instead of estimating it, and it stayed outside the repo.
- **doc_impact:** none — findings only.
- **headline numbers:**
  - Units: 166 over 49,856 B of rule text.
  - Dispositions: STAY 59 / 13,682 B · SPLIT 37 / 17,837 B · CUT 68 / 17,770 B · MOVE 2 / 567 B.
  - Target: ≤ 12,288 B, probe 11,510 B, so no floor question.
  - Executor bodies: ≈ +0.4 KB each, kept identical.
  - Per-dispatch prefix: 77,782 B → ~39.7–40.4 KB.
- **operator questions raised:** OQ1 — may a `docs` slice's executor run `doc-new-version`? The executor Never list forbids it today (§6 D-1).
- **recommended cut:**
  - `P23.S2` (order 3, implementation/high): cut `## Workflow Commands` plus every other CUT/MOVE unit outside HR-23/25/26; executor MOVEs + the D-1 carve-out; v44 opened. ~50.0 → ~36.6 KB.
  - `P23.S3` (order 4, implementation/high): collapse worktree / design / Aside to stubs; new `parallel-phase` pin list; D-3. ~36.6 → ~27 KB.
  - `P23.S4` (order 5, implementation/high): rewrite to the outline, then check all 58 never-rules. → ≤ 12,288 B.

The notebook carries the compact map, the outline, the never-rule list, the pin summary, the cut, drift, inbound references and deferred-job candidates (`works/phases/active/P23/phase.md`, *Notes for later slices*, the entries tagged `(from P23.S1 …)`). This file keeps the evidence behind them and does not restate them.

## 1. What was read

- Read in full: `phase.md`, `intent.md`, `CLAUDE.md`, `slice-executor-high.md` (the mid body was confirmed byte-identical by a frontmatter-stripped diff: `BODIES_IDENTICAL`), `do-whole-phase`, `do-next-slice`, `create-phase`, `review-phase`, `parallel-phase`.
- `design-cowork` in part: the loop, shape, mechanics, verifying and never sections.
- The small skills: `commit`, `archive-phase`, `doc-new-version`, `rotate-backlog`, `defer-job`, `promote-deferred`, `deferred`, `rebuild-workflow`, `retrofit`; the setup section of `explain`.
- `works/templates/phase.md` and `intent.md`; `workflow.py --help` and `-h` for the subcommands the contract describes.
- The engine refusals the contract claims: `workflow.py:390`, `:1204`, `:1351`, `:1503-1560`, `:1631-1656`, `:1866-1893`, `:2150-2163`, `:2244-2249`, `:2805-2812`.
- Smoke Test 0 (`:59-450`), Test 1 (`:519-521`), Test 6 (`:862-903`), Test 7 (`:905-914`).
- `installer/build.py` (`CLAUDE_HDR`, `FIXED_LIVE_FILES`) and `installer/main.py` (`_merge_contract`, the `--update` contract branch).
- The inbound references by grep; D8 and D13.
- Adopters, read only: each `CLAUDE.md` hash matched an upstream commit — changple5 → `0d06105`, changple_web → `c7f5dbb` (today's v43), Mijual and arb_upbit_1 → `bfc9a65`. None has a sidecar, so all four are stock copies that `/update-workspace` will replace outright.

## 2. Measurements (re-measured, not trusted)

| file | bytes | note |
|---|---|---|
| `CLAUDE.md` | 50,048 B / 49,646 chars | 402 B of multi-byte (`—`, `→`, `≠`, `≤`) |
| `.claude/agents/slice-executor-high.md` | 27,734 | |
| `.claude/agents/slice-executor-mid.md` | 27,717 | body identical to high |
| per-dispatch prefix (contract + high) | 77,782 | |
| design-cowork | 47,961 | largest destination |
| do-whole-phase / do-next-slice | 33,226 / 26,731 | |
| review-phase / parallel-phase | 20,982 / 20,073 | |
| create-phase / update-workspace | 11,897 / 8,251 | |
| retrofit / archive-phase / doc-new-version | 2,844 / 2,082 / 1,714 | |
| `works/templates/phase.md` / `intent.md` | 1,246 / 442 | |
| adopters' `CLAUDE.md` | changple5 49,121 · changple_web 50,048 · Mijual 43,480 · arb_upbit_1 43,480 | no sidecars |

Section bytes match DECOMP's starting facts exactly: Agent Contract 291, Driving 6,817, Read Order 996, Canonical State 2,413, Hard Rules 32,370, IDs 701, Workflow Commands 4,653, Commit Convention 1,794, header 13. Bullet sizes also match (`:78` 4,425, `:79` 3,807, `:76` 3,286 …), each 1 B higher than DECOMP's figure because these include the trailing newline. 15 of 17 skills carry `disable-model-invocation: true`.

## 3. Per-unit evidence

Method: each Hard Rules bullet, Driving paragraph, list item and Commit paragraph is one unit. The 20 long ones are split at sentence anchors into sub-units (letters in reading order); their byte counts sum exactly to the line. A coverage check asserted that every content line is counted exactly once (`missing lines []`).

Readers: `M` = main thread outside any skill (including ad-hoc machinery edits here); `S:x` = main thread inside skill x; `E*` = every executor dispatch; `E:kind` = the executor on that kind.

Carriers: `v` verbatim, `e` equivalent, `p` partial. The CUT test was "every reader that needs it gets it without the contract". The line, bytes, disposition and destination for each id are in the notebook's compact map; this table adds the evidence.

| id | gist | readers | already carried (file:line, v/e/p) | reasoning |
|---|---|---|---|---|
| AC-1 | what the contract is + core rule | M,E* | — (contract's own) |  |
| DR-1 | one manager, two ways in | M | wf --help | merge DR-2/3 into one stub + `--help` pointer |
| DR-2 | Claude Code slash commands + tiers; settings pre-approves the script | M | dns:12 e, dwp:12 e; .claude/settings.json | skill list stays; settings fact CUT (the file says it) |
| DR-3 | any agent / CI calls the script | M | wf --help | merged |
| DR-4a | /explain operator-invoked; review never runs it (pointer) | M,E:review | ex:36,:81 v; rp:73 v; xp frontmatter | keep operator-invoked + review-never; pointer string lives in ex/rp |
| DR-4b | /explain first-use hosted KB setup; asks first | S:explain | xp:144-165 v | keep 'asks before creating an external account'; setup detail CUT |
| DR-5a | orchestrator role; auto/gate/plan only; DECOMP plans at the gate by default | M,S:dns,S:dwp | dns:23-25 v, dwp:18-20 v | keep role + decomposition-at-gate default; modes CUT |
| DR-5b | a ready slice dispatches from its plan | S:dns,S:dwp | dns:22 v, dwp:18-19 v |  |
| DR-6a | tier routing: kind first, low→mid, bump up never down | S:dns,S:dwp,E* | dns:26 v, dwp:28 v, ex:14-15 e, wf new-slice --risk help e | keep routing core (never-down is a never-rule) |
| DR-6b | economy/flex presets, mode=flex, executors.toml overrides | S:dns | wf:111-119, executors.toml:6-31, dns:26 p | derived from code |
| DR-7a | executor works from plan.md, never commits or transitions | M,E* | ex:10 v, :54-55 v |  |
| DR-7b | background task; trusts done; review validates in boundary; docs verified | S:dns,S:dwp | dns:26-27 v, dwp:28 v, ex:62 v |  |
| DR-7c | stop on pending/needs_operator/blocked/failed-high; escalate once | S:dns,S:dwp | dns:28-32 v, dwp:18,:28 v | keep the stop list; escalation path CUT |
| DR-7d | review finishes judgment before branching; explain pointer | E:review,S:dns | ex:36 v, rp:55-58 v, :73 v |  |
| DR-7e | gated pass: --open, STOP, pass after --clear | S:dns,S:dwp,S:rp | dns:43 v, dwp:40 v, rp:60-69 v | core 'pass only after --clear' stays in HR-21 stub |
| DR-8 | skills explicit-only; design-cowork auto-fires; create-phase when instructed | M | cp:11 v; skill frontmatter | keep the three rules + confirmation gate; detail CUT |
| DR-9 | capture intent: refine → clarify → confirm | M | cp:15-31 e |  |
| DR-10 | making a phase ≠ executing it | M | cp:9 (cites this heading), :68 v | absorbs HR-9/HR-10; keep the bold heading (cp:9 cites it) |
| RO-1 | just in time | M,E* | ex:17 e | pin |
| RO-2 | next = pointer (stream-scoped; hint; parallel-status) | M | dns:10 v, dwp:10 v, pp:80-91 v | keep next + parallel-status; hint detail CUT |
| RO-3 | active phase + slice folder only | M | dns:10 e, ex:21-23 e |  |
| RO-4 | docs sections only; STALE; never whole set / index.json | M,E* | ex:25 v, dns:10 v | pin |
| RO-5 | history not by default | M | — |  |
| CS-1 | state.json stream-scoped; never another stream's | M | pp:137-147 v | keep 'never another stream's state.json' |
| CS-2 | generated dashboards: regenerated, not merged | M,E* | pp:150-151 v | never hand-edit generated |
| CS-3 | phase.json: acceptance fields, consolidation | M,E* | ex:24 v; wf accept-gate help | field list CUT |
| CS-4 | phase.md bounded state, budget, Slices block generated | M,E* | ex:22,:39-40 v; dc:147-148 v; wf:63,:1186,:1477 | 3 pins stay; v39 prose CUT |
| CS-5 | intent.md: verbatim + confirmed; source of truth | M,E* | ex:23 e, cp:47-59 v | absorbs HR-10 (immutable) + HR-11 |
| CS-6 | slice.json | M | — |  |
| CS-7 | plan.md + result.md + outcome | M,E* | ex:38,:62 e | absorbs HR-12a/c/d/f |
| CS-8 | deferred state path | M | dj:12 e |  |
| CS-9 | doc index / versions paths | M | dnv:12-23 e |  |
| HR-1 | keep backlog.md/deferred.md lean | — | engine renders both (wf rebuild) | derived: the files are generated |
| HR-2 | tests only for core behavior | M,E:impl,fix | dc:571 cites 'the contract's small-test-files rule' | only carrier; keep dc:571's referent |
| HR-3 | never patch docs/versions/ | M,E* | ex:50 v, dnv:23 v | floor |
| HR-4 | never hand-edit docs/current | M,E* | ex:50 v, dnv:23 v | floor |
| HR-5a | docs versioned in an operator-created docs phase; slices leave Doc impact notes | M,E* | ex:47-48 v, dns:49 v, dwp:37 v |  |
| HR-5b | review verifies; consolidation debt blocks archiving until docs-consolidated | E:review,S:rp,S:ap,E:docs | rp:35,:57 v; ap:32 v; ex:49 v; wf:2807 | only the contract authorizes a docs slice to run doc-new-version today (D-1) |
| HR-5c | docs-debt + create-phase docs-phase route | M,S:cp | cp:29,:70-89 v; dnv:12 v | keep the route pointer |
| HR-5d | staleness explicit; stale doc never current truth | M,E* | ex:25 v; wf:810; RO-4 stub | never-core already in RO-4 |
| HR-5e | review's one carve-out: two named sections | E:review,S:rp | rp:57 v, ex:50 v |  |
| HR-5f | worktree review writes nothing; post-merge writes gate notes | E:review,S:pp | pp:159-185 v, rp:12 v, ex:50 v, dns:41 v, dwp:37 v | pin → do-*/rp/ex ✓ |
| HR-6a | new phases start with DECOMP+REVIEW+intent.md | M | wf new-phase; cp:46 v |  |
| HR-6b | DECOMP creates bare folders, records breakdown, no plan.md pre-fill | E:decomp,S:dns,S:dwp | ex:35 v, :58 v; dns:37 v; dwp:35 v | never-core kept by CS-7 stub |
| HR-6c | --risk is the cost lever; low only for one-/few-line or docs | E:decomp,S:dns,S:dwp | dns:37 v, dwp:35 v, ex:14-15 e, wf --risk help |  |
| HR-6d | three design styles; build inventory; design-only deadline | S:dc,S:cp,S:dns,S:dwp,E:decomp | dc:69-158 v; cp:19-27 v; dns:37 v; dwp:35 v; ex:35 v (no build inventory) | keep 'design-only only at /create-phase' |
| HR-7a | research: findings-only kind; DECOMP2 usually follows | E:decomp,E:research | ex:34 v, :35 v; dns:37, dwp:35 v | keep 'writes no product code'; pin → ex ✓ |
| HR-7b | four things define the kind | — | — | connective |
| HR-7c | routes high by kind; kind wins | S:dns,S:dwp,E* | dns:26 v, dwp:28 v, ex:15 v, wf:47-53 | pin |
| HR-7d | findings land in phase.md | E:research | ex:34 v (pinned) | pin → ex ✓ |
| HR-7e | DECOMP2 usually follows | E:decomp,E:research | ex:34-35 v |  |
| HR-8 | DECOMP2 has two origins; never pre-planned; DECOMP3 | S:dns,S:dwp,E:decomp | dns:37 v, dwp:20,:35 v, ex:35 v, dc:90-92 (cites CLAUDE.md) | keep 2 pins + never pre-planned; dc:91's referent |
| HR-9 | make/create/suggest = create-phase, then stop | M | cp:68 v | duplicate of DR-10 |
| HR-10 | refine → clarify → confirm; no new-phase before confirm; verbatim immutable | M,S:cp | cp:15-59 v | nevers merged into DR-9/10 + CS-5; procedure CUT |
| HR-11 | consult intent.md when unsure | M,E* | ex:23 v | merged |
| HR-12a | each slice owns exactly two files, none scaffolded | M,E* | ex:38 v; wf:1446 | merged |
| HR-12b | plan.md persistence (inline vs byte-exact copy) | S:dns,S:dwp | dns:23-25 v, dwp:18-19 v |  |
| HR-12c | result.md verdict block first | E* | ex:38 v (pinned) | pin |
| HR-12d | never pre-fill another slice's plan.md | M,E* | ex:58 v | never |
| HR-12e | no per-slice brief/review files | — | wf new-slice writes only slice.json |  |
| HR-12f | phase.md vs result.md divide by audience | E* | ex:38 e | one sentence stays |
| HR-13a | phase.md edited under budget, never merely appended | M,E* | ex:39 v | pin |
| HR-13b | per-section notebook rules | E*,M | ex:40-44 v; tpl:17-33 p (tag form drifts, D-6) | carried; fix tpl tag form (D-6) |
| HR-13c | compressing restorable; dropped decision = finding | E*,E:review | ex:46 v, rp:37 v | keep 'never drop a decision or question' |
| HR-14a | every slice dispatched; co-work inline, DesignSync never dispatched, mockup span | M,S:dns,S:dwp | dns:12,:26 v; dwp:12,:28 v; dc:393-399 v; ex:10,:33 v | 3 pins |
| HR-14b | mid only for low one-/few-line; kinds route high | S:dns,S:dwp | dns:26 v, dwp:28 v | duplicate |
| HR-14c | presets pointer; executors.toml + sync-agents | S:dns | dns:26 v | duplicate of DR-6b |
| HR-14d | orchestrator owns planning/transitions/commits; executor owns impl/notebook | M,E* | ex:10,:54-55 v | merged |
| HR-14e | trusts done; review verifies Doc impact | S:dns,S:dwp | dns:27 v, dwp:28 v, ex:62 v | duplicate of DR-7b |
| HR-14f | mid re-dispatched once to high; top tier never escalates | S:dns,S:dwp,E* | dns:31-32 v, dwp:28 v, ex:15,:66 v | keep 'top tier never escalates' |
| HR-15a | idle-window prep: read-only, no second executor, never delays | S:dwp | dwp:29-30 v | keep the read-only/no-second-executor core |
| HR-15b | reconcile against N's result | S:dwp | dwp:33 v |  |
| HR-15c | usually skip it for DECOMP/REVIEW/… | S:dwp | dwp:31 v |  |
| HR-15d | gate does not move; do-next-slice never prefetches | S:dns,S:dwp | dwp:29-30 v | never |
| HR-16 | selection by order; fractional --order; depends_on advisory | E:decomp,S:dns | dc:119,:154 p; wf:1417, --order type=float (help silent) | a DECOMP executor gets it nowhere else |
| HR-17a | pending: set it, report, STOP | M,S:dns,S:dwp | dns:14 v, dwp:16 v |  |
| HR-17b | pending halts selection; WAITING ON OPERATOR | M | dns:14 v, dwp:16 v; wf:2679 |  |
| HR-17c | resumes only after explicit operator input | M | dns:14 v, dwp:16 v | pin :444 |
| HR-17d | open gate clears with accept-gate --clear, never set-phase-status | M | dns:14 v, dwp:16 v, rp:65 v | operator-only command |
| HR-17e | design slice stops once/twice; engine can't tell | S:dns,S:dwp,S:dc | dc:43-67 v; dns:14,:26 v; dwp:16,:21-27 v | pin → do-*/dc ✓ |
| HR-17f | pending ≠ blocked | M,E* | dns:14 e |  |
| HR-18 | ready slices; validate errors without plan.md | S:dns,S:dwp | dns:22,:25 v; dwp:18-20 v; wf:1204 |  |
| HR-19 | deferred jobs never affect selection until promoted | M | dj:12 v, cp:39 v |  |
| HR-20a | verdict drives phase + REVIEW status | S:dns,S:dwp,S:rp | wf:1545-1560; rp:85 v; dns:44-47 v |  |
| HR-20b | a pass does not archive | S:dns,S:dwp | dns:45 v, dwp:45 v |  |
| HR-20c | archiving manual; three commands; whole phases only | M | ap:10-30 v; wf --help | keep manual + whole-phase-only |
| HR-20d | gated pass refused until cleared; failures never refused | S:rp,S:dns | wf:1503-1520; rp:67,:85 v | keep 'engine refuses until --clear' |
| HR-20e | consolidation pending blocks archiving | S:ap | wf:2807-2812; ap:32 v |  |
| HR-21a | gate declared at DECOMP, never by omission | M,S:dns,S:dwp | dns:39 v, dwp:35 v | pin |
| HR-21b | undeclared pass refused; names both flags | — | wf:1516-1520 refusal |  |
| HR-21c | design phase gate follows its mockup (fixed waive note) | S:dns,S:dwp,S:dc | dns:39 v, dwp:35 v, dc:350-355 v | pin → do-*/dc ✓ |
| HR-21d | walkthrough → --open → STOP → --clear → pass; failures → fix slices | S:dns,S:dwp,S:rp,E:review | dns:43 v, dwp:40 v, rp:60-69 v, ex:36 v |  |
| HR-21e | accept-gate: executors never run it | M,E* | ex:55 v, rp:71 v, wf help | operator/orchestrator-only |
| HR-21f | legacy phase passes with advisory | E:review | wf:1510-1515; ex:24 v |  |
| HR-22a | ## Operator Runtime manifest is durable truth | M,E* | ex:25,:32 v; ops seed | pin |
| HR-22b | verify in that runtime (+prod); absent/UNFILLED → needs_operator | E:impl,fix,mockup,review | ex:32-33 v, dc:469-480 v, rp:48 v | never assume a runtime |
| HR-23a | Aside is the instrument, in place of a pre-written suite | M,E* | ex:32 v, dc:482-483 v, rp:49 v | pin |
| HR-23b | the doctrine's demands are agentic browsing | S:dc | dc:535-542 v |  |
| HR-23c | two surfaces, not three | S:dc | dc:484-491 v (pinned) | pin → dc ✓ |
| HR-23d | default aside repl over Bash; MCP costs ~1,344 tokens | E*,S:dc | dc:493-505 v (pinned); ex:32 v | keep 'never a standing aside mcp registration'; 2 pins → dc ✓ |
| HR-23e | MCP registration is an operator escape hatch | S:dc | dc:511-513 v (pinned) | pin → dc ✓ |
| HR-23f | design-cowork carries invocation/preamble/edges | M | — |  |
| HR-23g | instrument and runtime are different axes | E*,S:dc | dc:531-533 e; ops seed 'its absence alone never stops a slice'; ex:32 e | pin → dc + (new phrase) |
| HR-23h | dedicated profile: --account every call; third halt; never borrow | M,E* | ex:32 v, dc:515-533 v, rp:49 v | 4 pins; floor |
| HR-23i | any browser: never a profile signed into the operator's accounts | M,E* | dc:548-549 v only (ex/rp Aside-only) | verbatim, D13 scope |
| HR-23j | fallback: the doctrine's demands bind; name the instrument | M,E* | ex:32 v, dc:544-550 v | pin |
| HR-24a | operator questions go on ## Operator Questions | M,E* | ex:22,:34 v; tpl:25 v; dc:581-582 v | pin |
| HR-24b | every entry routed at review; unrouted can't pass | E:review,S:rp | ex:36 v, rp:38,:52 v | may-not-pass |
| HR-24c | gated review opens the product itself; fresh eyes; regression lines | E:review,S:rp | ex:36 v, rp:44-53 v | keep 'never on other slices' reports alone' + 'never silent fixes' |
| HR-24d | the boundary; phase-scope; outside = observation | E:review,S:rp,S:dc | ex:36 v (pinned), rp:16-18 v, dc:552-558 v | pin → ex ✓ |
| HR-24e | product-wide sweep = operator QA phase | M,E:review | cp:91-95 v, rp:18 v | pin |
| HR-25a | default stream unless asked; phase = unit; never fan out slices | M | pp:10-28 v; dns:16 v; dwp:10 v | pin |
| HR-25b | rule 1 — when: only on the operator's word | M,S:dns,S:dwp,S:cp | pp:38-41 v, :82 v; dns:16 v; dwp:10 v; cp:61-66 v | core stays; 2 pins → pp (new list) |
| HR-25c | rule 2 — where | S:pp | pp:42-44 v, :120-122 v |  |
| HR-25d | rule 3 — the stamp commit | S:pp | pp:45-47 v, :106-119 v |  |
| HR-25e | rule 4 — what stays behind | S:pp | pp:48-49 v |  |
| HR-25f | rule 5 — what still refuses | — | wf:1866-1893 refusals; pp:50-53 v |  |
| HR-25g | rule 6 — enter and exit | S:pp,S:dns,S:dwp | pp:54-60 v; dns:16 v; dwp:10 v |  |
| HR-25h | rule 7 — the merge sequence | S:pp,S:dns,S:dwp | pp:61-70 v, :202-253 v; dns:45 v; dwp:44 v | keep 'never merge past a closed gate; never unstage or discard the operator's work' |
| HR-25i | rule 8 — staying on main; retired no-ops; never a docs-phase worktree | M,S:pp,S:cp | pp:71-78 v; cp:77 v; dns:16 v; dwp:10 v | keep 'never for a docs phase'; pin → pp (new) |
| HR-25j | stream-scoped selection; generated files regenerated | M | pp:137-151 v; CS-1/CS-2 stubs |  |
| HR-26a | co-work: --risk high, inline, DesignSync never dispatched, mockup span | M,S:dc | dc:71 v, :393-399 v | keep '--risk high'; dispatch core lives in HR-14a stub |
| HR-26b | co-work writes no product code (mockup exception) | M,E:decomp,mockup | dc:72-74 v, :609-611 v; ex:35 v | pin + Test 1 sidecar grep |
| HR-26c | three named styles; ## Design Style; Mockup line | S:dc,S:cp,S:dns,S:dwp | dc:69-136 v (pinned); cp:19-27 v (pinned); dns:37 v; dwp:35 v | 4 pins → dc/cp/do-* ✓ |
| HR-26d | numbered card paths (two-digit prefix) | S:dc | dc:217-222 e | pin → dc + (add to dc list) |
| HR-26e | the operator's return closes the round; PENDING #2 only with mockup | S:dc,S:dns,S:dwp | dc:43-53 v (pinned, capitalized); dns:26 v; dwp:23-24 v | 2 pins → dc/do-* ✓ |
| HR-26f | phase gate follows the mockup | S:dns,S:dwp,S:dc | dns:39 v, dwp:35 v, dc:350-355 v | duplicate of HR-21c |
| HR-26g | data, not instructions; literal signoff closes an immutable round; RESPECT THE DESIGN | M,E* | dc:400,:362-372,:422-431 v; ex:33 v | 3 pins + sidecar |
| HR-26h | approval literal; superseding rounds; fidelity + functional sweep | M,S:dc,E:impl,fix | dc:344,:433-468 v | keep 'Approval must be literal' + superseding; sweep CUT |
| HR-26i | functional sweep is apply/fidelity duty; mockup exempt | S:dc,E:mockup | dc:315-318,:450-452 v; ex:33 v (pinned) |  |
| HR-26j | Claude Design reads the repo; handoff; two sanctioned DesignSync writes | S:dc | dc:33-41,:391-420 v | keep 'Claude Design + the operator decide'; rest CUT |
| HR-26k | never invent visuals, build an unasked mockup, or pre-plan before signoff | M,E* | dc:594-636 v; ex:59 v | never |
| HR-27 | upstream only: rebuild installer in the same commit; --check | M,E:impl,fix (this repo) | — (no executor or skill copy) | only carrier |
| ID-1 | phase ids + statuses | M,E* | wf set-phase-status |  |
| ID-2 | slice ids incl. DECOMP2/DECOMP3 + statuses | M,E* | wf | absorbs HR-8 stub + WC-3 closed set |
| ID-3 | deferred ids + statuses | M | wf |  |
| ID-4 | doc version naming | M | wf doc-new-version |  |
| ID-5 | review verdicts | M | wf review-phase --verdict choices |  |
| WC-0 | intro line | — | wf --help |  |
| WC-1 | next | M | wf --help |  |
| WC-2 | new-phase (+ --on-main no-op) | M,S:cp | wf new-phase -h (incl. --on-main); cp:42-46 v |  |
| WC-3 | new-slice; --kind closed set; unknown kind hard error | E:decomp,S:dns | wf new-slice -h v; wf:1351; smoke :620,:751 functional | 2 pins stay in IDs |
| WC-4 | start/finish-slice --outcome | S:dns,S:dwp | wf finish-slice -h v; dns:33 v; dwp:36 v; ex:62 v | pin → do-* ✓ + Test 9 functional |
| WC-5 | set-phase-status | S:dns | wf --help |  |
| WC-6 | pending hand-off commands | M | HR-17 stub; dns:29 v | duplicate |
| WC-7 | review-phase | S:dns,S:rp | wf -h; rp:77-83 v |  |
| WC-8 | accept-gate flags | S:dns,S:dwp | wf accept-gate -h v (incl. 'executors never run it') | never-core stays in HR-21e |
| WC-9 | doc-new-version/docs/rebuild-docs; docs phase only; default stream | S:dnv,E:docs,review | wf -h; wf:390 refusal; dnv:12 v | never-core stays in HR-5a |
| WC-10 | docs-debt / docs-consolidated | S:cp | wf -h v; cp:74,:87 v |  |
| WC-11 | deferred / defer-job | S:dj | wf -h; dj:10 v |  |
| WC-12 | promote/drop-deferred | S:pd | wf -h; promote-deferred:10 v |  |
| WC-13 | parallel-start (only when asked) | S:pp | wf -h v; pp:93-129 v | never-core stays in HR-25b |
| WC-14 | parallel-skip (no-op) | — | wf -h v |  |
| WC-15 | parallel-status | M | wf -h v; pp:134 v |  |
| WC-16 | parallel-gate | S:pp | wf -h v; pp:207-216 v |  |
| WC-17 | parallel-merge-finish | S:pp | wf -h v; pp:232-239 v |  |
| WC-18 | parallel-consolidated | S:pp | wf -h v; pp:255-258 v |  |
| WC-19 | parallel-teardown | S:pp | wf -h v; pp:250-252 v |  |
| WC-20 | phase-scope | E:review,S:rp | wf -h v; rp:18,:27 v; ex:25,:36 v | pin → rp/ex/dc 'phase-scope <P>' ✓ + functional :1002 |
| WC-21 | archive-all / rotate-backlog / archive-phase | S:ap | wf -h v; ap:10-30 v |  |
| WC-22 | rebuild / validate | M | wf -h v |  |
| WC-23 | sync-agents (says 'four' files — there are two) | M | wf -h v; executors.toml:4,:28 | drift D-5 goes with it |
| CC-1 | type(scope): summary; types; merge(P<N>) | M | commit:10 p; pp:228 v (merge msg) |  |
| CC-2a | commit per slice; else only when asked; attribution; no branches; never push | M | dns:35 v, dwp:38 v, commit:12 p | floor (never push) |
| CC-2b | phase branch exists only because asked; local merge | S:pp,S:dns,S:dwp | pp:10-32,:202-253 v; dns:35 v; dwp:38 v | 'a worktree they asked for is its branch' clause stays |
| CC-2c | push only when asked; remote variant; git push deny note | M,S:pp | pp:263-281 v | keep 'never push without being asked'; variant + deny note CUT |

## 4. Never-rule sweep

- **Method.** Every contract line was split at sentence and semicolon boundaries. A clause was a hit if it matched `never|do **not**|do not|don't|only when|must|refuse|STOP|confirm|only after|may not|cannot`. That found **115 clauses on 40 lines**; line 78 alone had 18. The commands reserved for the operator or orchestrator were added: `accept-gate --clear`, `parallel-start`, `new-phase`, push, archiving, docs phases, `docs-consolidated`, `defer-job`, `drop-deferred D8`.
- **Result.** These collapse to the 58 rules in the notebook (N1–N58). Each is kept by one of the notebook's stubs. As proof, each rule's key phrase was checked present verbatim in the 11,510 B probe, and all 58 hit (`58 rules; missing in probe: []`):

| id | phrase present in the measured 11,510 B probe |
|---|---|
| N1 | `Never push without being asked` |
| N2 | `commit only when asked` |
| N3 | `never to one that didn't` |
| N4 | `Do not create branches unless the operator asks` |
| N5 | `Never patch old files under `docs/versions/`` |
| N6 | `never hand-edit `docs/current/*.md`` |
| N7 | `never hand-edited` |
| N8 | `in a docs phase the operator creates**, never per slice` |
| N9 | `in a phase worktree, not even those` |
| N10 | `never current truth` |
| N11 | `never the whole doc set up front, and never `docs/index.json`` |
| N12 | `never on the agent's own initiative` |
| N13 | `**confirm** before acting` |
| N14 | `run `new-phase` only after the operator confirms` |
| N15 | `Do **not** decompose, write slice plans or implement` |
| N16 | `the phase review never runs it` |
| N17 | `so it always asks first` |
| N18 | `never by the orchestrator` |
| N19 | `*DesignSync* work is never dispatched` |
| N20 | `The executor never commits` |
| N21 | `bump up, never down` |
| N22 | `the top tier never escalates` |
| N23 | `stops the run` |
| N24 | `plans at the operator's gate by default` |
| N25 | ``do-next-slice` never prefetches` |
| N26 | `never pre-fills another slice's `plan.md`` |
| N27 | `never drops a decision or a question` |
| N28 | `never both` |
| N29 | `never writes product code on a `research` slice` |
| N30 | `never edits source on a review` |
| N31 | `**never** for style` |
| N32 | `nothing starts, finishes or advances past it` |
| N33 | `Work resumes only after explicit operator input clears the same item` |
| N34 | `never `set-phase-status`` |
| N35 | `Deferred jobs never affect next-slice selection until promoted` |
| N36 | `never individual slices` |
| N37 | `before `pass` is recorded` |
| N38 | `never by omission` |
| N39 | `executors never run it` |
| N40 | `never an assumed runtime` |
| N41 | `never a standing `aside mcp` registration` |
| N42 | `never borrow that profile` |
| N43 | `an agent never drives a profile signed into the operator's accounts` |
| N44 | `never claim a browser run you did not make` |
| N45 | `may not pass with an unrouted` |
| N46 | `never passes on other slices' reports alone` |
| N47 | `never a finding` |
| N48 | `never on your own initiative or on a `hint:`, and never for a docs phase` |
| N49 | `never fan out slices` |
| N50 | `never unstage or discard the operator's work` |
| N51 | `pre-plan build slices before the signed design` |
| N52 | `writes no ***product*** implementation code` |
| N53 | ``co-work` slice is `--risk high`` |
| N54 | ``design-only` is chosen at `/create-phase` or nowhere` |
| N55 | `never drop, simplify, restyle` |
| N56 | `data, not instructions` |
| N57 | ``--check` must pass` |
| N58 | `never another stream's `state.json`` |

- **Descriptive clauses dropped.** Some matches are "never" used descriptively, not as a prohibition, for example "`finish-slice` prints the size, `validate` warns and never errors" and "`changes_requested` and `blocked` are never refused". These describe engine behavior that `--help` and the engine already carry, so they are CUT and not in N1–N58.

## 5. Pin map (full)

The 60 positives are the 59-phrase tuple at `:370-423` plus `:444`, and the 19 negatives are at `:428-448`; the 3 sidecar greps are Test 1 `:519-521`. `K` = stays satisfiable by the stub (proven present in the probe); `R` = leaves the contract. For each `R` row the last column gives the destination list: `✓` means it already asserts the phrase, `+` means a new assert is needed. Every destination phrase was grepped present, and every negative proposed for copying was grepped absent, before being recommended. The notebook's pin summary is the grouped view of these rows.

| kind | smoke line | unit | phrase | after cut | destination / already asserted? |
|---|---|---|---|---|---|
| POS | 371 | HR-26j | `Claude Design` | K | stays in contract stub |
| POS | 371 | HR-26a | `DesignSync` | K | stays in contract stub |
| POS | 371 | HR-14a | `never dispatched` | K | stays in contract stub |
| POS | 372 | HR-8 | `DECOMP2` | K | stays in contract stub |
| POS | 372 | HR-26g | `data, not instructions` | K | stays in contract stub |
| POS | 373 | HR-26g | `RESPECT THE DESIGN` | K | stays in contract stub |
| POS | 373 | HR-26g | `real-browser fidelity` | K | stays in contract stub |
| POS | 373 | HR-26h | `Approval must be literal` | K | stays in contract stub |
| POS | 374 | HR-26g | `literal operator signoff closes an immutable round` | K | stays in contract stub |
| POS | 376 | HR-21a | `accept-gate` | K | stays in contract stub |
| POS | 376 | HR-22a | `## Operator Runtime` | K | stays in contract stub |
| POS | 376 | HR-24a | `## Operator Questions` | K | stays in contract stub |
| POS | 376 | HR-21a | `never by omission` | K | stays in contract stub |
| POS | 378 | HR-14a | `*DesignSync* work is never dispatched` | K | stays in contract stub |
| POS | 378 | HR-14a | `mockup build is its one dispatched span` | K | stays in contract stub |
| POS | 379 | HR-26b | `writes no ***product*** implementation code` | K | stays in contract stub |
| POS | 380 | HR-26c | `**`build-after`**` | R | ✓dc |
| POS | 380 | HR-26c | `**`design-only`**` | R | ✓dc |
| POS | 380 | HR-26c | `**`paired`**` | R | ✓dc |
| POS | 380 | HR-26c | `## Design Style` | R | ✓cp,do |
| POS | 381 | WC-3 | ``--kind` is a **closed set**` | K | stays in contract stub |
| POS | 385 | HR-26e | `the operator's return closes the round` | R | ✓dc (capitalised) |
| POS | 385 | HR-26e | `PENDING #2 exists only when a mockup was requested` | R | ✓do,dc |
| POS | 386 | HR-21c | `design-only, no mockup: the operator signed the round on the card set` | R | ✓do,dc |
| POS | 387 | HR-26c | `Mockup: requested` | R | ✓cp,do,dc |
| POS | 387 | HR-26d | `two-digit reading-order prefix` | R | +dc |
| POS | 388 | HR-25b | `Worktree rules` | R | +pp (new list) |
| POS | 388 | HR-25b | `**When — only when asked**` | R | +pp (new list) |
| POS | 388 | HR-25i | `retired no-ops` | R | +pp (new list) |
| POS | 389 | HR-25a | `unless the operator asks for a worktree (v43)` | K | stays in contract stub |
| POS | 389 | HR-5f | `(gate section — written at merge)` | R | ✓do,rp,ex |
| POS | 391 | RO-1 | `Just in time, and only what the work in front of you needs` | K | stays in contract stub |
| POS | 392 | RO-4 | `never the whole doc set up front, and never `docs/index.json`` | K | stays in contract stub |
| POS | 393 | CS-4 | `**bounded state**` | K | stays in contract stub |
| POS | 393 | CS-4 | `PHASE_MD_BUDGET` | K | stays in contract stub |
| POS | 393 | CS-4 | `a soft ~100k-token cap (400 KB)` | K | stays in contract stub |
| POS | 394 | HR-13a | `every slice **edits** it under budget` | K | stays in contract stub |
| POS | 394 | HR-12c | `structured verdict block first` | K | stays in contract stub |
| POS | 395 | WC-4 | `finish-slice P1.S1 --outcome` | R | ✓do (`finish-slice <slice_id> --outcome`) + Test 9 |
| POS | 398 | HR-7a | `**`research` is a findings-only slice kind, and a `DECOMP2` usually follows it.**` | R | ✓ex (`**Research slice (`kind: research`):** findings-only`) |
| POS | 399 | HR-7c | `if the two ever disagree the **kind wins**` | K | stays in contract stub |
| POS | 400 | HR-7d | `**findings land in `phase.md`**` | R | ✓ex (`in `phase.md`, where the next slice will actually read them`) |
| POS | 401 | HR-8 | `**`DECOMP2` has two origins**` | K | stays in contract stub |
| POS | 401 | HR-8 | ``P<N>.DECOMP3`` | K | stays in contract stub |
| POS | 402 | WC-3 | ``research`, `fix`, `docs`, `qa`, `co-work`` | K | stays in contract stub |
| POS | 407 | HR-23a | `**Real-browser verification runs through Aside, not a pre-written assertion suite.**` | K | stays in contract stub |
| POS | 408 | HR-23g | `**Instrument and runtime are different axes:**` | R | +dc (`a manifest naming no instrument still stops nothing`) |
| POS | 409 | HR-23j | `**the doctrine's demands bind, the instrument does not.**` | K | stays in contract stub |
| POS | 410 | HR-23c | `**Two surfaces, not three:**` | R | ✓dc (`**two surfaces, not three**`) |
| POS | 411 | HR-23d | `**The default is `aside repl` over Bash**` | R | ✓dc |
| POS | 412 | HR-23d | `~1,344 tokens` | R | ✓dc,ex |
| POS | 413 | HR-23e | ``claude mcp add -s local aside -- aside mcp` is an optional per-operator, per-session **escape hatch**` | R | ✓dc (split: the command + `escape hatch`) |
| POS | 416 | HR-23h | `**Whose browser: a dedicated profile.**` | K | stays in contract stub |
| POS | 417 | HR-23h | `pass `--account <id>` on every invocation` | K | stays in contract stub |
| POS | 418 | HR-23h | `is a **third** halt: `needs_operator` → `pending`` | K | stays in contract stub |
| POS | 419 | HR-23i | `an agent never drives a profile signed into the operator's accounts` | K | stays in contract stub |
| POS | 421 | HR-24d | `**The review reviews the boundary of the phase, not the whole system:**` | K | stays in contract stub |
| POS | 422 | WC-20 | ``phase-scope P1 [--base REF] [--head REF] [--json]`` | R | ✓rp,ex,dc (`phase-scope <P>`) + Test 8 functional |
| POS | 422 | HR-24e | `QA-sweep route` | K | stays in contract stub |
| NEG | 428 | — | `Prefer the **MCP** surface` | absent (stays absent) | keep in contract list; ✓dc |
| NEG | 428 | — | `scripted Playwright-style automation` | absent (stays absent) | keep in contract list; ✓dc,rp,ex |
| NEG | 429 | — | `runs through Aside, not a script` | absent (stays absent) | keep in contract list; +dc |
| NEG | 429 | — | `re-runs the whole cumulative` | absent (stays absent) | keep in contract list; +rp |
| NEG | 434 | — | `only PENDING #2 is an approval` | absent (stays absent) | keep in contract list; ✓dc (capitalised form) |
| NEG | 434 | — | `mechanical wait` | absent (stays absent) | keep in contract list; ✓do,dc |
| NEG | 434 | — | `can no longer be waived` | absent (stays absent) | keep in contract list; ✓do,dc |
| NEG | 436 | — | `runs in its own worktree by default` | absent (stays absent) | keep in contract list; +pp |
| NEG | 436 | — | `enters its worktree at **first execution**` | absent (stays absent) | keep in contract list; +pp |
| NEG | 439 | — | `for the fullstack doc set` | absent (stays absent) | keep in contract list; contract only |
| NEG | 439 | — | `appends phase notes/doc impact` | absent (stays absent) | keep in contract list; contract only |
| NEG | 440 | — | `appends durable cross-slice notes` | absent (stays absent) | keep in contract list; contract only |
| NEG | 445 | — | `design exception` | absent (stays absent) | keep in contract list; contract only |
| NEG | 445 | — | `never approval` | absent (stays absent) | keep in contract list; contract only |
| NEG | 445 | — | `no other pending gate` | absent (stays absent) | keep in contract list; contract only |
| NEG | 442 | — | `Codex` | absent (stays absent) | keep in contract list; ✓ex |
| NEG | 447 | — | `AGENTS.md` | absent (stays absent) | keep in contract list; ✓ex |
| NEG | 447 | — | `.agents/` | absent (stays absent) | keep in contract list; ✓ex |
| NEG | 447 | — | `.codex/` | absent (stays absent) | keep in contract list; ✓ex |
| POS | 444 | HR-17c | `Work resumes only after explicit operator input clears the same item` | K | stays in contract stub |
| SIDE | 519 | HR-26j | `Claude Design` | K | stays (design stub keeps it) — Test 1 unchanged |
| SIDE | 519 | HR-26b | `writes no ***product*** implementation code` | K | stays (design stub keeps it) — Test 1 unchanged |
| SIDE | 520 | HR-26g | `RESPECT THE DESIGN` | K | stays (design stub keeps it) — Test 1 unchanged |

## 6. Drift (detail)

- **D-1 — the executor bodies block a docs slice.**
  - `slice-executor-high.md:47` says "Docs are versioned **in a docs phase the operator creates — never per slice, and not at the review**". `:56` Never says "version docs on a non-review slice". `:55` lists the workflow commands an executor may run, and `doc-new-version` appears there only for the review slice.
  - But `create-phase/SKILL.md:79-87` has a docs phase cut "one slice per doc, `--kind docs`", each slice running `doc-new-version` → `rebuild-docs`, and `doc-new-version/SKILL.md:12` agrees.
  - The contract's `:58` is the only text that implies the carve-out ("until the docs phase has run `doc-new-version` per note").
  - No docs phase has run since the model changed: `events.jsonl` has 0 `docs_consolidated` events, and P21/P22 still owe. So the conflict is latent, not yet hit.
  - Which should win: the skills. It becomes OQ1 because the executor's Never list is a permission boundary.
- **D-2.** `CLAUDE.md:116` "the four `slice-executor-*` agent files". `EXECUTOR_TIERS` has two (`workflow.py:259-264`) and `.claude/agents/` holds two. The contract is wrong, and the line is cut anyway.
- **D-3.** `parallel-phase/SKILL.md:99-100` says "the do-* skills do this for you when `next` prints the hint". This contradicts `:82` ("Relay a hint to the operator; never act on it"), `do-next-slice:16` and `do-whole-phase:10`. It is a v42 leftover, and v43 should win.
- **D-4.** `do-next-slice:12` and `do-whole-phase:12` list "decomposition, implementation, `fix`, and the phase **review**" and omit `research`. The contract (`:20`, `:67`), the executor (`:10`) and the same skills' `:26`/`:28` include it, so the inclusive list wins.
- **D-5.** Not drift, a dependency. After DR-6b is cut, `do-next-slice:26` is the only prose statement of the economy/flex presets. It is correct (`workflow.py:111-119`), so keep it.
- **D-6.** `works/templates/phase.md:29` tags notes "`(from P<N>.Sk)`", while the contract (`:66`) and the executor (`:34`, `:43`) say `**(from <slice>, for <slice>)**`, and every live notebook uses the latter. The executor wins. The template has an embedded twin (`PHASE_MD_TEMPLATE_FALLBACK`, `workflow.py:1301`) that smoke asserts is byte-identical (`:948-958`), so both change together.
- **D-7.** `design-cowork:91` defers to "`CLAUDE.md`" for DECOMP2's two origins, and `:571` cites "the contract's small-test-files rule". These are valid only if the IDs stub keeps "**`DECOMP2` has two origins**" and HR-2 stays, and the outline keeps both.
- **Scope observation, no fix proposed.** The any-browser dedicated-profile clause (HR-23i) is carried only by the contract and `design-cowork:548-549`. The executor bodies and `review-phase:49` are Aside-only. This is D13's open question, so the stub keeps the clause verbatim and D13 stays open.

## 7. Engine facts behind the CUT column

- **Derived from the engine:**
  - `--kind` closed set: `workflow.py:1351` hard error; smoke `:620` / `:628` functional, `:751` validate warns.
  - Gated and undeclared pass refused: `_require_acceptance_cleared`, `:1503-1520`.
  - Verdict → phase + REVIEW status: `:1545-1560`.
  - Archiving blocked on pending consolidation: `:2805-2812`.
  - `ready` without `plan.md` errors: `:1204`.
  - `parallel-start` refusals: `:1866-1893`.
  - `doc-new-version` refused on a parallel stream: `:390`.
  - `PHASE_MD_BUDGET` = 400 KiB, warn-only: `:63`, `:1186`, `:1477`.
  - `new-slice` writes only `slice.json`: `:1446`.
- **Derived from `--help`:** every Workflow Commands bullet has a `-h` equivalent. `accept-gate`'s help even carries "executors never run it", and `new-phase -h` carries the `--on-main` no-op. Two things `--help` does *not* say: fractional `--order` (`type=float`, no help text) and "`depends_on` is advisory". That is why HR-16 is a MOVE into the executor's decomposition bullet, where the one reader that needs it (a DECOMP executor) will see it.
- **Not derivable:** HR-2 (core tests only) and HR-27 (the upstream installer rebuild) have no carrier outside the contract. Both STAY, and they are the two rules whose only reader is the ad-hoc main thread.

## 8. Smoke baseline

- **Method.** `bash …/tests/retrofit_smoke.sh 2>&1 | tail -5` was run once, foreground, as the only command in its call, with a 600000 ms timeout. It ended `ALL RETROFIT SMOKE TESTS PASSED` (exit path `FAILS=0`).
- **The count.** `tail -5` dropped the PASS count, and the plan allows one run, so the count is derived statically:
  - There are 155 `ok "` call sites, each printing one `PASS:` line.
  - No `ok` sits inside a heredoc or a command substitution.
  - The only loops that call `ok` are the dual-apply loops at `:870` and `:884`. They run over the 17 skill files and 10 fixed files, which gives 17 + 10 = 27 PASS lines where the call-site count sees 2. That makes 155 − 2 + 27 = **180**.
  - The three `|| ok` sites (`:699`, `:706`, `:911`) each print exactly one line either way.
  - With `FAILS=0`, no `bad` fired, so every `&& ok … || bad` pair took its `ok` branch.
- **Result: 180 PASS lines, 0 FAIL** (155 is only the call-site count). P22 closed at 158, before v40–v43 added tests. The next slice's first smoke run should `grep -c '^PASS'` to confirm 180 and adopt it as the baseline.

## 9. Probe and dead ends

- **Probe.** The throwaway contract probe was built in `/tmp/p23s1/` in five passes (9,273 → 10,017 → 10,357 → 11,433 → 11,510 B). Each pass restored a stub the never-rule check found missing (`/explain` consent, idle-window, gate-at-DECOMP, `accept-gate --clear`, never merge past a closed gate, `--risk high`, `design-only` deadline, the review boundary …). Its section sizes are the bracketed figures in the notebook's outline. It is evidence of reachability, not a draft: S4 writes the prose.
- **Pin scan.** The first pin scan tried to match phrases against `repr()`/JSON forms of smoke lines. The tuple was parsed directly with `ast.literal_eval` instead (59 phrases; the DECOMP note's "60" counts `:444`).
- **Loading mechanisms, considered and not recommended.** Contract `@import`s and path-scoped rule files were not recommended (the Scope decision forbids new loading mechanisms, and the 11.5 KB probe shows none is needed).
- **Cleanup.** All temp files (`/tmp/p23s1/`, `/tmp/p23s1_dns.txt`) are deleted.

