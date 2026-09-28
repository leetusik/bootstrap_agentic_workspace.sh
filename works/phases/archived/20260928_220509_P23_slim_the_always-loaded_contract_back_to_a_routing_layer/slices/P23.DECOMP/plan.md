# Plan — P23.DECOMP (decomposition)

## Context

P23 slims `CLAUDE.md` toward D8's ≤ 12 KB routing layer without losing a load-bearing rule. It is 50,048 B (49,646 chars), which is over Claude Code's 40k-char per-file warning floor, and it loads into every session and every executor dispatch. `works/phases/active/P23/intent.md` is the confirmed operator intent, so read it in full. Its step 1 fixes the shape of this decomposition: **research first**. Each rule gets mapped to the reader that needs it before anything is cut. That map decides which rules stay, move or go, and so it also decides how the editorial work is best sliced. So this DECOMP cuts one `research` slice and a `P23.DECOMP2` after it, and nothing else, the same way P21 did. Any edit slice cut today would be a guess that DECOMP2 has to re-cut.

## What to do

1. Read `intent.md`, the seeded `phase.md`, and the contract's research-kind and DECOMP2 bullets (`CLAUDE.md:60`–`:61`).
2. Create exactly two middle slices as **bare folders**. Never pre-fill their `plan.md`.
   - `python3 scripts/workflow.py new-slice --phase P23 --slice P23.S1 --name "map every contract rule to the reader that needs it" --kind research --risk high --order 1`
   - `python3 scripts/workflow.py new-slice --phase P23 --slice P23.DECOMP2 --name "cut the editorial slices from the rule map" --kind decomposition --risk high --order 2 --depends-on P23.S1`
   - Orders 3–9998 stay free for DECOMP2's slices. REVIEW is 9999.
3. Seed `phase.md` from the two lists below. Edit around the generated `## Slices` block, never inside it. The budget is the soft 400 KB cap, so write what the next slices need and don't squeeze.
   - `## Decisions`: the six decisions below, one line each, tagged `(P23.DECOMP)`.
   - `## Doc impact`: one line saying `(none from P23.DECOMP — decomposition changes no durable truth)`, plus the expected targets: architecture.md *Current Repo Shape*, operations.md installer build/release, qa.md *Test Commands* (where the prose invariants are pinned, smoke baseline), and decisions.md (why the contract slimmed and where its rules went).
   - `## Operator Questions`: `(none from P23.DECOMP)`.
   - `## Notes for later slices`: the tagged notes below.
   - `## Now`: rewrite it last, in ≤ 15 lines, as the handoff to S1.
4. Run `python3 scripts/workflow.py rebuild` and then `python3 scripts/workflow.py validate`. Both must pass.
5. Write `result.md` with the **structured verdict block first**. The cut's rationale lives in `phase.md`, so reference it from `result.md` instead of restating it.

### Decisions to record

1. **Research-first cut.** S1 is `research/high` and DECOMP2 is `decomposition/high`. DECOMP2 is gated by default (v40), so the operator sees the edit-slice cut, with the map in hand, before any contract text changes. "One editorial pass" (from intent) means this phase lands the whole reduction, with no under-40k stage first. How many slices that takes is DECOMP2's call.
2. **Target.** ≤ 12 KB means ≤ 12,288 B by `wc -c CLAUDE.md` (1 KB = 1,024 B, the same unit `PHASE_MD_BUDGET` uses). It is an aim, per the operator's pick "Aim for ≤ 12 KB". If the honest floor, with every never-rule kept, comes out higher, that number and its reason go to `## Operator Questions`. It is never a silent overshoot, and it is never paid for with a dropped rule.
3. **Scope.** This covers this repo's machinery and doctrine only. Adopters are evidence and are never edited.
   - The executor files may take on moved rules, and their two bodies stay byte-identical. They must not grow by more than the contract shrinks. Every shipping slice reports the per-dispatch prefix, which is `CLAUDE.md` plus one executor file: 77,782 B today with the high tier.
   - The goal is the contract. Executor bodies change only to receive a moved rule or fix a reference. Wider executor slimming is a follow-up that S1 may list as a deferred-job candidate.
   - No new loading mechanism, such as contract imports or path-scoped rule files. If one looks compelling, it becomes an Operator Question.
4. **Release.** This ships as workspace **v44**. `WORKSPACE_VERSION` goes 43 → 44 at `installer/main.py:38`, with one `## v44` CHANGELOG section that includes a Migration notes line. The first shipping slice opens that section and later slices append to it.
5. **D8 closes at review-pass time.** The orchestrator runs `drop-deferred D8 --reason "resolved by P23"`, following the P22 precedent for D14–D16. Executors never run it.
6. **Acceptance gate read: waive.** The phase touches machinery and doctrine only. There is no running product for the operator to walk.

### Notes to record (tag each `**(from P23.DECOMP, for …)**`)

- **For P23.S1: the research agenda.** S1 writes findings only, no machinery.
  1. Split the contract into rule units: each Hard Rules bullet, each Driving paragraph, and each item in the other sections. For each unit, record its line, its bytes, a one-line gist, and its readers (main thread outside any skill / main thread inside skill X / executor on slice kind Y). Also record where it is already carried (skill or executor body, verbatim or equivalent, `file:line`).
  2. Give each unit one disposition:
     - **STAY**: always-on main-thread routing, or a prohibition or gate core.
     - **CUT**: derived from code (`workflow.py --help`, engine refusals), or already carried everywhere every reader gets it.
     - **MOVE**: some reader lacks it. Name the destination.
     - **SPLIT**: the never-core stays and the procedure moves.

     Two destination tests apply. First, a skill body loads only when that skill runs, and 15 of the 17 skills (`disable-model-invocation: true`) run only on an explicit slash command. So a rule may move into a skill only if it matters solely while that skill runs. Second, anything an executor needs goes to the executor bodies or stays in the contract. It never goes into a skill, because executors can't invoke skills.
  3. List every never-rule, confirmation gate and operator-only command, and show that each one survives in the target. Intent step 4's list is the floor.
  4. Build the pin map: every smoke assertion that reads the contract, where its phrase lives after the cut, and whether that destination's pin list already asserts it.
  5. Check each inbound reference (listed below): is it still valid, or does it need re-pointing?
  6. Write a target outline: the sections, the rule stubs each section keeps (named, not drafted, because the prose is the editorial slice's job), and a byte budget per section totalling ≤ 12,288 B. If that total can't be reached, give the honest floor and the reason.
  7. Note drift: every place where the contract and a skill or executor body state a rule differently, and which statement should win. These are findings, not fixes.
  8. Recommend a cut for DECOMP2: slice count, what each covers, risk and order.
  9. Record baselines: `wc -c` of the contract, both executor files and every destination skill, plus the current smoke PASS count from one run.

  Where the findings land: `phase.md` gets the map in compact form (one row per unit: id, line, bytes, disposition, destination, pins), plus the outline, the never-rule list and the recommended cut. The per-row evidence stays in S1's `result.md` and is referenced by path.
- **For P23.S1: starting facts, measured at DECOMP.** Re-measure these rather than trusting them.
  - **Section sizes in bytes:** Agent Contract 291, Driving 6,817, Read Order 996, Canonical State 2,413, Hard Rules 32,370, IDs and Status 701, Workflow Commands 4,653, Commit Convention 1,794.
  - **Biggest bullets:** `:78` worktrees 4,424, `:79` design 3,806, `:76` Aside 3,285, `:58` docs phase 2,114, `:74` acceptance gate 2,078, `:59` new phases 1,982, `:77` questions/boundary 1,876, `:70` pending 1,588.
  - **Executor files:** high is 27,734 B and mid is 27,717 B. Their bodies are byte-identical, and only the frontmatter differs (smoke asserts this).
  - **Pins in `tests/retrofit_smoke.sh`:**
    - Test 0 reads the contract at `:369`. It holds 60 positive phrases at `:370`–`:424`: 49 in Hard Rules, 4 in Workflow Commands, 3 in Canonical State, 2 in Driving and 2 in Read Order. The densest lines are `:76` with 11, `:79` with 8, and `:59` and `:78` with 5 each. The `gone not in claude` negatives and one more positive follow at `:425`–`:448`.
    - Test 1 greps the retrofit sidecar `CLAUDE.workspace.md` for three contract phrases at `:519`–`:521`.
    - Test 6 diffs the contract against the embedded copy at `:884`.
    - Contract pins are **raw substring** checks, so a pinned phrase must stay on one line. The design-cowork check at `:145` normalizes whitespace, but the contract check does not.
    - A moved rule's pin can join an existing per-file list:
      - create-phase at `:82`
      - the do-next-slice and do-whole-phase checks at `:102`
      - design-cowork at `:145`, which is whitespace-normalized
      - review-phase at `:224`
      - the executor bodies at `:279`
    - `parallel-phase` has **no** pin list today. The five worktree pins would need a new one, and the pin map should say so.
  - **Inbound references:**
    - `create-phase/SKILL.md:9` cites *Making a phase ≠ executing it* "in the contract".
    - `design-cowork/SKILL.md:91` says "see `CLAUDE.md`" for DECOMP2's origins.
    - `parallel-phase/SKILL.md:31` says "the contract carries only the rules".
    - The executor bodies at `:27` and `:60` defer to the contract's safety rules.
    - `do-whole-phase:10`, `do-next-slice:10` and `review-phase:22` all read `CLAUDE.md`.
    - `README.en.md:266` ("the full command list lives in CLAUDE.md") and `:389` ("CLAUDE.md for the command reference") both go stale once Workflow Commands goes.
    - `README.md:216`, `:257` and `:277`.
    - `installer/README.md:45` and `:91` (`CLAUDE_HDR`).
    - The contract's own cross-references (*Driving This Workspace*, *Hard Rules*, *Orchestrator and executor*).
    - `docs/current/*` also cites the contract. Those are durable docs, so they get Doc impact notes only.
  - **Loading:** only `create-phase` and `design-cowork` are model-invocable. Every executor dispatch loads `CLAUDE.md` (per intent, 164 of 164 transcripts).
  - **Installer:**
    - `build.py` requires the first line to stay `# CLAUDE.md` followed by a blank line (`CLAUDE_HDR`, `:60`).
    - A retrofit writes the full contract to a `CLAUDE.workspace.md` sidecar and adds a pointer block (`installer/main.py:214`).
    - `--update` refreshes that sidecar, or overwrites a fresh-installed `CLAUDE.md` in place (`:331`).
    - All four known adopters carry a stock `CLAUDE.md` and no sidecar: changple5 on v42, changple_web on v43, Mijual and arb_upbit_1 on v41. So `/update-workspace` replaces their contract outright.
  - **Version:**
    - The CHANGELOG top section is `## v43`.
    - The reverted Kiro v44 (`eb42c7f`, reverted by `c7f5dbb`) was on `origin/main` for about 70 s on 2026-09-28. No known adopter synced it, so reusing v44 is safe.
    - Smoke asserts that `WORKSPACE_VERSION`, the top CHANGELOG heading and the fresh-install marker all agree, and that every CHANGELOG section has a Migration notes line (`:566`–`:594`).
- **For P23.DECOMP2: cutting constraints.**
  - Every edit slice is `implementation/high`, because each one is multi-file and needs the installer rebuild.
  - Every slice boundary must leave smoke green and `build.py --check` passing. So a contract cut and the re-pointing of its pins land in the same slice.
  - The v44 bump rides the first shipping slice.
  - There's no co-work, since nothing here is visual.
  - There's no further research unless S1 says a question is still open.
- **For every later slice and P23.REVIEW: machinery discipline.**
  - Any edit to `CLAUDE.md`, `.claude/*`, `scripts/workflow.py` or `works/templates/*` runs `python3 installer/build.py` in the same slice, and `--check` must pass (the pre-commit hook enforces it).
  - Run `bash tests/retrofit_smoke.sh` as the **only** command in its Bash call, in the foreground, with a 600000 ms timeout. Chained or backgrounded runs have stalled at 0 % CPU here.
  - P22 closed at 158 PASS. v40–v43 changed the suite after that, so S1 records the current baseline.
- **For the editorial slices and P23.REVIEW: D13 is triggered.** D13's trigger ("whenever the Aside doctrine is next edited") fires when the Aside text moves. The dedicated-profile rule keeps exactly the scope it has today, including the clause "an agent never drives a profile signed into the operator's accounts". Don't resolve D13; it stays open for the operator, and the review mentions that the trigger fired.

## Boundaries

- Create bare folders only, with no `plan.md` for S1 or DECOMP2. Don't start mapping either, because that is S1's work.
- Make no machinery edits. Don't run `accept-gate`, don't commit, and don't change any status beyond what `new-slice` does itself.

## Verification

- Both new slice folders hold only `slice.json` (check with `ls -la`).
- `rebuild` regenerates `## Slices` as DECOMP → S1 → DECOMP2 → REVIEW.
- `validate` exits 0. The advisory P21/P22 debt warnings are pre-existing and expected.
- Report `wc -c` of `phase.md`.

## Verdict

Return:
- status
- a short one-line summary for `finish-slice --outcome`
- files_changed
- validation outcomes
- the slices you cut (id / name / kind / risk / order)
- your acceptance-gate read, flagging anything that would change the expected waive
