# Result — P26.REVIEW (review)

## Verdict

- `status`: done
- `tier`: high
- `summary`: Reviewed P26 inside its boundary (18 files, `869f207..f21129d`). The build check, `sync-agents --check`, `validate` and the smoke (195 PASS / 0 FAIL) all pass, all 6 checklist lines sit inside the boundary and pass, and an end-to-end run of the contract in a scratch fresh install works (`~/.config/agentic-workspace` never created). All five intent deliverables are present and governance held. Verdict **changes_requested**: four small source inconsistencies need one fix slice, `P26.F1` (risk high). The first is that the drafter's `frontend-design` licence ignores the handoff's `new visual direction` line. Two more findings were repaired in the notebook.
- `files_changed`:
  - `works/phases/active/P26/slices/P26.REVIEW/result.md` (new)
  - `works/phases/active/P26/phase.md`
- `validation`:
  - `python3 scripts/workflow.py phase-scope P26`: range `869f207..f21129d`, 6 commits, 18 product files. PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `python3 scripts/workflow.py sync-agents --check`: agent files in sync. PASS
  - `python3 scripts/workflow.py validate`: passed, exit 0. Its only warning is the pre-existing `oversized_doc_sections=7`. PASS
  - `bash tests/retrofit_smoke.sh` (alone in its call, foreground, 600 s): `ALL RETROFIT SMOKE TESTS PASSED`, 195 `PASS:` / 0 `FAIL`. PASS
  - `## Regression Checklist`: 6 lines, 6 inside, 0 outside, all passing (see *Checklist*). PASS
  - End-to-end contract probes in a scratch fresh install (`HOME` and `$AGENTIC_DESIGN_REGISTRY` in scratch): every step the plan lists behaves as the contract says. PASS, with finding 3 and repaired finding 5.
  - The real `~/.config/agentic-workspace` was absent before and after every probe. PASS
  - The drafter, executor and changed skill frontmatter parse as YAML (Ruby's `YAML.load_file`), with no `: ` in any `description`. PASS
  - `CLAUDE.md` is 12,286 B, under the 12,288 B cap. PASS
  - Residual `DesignSync` / `Claude Design` sweep: only allowed hits. PASS
  - `python3 scripts/workflow.py validate` re-run after the notebook edit: passed. PASS
- `deviations`: none from the plan's steps. I ran two probes beyond the plan's list, both in scratch:
  - a second install for the edge cases (attribute order, a CRLF line 1, closing with no `tokens.css`, an id collision);
  - a reference-rule probe.

  Neither the orchestrator's instruction nor the plan allows `review-phase` or `accept-gate`, even in scratch, so I did not re-probe the "uncleared gate" half of checklist line 2. The engine diff does not touch that code (see *Checklist*).
- `doc_versions`: none — deferred to a docs phase. The gate is waived, so no gate sections were written.
- `review_verdict`: **changes_requested**. Findings 1–4 need the fix slice; findings 5 and 6 were repaired in the notebook:
  1. **The drafter's `frontend-design` licence is not the handoff's line.**
     - The rule everywhere else: `design-cowork` (L198–201, L828–830), `do-whole-phase` L22, `do-next-slice` L26 and CHANGELOG v47 L38–39 say the handoff's `new visual direction: yes|no` line is the operator's call and the drafter's **only** licence to load `frontend-design`.
     - The drafter body says otherwise. `.claude/agents/design-drafter.md` §Do 7 (L31) has the drafter judge for itself what "sets a new visual direction". §Inputs 1 (L18) lists the handoff's contents without that line, and the body never mentions the line anywhere.
     - This matters because the drafter reads only the contract section of `design-cowork`. The agent that actually loads the skill therefore follows a different rule from the one the doctrine promises.
     - How it happened: S2 (tier mid) wrote the body to its plan before S3 introduced the line, and the S3 and S4 scopes did not include the drafter body. No smoke pin covers it.
  2. **`design-check` accepts references the contract forbids.**
     - The engine: `DESIGN_ABSOLUTE_REFS` (`scripts/workflow.py` L3043) lets `http://` and protocol-relative `//` through.
     - The contract says "anything else is an absolute `https:` URL", and `design-check`'s own error text says "an absolute https URL".
     - The harm: `//host/x` resolves to `file://host/x` when the operator opens a card file directly, which is the stated way to view cards before the dashboard exists. A card that passes the check therefore renders broken.
     - Probed: a card with `//cdn.example.com/x.png` and `http://x.example/y.css` passes `design-check` (OK, rc 0).
  3. **The CHANGELOG v47 contradicts itself on the regroup.**
     - L47–48 says "The `DesignSync` read-back and the SIGNOFF regroup are retired".
     - L29–30 and `design-cowork` §Closing step 2 say `design-close --words` regroups line 1, and my probe confirms that it does.
     - What was retired is the DesignSync-side regroup. `/update-workspace` shows this entry to adopters.
  4. **The do-* feedback step skips the revision handoff and the read-back.**
     - `do-whole-phase` L27 and `do-next-slice` L26 say: `feedback.md` → `design-close --superseded` → `design-open` → "re-dispatch the drafter" → PENDING #1.
     - `design-cowork` §Closing (L569–574) and §The loop add "write its handoff … re-dispatch the drafter, read back". S3's recorded decision also requires the revision handoff to list every card still carrying the slice's address (L215; `design-check` fails otherwise).
     - An orchestrator following the do-* step literally would dispatch into a round with no `handoff.md` and reach PENDING #1 unread. The counts, PENDING #1/#2 and the literal-signoff rule do agree (plan step 4 holds).
  5. *(repaired in the notebook)* **The S1 relay summary for the dashboard is narrower than the contract and the engine.**
     - It gives line 1 as a fixed shape ("exactly `<!-- @dsCard group="…" viewport="WxH" -->`, optionally with `title`"). The contract ("in any order"; "`\n` or `\r\n`") and the engine accept any attribute order and a CRLF line end. Probed: a `title`-first card with a CRLF line 1 passes, and `design-close` keeps the attribute order.
     - It lists `rounds/NN-slug/tokens.css` as always present. The engine snapshots it only when the root has one. Probed: closing with no `tokens.css` writes no snapshot `tokens.css`.

     A dashboard built to the summary's literal line-1 shape would reject valid cards. The corrected summary is in *Relay summary, corrected* below, and `phase.md` `## Decisions` now points to it.
  6. *(repaired in the notebook)* **`## Doc impact` missed decisions.md for S1 and S2.**
     - The schema-1 choices and their reasons were recorded only as facts in the operations and architecture lines: the fixed root, one project per repo, history as a close-time snapshot rather than git refs, and the registry outside the repo as the first out-of-repo engine write, run by the operator.
     - So was the rule that the drafter follows the high tier and is not a tier of its own.
     - I appended one decisions.md line.

  **Proposed fix slice:** `P26.F1` "align the drafter's frontend-design licence, design-check's reference rule, the v47 changelog and the do-* feedback step with the doctrine". It is `--kind fix --risk high`: it repairs defects in S2 and S4, whose verdicts read `tier: mid`, and finding 2 is in S1's engine. The fix per finding:
  1. In the drafter body §Do 7, key `frontend-design` on the handoff's line: `yes` means it may load the skill, and `no` or a missing line means never. If the line seems wrong for the round, that goes in `open_questions`, not to the drafter's own judgment. §Inputs 1 names the line.
  2. Drop `//` and `http://` from `DESIGN_ABSOLUTE_REFS`, which matches the published contract. Keep the fragment and non-resource schemes as the fix slice judges.
  3. Reword CHANGELOG L47–48 to say the `DesignSync` read-back and *its* SIGNOFF regroup are retired, and that the regroup is now `design-close --words`, line 1 only.
  4. In both do-* feedback steps, add: write its handoff (every card still carrying the slice's address), re-dispatch the drafter, read back and commit.

  Then add pins inside the existing Test 0 and Test 13 assertion blocks, so the baseline stays 195, and rebuild the installer. Validate with `build.py`, `build.py --check`, `sync-agents --check`, the smoke (195 / 0) and `validate`. Then re-run `P26.REVIEW`.
- `walkthrough`: none. The gate is waived (`acceptance.required: false`, machinery only).
  - **Question for the orchestrator to relay to the operator** (the one `## Operator Questions` entry): will any repo you design in need **more than one design project**, for example a monorepo whose apps each carry their own design system? Schema 1 holds one project per repo. A "yes" becomes deferred job DJ1 below; a "no" changes nothing.
  - **Deferred jobs to file** (I did not run `defer-job`):
    - **DJ1 — "Design schema 2: more than one design project per repo".**
      - Reason: schema 1 fixes one `docs/reference/design/design.json` per repo, while the registry is already keyed per project. This routes the P26.S1 operator question.
      - Trigger: the operator answers yes, or a repo needs a second design system.
    - **DJ2 — "Flag a design round left open, or review addresses left over, when a design phase ends".**
      - Reason: `validate` does not run `design-check`, and neither `validate` nor `review-phase` checks that a design-bearing phase ends with no `open` round and no card still carrying a `⏳` address. For example, a slice abandoned after `design-close --superseded` leaves addressed cards that `design-check` flags but nothing runs (S4's observation).
      - Trigger: the first design-bearing phase under v47, or its review.
    - **DJ3 — "Bring `docs/reference/design/` into a design phase's review boundary".**
      - Reason: `phase-scope`'s `PRODUCT_PATHSPEC` excludes `docs/`, so the cards and rounds a design phase drafts never enter its review boundary (S1's observation).
      - Trigger: the first design-bearing phase review under v47.
- `explain`: not written — run /explain for this phase

## Boundary

`python3 scripts/workflow.py phase-scope P26`:
- range `869f207..f21129d`, 6 commits;
- 18 product files: 1 added, `.claude/agents/design-drafter.md`, and 17 modified:
  - `.claude/agents/slice-executor-{mid,high}.md`;
  - `.claude/skills/{create-phase,design-cowork,do-next-slice,do-whole-phase}/SKILL.md`;
  - `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `README.en.md`, `bootstrap_agentic_workspace.sh`, `executors.toml`;
  - `installer/{README.md,build.py,main.py}`, `scripts/workflow.py`, `tests/retrofit_smoke.sh`.

`docs/retrofit-guide.md`, which S4 edited, sits under `docs/` and so outside `phase-scope`. It was still included in the plan's sweep, and it is clean.

The P26 engine diff is additive. It covers:
- `SLICE_KINDS`' comment at L39–42;
- `DESIGN_DRAFTER_FOLLOWS` and `executor_agent_files()` at L261–276;
- the `DESIGN_*` block before `main()`;
- the five subparsers.

No gate, notebook or slice-kind code changed.

## Checklist (`docs/current/qa.md` `## Regression Checklist`)

All 6 lines are **inside** the boundary: each is fed by `scripts/workflow.py`, `installer/*`, `bootstrap_agentic_workspace.sh`, `tests/retrofit_smoke.sh` or `.claude/*`, all of which are in the diff. **Outside: 0.** The proof is the file list above. The re-runs:

| Line | Re-run evidence | Result |
|---|---|---|
| installer: a fresh install validates and stamps `workspace_version` (P16) | smoke T5: "fresh install exits 0", "fresh workspace validates", "release version agrees across installer, top changelog heading, and fresh marker"; my scratch install: rc 0, `validate` rc 0, `works/.workspace-version.json` `workspace_version: 47` | pass |
| engine: an undeclared or uncleared gate refuses `review-phase --verdict pass` (P16) | smoke T5 "review-phase --verdict pass refuses an undeclared acceptance gate". The gate code is untouched by the P26 diff, which is additive (see *Boundary*). I did not probe "uncleared" in scratch, because the review may not run `review-phase` or `accept-gate`. | pass |
| machinery text: Test 0's invariants hold, including tier body parity (P16) | smoke Test 0 PASS | pass |
| engine: `## Slices` renders from `slice.json`, and `finish-slice --outcome` fills the row (P18) | smoke T9 (3 lines) | pass |
| engine: a marker-less notebook stays byte-identical, and repeated `next` leaves the dashboards clean (P18) | smoke T9 "a marker-less phase.md is left byte-identical", T10 "two next calls leave the dashboards byte-identical" | pass |
| engine: `new-slice --kind research` works, and an invented kind errors naming the closed set (P19) | smoke T5 (4 lines) | pass |

No lines were appended: the gate is waived, and waived phases (P21–P24) appended none.

## The contract, end to end (scratch fresh install)

- **Setup:**
  - built installer → `scratchpad/p26r/acme-web`;
  - `HOME=scratchpad/p26r/home`, `AGENTIC_DESIGN_REGISTRY=scratchpad/p26r/reg/design-registry.json`;
  - scripts `scratchpad/review_probe.sh` and `review_probe2.sh`, log in `probe.log`.
- **The install:** it ships `.claude/agents/{design-drafter,slice-executor-high,slice-executor-mid}.md`.
- **Before init:** `design-check` (rc 1: "no design root … run design-init") and `design-open` (refused, no valid `design.json`) both point at `design-init`.
- **`design-init`:**
  - it writes `{"schema": 1, "id": "acme-web", "name": "acme-web"}`;
  - a re-run prints "unchanged".
- **`design-open --slug signin --slice P1.S1`:**
  - it writes `rounds/01-signin/round.json` with exactly the 10 contract keys: `status: open`, `closed_at: null`, `cards: []`, `supersedes: []`;
  - a second `design-open` is refused while `01-signin` is open.
- **Two cards written by hand:**
  - `01-colors` with a `title` and a `⏳ P1.S1 · Foundations` address;
  - `02-button`, with `viewport` before `group` and a CRLF inside the body;
  - plus `tokens.css` and `handoff.md`.

  `design-check` and `design-check cards/01-colors.html cards/02-button.html` both pass: "OK -- 2 card(s), 1 round(s), open round: 01-signin".
- **Negative runs:** one run named five problems with exit 1:
  - an unknown attribute `name`;
  - a relative `logo.png`;
  - `cards/type.html: unnumbered card path`;
  - `gap in the card numbering: no card numbered 02`;
  - a stray `design-system.html`.

  Other runs named:
  - a handoff path that is missing;
  - a marker not on line 1;
  - `viewport 'wide'`;
  - `--` in a value;
  - a padded value;
  - a non-canonical `004`;
  - a double space in the marker.
- **`design-close 01-signin --words "ship it"`:**
  - It is refused before `SIGNOFF.md` exists. After that, the card snapshot, `tokens.css` snapshot, regroup and manifest all behaved as the contract says:

    | What | Result |
    |---|---|
    | card snapshot | equals the pre-close bytes, address on |
    | `tokens.css` snapshot | identical |
    | regroup | line 1 only (`group="Foundations"`, `group="Components"`, attribute order kept); every byte after line 1 identical |
    | `round.json` | `signed`, `cards` filled in numeric order, `supersedes: []`, `signoff_words: "ship it"` |

  - Re-running it prints "already signed (nothing written)", and the whole tree's shasum list is unchanged.
  - `--superseded` on the signed round is refused ("a closed round is immutable").
- **The supersede chain:**
  1. `02-form` for `P1.S2` re-drafts `02-button` and adds `03-input`. `design-close 02-form --superseded`:
     - snapshots both cards and `tokens.css`, with no regroup (the cards keep `⏳ P1.S2`);
     - derives `supersedes: ["01-signin"]`.
  2. `design-open` for `P1.S3` is refused: "cards still carry the review address of P1.S2".
  3. `design-check` in the gap flags both addressed cards: "…P1.S2, which has no open round".
  4. `design-open` for `P1.S2` opens `03-form-v2`. A handoff list that leaves out inherited `02-button` fails ("added beyond the handoff's list but numbered before its last card"). The full list passes.
  5. Signing gives `supersedes: ["02-form"]`, and both cards are regrouped.
  6. The final `design-check` is OK with no open round.
- **`design-register`:**
  - it writes `{schema: 1, projects: [{id, name, repo, root, registered_at}]}` with absolute paths, to the scratch registry only, with mode 0600;
  - a re-run prints "already registered … (nothing written)", and the file sha is unchanged;
  - a second repo claiming the same live id is refused and the registry is untouched.
- **Isolation:** the scratch HOME has no `.config` (only macOS Python's `Library/` cache). The operator's real `~/.config/agentic-workspace` does not exist, before or after.
- **Edge probes:**
  - A `title`-first card whose line 1 ends in CRLF passes and closes with its order and CRLF kept.
  - A close with no root `tokens.css` writes no snapshot `tokens.css`.
  - `//cdn…` and `http://…` references pass (finding 2).

**Against the S1 contract summary:** everything matches except the two points in finding 5, now corrected below. All three agree on the `round.json` keys, the registry shape and sort, numbering, the address grammar, `cards` being empty while open, `supersedes` being derived, and closed rounds being immutable. The three are the summary, `design-cowork`'s contract section (L286–446, byte-identical since S1) and the engine. Finding 2 is a mismatch between the engine and the contract section; the summary is silent on it.

## Intent coverage

1. **The contract:** `design-cowork` §*The design record — the on-disk contract (schema 1)*, plus the five commands. Present.
2. **The drafter:**
   - Present and background-dispatched. `design-cowork` §Mechanics and both do-* skills use `subagent_type: design-drafter`, as a background task, with a prompt of only the round folder and the slice id. It follows the high tier.
   - `frontend-design` is limited to new-direction rounds in substance, but the drafter body keys that on its own judgment rather than the handoff's line (finding 1).
3. **The `design-cowork` rewrite:**
   - `DesignSync` is gone from `allowed-tools` and from the loop, and the bundle import is optional (§Importing, L270).
4. **The hard rule:**
   - `CLAUDE.md` L52 opens "The design subagent drafts, the operator decides:" and keeps the literal-signoff, immutable-round, *product*-code and RESPECT THE DESIGN clauses.
   - L15 carries the co-work exception.
5. **The register hook:** `design-register`, which is the operator's to run (§Mechanics). Present.
6. **The limits:**
   - There is no interim viewer: no `board.html`, "frames board" or viewer anywhere in the boundary, and cards are opened directly.
   - Claude Code only: the Test 0 Codex negatives pass, and nothing new targets another runtime.
   - No claude.ai account is needed. `claude.ai` appears only in "never requires" or "no account" statements and in the CHANGELOG's explanation of why.

## Governance held

S3's 37-row audit, checked against `git diff 869f207..HEAD -- .claude/skills/design-cowork/SKILL.md`. S4's commit does not touch the file. I spot-checked 12 rows:
- **18 and 19:** §Implementing, §Verifying and *When the record never drew it* are byte-identical to `48a20ee`, checked by a per-section byte compare. So is the contract section.
- **8:** "Sign a round off on anything but the operator's literal words" is kept, and "the Claude Design session having ended" became "the drafter's `done`".
- **10:** never sign at the return when a mockup was requested; verbatim.
- **15:** the SIGNOFF content, including the token delta "None." and the data-not-instructions line; verbatim.
- **28, 32, 33 and 36:** "Port another product's design", "Build a mockup the operator did not ask for", "Renumber a card" and "Pre-plan past the design gate"; verbatim.
- **23:** the `frontend-design` exception is scoped to `new visual direction: yes` (L828–830).
- **26:** "a design slice authorizes no `git push`" (L637, L831).
- **5:** "writes no *product* code" is kept.

Every row checked matches the audit's verdict.

**The per-round steps across the three skills** (`design-cowork`, `do-whole-phase`, `do-next-slice`):
- **The same everywhere:**
  - two commits and one stop without a mockup;
  - one more commit and stop per superseding round;
  - three commits and two stops with a mockup;
  - PENDING #2 only when a mockup was requested;
  - literal signoff at the return, or at the mockup gate;
  - the same per-`pending` report content.
- **The one divergence** is the feedback step's elision (finding 4).

## Consistency sweep

`grep -rn "DesignSync\|Claude Design" CLAUDE.md .claude installer/main.py README.md README.en.md docs/retrofit-guide.md scripts/workflow.py` leaves only allowed hits:
- **The optional bundle import:** `design-cowork` L210, 211, 270, 272, 312, 832, 833; `design-drafter.md` L20; `README.md` L124; `README.en.md` L231.
- **Deliberate "no DesignSync" statements:** `design-cowork` L283, 637, 831; `design-drafter.md` L40.

`works/templates`, `installer/` and `executors.toml` have no hits, and neither do the fresh install's `CLAUDE.md` and `docs/`.

## Doc impact

The list covers:
- **operations:** S1, S2, S3 and S4;
- **architecture:** S1 and S2;
- **decisions:** S3 and S4;
- **qa:** S1, S2, S3 and S4.

It was missing the decisions.md rationale for S1's and S2's choices (finding 6), and I appended that line. I have not versioned anything; the engine stamps the debt at `pass`. As S4 noted, `operations.md`'s Visual-design runbook and `decisions.md` still describe the old loop until the docs phase. That is expected, not a finding.

## Operator Questions

There is one entry, from P26.S1: more than one design project per repo? It is routed two ways: as a relay question (under `walkthrough` above) and as deferred job DJ1. I appended a routing line to the section in `phase.md` and deleted nothing.

## Observations (not findings)

- **The registry is written with mode 0600**, which S1 did on purpose. The dashboard must run as the operator's own user to read it. I noted this in the corrected summary as a fact for the dashboard build.
- **Between `design-close --superseded` and the next `design-open`**, the working tree briefly holds `⏳` cards with no open round.
  - The doctrine puts both into one commit, so git never holds that state, but the dashboard reads the working tree.
  - The corrected summary tells readers to show such cards under review.
- **`design-register` before `design-init`** is refused with a pointer to `design-init`. Both READMEs and CHANGELOG migration note (4) say "run `design-register` once per repo" without the `design-init` prerequisite, but the error message covers it.

## Relay summary, corrected (for the dashboard build; relay verbatim)

This is S1's summary (`slices/P26.S1/result.md`, end) with finding 5's corrections and the two reader notes from the observations. The changes are marked **[corrected]** and **[added]**.

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
  - **[corrected]** Line 1 is the marker and only the marker: `<!-- @dsCard` then one or more ` key="value"` pairs **in any order**, then ` -->`, and the line ends in `\n` or `\r\n`.
    - The keys are `group` and `viewport`, which are required, and `title`, which is optional. There are no other keys, and each appears once.
    - Parse the pairs; do not match a fixed attribute order.
    - `viewport` is `WxH`, the iframe size in CSS px. Mobile sizes are valid.
  - A `group` starting `⏳ <slice-id> · ` (U+23F3 … U+00B7) marks a card **under review**; strip that prefix to get its library group. Any other `group` is a signed library heading.
  - Cards reference only `../tokens.css` relatively, so serve the root as static files and render each card in its own iframe.
- **`rounds/NN-slug/`**: one folder per design round, numbered like cards. At most one is `open`.
  - **`round.json`**: `{"schema": 1, "round", "title", "slice", "status": "open"|"signed"|"superseded", "opened_at", "closed_at", "cards": ["cards/NN-slug.html", …], "supersedes": ["NN-slug", …], "signoff_words"}`.
  - **Prose** (render whichever exist): `handoff.md` (the brief), `result.md` (what was designed), `build-prompt.md` (the implementation contract), `feedback.md` (the operator's notes), `SIGNOFF.md` (signed rounds).
  - **[corrected]** A **closed round** (signed or superseded) holds a snapshot: `rounds/NN-slug/cards/<file>` for each entry of `cards`, plus `rounds/NN-slug/tokens.css` **when the design root had one at close**. The files are exactly as they were at close. Render those, not the live cards. Nothing in a closed round's folder ever changes.
  - **The open round**'s cards are the live `cards/` files whose group carries `⏳ <its slice> · `; its `cards` list stays empty until close.
  - **[added]** Between a superseded close and the same slice's next round, `⏳` cards can briefly exist with no open round. Show them under review anyway.
  - **History:** walk `rounds/` by number. `supersedes` names the earlier rounds this one re-drafted. Compute "superseded by" yourself.

**What the dashboard never does:** write anything, shell out to git, or build anything. Every view is a plain file read.

## Notebook edits (`phase.md`)

- **`## Decisions`:**
  - The contract line's pointer now names this corrected relay summary.
  - One line records the review outcome and the four points `P26.F1` must fix.
- **`## Doc impact`:** one decisions.md line appended (finding 6).
- **`## Operator Questions`:** one routing line appended; the entry is unchanged.
- **`## Notes for later slices`:**
  - The S4 → REVIEW note is consumed.
  - The DECOMP "every slice" note is kept.
  - One note was added for `P26.F1`.
- **`## Now`:** rewritten.
