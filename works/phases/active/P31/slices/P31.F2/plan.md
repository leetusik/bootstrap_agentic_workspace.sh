# Plan — P31.F2 Operations fix: workflow/ refusal, gated reviews here, rounds inside a design slice

## Goal

Fix P31.REVIEW **findings 1–3** in operations: one new operations version on top of v0037, made under the docs-slice carve-out, in the P24.F2 pattern. Read `works/phases/active/P31/slices/P31.REVIEW/result.md` (findings 1–3 and the two optional riders) and P31.S2's `result.md` first.

## Steps

1. **Verify each fact before writing it.** Read only; never run the installer against anything.
   - (a) `resolve_layout()` in `installer/main.py` (~L105–111) and P29's recorded wording: on a nested install's own `workflow/`, only a bare install or an `--update` refuses. If P31.F1 has already landed, use the same wording as architecture's new version (see `phase.md` `## Now` / `## Decisions`) and as decisions v0043.
   - (b) `phase.json` for P29 and P30 (`acceptance.required: true`, cleared by the operator). Also the `review-phase` skill's gate stages, and operations v0037's `## Operator Runtime`.
   - (c) `.claude/skills/design-cowork/SKILL.md`, ~L257–260 and ~L287–291: design slices are counted at `DECOMP`, revisions are superseding rounds inside the same slice, and `paired`'s apply-slice count equals the design-slice count.
2. **Create the version:**
   ```
   python3 scripts/workflow.py doc-new-version --doc operations --source P31.REVIEW --summary "P31 fix: workflow/ refusal, gated CLI reviews here, rounds inside a design slice"
   ```
3. **Edit only the returned `edit_path`:**
   - **(a) Install modes** (v0037 ~L745): narrow "any run on a nested install's `workflow/`" to the verified statement.
   - **(b) The acceptance-gate paragraph** (v0037 ~L1300–1302): replace "its phases are legacy-shaped or waived and the gate stages never fire here". Write that a phase here that changes CLI or skill behaviour the operator runs takes a required gate (P29, P30). Its review reads `## Operator Runtime` at stage 1 and walks the CLI in scratch directories, and phases that change no operator-run surface (docs phases, for example) are waived.
   - **(c) Design styles** (v0037 ~L238, ~L248, ~L257): replace the "one `co-work` slice per round" model.
     - Design slices are counted at `DECOMP`.
     - Revisions are superseding rounds inside the same slice.
     - Under `paired`, the apply-slice count equals the design-slice count.
     - Fix "`co-work` rounds" wording to match.
     - Keep everything else in the section.
   - **Riders, only if verified true in the code or skill:** `--nested` still refuses beside `--at-root` or `--into-existing` (`installer/wrapper.sh` ~L88–89); the mockup route's path also goes into the round's SIGNOFF.
4. Run `python3 scripts/workflow.py rebuild-docs`, then `python3 scripts/workflow.py validate`. Grep `docs/current/operations.md` for any other leftover of the three phrasings, and fix it in the same version.

## Notebook

- `result.md`, verdict block first: the version filename and each finding's fix.
- `phase.md`:
  - add a compact `## Decisions` line for the F1/F2 cut (`docs / high`, `--source P31.REVIEW`, P24.F1/F2 precedent; no `docs-consolidated` needed);
  - consume the REVIEW-addressed notes the fixes settle;
  - rewrite `## Now` to point at the re-review.
- No `## Doc impact` notes.

Do not commit or transition state. Touch no other doc.
