# Plan — P26.F1 (fix): align the drafter's frontend-design licence, design-check's reference rule, the v47 changelog and the do-* feedback step with the doctrine

## Context

`P26.REVIEW` returned `changes_requested` with four findings in shipped files. The full detail is in `slices/P26.REVIEW/result.md`; read its findings section first. This slice fixes exactly those four. It is rated `high` because it repairs mid-tier work (S2, S4) and S1's engine.

The phase's `phase.md` notes tagged `for every slice` bind: rebuild the installer, run smoke alone, `--check`. Stay on **v47**: no version bump. It is the same unreleased release, so the fixes amend the v47 CHANGELOG entry.

## Fixes

1. **The drafter's `frontend-design` licence is keyed to the handoff's line.** In `.claude/agents/design-drafter.md` (§Inputs, ~L18; §Do step 7, ~L31):
   - The handoff's `new visual direction: yes|no` line is the operator-side decision. It is the drafter's **only** licence to load `frontend-design`: load it only on `yes`, never on `no`.
   - If the line is missing, do **not** load it, and name the missing line in `open_questions`. The drafter never infers the licence itself.

   Match the wording `design-cowork` and the do-* skills already use. Add a Test 0 pin (existing block) that `design-drafter.md` names `new visual direction`.
2. **`design-check`'s reference rule matches the contract.** `DESIGN_ABSOLUTE_REFS` (`scripts/workflow.py`, ~L3043) currently lets `//` (protocol-relative) and `http://` through.
   - Read the contract section in `design-cowork` (§*The design record — the on-disk contract (schema 1)*) for the exact allowed set, and make the engine accept **exactly** that set: `../tokens.css` as the one relative reference, plus `https:`, `data:` and in-page `#` fragments if the contract names them.
   - `//…` and `http://…` fail with a named problem.
   - If the contract text and the engine disagree beyond those two schemes, the contract text wins; say so in `result.md`.
   - Add the negative case inside the existing **Test 13** block: a card with a `//` and an `http://` reference fails `design-check`. Keep the PASS count at 195 by extending an existing assertion rather than adding an `ok` line, unless that is awkward; report the count either way.
3. **The v47 CHANGELOG is consistent.** L47–48 says the SIGNOFF regroup is retired, while L29–30 and `design-close --words` still regroup line 1. Reword L47–48 so that only the **`DesignSync`-side** regroup (the write into the Claude Design project) is retired, and the local line-1 regroup lives on in `design-close`.
4. **The do-* feedback step includes the revision handoff and read-back.** In `do-whole-phase` (~L27) and `do-next-slice` (~L26), the feedback branch goes: `feedback.md` → `design-close <round> --superseded` → `design-open` in the same slice → **write the revision round's `handoff.md`, listing every card still carrying the slice's address** → re-dispatch `design-drafter` → **the same inline read-back** (`design-check`, the cards, `result.md`, concreteness) → commit → PENDING #1 again.
   - Mirror `design-cowork` (~L215 and ~L569–574) word for word where possible.
   - Keep the stop and commit counts as stated (one commit and one stop per superseding round).
   - Update or extend the do-* pins in Test 0 so this can't drift again.

## Validation

- `python3 installer/build.py`;
- in its own foreground Bash call with a 600 s timeout: `bash tests/retrofit_smoke.sh` (all PASS; report the count);
- `python3 installer/build.py --check`;
- `python3 scripts/workflow.py validate`;
- one scratch probe outside the repo, with `HOME` and `AGENTIC_DESIGN_REGISTRY` in scratch: a card referencing `//x.css` and one referencing `http://x` both fail `design-check`, while `https:`, `data:` and `../tokens.css` pass.

## Notebook

- Add a `## Doc impact` line only if the reference rule changes durable truth beyond S1's line, e.g. qa for the Test 13 extension.
- Update `## Now` for the re-review.
- Write `result.md` with the verdict block first, mapping each finding (1–4) to its fix and its evidence.
