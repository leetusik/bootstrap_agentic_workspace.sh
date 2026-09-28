# Plan — P21.S4 (docs-phase entry point; R4)

## Context

Read `works/phases/active/P21/phase.md` whole (the two notes tagged for P21.S4 are binding), `slices/P21.S1/result.md` §11 (R4: confidence medium on *shape*, high that R1 is incomplete without it), and the current `.claude/skills/create-phase/SKILL.md` (65 lines: refine → clarify → confirm-gate at step 3 → route; the confirmation gate is its safety invariant and does not move).

The rule already exists everywhere ("a docs phase the operator creates"); this slice supplies the **how**: when the operator says "run a docs phase" (or clears debt `next` is naming), there must be one obvious, documented path from that sentence to consolidated docs.

## Shape (recommendation — deviate with reasons in result.md if the code argues otherwise)

1. **A `workflow.py` read-only helper** so the intake never re-derives the debt: e.g. `docs-debt` — for each owing phase (via `phases_owing_consolidation()` / the S3 helpers), print its `## Doc impact` lines (via `phase_doc_impact_notes()`), the docs touched, and the paying command. Zero writes; this is the docs phase's worklist and the create-phase intake's evidence. Keep output lean and greppable.
2. **A docs-phase route in `create-phase/SKILL.md`**: a short subsection — when the request is "consolidate docs / run a docs phase", run `docs-debt`, present the owing phases + docs as the proposed scope, confirm name/objective at the *existing* step-3 gate (no new gate, no gate moved), then `new-phase` as usual. The docs phase's DECOMP then cuts one slice per doc (or per owing phase — state the default: **per doc**, since `doc-new-version` is per doc and one doc may collect notes from several phases), kind `docs`, risk per the normal rules; each slice runs `doc-new-version --source <P>.REVIEW` per note; the phase ends `rebuild-docs` → `docs-consolidated <P>` for **each** covered phase, on the default stream — exactly the sequence the S2 note prescribes, stated once here and referenced elsewhere.
3. **CLAUDE.md**: the minimal edit that makes the path discoverable — likely one sentence where the docs-phase rule already lives, pointing at `docs-debt` and the create-phase route. Replace/extend a sentence; no new paragraph (OQ2 pressure).
4. **Consistency pass**: `doc-new-version` skill / `review-phase` skill / `do-*` skills — only where a sentence is now false or misses the pointer; one-line edits.

## Constraints

- `docs-consolidated` / `parallel-consolidated` semantics unchanged; `docs-debt` (or whatever you name it) is read-only.
- The create-phase confirmation gate does not move; the docs route is a specialization of the existing procedure, not a bypass.
- Installer: `python3 installer/build.py`, `--check` passes, rebuilt artifact in tree. Append a `## v38` CHANGELOG bullet; do **not** bump the version.
- Keep tests terse: extend `tests/retrofit_smoke.sh` with a few assertions for the helper (present, read-only, correct phases/docs in a scratch copy).

## Validation

- Scratch copy with an owing phase (and one legacy-shape owing phase): helper lists the right phases, docs and commands; live repo: helper reports nothing owed.
- Walk the documented sequence end-to-end in the scratch copy (doc-new-version per note → rebuild-docs → docs-consolidated) and confirm the debt clears and archiving unblocks.
- `bash tests/retrofit_smoke.sh` green (146 baseline), `python3 scripts/workflow.py validate` clean, `python3 installer/build.py --check` passes.

## phase.md duties

One-line `## Doc impact` additions only (operations.md: the docs-phase how + helper; workflow doc if that is where commands are listed). Consume the two S4 notes. Rewrite `## Now` for S5. Notebook at 16,142/16,384 — consuming your notes frees room; leave a few hundred bytes headroom.

## Boundaries

No commits, no status transitions, no accept-gate, no doc-new-version runs on this live repo. Do not touch S5's territory (oversized-section guidance).
