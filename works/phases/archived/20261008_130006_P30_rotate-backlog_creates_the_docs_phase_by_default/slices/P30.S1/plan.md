# Plan — P30.S1 Engine: rotate-backlog proposes the docs phase

## Goal

Implement **D1–D5** of `works/phases/active/P30/phase.md` `## Decisions` in `scripts/workflow.py` and `tests/retrofit_smoke.sh`. Read those decisions and the four `(from P30.DECOMP, for P30.S1)` notes first. They are the spec; this plan only pins the remaining choices and the order of work. Read `intent.md` if anything is unclear.

## Steps

1. **Typed blockers (D2, D4).**
   - Give `_phase_blockers` a typed companion. Recommended: `_phase_blocker_kinds(pdir) -> list[tuple[kind, text]]`, with kinds `"slices"`, `"review"` and `"consolidation"`. `_phase_blockers` stays a thin wrapper that returns the texts.
   - Every existing caller (`archive-phase`, `archive-all`, rotate, and any other `grep -n "_phase_blockers"` hit) must print **identical** text.
   - Then add `_debt_only(pdir_or_phase)`: true iff the kinds are exactly `["consolidation"]`, and the phase is not an unmerged parallel phase.
   - For the merged check, factor the existing logic in `parallel_merge_finish` (~L2479–2484) into a small helper and call it from both places: no branch, or a deleted branch, counts as merged; otherwise `merge-base --is-ancestor <branch> HEAD`, guarded by git availability as there. Do not change `parallel_merge_finish`'s output.

2. **`new-phase --consolidates` (D1).**
   - Takes a comma-separated list of ids (tolerate spaces; dedupe while keeping order).
   - Validate **before any write**. Refuse with `SystemExit` naming each offending id when the id is not an active phase or its `phase_consolidation` is not `"pending"`.
   - Store the key as `"consolidates": [...]` only when the flag is given.
   - Check `validate` and any phase.json key allowlist; accept the key there if one exists.

3. **Next phase id.**
   - Add a helper that returns `P<max+1>` over the active `phase.json` ids **and** the archived phases. Prefer each archived folder's `archive_manifest.json` `phase_id`; fall back to the `_P<N>_` regex in the folder name.
   - In nested mode, use the engine's own `ACTIVE`/`ARCHIVED` roots, as everything else does.

4. **`rotate-backlog [--archive-only]` (D2).**
   - Add the flag to the parser. Its help says it archives only and prints no docs-phase proposal.
   - Keep every existing line and early return **byte-for-byte**.
   - After the archive output, and also on the `no done phases to rotate` path and on the `no active phases to rotate` path (where it prints `docs_phase=none`), call one function, `_print_docs_phase_proposal()`, unless `--archive-only`.
   - That function recomputes from the post-archive active set:
     - **Debt-only phases.** None → print `docs_phase=none`.
     - **Covered phases.** For each active, not-`done` phase whose `consolidates` intersects the debt-only set, print `docs_phase_covered=<PX> (pays P26, P27)`.
     - **The uncovered rest.** None → stop. Otherwise print, in order:
       ```
       docs_phase_proposal=P26, P27, P28, P29
       phase=P31
       name=Consolidate the doc impact of P26–P29
       objective=consolidate the '## Doc impact' notes from P26, P27, P28, P29 into new versions of architecture, decisions, operations, qa
       create: {WORKFLOW_CMD} new-phase --phase P31 --name "…" --objective "…" --consolidates P26,P27,P28,P29
       scope: {WORKFLOW_CMD} docs-debt
       proposal only: nothing was created -- confirm the name and objective with the operator first (create-phase's docs-phase route)
       ```
   - **Name rule:** a single phase reads `of P26`. Consecutive numbers use the en dash range `P26–P29`. Otherwise use a comma list.
   - **Docs:** take them from `stale_docs(<the uncovered phases>)`, excluding `UNASSIGNED_DOC`, sorted. If that leaves none, say `into new versions of the docs their notes name`.
   - **Quoting:** quote the command's arguments with `shlex.quote` so the line is copy-pasteable. The name contains an en dash, which is fine.
   - If you need to deviate from these exact key names, record the final ones in `result.md` and `## Decisions`; S2 writes the skill from them.

5. **`docs-debt` (D3).** In each owing phase's block, after the `pay:` line, add `  paid by: <PX> (<status>)` for every active, not-done phase whose `consolidates` contains it. Change nothing else.

6. **Smoke (D5).** Add one small block, with **3–5 asserts at most**, following the DECOMP fixture note.
   - Run the probes while P2 still owes. Use a `cp -R` copy of `$F` (at the matching point, e.g. `$F.rot`), so the original fixture's later assertions are untouched.
   - Assert:
     - (a) rotate prints `docs_phase_proposal=P2` and the `new-phase … --consolidates P2` line, and P2 is still under `works/phases/active/`;
     - (b) `new-phase --phase P<n> … --consolidates P2` succeeds, then rotate prints `docs_phase_covered=` and no `docs_phase_proposal=`; and `new-phase --consolidates` naming a phase that owes nothing refuses, writing nothing;
     - (c) `rotate-backlog --archive-only` output has no `docs_phase` line.
   - Clean up the copy.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `python3 scripts/workflow.py rotate-backlog --help` shows the flag.
- **Never run a real `rotate-backlog` in this repo**: it would archive P25. Exercise it only in scratch copies; a `cp -R` of the repo into the session scratchpad is fine.
- Show the proposal output from a scratch copy of this repo in `result.md`. Expected: P25 archived, then a proposal for P26–P29, phase `P31`.
- Run `bash tests/retrofit_smoke.sh` **once, as the only command in its own foreground Bash call** (long timeout). Report PASS/FAIL against the baseline of 235, which is expected to grow by your new asserts.
- `python3 installer/build.py` then `python3 installer/build.py --check`: the engine is embedded, so the built installer must be rebuilt and pass the check.

## Notebook

- Append `## Doc impact` lines per D6: operations, architecture and decisions, tagged `(P30.S1)`, plus a qa line for the new smoke asserts and the new baseline.
- Record the final key names and the early-return choice in `## Decisions`.
- Remove the consumed S1 notes, and rewrite `## Now`.

Do not commit and do not transition state.
