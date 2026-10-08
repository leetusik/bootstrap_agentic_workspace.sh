# Plan — P31.F1 Architecture fix: narrow the workflow/ refusal

## Goal

Fix P31.REVIEW **finding 1** in architecture, and record **finding 4**. Read `works/phases/active/P31/slices/P31.REVIEW/result.md` (findings 1 and 4) and P31.S1's `result.md`.

This is a `docs` fix in the P24.F1 pattern: one new architecture version, built on v0010, under the docs-slice carve-out.

## Steps

1. Verify the truth. Read `resolve_layout()` in `installer/main.py` (around lines 105–111) and P29's recorded wording (`works/phases/active/P29/phase.md` ~L55, P29.S2's `result.md`). Confirm which runs on a nested install's own `workflow/` directory refuse: a bare install or an `--update`. Also confirm that `--into-existing` and `--at-root` without `--update` are not covered by that refusal. Read code only; don't run the installer against anything.
2. Create the new version:
   ```
   python3 scripts/workflow.py doc-new-version --doc architecture --source P31.REVIEW --summary "P31 fix: a nested install's workflow/ refuses only a bare install or --update"
   ```
3. Edit only the returned `edit_path`. In `## Nested Install`, *The default and its flags* (v0010 ~L141–142), replace "any run on a nested install's `workflow/`" with the narrow statement verified in step 1. Use the same wording decisions v0043 uses, so architecture, decisions and operations agree. Change nothing else.
4. Run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate`.
5. Grep `docs/current/architecture.md` for any other "any run" / `workflow/` refusal phrasing, and fix it in the same version if you find one.

## Notebook

- Add the missing line to `phase.md` `## Decisions` (finding 4): **"Architecture v0010 shape (P31.S1)"**. Make it one compact bullet in the style of the S2–S4 shape lines, covering:
  - the three new sections;
  - the edits beyond the notes: the skill count 17 → 18 in two places, verified against `EXPECTED_SKILL_COUNT = 18`; "byte-identical" narrowed to the at-root build output; "a fresh `--at-root` install";
  - the F1 version that fixed the refusal wording.
- Write `result.md` with the verdict block first.
- Rewrite `## Now`.
- No `## Doc impact` notes. No `docs-consolidated`: P26–P30 stay paid.

Do not commit or transition state. Touch no other doc.
