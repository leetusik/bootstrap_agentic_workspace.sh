# Plan — P23.S4 (implementation/high): rewrite the contract to the 12 KB outline

## Context

P23 slims `CLAUDE.md` to a ≤ 12,288 B routing layer without losing a load-bearing rule (`intent.md`; D8's target, which the operator picked). S1 mapped every rule and measured an 11,510 B probe that kept all 58 never-rules. S2 cut the derived and duplicated text and opened v44 (commit `a63ed44`). S3 collapsed the Aside, worktree and design bullets plus HR-6d's design-styles tail to final never-stubs (commit `ee84e6a`): `CLAUDE.md` is now 26,373 B / 26,203 chars, and the three stubs total 2,465 B, about half the outline's 5,000 B Hard Rules budget. Smoke has counted 180 PASS / 0 FAIL at every boundary so far. This is the **last shipping slice and the only one that writes contract prose**: it re-expresses every remaining STAY and SPLIT unit as the stub the outline names, section by section, within the byte budget, then proves the floor held.

**Done when** `wc -c CLAUDE.md` ≤ 12,288 B, all 58 never-rules are present by a phrase you name, smoke is green, and `build.py --check` passes.

## Inputs

- `phase.md` whole. The parts you work from:
  - the *Target outline* note: section budgets (header 13 · Agent Contract 400 · Driving 3,300 · Read Order 650 · Canonical State 1,650 · Hard Rules 5,000 · IDs and Status 750 · Commit Convention 525 = 12,288) and what each section's stubs keep;
  - the *Never-rule floor* note (N1–N58, each with its source unit and target section);
  - the rule map rows still present (STAY and SPLIT units; S2 and S3 pruned what they cut);
  - the *(from P23.S2, for P23.S4)* note and S3's *Where the contract stands after S3* note: edits you must keep, line positions, stub sizes;
  - the *Pin map summary* and the *Inbound references* note.
- S1 `result.md` §4, the probe phrase that proved each never-rule; §5, the full pin table.

## Steps

### 1. Rewrite, section by section

- Keep the header `# CLAUDE.md` plus a blank line (`installer/build.py` `CLAUDE_HDR`), and these section headings in this order: *Agent Contract*, *Driving This Workspace*, *Read Order*, *Canonical State*, *Hard Rules*, *IDs and Status*, *Commit Convention*. `## Workflow Commands` stays gone.
- Keep these inbound anchors: the bold *Making a phase ≠ executing it* lead (`create-phase/SKILL.md:9` cites it), the *Orchestrator and executor* lead, the *Commit Convention* heading, the small-test-files rule (`design-cowork` cites "the contract's small-test-files rule"), and the IDs stub's "two origins" wording for `DECOMP2` (`design-cowork` says "see `CLAUDE.md`" for it; D-7).
- **Merges:** the intent rules (HR-10, HR-11) into *Capture intent first* / *Making a phase ≠ executing it* and the `intent.md` line of Canonical State (verbatim original immutable; consult it when unsure); the slice-file rules (HR-12, HR-13) into the `phase.md` and slice-context lines of Canonical State (two files, verdict block first, the audience split, never pre-fill, the notebook edited under budget, never drop a decision or question, section rules live in the template and executor). Drop the "see the slice-files rule under *Hard Rules*" cross-reference once the rule lives in Canonical State.
- **Keep S3's three stubs** (Aside, worktree, design) as written. Trim them only if the total cannot otherwise fit, and never by a pin or a never-rule (S3's `result.md` lists each stub's phrases). The D13 sentence "The same holds whichever browser is driven: an agent never drives a profile signed into the operator's accounts." stays byte-identical (D13 is open and its scope must not move).
- **Keep S2's surviving edits** per its note: the `--help` pointer in DR-1; `decomposition/review/docs` in the carve-out lists; the IDs `Slice kinds:` line with both kind pins on one line; N29's statement ("never writes product code on a `research` slice") lands in the Driving stub before HR-7b's text goes.
- Budget honestly. The **total ≤ 12,288 B is the hard cap**; the per-section budgets are guides, because S3's stubs (2,465 B) take more of Hard Rules than S1's probe gave them, so the other Hard Rules bullets must land near the probe's sizes or another section must come in under its guide. The headroom is for clarity, never for restoring a procedure. Report each section's bytes.
- If a rule turns out to have no carrier outside the contract and no room inside it, stop and return `needs_operator` with the number rather than dropping it (the Target decision: never a silent overshoot, never paid for with a dropped rule).

### 2. Pins (`tests/retrofit_smoke.sh`)

- Every contract positive that stays must hit **raw, on one line**; watch S1's at-risk list: the pending phrase `Work resumes only after explicit operator input clears the same item`, `*DesignSync* work is never dispatched` (the asterisks matter), `writes no ***product*** implementation code` (Test 1 greps the retrofit sidecar for it with escaped asterisks), `` **`DECOMP2` has two origins** `` and `` `P<N>.DECOMP3` ``.
- S1 expects two positives to be reworded away: `(gate section — written at merge)` (asserted on the do-*, review-phase and executor lists) and `` **`research` is a findings-only slice kind, and a `DECOMP2` usually follows it.** `` (the executor list asserts an equivalent phrase). If your stubs drop them, remove them from the contract list after confirming those destination asserts; if a stub keeps one naturally, keep its pin. Remove any other positive only if the pin map marks it as leaving and a destination asserts it; list each in `result.md`.
- Every contract negative stays. The Test 1 sidecar greps stay satisfiable.
- Update Test 0's comments where they describe what the contract holds.

### 3. Release and rebuild

- The `## v44` CHANGELOG section becomes the whole phase's entry: make its *Why this release* bullet state the outcome (from 50,048 B to the final size, under D8's 12 KB target), say where the removed text lives (`--help`, the owning skills, the executor bodies), and keep the Migration notes line accurate. Keep what S2 and S3 appended; edit for one coherent entry.
- `python3 installer/build.py`, then `--check`, each in its own call.

### 4. Notebook and result

- `phase.md`: append this slice's `## Doc impact` lines (architecture.md: the contract's final shape and sections; decisions.md: the ≤ 12 KB routing-layer decision and the never-rule floor). Consume the notes that were only for S4 (the rule map, the outline, the pin map, drift, inbound references, and S2's and S3's notes for S4), leaving a one-line pointer to S1's `result.md` §3–§5 for the review. **Re-tag the never-rule floor `for P23.REVIEW`** rather than dropping it: the review cross-checks it against your 58-row table. Keep the deferred-job candidates, the machinery note and the D13 note for the review. Rewrite `## Now` last, for P23.REVIEW.
- `result.md`: verdict block first; per-section bytes; a 58-row never-rule table (N-id, the exact phrase in the final contract, section); pin changes; deviations.

## Boundaries

- Contract prose, its pins, the CHANGELOG entry and the rebuild only. Executor bodies change only if a rule would otherwise lose its only carrier (report the bytes). No new loading mechanism, no adopter edits, no `docs/` edits. Never commit or run status commands; do not touch `works/deferred/`.

## Verification

- `wc -c CLAUDE.md` ≤ 12,288, and the per-dispatch prefix `wc -c CLAUDE.md .claude/agents/slice-executor-high.md` (77,782 B at the phase start).
- The 58-row never-rule check, by phrase, against the final file.
- Inbound anchors still resolve: `grep` for the *Making a phase ≠ executing it* lead, *Commit Convention*, "two origins", the small-test-files rule.
- `python3 scripts/workflow.py validate`; `python3 installer/build.py --check`.
- Smoke: `bash tests/retrofit_smoke.sh > <your scratch>/p23-s4-smoke.log 2>&1` as the **only** command in its Bash call, foreground, `timeout: 600000`; count `^PASS` / `^FAIL` and read the tail in a separate call; account for any change from S3's count.
- `git status --porcelain`: only the files this plan names plus the rebuilt `bootstrap_agentic_workspace.sh`.

## Verdict

Return: status; one-line summary for `finish-slice --outcome`; files_changed; validation (final bytes, per-section bytes, prefix, counted PASS/FAIL, never-rules 58/58); deviations; doc_impact lines added.
