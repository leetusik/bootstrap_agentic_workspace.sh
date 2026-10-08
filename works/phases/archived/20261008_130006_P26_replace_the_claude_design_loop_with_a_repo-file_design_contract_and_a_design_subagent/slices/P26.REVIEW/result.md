# Result — P26.REVIEW (review), re-review after P26.F2

## Verdict

- `status`: done
- `tier`: high
- `summary`: Re-reviewed P26 over its whole boundary (18 product files, `869f207..22b3acb`, 10 commits, F2 included): finding 7 is fixed — the contract's Self-contained bullet, `design-drafter` §Do 2, the engine's `DESIGN_ALLOWED_REFS` and the relay summary now state the same reference set, confirmed by text read, a fresh-install probe and a mutation probe of F2's new Test 0 pin — and nothing regressed (smoke 195 / 0, 6/6 checklist lines, the whole contract re-run end to end on the F2 installer). Verdict **pass**; the final relay-ready dashboard contract summary closes this file.
- `files_changed`:
  - `works/phases/active/P26/slices/P26.REVIEW/result.md` (rewritten; the previous re-review is in git at `5092bd7`, the first review at `c44ab6f`)
  - `works/phases/active/P26/phase.md`
- `validation`:
  - `python3 scripts/workflow.py phase-scope P26`: range `869f207..22b3acb`, 10 commits, 18 product files (1 added, 17 modified; the same list as both earlier runs). PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `python3 scripts/workflow.py sync-agents --check`: agent files in sync (flex; mid sonnet@xhigh, high opus@xhigh). PASS
  - `python3 scripts/workflow.py validate`: passed, exit 0; the only warning is the pre-existing `oversized_doc_sections=7`. Re-run after the notebook edit: still passes. PASS
  - `bash tests/retrofit_smoke.sh`, alone in its call, foreground, 600 s: `ALL RETROFIT SMOKE TESTS PASSED`, **195 `PASS:` / 0 `FAIL`** (log `scratchpad/smoke_rr2.log`). PASS
  - `## Regression Checklist`: 6 lines, 6 inside, 0 outside, all passing (see *Checklist*). PASS
  - Fresh-install contract probe on the F2 installer (`scratchpad/rr2_probe.sh`, log `rr2_probe.log`), `HOME` and `$AGENTIC_DESIGN_REGISTRY` in scratch: the whole lifecycle plus a 24-entry card and 5-entry `tokens.css` reference matrix, every result as the contract text states. PASS
  - Test 0 pin mutation probe (`scratchpad/rr2/mutate.py`: Test 0 extracted from the smoke, run against mutated copies of a `git archive HEAD` snapshot): the baseline passes; an engine prefix the text does not name, a missing `data:` in the drafter, and the old `tokens.css` clause each fail it. PASS (one observation, below)
  - The real `~/.config/agentic-workspace` absent before and after; the scratch HOME holds only `Library/Caches`. PASS
  - Frontmatter of `design-drafter.md` and `design-cowork/SKILL.md` parses as YAML (Ruby), no `: ` in either `description`. PASS
  - `CLAUDE.md` 12,286 B, under the 12,288 B cap. PASS
  - `DesignSync` / `Claude Design` sweep: the same 14 allowed hits (optional bundle import, deliberate "no DesignSync" lines); F2 added none. PASS
- `deviations`: none from the plan. Two probes go beyond it: the Test 0 pin mutation probe, and six new matrix entries (`data:` stylesheet, `data:` font in `url()`, `xlink:href="#g"`, `./x.png`, `/x.png`, `file:`) that test F2's new "a `data:` URI suits any resource" text. I ran no `review-phase`, `accept-gate` or `defer-job`, scratch included.
- `doc_versions`: none — deferred to a docs phase. The gate is waived, so no gate sections were written.
- `review_verdict`: **pass**. Finding 7 is fixed and F2's three deviations are accepted; every check the first two reviews passed still passes. No new findings. The observations below are not findings and propose no fix slice.
- `walkthrough`: none — the gate is waived (`acceptance.required: false`, machinery only).
  - **Operator question: already routed** as **D29** (filed, `deferred`); D30, D31 and D32 (the previous run's DJ4) are filed too. Not re-listed. The orchestrator still owes the operator two relays: the D29 question ("will any repo need more than one design project?"), and the **Relay summary, final** at the end of this file, for the dashboard build.
  - **No new deferred-job candidates.**
- `explain`: not written — run /explain for this phase

## Boundary

`phase-scope P26`: range `869f207..22b3acb` (10 commits), the same 18 product files as both earlier runs — `.claude/agents/{design-drafter (A),slice-executor-high,slice-executor-mid}.md`, `.claude/skills/{create-phase,design-cowork,do-next-slice,do-whole-phase}/SKILL.md`, `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `README.en.md`, `bootstrap_agentic_workspace.sh`, `executors.toml`, `installer/{README.md,build.py,main.py}`, `scripts/workflow.py`, `tests/retrofit_smoke.sh`.

F2 (`22b3acb`) touched 4 of them: `design-cowork` (two hunks: the Self-contained bullet L336–341, and read-back step 2's failure list L460–466), `design-drafter.md` (§Do 2, one line), `tests/retrofit_smoke.sh` (+15 lines inside the one Test 0 block) and the rebuilt installer. `git diff b84eb1e 22b3acb` shows no change to `scripts/workflow.py`, `CHANGELOG.md`, `CLAUDE.md`, the do-* skills, the executors, the READMEs or `installer/`.

## Finding 7: fixed

The four statements of the reference rule now agree:

| Source | What it says |
|---|---|
| Contract, `design-cowork` L336–341 | nothing relative except `../tokens.css` and in-page `#` fragments (inline SVG's `url(#id)` / `<use href="#id">`, a `href="#"` stub); images inline SVG or `data:`, "a `data:` URI suits any resource"; anything else an absolute `https:` URL; `tokens.css` the same rule, `#` included, without the `../tokens.css` exception |
| `design-drafter.md` §Do 2 (L26) | the same, sentence for sentence ("The only relative references allowed are `../tokens.css` and in-page `#` fragments…") |
| Engine, `scripts/workflow.py` L3049 | `DESIGN_ALLOWED_REFS = ("#", "data:", "https://")`, plus `../tokens.css` for cards only (`allow_tokens`); the error text names "../tokens.css, an in-page `#` fragment, `data:` or an absolute https URL" |
| Relay summary (below) | `../tokens.css`, in-page `#` fragments, `data:` URIs, absolute `https:` URLs; `tokens.css` the same without `../tokens.css` |

Probed on a scratch install of the F2 installer (whose `design-cowork` and `workflow.py` are byte-identical to the repo's, and whose drafter carries the F2 text):

| Card reference | rc | Matches the text |
|---|---|---|
| `https://…`, `HTTPS://…`, `data:image/gif…`, `href="#"`, `url(#g)` + `<use href="#g">` + `href="#top"`, `xlink:href="#g"` | 0 | allowed |
| `data:text/css,…` stylesheet, `url(data:font/woff2;…)` font (F2's "any resource") | 0 | allowed |
| `//cdn…` (named: protocol-relative), `url(//…)`, `http://…` and `HTTP://…` (named: plain http) | 1 | forbidden |
| `mailto:`, `tel:`, `javascript:`, `about:blank`, `file:///x.png`, `logo.png`, `./x.png`, `/x.png`, `../other.css` | 1 | forbidden |
| `srcset="//…"`, a string `@import "http://…"` | 0 | outside the scan (`src`/`href`/`url()` only): the known gap filed as D32, unchanged since S1 |

`tokens.css`: `//` and `../tokens.css` fail; `url(#f)`, `https:` and `data:` pass — exactly "the same rule, `#` included, without the `../tokens.css` exception". The first-round card `01-colors` (inline-SVG `url(#g)`, `<use href="#g">`, `href="#"`, `data:`, `https:`) checked, signed and regrouped cleanly.

### F2's three deviations: all accepted

1. **"a `data:` URI suits any resource."** Right call. "Images are inline SVG or `data:`, and anything else is an absolute `https:` URL" read literally sends a `data:` font or stylesheet to `https:`, while the engine accepts `data:` anywhere (probed: stylesheet and font both pass). Same text-vs-engine class as finding 7; "anything else is an absolute `https:` URL" is kept verbatim, so nothing was loosened.
2. **Read-back step 2: "a relative reference" → "a reference the self-contained rule forbids".** Right call: `#` and `../tokens.css` are relative and pass, so the old phrase told the orchestrator the wrong failure cause. The governance around it is intact (run `design-check` yourself, never rest on the drafter's line, never fix by editing the cards, one re-dispatch then `pending`); the rest of the hunk is reflow. No other boundary text restates the rule (grep over `CLAUDE.md`, `.claude`, `CHANGELOG.md`, both READMEs, `installer/`, `docs/retrofit-guide.md`, `scripts/workflow.py`).
3. **The Test 0 pin covers the drafter too.** Right call: the drafter repeated the defect and is the literal reader. The pin reads `DESIGN_ALLOWED_REFS` from the engine by regex, so a new engine prefix fails it until both texts name it (mutation-probed below).

### Test 0 pin, mutation-probed

| Mutation (one per copy of a `git archive HEAD` snapshot) | Test 0 |
|---|---|
| none (baseline) | pass |
| engine adds `"mailto:"` to `DESIGN_ALLOWED_REFS` | **fails**, naming `mailto:` |
| drafter drops "`data:` (a `data:` URI suits any resource)" | **fails**, naming `data:` |
| contract reverts the `tokens.css` clause to "with no exception" | **fails** |
| contract drops `` `#` `` from the card sentence only | passes (observation 1) |
| drafter drops `` `#` `` from its first sentence only | passes (observation 1) |

## No regression: the first two reviews' checks still hold

- **Validation:** `build.py --check`, `sync-agents --check`, `validate` and the smoke (195 / 0) pass. Test 13's first line still passes: "design-check names a gap, an unnumbered card, a // and an http:// reference (exit 1) and passes the numbered set with ../tokens.css, #, data: and https references".
- **The contract end to end** (`rr2_probe.log`), each step as in both earlier runs:
  - install rc 0, `validate` rc 0, three agent files shipped; `works/.workspace-version.json` stamps `workspace_version: 47`;
  - `design-check` / `design-open` before init point at `design-init`; `design-init` writes `{schema 1, id, name}`, a re-run is "unchanged";
  - `design-open` writes the 10 `round.json` keys (`open`, `closed_at: null`, `cards: []`, `supersedes: []`); a second open is refused;
  - two hand-written cards (one `title`-last, one `viewport`-first with a CRLF body) pass whole and against the handoff list;
  - negative runs name every problem: a gap, an unnumbered `type.html`, an unknown attribute, a relative `logo.png`, a stray `design-system.html`, a missing handoff path, a marker not on line 1, `viewport 'wide'`;
  - `design-close --words` is refused before `SIGNOFF.md`; the snapshot equals the pre-close bytes, the `tokens.css` snapshot is identical, the regroup touches line 1 only (attribute order kept, every later byte identical); a re-run leaves the tree's shasum unchanged; `--superseded` on a signed round is refused;
  - the supersede chain: `02-form` (P1.S2) closes `--superseded` with no regroup and `supersedes: ["01-signin"]`; P1.S3's `design-open` is refused; `design-check` flags both addressed cards in the gap; P1.S2's `03-form-v2` opens; a list omitting the inherited card fails and the full list passes; signing gives `supersedes: ["02-form"]`;
  - `design-register` writes absolute paths to the scratch registry only, mode 0600; a re-run prints "already registered (nothing written)" and the sha is unchanged;
  - isolation: the scratch HOME has no `.config`; the real `~/.config/agentic-workspace` is absent before and after.
- **Findings 1–4 (F1) stay fixed:** F2 touched none of the drafter's §Inputs 1 / §Do 7 licence lines, the engine, `CHANGELOG.md` or the do-* skills.
- **Intent:** all five deliverables present — the contract, the drafter (background-dispatchable, `frontend-design` keyed to the handoff line), the `design-cowork` rewrite (`DesignSync` retired, bundle import optional), the `CLAUDE.md` L52 reword, the register hook. No interim viewer, Claude Code only, no claude.ai account anywhere.
- **Governance:** F2's two `design-cowork` hunks touch no governance row of the S3 audit (the contract's reference rule and one failure-cause phrase); the per-round steps, stop and commit counts, PENDING #1/#2 and literal signoff in `design-cowork`, `do-whole-phase` and `do-next-slice` are untouched since F1 and still agree.
- **Sweep:** the 14 `DesignSync` / `Claude Design` hits are the optional bundle import and the deliberate "no DesignSync" lines; both F2-touched files' frontmatter is valid YAML; `CLAUDE.md` is under its cap.

## Checklist (`docs/current/qa.md` `## Regression Checklist`)

All 6 lines are **inside** the boundary: each is fed by `scripts/workflow.py`, `installer/*`, `bootstrap_agentic_workspace.sh`, `tests/retrofit_smoke.sh` or `.claude/*`, all in the diff. **Outside: 0**, with the `phase-scope` file list above as the proof.

| Line | Re-run evidence (`smoke_rr2.log`, `rr2_probe.log`) | Result |
|---|---|---|
| installer: a fresh install validates and stamps `workspace_version` (P16) | T5 "fresh install exits 0", "fresh workspace validates", "release version agrees across installer, top changelog heading, and fresh marker"; my scratch install rc 0, `validate` rc 0, `workspace_version: 47` | pass |
| engine: an undeclared or uncleared gate refuses `review-phase --verdict pass` (P16) | T5 "review-phase --verdict pass refuses an undeclared acceptance gate"; the uncleared half by inspection: `git diff 869f207..HEAD -- scripts/workflow.py` has 0 lines touching `acceptance` or `cleared_at` | pass |
| machinery text: Test 0's invariants hold, including tier body parity (P16) | Test 0 PASS (now including F2's pin) | pass |
| engine: `## Slices` renders from `slice.json`, and `finish-slice --outcome` fills the row (P18) | T9 "new-phase renders the generated ## Slices block", "finish-slice --outcome lands in the slice's generated row" | pass |
| engine: a marker-less notebook stays byte-identical, and repeated `next` leaves the dashboards clean (P18) | T9 "a marker-less phase.md is left byte-identical", T10 "two next calls leave the dashboards byte-identical" | pass |
| engine: `new-slice --kind research` works, and an invented kind errors naming the closed set (P19) | T5 "new-slice accepts --kind research", "the unknown-kind error names research in the closed set", "new-slice rejects an unknown --kind and creates nothing" | pass |

No lines were appended: the gate is waived.

## Doc impact: complete

- **operations:** S1, S2, S3, S4, F1, F2;
- **architecture:** S1, S2;
- **decisions:** S1/S2 (added at the first review), S3, S4, F1, F2;
- **qa:** S1, S2, S3, S4, F1, F2.

F2's three lines are present: operations (the self-contained rule as the text now states it, drafter §Do 2 the same), decisions (`#` named in the text, replacing the `#` half of F1's decisions line, with the reason), and qa (Test 0 pins both texts against `DESIGN_ALLOWED_REFS`, baseline 195). F2's read-back phrase change is covered by its operations line. Nothing is versioned here.

## Operator Questions

One entry (P26.S1), routed at the first review and filed as **D29**. Nothing new was raised; no routing line was added.

## Observations (not findings; no fix slice, no job proposed)

1. **The pin's `#` check is also satisfied by the pinned `tokens.css` clause.** "`#` fragments included" names `` `#` ``, so deleting `#` from the card sentence alone still passes Test 0 (mutation-probed). The pin meets its stated spec (the bullet names every `DESIGN_ALLOWED_REFS` prefix), and the only escaping edit leaves a bullet that still names `#` fragments through the clause the pin requires. Not worth a larger test under the repo's tiny-tests rule.
2. **An empty `src=""` / `href=""` passes `design-check`** (the engine skips an empty reference). The text does not name it, but an empty reference loads nothing, so a card's rendering is the same from any location and neither the drafter (which has `href="#"`) nor the dashboard needs it. Seen and accepted at the previous run too.
3. `design_reference_problems`' docstring says `tokens.css` is "self-contained outright"; its behaviour matches the contract (the same set without `../tokens.css`). Wording only, internal.

## Review history

- **First run** (`c44ab6f`): `changes_requested`, findings 1–4, fixed in `P26.F1`; findings 5–6 repaired in the notebook; DJ1–DJ3 filed as D29–D31.
- **Re-review after F1** (`5092bd7`): `changes_requested`, finding 7 (the contract text forbade the `#` fragments the engine allows), fixed in `P26.F2`; DJ4 filed as D32.
- **This run:** `pass`.

## Notebook edits (`phase.md`)

- **`## Decisions`:** the contract line's relay pointer now names the final summary below (relay-ready); the two re-review lines are merged into one recording both re-reviews, this one `pass`.
- **`## Doc impact`**, **`## Operator Questions`:** unchanged (complete; routed).
- **`## Notes for later slices`:** the F2 → REVIEW note and the DECOMP every-slice note are consumed; no slice remains.
- **`## Now`:** rewritten as the close-out.

## Relay summary, final (for the dashboard build; relay verbatim)

This is the schema-1 contract as a reader needs it, checked line by line against `design-cowork` §*The design record — the on-disk contract (schema 1)* and against the engine by the probes above. It replaces the summary at the end of `slices/P26.S1/result.md` and the earlier review versions.

**Where projects are.** The registry is one JSON file on the Mac: `$AGENTIC_DESIGN_REGISTRY` if set, else `~/.config/agentic-workspace/design-registry.json`.

```json
{"schema": 1, "projects": [{"id": "acme-web", "name": "Acme Web", "repo": "/abs/repo",
  "root": "/abs/repo/docs/reference/design", "registered_at": "2026-09-29T21:30:00+09:00"}]}
```

- `projects` is sorted by `id`; `repo` and `root` are absolute paths.
- A product repo registers itself with `python3 scripts/workflow.py design-init` (once), then `python3 scripts/workflow.py design-register`. `design-register` is the only writer, atomic and idempotent.
- Show an entry whose `root` no longer exists as unavailable instead of failing.
- The engine writes the file owner-only (mode 0600), so run the dashboard as the same macOS user.

**What is under each `root`.** Text is UTF-8 without a BOM; each JSON file holds one object (do not depend on its formatting). Ignore any file or key not named here; treat a `schema` other than `1` as unsupported.

- **`design.json`**: exactly `{"schema": 1, "id", "name"}`. `id` is lowercase `[a-z0-9-]`, starts alphanumeric, at most 63 characters, unique in the registry (the dashboard's key); `name` is the display name. One project per repo in schema 1.
- **`tokens.css`**: the design tokens, one stylesheet. Optional until a round drafts it.
- **`cards/NN-slug.html`**: the live card library.
  - `NN` is at least two digits, zero-padded (`01` … `99`, then `100`), from `01`, contiguous; `slug` is `[a-z0-9]+(-[a-z0-9]+)*`. **Sort numerically**, never lexically. A path never changes: a card that supersedes one is written at the same path.
  - **Line 1 is the marker and only the marker:** `<!-- @dsCard`, then one or more ` key="value"` pairs (one space before each, double quotes) **in any order**, then ` -->`, then `\n` or `\r\n`. Parse the pairs; never match a fixed order.
    - Keys: `group` (required), `viewport` (required, `WxH` in positive-integer CSS px: the frame size to render at; mobile sizes are valid), `title` (optional; fall back to the slug). No other keys; each at most once.
    - Values are non-empty, have no leading or trailing space, and contain none of `"`, `<`, `>` or `--`.
  - A `group` starting `⏳ <slice-id> · ` (U+23F3, space, the owning slice id, space, U+00B7, space) marks a card **under review**; the rest is its library group. Any other `group` is a signed library heading.
  - **References.** A card references only:
    - `../tokens.css`;
    - in-page `#` fragments (inline SVG's `url(#id)` and `<use href="#id">`, a `href="#"` link stub);
    - `data:` URIs, for any resource;
    - absolute `https:` URLs.

    Nothing else: no other relative path, and no `//`, `http:`, `mailto:`, `tel:`, `javascript:`, `about:` or `file:`. `tokens.css` follows the same rule without the `../tokens.css` entry. So serve the root as static files and render each card in its own iframe at its `viewport`: `../tokens.css` resolves from `cards/` and from a snapshot alike, and only `https:` references need the network.
- **`rounds/NN-slug/`**: one folder per design round, numbered like cards. **At most one is `open`.**
  - **`round.json`**: exactly `{"schema": 1, "round", "title", "slice", "status": "open"|"signed"|"superseded", "opened_at", "closed_at", "cards": ["cards/NN-slug.html", …], "supersedes": ["NN-slug", …], "signoff_words"}`. Times are ISO-8601 with offset; `closed_at` is `null` while open; `cards` (numeric order) is filled at close and empty while open; `supersedes` is `[]` while open; `signoff_words` is the operator's literal words when `signed`, otherwise `null`.
  - **Prose** (render whichever exist): `handoff.md` (the brief), `result.md` (what was designed, departures logged), `build-prompt.md` (the implementation contract), `feedback.md` (the operator's notes), `SIGNOFF.md` (signed rounds only).
  - **`import/`** (optional): a Claude Design bundle filed as-is. It is not a card; the dashboard may ignore it.
  - **A closed round** (signed or superseded) holds a snapshot: `rounds/NN-slug/cards/<file>` for each entry of `cards`, plus `rounds/NN-slug/tokens.css` when the design root had one at close — exactly as they were at close, address still on. Render those, not the live cards; the same `../tokens.css` link picks up the round's own `tokens.css`. Nothing in a closed round's folder ever changes.
  - **The open round**'s cards are the live `cards/` files whose `group` carries `⏳ <its slice> · `.
  - Between a superseded close and the same slice's next round, `⏳` cards can briefly exist with no open round. Show them under review anyway.

**What to show.** The library is `cards/`, sorted by number and grouped by `group`, with under-review groups first. History: walk `rounds/` by number; `supersedes` names the earlier rounds whose cards this round re-drafted, and "superseded by" is yours to compute (a closed `round.json` is never rewritten to add it).

**What the dashboard never does:** write anything, shell out to git, or build anything. Every view is a plain file read.
