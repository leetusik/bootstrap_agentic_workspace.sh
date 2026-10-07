# Plan — P30.DECOMP (decomposition)

## Context

P30 changes `/rotate-backlog` so that by default it proposes the docs phase that pays the doc-consolidation debt holding phases back from archiving. The operator's intent is recorded verbatim and confirmed in `works/phases/active/P30/intent.md`; read it in full first.

1. Archive every clean phase, as today.
2. Collect the phases whose **only** blocker is `consolidation: pending`.
3. Propose a docs phase for them: name, objective and scope drafted from `docs-debt`.
4. Ask the operator to confirm **once**. Their yes runs `new-phase` and fills `intent.md` the way create-phase's *docs-phase route* does. Then STOP.

Further requirements:
- An **opt-out word** (`/rotate-backlog archive-only`) keeps today's behaviour.
- The create-phase confirmation gate does not move.
- Never propose a duplicate docs phase.
- Phases with other blockers are reported, never turned into a phase.

At the time of writing, P25 is clean and P26–P29 are done and blocked only by debt (`docs-debt`: 46 notes over 4 docs).

## Footprint (read-only exploration, this session)

- **Engine `scripts/workflow.py`:**
  - `rotate_backlog` is at ~L3424. Its parser is at ~L4409 and has no flags today.
  - `_phase_blockers` is at ~L3334. It returns free-text reasons: unfinished slices, a review that is not `pass`, and `consolidation` still `pending`.
  - Helpers to reuse:
    - `phases_owing_consolidation` (~L1034), `consolidation_command` (~L1040) and `phase_consolidation` (~L959);
    - `stale_docs` (~L1046), which gives the per-doc rollup `docs-debt` prints;
    - `docs_debt` (~L2538), which is read-only and prints the worklist;
    - `all_active_phases` (~L849) and `phase_execution` (~L925).
  - `new_phase` is at ~L1717. Its parser is at ~L4231.
  - `WORKFLOW_CMD` is the printed command prefix; it is nested-aware.
- **Skills:**
  - `.claude/skills/rotate-backlog/SKILL.md` has frontmatter `disable-model-invocation: true` and `allowed-tools: Bash(python3 scripts/workflow.py:*)`. The new flow edits `intent.md`, so the allowed tools must cover that.
  - `.claude/skills/create-phase/SKILL.md` contains *The docs-phase route*. It should name rotate as an entry point, and `--consolidates` (below).
  - `.claude/skills/archive-phase/SKILL.md` L23/L32 describe rotate as "leaves it active".
  - `do-next-slice` / `do-whole-phase` mention `rotate-backlog` only in passing. Touch them only if a line becomes false.
- **Smoke `tests/retrofit_smoke.sh`:** it has no rotate-backlog test. The `docs-debt` fixture at ~L874–906 is the pattern to extend.
- **Release:** `WORKSPACE_VERSION` 50 → **51**, a `CHANGELOG.md` `## v51` entry, then `python3 installer/build.py` (`--check` must pass).

## The cut

Order **S1 → S2**, with `depends_on` chained, then `P30.REVIEW`. No research slice is needed, because every open point is pinned below.

- **`P30.S1` Engine: rotate-backlog proposes the docs phase** — implementation / **low**.
  - The approach is fully pinned below.
  - It adds one optional `phase.json` key with no migration. Archiving logic is untouched.
  - Scope: the engine, plus a small smoke probe.
- **`P30.S2` Skills, texts and release v51** — implementation / **low**.
  - Rewrite the rotate-backlog skill: the default flow and the opt-out word.
  - Update the create-phase docs-phase route, the archive-phase lines, the CHANGELOG `## v51`, and `WORKSPACE_VERSION = 51`.
  - Rebuild the installer.
  - Update smoke Test 0 pins, if any touched text is pinned.

**Acceptance gate:** `accept-gate P30 --require`. `/rotate-backlog`'s default behaviour is an operator-run surface.

## Decisions S1 must hold (record them compactly in phase.md `## Decisions`)

1. **`new-phase --consolidates P26,P27,…`** writes `"consolidates": ["P26", …]` into the new `phase.json`. The key is absent when the flag is not given, so older phases need no migration.
   - Refuse, with nothing written, when a named id is not an active phase owing consolidation.
   - It is the marker that a docs phase covers those phases. Nothing else reads phase names or intent text to detect a docs phase.
   - `validate` must accept the key.
2. **`rotate-backlog [--archive-only]`:** archiving and its output are **byte-for-byte as today**. After that, unless `--archive-only`, it prints a read-only **proposal block**:
   - **The phases it proposes for:** debt-only phases are the remaining active phases whose only `_phase_blockers` reason is the consolidation one: every slice done, review `pass`, `consolidation: pending`.
     - Restructure `_phase_blockers` minimally, for example with a reason kind, so this is a check rather than string matching. `archive-phase`, `archive-all` and rotate must keep identical refusal text.
     - A phase in parallel mode that has not merged yet is never debt-only.
   - **Already covered:** an active phase that is **not done** and whose `consolidates` intersects the debt-only set covers those phases. The block prints `docs_phase_covered=<PX> (pays P26, P27)` and proposes nothing for them.
   - **The proposal:** for the uncovered remainder, print key=value lines:
     - `docs_phase_proposal=P26, P27, P28, P29` and `phase=P<next>`. The next id is one above the highest phase number across active **and** archived phases; archived folder names carry `_P<N>_`, and `archive_manifest.json` has `phase_id`.
     - `name=Consolidate the doc impact of P26–P29`.
     - `objective=consolidate the '## Doc impact' notes from P26, P27, P28, P29 into new versions of <docs from stale_docs>`.
     - The exact command `{WORKFLOW_CMD} new-phase --phase … --name "…" --objective "…" --consolidates P26,P27,P28,P29`.
     - A pointer to `{WORKFLOW_CMD} docs-debt` for the scope.
     - A closing line saying the proposal wrote nothing and that the create-phase confirmation gate applies.
   - **Nothing to propose:** when there is no debt-only phase, print one line, `docs_phase=none`.
   - **Other blockers:** phases blocked for other reasons stay in today's `left N phase(s) active` line. They are never proposed.
   - **The no-done-phases path:** the `no done phases to rotate` early return must still print the block, because the debt-only phases are exactly what remains.
3. **`docs-debt`** adds one line per owing phase that a live docs phase already covers (`  paid by: P31 (in progress)`). This is the only change to it, and it stays read-only.
4. **Not touched:**
   - the archive gate itself, whether `_phase_blockers` blocks or not, and the archive manifest;
   - `archive-all` and `archive-phase` behaviour.
   - Rotate never runs `new-phase` itself; the skill does, after the operator's yes.
5. **Tests (core only).** Add one small smoke block next to the `docs-debt` fixture, with three probes:
   - (a) A debt-only phase makes rotate print `docs_phase_proposal=` and the exact `new-phase … --consolidates` command, and leave the phase active.
   - (b) After `new-phase --consolidates` for it, rotate prints `docs_phase_covered=` and no proposal. `new-phase --consolidates` naming a phase that owes nothing refuses.
   - (c) `--archive-only` prints no proposal block.

   Run the suite **once, alone in its own foreground Bash call**, and report the count against the baseline.
6. **Doc impact (S1 and S2 each leave one-line notes):**
   - operations: the archive/rotate runbook and the docs-phase route entry;
   - architecture: the `consolidates` key and the rotate proposal;
   - decisions: why the marker is an explicit key rather than name or intent detection, and why rotate proposes rather than creates (the confirmation gate).

   No `doc-new-version` in this phase.

## Decisions S2 must hold (also into `## Decisions`)

7. **The rotate-backlog skill flow:**
   - Run `rotate-backlog`, or `rotate-backlog --archive-only` when the args carry `archive-only`.
   - Relay what was archived.
   - On a proposal block, present the name, objective and docs scope (`docs-debt`), and ask **once** for confirmation. The operator may edit the name or objective, or narrow the phase list; a phase left out keeps owing.
   - On their yes, run the printed `new-phase … --consolidates …`.
   - Fill `intent.md` exactly as create-phase's docs-phase route says:
     - the operator's verbatim words;
     - the confirmed intent with the `docs-debt` scope;
     - the DECOMP cut: one `--kind docs` slice per doc, `docs-consolidated <P>` per covered phase, waive the gate.
   - Then STOP, never decomposing. If there is no proposal, or only `docs_phase_covered`, report it and stop.
   - Keep `disable-model-invocation: true`. Extend `allowed-tools` so the flow does not need to ask for its own steps (`Read`, `Edit`, `Write` on `intent.md`).
   - The docs phase runs on the default stream; never mention worktrees.
8. **The create-phase docs-phase route:**
   - It passes `--consolidates <the confirmed phases>` to `new-phase`.
   - It names `/rotate-backlog` as the default entry point that proposes this route.
9. **`archive-phase` SKILL.md** L23/L32: rotate "leaves it active **and proposes the docs phase that pays it**".
10. **Release:**
    - CHANGELOG `## v51` lists the new default, `--archive-only`, `new-phase --consolidates`, and the `docs-debt` "paid by" line. Its migration note: none required, old phases have no key.
    - `WORKSPACE_VERSION = 51`.
    - Run `python3 installer/build.py` with `--check` passing in the same change.

## What this DECOMP executor does

1. Create the two middle slices as **bare folders**, never pre-filling their `plan.md`. Chain `depends_on` S1 → S2, ordered before `P30.REVIEW`:
   - `python3 scripts/workflow.py new-slice --phase P30 --slice P30.S1 --name "Engine: rotate-backlog proposes the docs phase" --kind implementation --risk low`
   - `python3 scripts/workflow.py new-slice --phase P30 --slice P30.S2 --name "Skills, texts and release v51" --kind implementation --risk low --depends-on P30.S1`

   Check `new-slice --help` for the exact flag spelling.
2. Edit `phase.md` under budget:
   - `## Decisions`: the cut with its risk rationale, then decisions 1–10 above, compact.
   - `## Notes for later slices`:
     - S2 writes the skill from S1's **final** printed key names.
     - Live walkthrough material for the review: this repo has P25 clean and P26–P29 debt-only. A rotate here would really archive P25, so the review demonstrates in a scratch install or with `--archive-only` semantics understood, never by archiving here without the operator.
   - `## Now`: point at S1.
3. Write `result.md` with the verdict block first.
4. Run `python3 scripts/workflow.py validate`.

It does not commit or transition state, and it does not run `accept-gate`. The orchestrator runs `accept-gate P30 --require` in the DECOMP commit.

## Verification

- `python3 scripts/workflow.py validate` passes.
- `next` points at `P30.S1`.
- `phase.md` `## Slices` lists S1, S2 and REVIEW.
- The S1 and S2 folders hold only `slice.json`.
