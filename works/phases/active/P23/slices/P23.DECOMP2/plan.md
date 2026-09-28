# Plan — P23.DECOMP2 (decomposition): cut the editorial slices from the rule map

## Context

P23 slims `CLAUDE.md` (50,048 B today, over Claude Code's 40k-char per-file warning, loaded into every session and every executor dispatch) to a ≤ 12,288 B routing layer without losing a load-bearing rule. `intent.md` is the confirmed operator intent. P23.S1 (research, done) mapped all 166 rule units to their readers, measured a probe holding every never-rule at 11,510 B, and recommended a three-slice cut. Its findings live in `phase.md` under *Notes for later slices* (the `(from P23.S1 …)` entries) and its evidence in `slices/P23.S1/result.md`. The tree has not moved since S1: `CLAUDE.md` is still 50,048 B and the only uncommitted changes are two timestamp lines in `works/`.

This slice turns that recommendation into bare slice folders and a notebook the editorial slices can be planned from. **Adopt S1's cut as recommended: three `implementation/high` slices in order.** Its reasons hold. S2 is derived or verified-duplicate text only and alone clears the 40k warning the operator saw. S3 moves text whose owners already carry it. S4 is the only slice that writes new contract prose, and it works on a file half the size. Every boundary leaves smoke green and `build.py --check` passing. Do not re-derive the rule map, the outline or the never-rule list; they are final inputs.

## OQ1 — answered by approving this plan

S1 raised OQ1: the executor bodies forbid a `docs` slice from running `doc-new-version`, although a docs phase's slices exist to do exactly that. **Approving this plan confirms the carve-out below.** S2 lands it in both executor bodies. If you want different wording, or want the ban kept, say so in your response to this plan.

> A `docs` slice in an operator-created docs phase, on the default stream, may run `doc-new-version` and `rebuild-docs` for the `## Doc impact` notes its plan names, editing only the returned `edit_path`. Recording `docs-consolidated <P>` stays the orchestrator's, like every other state change.

The executor body carries the restriction in four places, and S2 changes all four in both bodies identically:
- the opening paragraph's "Two carve-outs, each tied to one kind" (`slice-executor-high.md:10`);
- step 5's "never per slice" (`:47`–`:48`);
- "The only workflow commands you may run are …" (`:55`);
- "version docs on a non-review slice" (`:56`).

## What to do

1. Read `phase.md` whole, `intent.md`, and the head of `slices/P23.S1/result.md` (its verdict block carries the recommended cut) plus §6 (drift). Read other sections of `result.md` only if a note below is unclear.
2. Create exactly three middle slices as **bare folders**. Never pre-fill their `plan.md`.
   ```sh
   python3 scripts/workflow.py new-slice --phase P23 --slice P23.S2 --name "cut the derived and duplicated contract text and open v44" --kind implementation --risk high --order 3 --depends-on P23.S1
   python3 scripts/workflow.py new-slice --phase P23 --slice P23.S3 --name "collapse the worktree, design and Aside bullets to stubs" --kind implementation --risk high --order 4 --depends-on P23.S2
   python3 scripts/workflow.py new-slice --phase P23 --slice P23.S4 --name "rewrite the contract to the 12 KB outline" --kind implementation --risk high --order 5 --depends-on P23.S3
   ```
3. Edit `phase.md` as described in the next two sections. Edit around the generated `## Slices` block, never inside it. The budget is the soft 400 KB cap, so write what the editorial slices need.
4. Run `python3 scripts/workflow.py rebuild`, then `python3 scripts/workflow.py validate`. Both must pass.
5. Write `result.md` with the **structured verdict block first**. The breakdown lives in `phase.md`, so reference it from `result.md` instead of restating it.

## Notebook edits

### `## Decisions`
- Replace the *Research-first cut* line's closing clause ("how many slices that takes is DECOMP2's call") with the outcome: **DECOMP2 cut three `implementation/high` slices, S2 → S3 → S4 (orders 3–5)**, S1's recommendation as measured, with its reason in one clause.
- Add **OQ1 answered** `(P23.DECOMP2)`: the operator approved the docs-slice carve-out at the DECOMP2 plan gate, with the substance quoted above. S2 lands it.

### `## Operator Questions` (append-only)
- Append one line after OQ1: `(from P23.DECOMP2) OQ1 answered: the operator approved the docs-slice carve-out at the DECOMP2 plan gate (2026-09-28); the wording is in slices/P23.DECOMP2/plan.md. Routed: answered, so no walkthrough or deferred job is needed. P23.S2 lands it.`

### `## Notes for later slices`
- **Consume** S1's *Recommended cut* note. Replace it with one **slice-breakdown** note, tagged `**(from P23.DECOMP2, for P23.S2–S4)**`, giving each slice the fields below. It is the scope record the orchestrator plans each slice from, so it must be complete, but it names units by id and does not restate the map.
- **Re-tag, do not drop,** S1's notes the editorial slices still need: the rule map, the target outline, the never-rule floor, the pin map summary and the drift list become `(from P23.S1, for P23.S2–S4)`. The inbound-references note becomes `(from P23.S1, for P23.S2–S4)` with one correction: the three "the Commit Convention" references (`do-next-slice:35`, `do-whole-phase:38`, `parallel-phase:249`) need **no** re-point, because both do-* skills carry the full push detail themselves. Drop that item.
- **Consume** the DECOMP cutting-constraints note too; its content moves into the breakdown's shared rules.
- Leave the deferred-job candidates (for P23.REVIEW), the machinery-discipline note and the D13 note as they are.

**The slice breakdown**, one entry per slice:

- **P23.S2 — cut the derived and duplicated contract text and open v44** (order 3).
  - *Contract:* remove every CUT and MOVE unit outside HR-23, HR-25 and HR-26 (S1 counted 55): all of `## Workflow Commands` (WC-0..23) plus the duplicate-procedure units in Driving, Canonical State, Hard Rules and Commit Convention (CC-2b included). Move `` `--kind` is a **closed set** `` and the kind list into the IDs and Status section (WC-3). Surviving bullets stay grammatical; S4 rewrites them later, so do not polish.
  - *Executor bodies, identical:* the two MOVEs (HR-5b docs-slice carve-out, HR-16 fractional `--order` / advisory `depends_on`) and the OQ1 carve-out at the four places above.
  - *Drift:* D-1 (the OQ1 carve-out), D-2 (disappears with Workflow Commands), D-4 (add `research` to the delegated kinds in `do-next-slice:12` and `do-whole-phase:12`), D-6 (template note tag to `**(from <slice>, for <slice>)**`, with `PHASE_MD_TEMPLATE_FALLBACK` in `workflow.py` and smoke's byte-identity check moving with it). D-5 needs no edit.
  - *READMEs:* re-point `README.en.md:266` and `:389` and `README.md:216` to `python3 scripts/workflow.py --help`.
  - *Pins:* drop the 4 that leave (`finish-slice P1.S1 --outcome`, `phase-scope P1 …`, the fixed waive note, `` **findings land in `phase.md`** ``); they are asserted at their destinations already. The kind pins follow the IDs move.
  - *Release:* `WORKSPACE_VERSION` 43 → 44 (`installer/main.py:38`), open `## v44` in the CHANGELOG with a Migration notes line, rebuild.
  - *Done when:* `CLAUDE.md` ≈ 36.6 KB and under 40,000 chars.
- **P23.S3 — collapse the worktree, design and Aside bullets to stubs** (order 4).
  - *Contract:* HR-25 (worktree), HR-26 (design) and HR-23 (Aside) become the Hard Rules stubs the outline names, in their final form. The D13 clause "an agent never drives a profile signed into the operator's accounts" stays verbatim.
  - *Pins:* a **new `parallel-phase` pin list** in smoke with the 3 required phrases (plus the 2 recommended ones); on the design-cowork list, `two-digit reading-order prefix` and the instrument-axis phrase; copy the 4 negatives to the lists of the files that now carry their rules (dc, rp, pp as S1 lists them); drop the 16 contract positives that leave; reword the Test 0 `ok` label at `:450`.
  - *Drift:* D-3 (`parallel-phase/SKILL.md:99-100` contradicts "relay, never act").
  - *Release:* append to `## v44`, rebuild.
  - *Done when:* `CLAUDE.md` ≈ 27 KB.
- **P23.S4 — rewrite the contract to the 12 KB outline** (order 5).
  - *Contract:* re-express every remaining STAY and SPLIT unit as the stub the outline names, section by section within its byte budget. Merge the intent rules (HR-9/10/11 into DR-9/10 and CS-5) and the slice-file rules (HR-12/13 into CS-4/7). Keep the *Making a phase ≠ executing it* heading and the IDs stub's "two origins" wording (D-7).
  - *Pins:* the final pass; the last two reworded away are already asserted elsewhere. Watch S1's at-risk list (the `:444` pending phrase, the asterisked DesignSync and ***product*** phrases, the bolded `DECOMP2` heading).
  - *Verification specific to it:* check all 58 never-rules one by one, each by its phrase; report `wc -c CLAUDE.md` ≤ 12,288 B.
  - *Release:* append to `## v44`, rebuild.
- **Shared rules, every slice:** re-home each cut's pins in the same slice; smoke green (`bash tests/retrofit_smoke.sh`, the only command in its Bash call, foreground, 600000 ms) and `python3 installer/build.py --check` passing at the end; report `wc -c CLAUDE.md` and the per-dispatch prefix (`CLAUDE.md` + `slice-executor-high.md`); both executor bodies stay byte-identical and grow by far less than the contract shrinks; append the slice's own `## Doc impact` lines (the expected targets are already listed there).

### `## Now`
Rewrite it last, ≤ 15 lines: the cut is made, OQ1 is answered, S2 is next and what it must know, and what is still open (D13's trigger fires in S3; the two deferred-job candidates wait for the review; P21/P22 doc debt is untouched).

## Boundaries

- Bare folders only. Write no `plan.md` for S2, S3 or S4, and start none of their work: no edits to `CLAUDE.md`, the executor bodies, skills, smoke, installer or CHANGELOG.
- Do not run `accept-gate`, `defer-job`, `drop-deferred` or any status command, and do not commit.
- The acceptance gate stays waived. Flag it in the verdict if anything in the cut would make the phase operator-visible.

## Verification

- `ls -la` on each new slice folder shows only `slice.json`.
- `rebuild` regenerates `## Slices` as DECOMP → S1 → DECOMP2 → S2 → S3 → S4 → REVIEW.
- `validate` exits 0. The P21/P22 debt, `stale_docs` and `oversized_doc_sections` warnings are pre-existing and expected.
- Report `wc -c` of `phase.md`.

## Verdict

Return: status; a one-line summary for `finish-slice --outcome`; files_changed; validation outcomes; the slices cut (id / name / kind / risk / order / depends_on); the acceptance-gate read.
