# Plan — P23.S1 (research): map every contract rule to the reader that needs it

## Goal

Produce the evidence P23.DECOMP2 will cut the editorial slices from: a rule-by-rule map of `CLAUDE.md` saying who reads each rule, where it is already carried, and what happens to it (STAY / CUT / MOVE / SPLIT). Alongside the map, produce a target outline at ≤ 12,288 B (or the honest floor), the never-rule inventory, the smoke pin map and a recommended cut. This slice is findings only: no machinery changes.

The agenda is the 9-point note `(from P23.DECOMP, for P23.S1) Research agenda` in `phase.md`, and the starting facts are in the note after it. Follow both. This plan adds method and boundaries and does not restate them.

## Read

- `works/phases/active/P23/phase.md` whole and `intent.md` whole. This slice decides what gets cut next, so read the confirmed intent in full, including the scope boundary and the never-rule floor in step 4.
- `CLAUDE.md` whole, since it is the subject.
- `.claude/agents/slice-executor-high.md` whole. The mid body is byte-identical, so confirm that with a body diff instead of reading it twice.
- The candidate carriers and destinations, as the map needs them:
  - First, `.claude/skills/{do-whole-phase,do-next-slice,create-phase,review-phase,parallel-phase,design-cowork}/SKILL.md`.
  - Then any other skill a rule points to (`update-workspace`, `retrofit`, `archive-phase`, `doc-new-version`, `commit`, …).
  - `works/templates/phase.md` and `works/templates/intent.md`. Their section intros reach every slice that reads the notebook, so they count as a carrier too.
- `python3 scripts/workflow.py --help` and each subcommand's `-h`, plus the engine's refusals wherever a rule claims one (`scripts/workflow.py`). This is how you judge what is "derived from code".
- In `tests/retrofit_smoke.sh`: the per-file pin lists in Test 0 (`:72`–`:449`), the sidecar greps in Test 1 (`:519`–`:521`) and Test 6 (`:884`).
- In the installer: `installer/build.py` (`CLAUDE_HDR`) and `installer/main.py` (`_merge_contract`, and the contract branch of `--update`).
- The inbound references listed in the starting-facts note.
- Optional, read-only evidence: the four adopter repos, `/Users/sugang/projects/personal/{changple5,changple_web,Mijual,arb_upbit_1}`. Never edit them.

## Method

1. **Units.** Give every unit a stable id by section:
   - `AC-1` for Agent Contract and `DR-n` for the Driving paragraphs.
   - `RO-n`, `CS-n` and `ID-n` for Read Order, Canonical State and IDs.
   - `HR-n`, one per Hard Rules bullet.
   - `WC-n`, one per Workflow Commands bullet, and `CC-n` for Commit Convention.

   Split a long bullet into sub-units (`HR-25a`, `HR-25b`, …) wherever its clauses have different readers or dispositions. The eight biggest bullets almost certainly need this, and SPLIT only works if the never-core is its own sub-unit.
2. **Readers.** Use the three reader classes from the agenda. Where it applies, add a fourth: the main thread doing ad-hoc work outside any skill, such as answering an operator question or hand-editing machinery in this repo. Rules like the upstream installer rebuild and the commit convention bind there too. Every executor dispatch loads the contract (intent: 164 of 164), so "an executor needs it" never means "only while a skill runs".
3. **Where it is carried.** For each unit, grep its load-bearing phrases across the carriers. Record `file:line` and whether the copy is verbatim, equivalent or partial.

   For the CUT test, "carried" means **every reader that needs the rule gets it without the contract**. Each carrier reaches a different set of readers:
   - A skill carries a rule for the main thread only while that skill runs.
   - The executor bodies carry it for every dispatch.
   - The notebook template carries it for every slice.
   - `--help` carries it only for whoever runs `--help`.
4. **Destinations.** Allowed:
   - `CLAUDE.md`, as a stub.
   - The executor bodies, both of them, kept identical.
   - A skill, subject to test (a) in the agenda.
   - `works/templates/*`, in the section intros.
   - `workflow.py` help text or refusal messages, where the fact is about a command.

   Never destinations:
   - `docs/current/*`. Durable docs change only in a docs phase, and this phase leaves Doc impact notes instead.
   - The READMEs. No agent loads them.

   Record one finding here. The executor bodies already send an executor to a skill file by name: `slice-executor-high.md:32` to `design-cowork`, and `:36` to `review-phase`. A read directed by the plan is a real channel but not an always-loaded one. So it does not change intent's rule that a rule an executor needs never lives only in a skill.
5. **Never-rules.** Build the inventory by sweeping for `never`, `do not`/`don't`, `only when`, `must`, `refuse`, `STOP` and `confirm`. Also include every command the contract reserves for the operator or the orchestrator, for example:
   - `accept-gate --clear`
   - `parallel-start`, only on the operator's word
   - `new-phase`, only after confirmation
   - push only when asked
   - archiving, which is manual
   - docs phases, which the operator creates

   Map each entry to the target section and stub that keeps it. Intent step 4's list is the floor, not the whole list.
6. **Pin map.** Make one row per smoke assertion that reads the contract: all 60 positives, every `gone not in claude` negative, the extra positive at `:444`, and the three sidecar greps in Test 1. Each row gives:
   - the current line and the unit id
   - the destination after the cut
   - whether that destination's pin list already asserts the phrase

   A negative follows its rule: it moves to the destination's list, because that is where the retired phrasing could come back. Say explicitly what Test 1 should grep once the design phrases leave the contract (it needs a phrase that stays there). Flag every destination that has no pin list yet, such as `parallel-phase`.
7. **Outline and floor.** Budget each target section in bytes from the words its stubs must keep, meaning the never-core sentences, not from a wish. The total includes the `# CLAUDE.md\n\n` header, because `wc -c` counts it.

   If the honest total exceeds 12,288 B, say by how much and which rules force it. That becomes an Operator Question, not a quiet overshoot.

   Also project two numbers: how much the executor bodies grow from the MOVE-to-executor rows, and the resulting per-dispatch prefix compared with today's 77,782 B. Flag it if the bodies would grow by more than the contract shrinks.
8. **Drift and the recommended cut.** Cover agenda items 7 and 8 as the agenda asks. The cut must respect the DECOMP2 constraints note:
   - every edit slice is `implementation/high`
   - smoke stays green and `build.py --check` passes at every boundary
   - pins are re-pointed in the same slice as their rule
   - v44 lands on the first shipping slice

## Where the findings land

- **`phase.md`**, edited under its cap:
  - `## Decisions`: what the map settles, such as the target number or honest floor, the destination classes, and any disposition the phase must honour.
  - Notes tagged `**(from P23.S1, for P23.DECOMP2)**`:
    - the compact map, one row per unit: id, line, bytes, disposition, destination, pins
    - the outline with its byte budgets
    - the never-rule list
    - the pin-map summary: counts, plus every pin that is re-homed or at risk
    - the recommended cut
  - Remove the two notes tagged for P23.S1, since this slice consumes them. Keep the notes on DECOMP2 constraints, machinery discipline and D13.
  - `## Operator Questions`: append only genuine operator calls, such as a floor above 12,288 B or a disposition only the operator can judge. Items that evidence can answer stay findings.
  - Deferred-job candidates, such as wider slimming of the executor bodies: give a title, reason and trigger in a note tagged for P23.REVIEW. Don't run `defer-job` yourself.
  - `## Doc impact`: nothing, unless the research changes durable truth, which it should not.
  - `## Now`: rewrite it last, as the handoff to DECOMP2.
- **`result.md`**: the verdict block first. Then:
  - the full per-unit evidence: readers, carriers with `file:line`, and reasoning
  - the full pin map
  - the never-rule sweep
  - the drift list
  - measurements, commands and dead ends

  Anything already in the notebook gets a reference, not a restatement.

## Boundaries

- Findings only. Don't edit any of these: `CLAUDE.md`, any skill, either executor file, `works/templates/*`, `scripts/workflow.py`, `tests/`, `installer/`, `CHANGELOG.md` or the READMEs. Throwaway probes go in a temp dir outside the repo, and you delete them before you finish.
- No commits, no status transitions, no `defer-job`, no `accept-gate`, and no `new-slice` (cutting is DECOMP2's job).
- Run `bash tests/retrofit_smoke.sh` once. It must be the **only** command in its Bash call, in the foreground, with a 600000 ms timeout, and with nothing else touching the repo. Piping it to `| tail -3` is fine. Record the PASS count.

## Validation

- `python3 scripts/workflow.py validate` passes. The advisory P21/P22 warnings are already there and expected.
- `git status --porcelain` shows only `phase.md`, this slice's `result.md` and any engine-regenerated `works/` files. Nothing else in the tree has changed.
- The outline's section budgets add up to the total you report.
- The smoke baseline comes from that one run.

## Verdict

Return:
- status
- a one-line summary usable as the `finish-slice` outcome
- files_changed
- validation
- headline numbers: unit count, disposition totals, target total or honest floor, projected executor growth and per-dispatch prefix
- any Operator Questions raised
- the recommended cut, one line per slice
