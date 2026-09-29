# Result — P26.REVIEW (review), re-review after P26.F1

## Verdict

- `status`: done
- `tier`: high
- `summary`: I re-reviewed P26 over its whole boundary (18 files, `869f207..b84eb1e`, now including F1). Every check passes: `build.py --check`, `sync-agents --check`, `validate`, the smoke (195 PASS / 0 FAIL) and all 6 in-boundary checklist lines. I also re-ran the contract end to end in a scratch fresh install. My own probes confirm that F1 fixed first-review findings 1–4 and caused no regression. Verdict **changes_requested** on one small point: F1 accepts in-page `#` fragments, but the contract text still literally forbids them. Its "nothing relative except `../tokens.css`" rules out fragments, because a fragment-only reference *is* a relative reference. So the contract and the engine disagree. One fix slice, `P26.F2` (risk high), makes the text name `#`.
- `files_changed`:
  - `works/phases/active/P26/slices/P26.REVIEW/result.md` (rewritten; the first review is in git at `c44ab6f`)
  - `works/phases/active/P26/phase.md`
- `validation`:
  - `python3 scripts/workflow.py phase-scope P26`: range `869f207..b84eb1e`, 8 commits, 18 product files (the same list as the first review). PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `python3 scripts/workflow.py sync-agents --check`: agent files in sync. PASS
  - `python3 scripts/workflow.py validate`: passed, exit 0. Its only warning is the existing `oversized_doc_sections=7`. It was re-run after the notebook edit and still passed. PASS
  - `bash tests/retrofit_smoke.sh`, alone in its call, foreground, 600 s: `ALL RETROFIT SMOKE TESTS PASSED`, **195 `PASS:` / 0 `FAIL`**. PASS
  - `## Regression Checklist`: 6 lines, 6 inside, 0 outside, all passing (see *Checklist*). PASS
  - A scratch fresh install re-running the whole contract, plus a reference-rule matrix (`scratchpad/rereview_probe.sh`, log `rereview_probe.log`). It used `HOME` and `$AGENTIC_DESIGN_REGISTRY` in scratch. PASS, apart from finding 7, which is a text mismatch and not an engine defect.
  - The real `~/.config/agentic-workspace` was absent before and after the probe, and the scratch HOME has no `.config`. PASS
  - Frontmatter of the drafter, both executors and the four changed skills parses as YAML (Ruby), with no `: ` in any `description`. PASS
  - `CLAUDE.md` is 12,286 B, under the 12,288 B cap. PASS
  - Residual `DesignSync` / `Claude Design` sweep: the same allowed hits as the first review, and nothing new. PASS
- `deviations`: none from the plan.
  - The reference matrix goes beyond the four schemes the plan names. It adds `tel:`, `about:`, uppercase `HTTP://` and `HTTPS://`, `url(//…)`, `../other.css`, an empty `href`, `srcset`, a string `@import`, and a `tokens.css` matrix.
  - I did not run `review-phase` or `accept-gate` anywhere, scratch included. So the "uncleared gate" half of checklist line 2 is covered by code inspection: P26's diff touches no acceptance code.
- `doc_versions`: none — deferred to a docs phase. The gate is waived, so no gate sections were written.
- `review_verdict`: **changes_requested**. The numbering continues from the first review's findings 1–6.
  7. **The contract text forbids the `#` fragments that `design-check` accepts, and so does the drafter body.**
     - The contract (`design-cowork` L336–339, the Self-contained bullet) says: "A card references nothing relative except `../tokens.css`. Images are inline SVG or `data:`, and anything else is an absolute `https:` URL."
     - `design-drafter.md` §Do 2 (L26, written by S2, `tier: mid`) repeats it: "The only relative reference allowed is `../tokens.css`".
     - A fragment-only reference (`#top`, `url(#g)`, `href="#"`) is a *relative* reference: RFC 3986 §4.4 calls it a same-document reference, and WHATWG treats it as a relative-URL string. So the text literally forbids what the engine allows (`DESIGN_ALLOWED_REFS = ("#", "data:", "https://")`, probed below). It is not merely silent.
     - The engine's own error text now names "an in-page `#` fragment" as allowed, a rule the contract never states.
     - **Why it matters:**
       - The section calls itself "the whole interface between the two sides: a reader is built from it alone", and the dashboard repo builds against its text.
       - The drafter reads that text literally. With F1 now rejecting `mailto:`, `tel:` and `javascript:`, `href="#"` is the *only* way left to stub a link on a design card. Inline SVG gradients, filters and `<use>` also need `url(#id)`.
       - A literal drafter would either avoid those, or face a rule the text denies and the check permits.
       - `## Decisions` and F1's decisions.md Doc impact line record the allowance as "a reading". The durable docs would therefore carry a rule that the contract contradicts.
     - **My judgment on F1's call:** keeping `#` allowed is right. The contract's own "Images are inline SVG" needs it, and a same-document reference renders identically from `cards/` and from a snapshot. The defect is only that the text does not say so. The fix makes the text match the engine, not the reverse.

  **Proposed fix slice: `P26.F2`** "name in-page `#` fragments in the contract's self-contained rule". `--kind fix --risk high`, for two reasons: it edits the contract section, the cross-repo interface (the *wide blast radius* trigger that rated S1 high), and it repairs S2's drafter text, whose verdict reads `tier: mid`. The approach is pinned:
  1. **The contract text.** In `design-cowork`'s Self-contained bullet, name in-page `#` fragments beside `../tokens.css`, as same-document references such as inline SVG's `url(#id)` / `<use href="#id">` and a `href="#"` stub. Keep "anything else is an absolute `https:` URL". Make `tokens.css` "the same rule, `#` fragments included, without the `../tokens.css` exception", which is what the engine does.
  2. **The drafter.** Mirror the same wording in `design-drafter.md` §Do 2.
  3. **A Test 0 pin**, inside the existing block so the baseline stays 195. The contract's Self-contained bullet must name each `DESIGN_ALLOWED_REFS` entry: `#`, `data:`, and `https:` for `https://`. The contract and the engine then cannot drift again.
  4. **The build.** Rebuild the installer, then `build.py --check`, `sync-agents --check`, the smoke (195 / 0) and `validate`.
  5. **The notebook.** Replace the `## Decisions` reference-rule bullet "`#` is a reading, not literal text" with the contract naming it. Append the Doc impact lines, `operations.md` for the contract text and `decisions.md` for the resolution, and confirm the contract now matches the relay summary's reference line below.
  6. **Out of scope.** Change nothing in the engine: its behaviour is already right. `CHANGELOG.md` needs no edit, because v47 is unreleased and its "numbered self-contained cards" line stays true. Then re-run `P26.REVIEW`.
- `walkthrough`: none. The gate is waived (`acceptance.required: false`, machinery only).
  - **Operator question: already routed.** The P26.S1 question ("more than one design project per repo?") is filed as **D29** (`works/deferred/open/D29`, status `deferred`), and D30 and D31 are filed too. Per the plan they are not re-listed. The orchestrator still owes the operator the relay of that question, together with the corrected relay summary below.
  - **One new deferred-job candidate** (an observation, not a finding; I did not run `defer-job`):
    - **DJ4 — "Widen `design-check`'s reference scan beyond `src`, `href` and `url()`".**
      - Reason: `DESIGN_REF_RE` reads only `src=`, `href=` and `url(…)`. Probed: `<img srcset="//cdn…/x.png 1x">` and `<style>@import "http://x/y.css";</style>` both pass `design-check` (rc 0), although each breaks the self-contained rule. `poster=` and `<object data=>` escape it by inspection.
      - This has been true since S1, is not an F1 regression, and a hand-drafted card rarely uses those forms.
      - Trigger: a drafted card passes `design-check` but loads a resource through a form the scan does not read, or the dashboard build asks for a stricter check.
- `explain`: not written — run /explain for this phase

## Boundary

`python3 scripts/workflow.py phase-scope P26` gives range `869f207..b84eb1e` (8 commits) and the same 18 product files as before:
- 1 added: `.claude/agents/design-drafter.md`;
- 17 modified: the two executor bodies; the `create-phase`, `design-cowork`, `do-next-slice` and `do-whole-phase` skills; `CHANGELOG.md`, `CLAUDE.md`, both READMEs, `bootstrap_agentic_workspace.sh`, `executors.toml`, `installer/{README.md,build.py,main.py}`, `scripts/workflow.py` and `tests/retrofit_smoke.sh`.

F1 (`b84eb1e`) touched 7 of these files:
- the drafter;
- the two do-* skills;
- `CHANGELOG.md`;
- `scripts/workflow.py` (`DESIGN_ALLOWED_REFS` / `DESIGN_REF_WHY` / `design_reference_problems`);
- the smoke;
- the rebuilt installer.

It did not touch `design-cowork`, so the first review's governance and contract-section checks stand.

## Validation

- **Smoke:** 195 `PASS:` / 0 `FAIL`. Test 13's first line is "design-check names a gap, an unnumbered card, a // and an http:// reference (exit 1) and passes the numbered set with ../tokens.css, #, data: and https references". Test 0 and Test 5's drafter lines pass.
- **Other commands:** `build.py --check`, `sync-agents --check` (flex, mid sonnet@xhigh, high opus@xhigh) and `validate` pass.

## Findings 1–4: each fix verified by my own probe or read

1. **Fixed: the drafter's licence is keyed to the handoff line.**
   - `design-drafter.md` §Inputs 1 names "the `new visual direction: yes` or `no` line … your only licence for `frontend-design`".
   - §Do 7 says to load it only when the line says `yes` and never on `no`.
   - It also says: "If the line is missing, do not load it, and name the missing line in `open_questions`. You never infer the licence yourself". The old self-judged rule is gone.
   - This matches `design-cowork` L198–201 and L828–830, both do-* handoff steps and CHANGELOG v47 L38–39, which are the only other `new visual direction` hits in the boundary.
   - The frontmatter is unchanged and valid.
2. **Fixed: `//` and `http://` fail by name.** Probed in the scratch install with a library card, `cards/04-ref.html`:

   | Reference | rc | Named reason |
   |---|---|---|
   | `//cdn…/x.png` | 1 | "protocol-relative: it resolves against file:// when a card file is opened directly" |
   | `http://x…/y.css` | 1 | "plain http, not https" |
   | `HTTP://X.EXAMPLE/` | 1 | "plain http, not https" |
   | `url(//cdn…/b.png)` in a style | 1 | protocol-relative |
   | `mailto:`, `tel:`, `javascript:`, `about:blank`, `logo.png`, `../other.css` | 1 | the generic named problem |
   | `https://…`, `HTTPS://…`, `data:`, `#`, `url(#g)` + `<use href="#g">` + `href="#top"`, empty `href` | 0 | — |

   The `tokens.css` matrix:
   - `//` fails, and `../tokens.css` inside `tokens.css` fails (no self-exception);
   - `url(#f)`, `https:` and `data:` pass.

   The first-round card `01-colors`, carrying inline-SVG `url(#g)`, `<use href="#g">`, `href="#"`, `data:` and `https:`, checked, signed and regrouped cleanly.
3. **Fixed: the CHANGELOG is consistent.**
   - v47 L47–50 now retires "the `DesignSync` read-back and its SIGNOFF regroup (the write into the Claude Design project)".
   - It says "the regroup itself lives on locally in `design-close --words`, which rewrites line 1 of each signed card and nothing after it".
   - That agrees with L29–30 and `design-cowork` §Closing, and the probe confirms the local regroup. The v47 section has no other regroup mention.
4. **Fixed: the do-* feedback step writes the revision handoff and reads back.**
   - Both skills now run: `feedback.md` → `design-close --superseded` → `design-open` in the same slice → **write its handoff** (every card still carrying the slice's address plus new ones, with its `new visual direction` line) → re-dispatch → the same inline read-back → commit (the superseded round's `feedback.md` and close in the same commit) → PENDING #1.
   - This matches `design-cowork` L25–31 (the loop), L213–215 (the revision handoff), L82–84 (the superseding commit) and L569–574 (§Closing).
   - The counts are unchanged in both: one more commit and one more stop per superseding round. PENDING #1/#2 and the literal-signoff rule are untouched.

## F1's own call and the regression check (plan steps 3 and 4)

- **The `#` reading:** accepted in substance, but not in the text. See finding 7.
- **The widened rejected set:**
  - The contract ("anything else is an absolute `https:` URL") and the engine (rejects `mailto:`, `tel:`, `javascript:`, `about:`) now agree, as probed above.
  - No adopter is affected: v47 is unreleased, and closed-round snapshots are not reference-checked.
  - The relay summary said only "Cards reference only `../tokens.css` relatively". It is now **updated** to name the whole reference set (below).
- **The three-way state after this review:**
  - summary = engine;
  - contract = engine on every scheme;
  - contract ≠ engine on `#` (finding 7), and `P26.F2` closes that.

## Checklist (`docs/current/qa.md` `## Regression Checklist`)

All 6 lines are **inside** the boundary. Each is fed by `scripts/workflow.py`, `installer/*`, `bootstrap_agentic_workspace.sh`, `tests/retrofit_smoke.sh` or `.claude/*`, all in the diff. **Outside: 0**, with the file list above as the proof.

| Line | Re-run evidence | Result |
|---|---|---|
| installer: a fresh install validates and stamps `workspace_version` (P16) | smoke T5 "fresh install exits 0", "fresh workspace validates", "release version agrees…"; my scratch install: rc 0, `validate` rc 0, `works/.workspace-version.json` `workspace_version: 47` | pass |
| engine: an undeclared or uncleared gate refuses `review-phase --verdict pass` (P16) | smoke T5 "review-phase --verdict pass refuses an undeclared acceptance gate". The uncleared half: `scripts/workflow.py` L1616 still refuses when `cleared_at` is unset, and `git diff 869f207..HEAD -- scripts/workflow.py` has 0 lines touching `acceptance` or `cleared_at` | pass |
| machinery text: Test 0's invariants hold, including tier body parity (P16) | smoke Test 0 PASS | pass |
| engine: `## Slices` renders from `slice.json`, and `finish-slice --outcome` fills the row (P18) | smoke T9 "new-phase renders the generated ## Slices block", "finish-slice --outcome lands in the slice's generated row" | pass |
| engine: a marker-less notebook stays byte-identical, and repeated `next` leaves the dashboards clean (P18) | smoke T9 "a marker-less phase.md is left byte-identical", T10 "two next calls leave the dashboards byte-identical" | pass |
| engine: `new-slice --kind research` works, and an invented kind errors naming the closed set (P19) | smoke T5 "new-slice accepts --kind research", "the unknown-kind error names research in the closed set", "new-slice rejects an unknown --kind" | pass |

No lines were appended: the gate is waived.

## The contract, end to end (re-run on the F1 installer)

- **Setup:** `scratchpad/p26rr/acme-web`, with `HOME=scratchpad/p26rr/home` and `AGENTIC_DESIGN_REGISTRY=scratchpad/p26rr/reg/design-registry.json`. Every step behaved as in the first review:
- **Install:** rc 0, `validate` rc 0; it ships `.claude/agents/{design-drafter,slice-executor-high,slice-executor-mid}.md`.
- **Before and at init:**
  - `design-check` and `design-open` before init point at `design-init`.
  - `design-init` writes `{schema 1, id, name}`, and a re-run prints "unchanged".
- **`design-open`:**
  - it writes the 10 `round.json` keys (`open`, `closed_at: null`, `cards: []`, `supersedes: []`);
  - a second open is refused.
- **`design-check`:**
  - Two hand-written cards pass, both whole and against the handoff list. One is `title`-last; the other is `viewport`-first with a CRLF in its body.
  - Negative runs name every problem:
    - a gap;
    - an unnumbered `type.html`;
    - an unknown attribute;
    - a relative `logo.png`;
    - a stray `design-system.html`;
    - a missing handoff path;
    - a marker not on line 1;
    - `viewport 'wide'`.
- **`design-close --words`:**
  - it is refused before `SIGNOFF.md` exists;
  - the snapshot equals the pre-close bytes, and the `tokens.css` snapshot is identical;
  - the regroup touches line 1 only and keeps the attribute order, and every later byte is identical;
  - a re-run leaves the tree's shasum unchanged, and `--superseded` on a signed round is refused.
- **The supersede chain:**
  - `02-form` (P1.S2) closes `--superseded` with no regroup and `supersedes: ["01-signin"]`;
  - P1.S3's `design-open` is refused;
  - `design-check` flags both addressed cards in the gap;
  - P1.S2's `03-form-v2` opens;
  - a list omitting the inherited card fails, and the full list passes;
  - signing gives `supersedes: ["02-form"]`.
- **`design-register`:**
  - it writes absolute paths to the scratch registry only, mode 0600;
  - a re-run prints "already registered (nothing written)", and the sha is unchanged.
- **Isolation:** the scratch HOME holds only `Library/`, and the real `~/.config/agentic-workspace` is absent before and after.

Against the relay summary: everything agrees except the reference line, which is now updated.

## Intent, governance, sweep (re-confirmed)

- **Intent:** all five deliverables are present.
  - The drafter's `frontend-design` use is now keyed to the operator's handoff line, which closes the first review's gap on deliverable 2.
  - There is still no interim viewer, the phase is still Claude Code only, and no claude.ai account is needed anywhere.
- **Governance:** `design-cowork` is untouched since S3, so the 12-row spot check stands.
- **The per-round steps across `design-cowork`, `do-whole-phase` and `do-next-slice`:** they now agree fully.
  - The counts: two commits and one stop; one more of each per superseding round; three and two with a mockup.
  - PENDING #2 only on request, and literal signoff.
  - The feedback step, finding 4's former divergence.
- **Sweep:** `DesignSync` / `Claude Design` hits are only the optional bundle import and the deliberate "no DesignSync" lines. All YAML is valid, and `CLAUDE.md` is under its cap.

## Doc impact

The list is complete for what has landed:
- **operations:** S1, S2, S3, S4 and F1;
- **architecture:** S1 and S2;
- **decisions:** S1/S2 (added at the first review), S3, S4 and F1;
- **qa:** S1, S2, S3, S4 and F1.

F1's three lines are present: operations (the reference rule, the drafter licence, the revision handoff), qa (Test 13 and Test 0 pins, baseline 195) and decisions (the engine follows the contract text strictly, `#` as a reading). The CHANGELOG rewording is not a durable-doc change.

`P26.F2` must append its own lines: operations for the contract text naming `#`, and decisions for the "reading" being replaced by explicit text. Nothing is versioned here.

## Operator Questions

- There is one entry (P26.S1), already routed at the first review and filed as **D29**; D30 and D31 are filed too.
- Nothing new was raised, and no routing line was added.

## Relay summary, corrected (for the dashboard build; relay verbatim once `P26.F2` lands)

This is S1's summary (`slices/P26.S1/result.md`, end) with the first review's corrections, marked **[corrected]** and **[added]**. The re-review's reference-rule line is marked **[re-review]**.

**Where projects are.** The registry is one JSON file on the Mac, at `$AGENTIC_DESIGN_REGISTRY` if set, else `~/.config/agentic-workspace/design-registry.json`:

```json
{"schema": 1, "projects": [{"id": "acme-web", "name": "Acme Web", "repo": "/abs/repo",
  "root": "/abs/repo/docs/reference/design", "registered_at": "2026-09-29T21:30:00+09:00"}]}
```

- Entries are sorted by `id`, and the paths are absolute.
- Each product repo registers itself with `python3 scripts/workflow.py design-init` (once), then `python3 scripts/workflow.py design-register`.
- Show an entry whose `root` no longer exists as unavailable.
- **[added]** The file is written owner-only (mode 0600), so run the dashboard as the same macOS user.

**What is under each `root`** (UTF-8, no BOM; ignore any file or key not named here; reject `schema` ≠ 1):

- **`design.json`**: `{"schema": 1, "id", "name"}`. One project per repo.
- **`tokens.css`**: the design tokens. It is optional until a round drafts it.
- **`cards/NN-slug.html`**: the live card library.
  - Sort numerically: `NN` is 01, 02 … 99, 100, contiguous.
  - **[corrected]** Line 1 is the marker and only the marker: `<!-- @dsCard`, then one or more ` key="value"` pairs **in any order**, then ` -->`. The line ends in `\n` or `\r\n`.
    - The keys are `group` and `viewport`, which are required, and `title`, which is optional. There are no other keys, and each appears once.
    - Parse the pairs; do not match a fixed attribute order.
    - `viewport` is `WxH`, the iframe size in CSS px. Mobile sizes are valid.
  - A `group` starting `⏳ <slice-id> · ` (U+23F3 … U+00B7) marks a card **under review**; strip that prefix to get its library group. Any other `group` is a signed library heading.
  - **[re-review]** A card references only these, and nothing else:
    - `../tokens.css`;
    - in-page `#` fragments (inline SVG's `url(#id)`, `href="#"`);
    - `data:` URIs;
    - absolute `https:` URLs.

    There are no other relative paths, and no `//`, `http:`, `mailto:`, `tel:`, `javascript:` or `about:`. `tokens.css` follows the same rule, without the `../tokens.css` entry. So serve the root as static files and render each card in its own iframe: `../tokens.css` resolves from `cards/` and from a snapshot alike, and only `https:` references need the network.
- **`rounds/NN-slug/`**: one folder per design round, numbered like cards. At most one is `open`.
  - **`round.json`**: `{"schema": 1, "round", "title", "slice", "status": "open"|"signed"|"superseded", "opened_at", "closed_at", "cards": ["cards/NN-slug.html", …], "supersedes": ["NN-slug", …], "signoff_words"}`.
  - **Prose** (render whichever exist): `handoff.md` (the brief), `result.md` (what was designed), `build-prompt.md` (the implementation contract), `feedback.md` (the operator's notes), `SIGNOFF.md` (signed rounds).
  - **[corrected]** A **closed round** (signed or superseded) holds a snapshot: `rounds/NN-slug/cards/<file>` for each entry of `cards`, plus `rounds/NN-slug/tokens.css` **when the design root had one at close**. The files are exactly as they were at close. Render those, not the live cards. Nothing in a closed round's folder ever changes.
  - **The open round**'s cards are the live `cards/` files whose group carries `⏳ <its slice> · `. Its `cards` list stays empty until close.
  - **[added]** Between a superseded close and the same slice's next round, `⏳` cards can briefly exist with no open round. Show them under review anyway.
  - **History:** walk `rounds/` by number. `supersedes` names the earlier rounds this one re-drafted. Compute "superseded by" yourself.

**What the dashboard never does:** write anything, shell out to git, or build anything. Every view is a plain file read.

## The first review (history)

The first run returned `changes_requested` with findings 1–4, which F1 fixed, and repaired findings 5 and 6 in the notebook:
- 5 was the S1 relay summary's line-1 shape and its `tokens.css` snapshot;
- 6 was decisions.md for S1/S2.

It also filed DJ1–DJ3, now D29–D31. Its full log is this file at commit `c44ab6f`.

## Notebook edits (`phase.md`)

- **`## Decisions`:**
  - The Review line now records the re-review outcome.
  - The reference-rule line's "`#` is a reading" bullet is replaced: `#` stays allowed and the contract text must say so (`P26.F2`).
  - The contract line's pointer now notes that the relay summary names the reference set.
- **`## Doc impact`:** nothing appended. The list is complete for what has landed, and F2 appends its own.
- **`## Operator Questions`:** unchanged; the entry was already routed.
- **`## Notes for later slices`:**
  - The F1 → REVIEW note is consumed.
  - A note for `P26.F2` is added.
  - The DECOMP "every slice" note is kept.
- **`## Now`:** rewritten.
