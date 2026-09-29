# Result — P26.F2 (fix): name in-page `#` fragments in the contract's self-contained rule

## Verdict

- `status`: done
- `tier`: high
- `summary`: The contract's Self-contained bullet in `design-cowork` and `design-drafter` §Do 2 now name in-page `#` fragments beside `../tokens.css` (inline SVG's `url(#id)` / `<use href="#id">`, a `href="#"` stub). They also say a `data:` URI suits any resource, and `tokens.css` follows the same rule, `#` included, without the `../tokens.css` exception. Smoke Test 0 pins both texts against the engine's `DESIGN_ALLOWED_REFS`. The engine and `CHANGELOG.md` are unchanged, and the smoke still reports 195 PASS / 0 FAIL.
- `files_changed`:
  - `.claude/skills/design-cowork/SKILL.md`: the Self-contained bullet (L336–341), plus one phrase in read-back step 2
  - `.claude/agents/design-drafter.md`: §Do 2
  - `tests/retrofit_smoke.sh`: a Test 0 pin inside the existing block
  - `bootstrap_agentic_workspace.sh`: rebuilt
  - `works/phases/active/P26/phase.md`
  - `works/phases/active/P26/slices/P26.F2/result.md`
- `validation`:
  - `python3 installer/build.py`: wrote 596,310 bytes. PASS
  - `bash tests/retrofit_smoke.sh`, alone in its call, foreground, 600 s: `ALL RETROFIT SMOKE TESTS PASSED`, **195 `PASS:` / 0 `FAIL`**. PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `python3 scripts/workflow.py sync-agents --check`: agent files in sync. PASS
  - `python3 scripts/workflow.py validate`: passed, exit 0. It was run after the notebook edit. PASS
  - Negative probe: the new pin, applied to the `HEAD` text of both files, reports `#` missing and the `tokens.css` clause absent. On the edited text it reports nothing missing. PASS
  - The real `~/.config/agentic-workspace` was still absent after the smoke. PASS
- `deviations`: three small extensions, each within finding 7's intent.
  1. **`data:` for any resource.** The bullet said "Images are inline SVG or `data:`, and anything else is an absolute `https:` URL". Read literally, that forbids a `data:` font or stylesheet in `url(…)`, but `design-check` accepts a `data:` URI anywhere, and the relay summary's **[re-review]** line lists "`data:` URIs" with no limit. This is the same text-vs-engine mismatch as finding 7, so I added "(a `data:` URI suits any resource)" to both texts. "anything else is an absolute `https:` URL" is kept word for word.
  2. **Read-back step 2** of `design-cowork` gave "a relative reference" as an exit-1 cause. `#` and `../tokens.css` are relative and pass, so it now reads "a reference the self-contained rule forbids". No smoke pin referenced the old phrase.
  3. **The Test 0 pin also covers the drafter's §Do 2**, not just the contract bullet. The drafter repeated the defect, and it is the reader that takes the text literally. For both texts, the pin checks four things:
     - every `DESIGN_ALLOWED_REFS` prefix is named;
     - `../tokens.css` is named;
     - the `tokens.css` clause is present;
     - the old wording is absent.
- `doc_impact`: three lines appended to `phase.md` `## Doc impact`:
  - operations.md: the cards' self-contained rule as the contract text now states it (P26.F2)
  - decisions.md: `#` fragments are named in the contract text, no longer "a reading", with the reason (P26.F2)
  - qa.md: Test 0 pins the Self-contained bullet and drafter §Do 2 against `DESIGN_ALLOWED_REFS`, and the baseline stays 195 (P26.F2)

## What changed

**Contract, `design-cowork` Self-contained bullet** (whitespace-flattened):

> A card references nothing relative except `../tokens.css` and in-page `#` fragments, which are same-document references: inline SVG's `url(#id)` and `<use href="#id">`, or a `href="#"` stub for a link. Images are inline SVG or `data:` (a `data:` URI suits any resource), and anything else is an absolute `https:` URL. That is what lets the same bytes render from `cards/` and from a round snapshot. `tokens.css` follows the same rule, `#` fragments included, without the `../tokens.css` exception.

**`design-drafter.md` §Do 2** mirrors it. It opens with "The only relative references allowed are `../tokens.css` and in-page `#` fragments…" and carries the same `data:` and `tokens.css` clauses.

**Test 0 pin** (`tests/retrofit_smoke.sh`, right after the `DESIGN_ROOT_REL` constants loop, inside the one Test 0 assertion block):
- `DESIGN_ALLOWED_REFS` is parsed out of `scripts/workflow.py` by regex, so a new engine prefix fails the pin until the text names it.
- Both flattened texts must contain each prefix in backticks, with the trailing `/` dropped, so `https://` is matched as `` `https:` ``. They must also contain `` `../tokens.css` `` and the `tokens.css` clause.
- The old sentences are negatives.

## Contract vs. the relay summary's [re-review] line

Checked against `slices/P26.REVIEW/result.md` §*Relay summary, corrected*. The two now agree on every point:

| Relay summary **[re-review]** | Contract text after F2 |
|---|---|
| `../tokens.css` | "nothing relative except `../tokens.css` and …" |
| in-page `#` fragments (inline SVG's `url(#id)`, `href="#"`) | "in-page `#` fragments … inline SVG's `url(#id)` and `<use href="#id">`, or a `href="#"` stub" |
| `data:` URIs | "Images are inline SVG or `data:` (a `data:` URI suits any resource)" |
| absolute `https:` URLs | "anything else is an absolute `https:` URL" |
| no other relative paths, no `//`, `http:`, `mailto:`, `tel:`, `javascript:`, `about:` | the "nothing relative except" clause, plus "anything else is an absolute `https:` URL" |
| `tokens.css` follows the same rule without `../tokens.css` | "`tokens.css` follows the same rule, `#` fragments included, without the `../tokens.css` exception" |

The engine's error text (`design_reference_problems`) names the same set, so contract, drafter, engine and relay summary now say the same thing.

## Engine, left alone

- `git diff` shows no change to `scripts/workflow.py` or `CHANGELOG.md`.
- `DESIGN_ALLOWED_REFS = ("#", "data:", "https://")`. `tokens.css` is checked with `allow_tokens=False`, which gives the same set without `../tokens.css`, exactly what the text now says.

## Notebook edits (`phase.md`)

- **`## Decisions`:**
  - The reference-rule `#` bullet is replaced: `#` is now named in the text, replacing F1's "reading", and the reason is recorded.
  - The contract line's relay pointer now says F2 made the text name `#`.
  - The Library line's Self-contained summary now names `#`.
- **`## Doc impact`:** three lines appended (operations, decisions, qa).
- **`## Notes for later slices`:** the REVIEW → F2 note is consumed. A short F2 → REVIEW note lists what F2 touched.
- **`## Now`:** rewritten; next is the re-run of `P26.REVIEW`.
- The notebook is 31 KB, well under budget.
