# Plan — P26.F2 (fix): name in-page `#` fragments in the contract's self-contained rule

## Context

The P26 re-review returned `changes_requested` with one finding (7). `design-check` rightly accepts in-page `#` fragments (`DESIGN_ALLOWED_REFS = ("#", "data:", "https://")`), but two texts forbid them:
- the contract's "Self-contained" bullet in `.claude/skills/design-cowork/SKILL.md` (~L336–339), which says nothing relative except `../tokens.css`;
- `design-drafter.md` §Do 2.

A fragment is a relative reference (RFC 3986 §4.4). The dashboard repo builds against the contract text, so the **text** is fixed and the engine is left alone.

The approach is pinned by the phase notebook note tagged `for P26.F2`, and by `slices/P26.REVIEW/result.md` finding 7. Follow them.

## Work

1. **`design-cowork` contract, Self-contained bullet.**
   - Name in-page `#` fragments beside `../tokens.css` as same-document references: inline SVG `url(#id)` / `<use href="#id">`, and a `href="#"` stub.
   - Keep "anything else is an absolute `https:` URL", plus `data:` if the bullet already names it.
   - State that `tokens.css` follows the same rule, `#` included, without the `../tokens.css` exception.
   - Keep the wording tight.
2. **`design-drafter.md` §Do 2.** Mirror the same wording.
3. **Smoke, Test 0 (the existing block; the baseline stays 195).** Assert the Self-contained bullet names every `DESIGN_ALLOWED_REFS` entry (`#`, `data:`, `https:`), read from the engine's constant so the two cannot drift.
4. **Leave alone:** `scripts/workflow.py` and `CHANGELOG.md`.
5. **Build and checks:**
   - `python3 installer/build.py`;
   - `bash tests/retrofit_smoke.sh`, as the only command in its own foreground Bash call with a 600 s timeout;
   - `python3 installer/build.py --check`;
   - `python3 scripts/workflow.py sync-agents --check`;
   - `python3 scripts/workflow.py validate`.
6. **`phase.md`:**
   - replace the `## Decisions` `#` bullet (the text now names `#`, replacing F1's "reading");
   - append Doc impact lines: operations (the contract text names `#` fragments) and decisions (why);
   - confirm the contract now matches the **[re-review]** reference line of the relay summary in `slices/P26.REVIEW/result.md`, and say so in `result.md`;
   - consume the F2 note;
   - rewrite `## Now`.
7. **`result.md`:** the verdict block first.
