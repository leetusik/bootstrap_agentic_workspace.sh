---
doc_id: qa
version: v0013
created_at: 2026-10-07T17:11:34+09:00
commit: 1d107b5b1c047f1da7338852e882142394785950
source: P26.REVIEW, P27.REVIEW, P28.REVIEW, P29.REVIEW, P30.REVIEW
summary: P26-P30 smoke baseline 239, design and nested-install pins, fragile installer tokenizer
previous: v0012_p30_review_regression_checklist_gains_the_rotate-backlog_docs-phase_proposal_--archive-only_the_--consolidates_covering_mark_and_the_docs-debt_paid-by_checks
---

# QA

## Status

Default testing posture: **core-only**. Test files are written only for very core behavior — logic the product cannot afford to break — and never for style, cosmetic or trivial surface, which is verified live instead. What exists stays terse: minimal high-value cases, no fixture or scaffolding sprawl. The workspace itself follows this with a single committed smoke test (`tests/retrofit_smoke.sh`) plus `python3 scripts/workflow.py validate`.

As of **v39 the posture above is core-only** (P22): test files exist for very core behavior only, and everything else — style, cosmetic or trivial surface — is verified live. The retrofit smoke baseline stands at **239 PASS / 0 FAIL**, counted as of **v51** (P30). That one script now runs Tests 0-16, including the design contract (Test 13) and the nested engine and installs (Tests 14-16). See *Testing Philosophy* and *Test Commands* below.

As of **v32** the workspace also states *what verification has to look at*, not only how much of it to write. Fidelity has **two yardsticks, both mandatory** — *matches the record* and *works as a product* — the phase review performs **gate stages against the running product itself** on any phase that changes operator-visible surfaces, and `## Regression Checklist` below is the product's **cumulative smoke list**, re-run by every later phase **inside its own boundary** — the lines its changed files feed, `phase-scope <P>` naming the files; the whole list only by an operator-created QA phase (since v41). Terseness is unchanged and is the point: headline behaviours, not 230 assertions. See *Verification doctrine* below.

As of **v34 the doctrine has one bounded exemption**: a design round's **stubbed mockup** proves *look and states, not wiring*, so the functional sweep does not apply to it. The sweep is an **apply/fidelity** duty on real wiring, and confusing the two is what turns a design gate into the build it was supposed to precede. **Since v42 a mockup is built only when the operator asks for one**, so the exemption applies only to those rounds; a round that closes on the operator's return ships no mockup and meets no exemption at all. See *The one exemption* below.

As of **v36 the doctrine finally names its instrument**: **Aside** — a local-first Chromium browser agent — **in place of a pre-written assertion suite**. Since v32 this doctrine has said thoroughly *what* to check and *where*, and never once *with what*, which left the pre-written assertion suite as the default by silence — the very shape of check that let eleven user-visible failures through thirty slices. **v37 makes that prescription true in the particulars v36 got wrong or never said**: Aside has **two** surfaces rather than three, the default is **`aside repl` over Bash** (executor-driven, and explicitly *not* a standing MCP registration, whose one tool definition is paid in every session), and agent runs happen on a **dedicated Aside profile** named per invocation — never the operator's signed-in one, which is a **third** `needs_operator` halt. The fallback keeps the prescription honest without making it a gate: *the doctrine's demands bind, the instrument does not*. See *With what — the instrument* below.

## Purpose

Use this doc for test commands, acceptance criteria style, manual QA missions, browser QA flows, regression checks, and known fragile areas.

## Testing Philosophy

- **Core-only (since v39).** Test files exist for very core behavior — logic the product cannot afford to break — and never for style, cosmetic or trivial surface, which is verified live instead.
- **Minimal by default.** Prefer lightweight verification — run the code, `validate`, a small smoke check — over broad automated suites.
- **Keep test files small.** When a test is worth committing, keep the file or suite terse: a few high-value cases, no fixture or scaffolding sprawl.
- **Grow on demand.** Expand coverage only when the operator asks or the risk clearly warrants it; note the reason here when you do.

## Verification doctrine — matches the record, works as a product, driven by a browsing agent (v32, instrument named in v36)

A rigorous conformance pass can be a false negative for the only question that matters. The failure
class this doctrine exists to close: two build phases, thirty slices, a scripted real-browser
fidelity slice at the end of each, both reviews passed — and the product owner, opening the running
product for the first time afterwards, found eleven user-visible failures, led by a login link that
never rendered in the runtime *they* use. Every check had passed, because the checks measured the
signed design record in the executor's most convenient runtime.

**Two yardsticks, both mandatory.**

1. **Matches the record** — rendered values, tokens, layout, states, measured against the signed
   design record. Unchanged, and still RESPECT THE DESIGN.
2. **Works as a product** — the record is the **floor** of what to check, never the ceiling, and
   *matching it is not acceptance*. A screen can be pixel-perfect and dead.

**The functional sweep** (specified in the `design-cowork` skill's *Verifying* section) — an
**apply/fidelity duty, on real wiring**, and each item a defect when it fails **even if the pixels are
perfect**:

- **Every visible interactive element does something observable.** A control that no-ops is a defect,
  not a "not wired yet".
- **Interaction states** — focus, hover, keyboard path — on every input and control, *including the
  browser defaults the record never drew*. An ugly focus ring, or one the neighbouring button covers,
  is a finding, not "unspecified".
- **Liveness over time.** Watch a timer tick for a real interval instead of reading its code; check
  that polling or auto-refresh does not destroy in-progress input.
- **Type into it and wait.** Search, typeahead, validation, autosave are exercised by typing and
  waiting, not only by submitting — "nothing happens while I type" is a finding no submit-only check
  can make.

**The one exemption — a design round's stubbed mockup (since v34; on request since v42).** A design
round may end with a **throwaway route in the project's own frontend** — only when the operator asked
for one (`Mockup: requested` under `## Design Style`, or in their own words before the round closed);
otherwise the round closes on the operator's return, signed on the card set, and there is nothing
here to exempt. A requested mockup is built from the landed `build-prompt.md` and opened by the
operator at the round's gate. It carries **stubbed data and does no backing work**, so:

- **Non-functional controls are not defects there.** They are named as deliberately unwired — in the
  gate walkthrough, and in the mockup span's `result.md` — never filed as findings.
- **What is checked instead:** it runs; every designed element and every designed state renders;
  nothing is dropped, simplified, restyled or "improved" (RESPECT THE DESIGN); and it matches the
  record. Plus the third `needs_operator` condition — a record wrong, inconsistent, or too thin to
  build without inventing is raised, never filled in.
- **The manifest runtime is *not* relaxed.** `## Operator Runtime` applies **everywhere, the mockup
  included** — only the sweep is exempt, and only there.
- **Why the bound is load-bearing.** Sweeping a stubbed mockup would demand exactly the backing work
  the mockup exists to defer; the span would grow into the apply slice it precedes, and the design
  gate would land after the build instead of before it.
- **The review's stage 3 carries the same qualifier.** The phase gate follows the mockup with no
  judgment left in it (v42): a phase shipping one takes `acceptance.required: true`, so its gated
  review meets stubbed surfaces and names their unwired controls in the walkthrough rather than
  filing them as defects, while still judging what the mockup *is* for. A **`design-only` phase that
  ships none** ships no running surface and is waived with the fixed note
  `design-only, no mockup: the operator signed the round on the card set`; `build-after` and `paired`
  phases are gated by their build/apply slices as always. A phase shipping real wiring gets the
  unqualified stage.

Everything else in this doctrine is unchanged: the exemption is one slice-kind wide and one phase
deep, and the wired product still meets the operator at the phase's acceptance gate. **Signing the
round off — the cards, and any stubbed mockup with them — is not accepting the product.**

**Where verification runs.** In the runtime and access path the adopting workspace's
`## Operator Runtime` manifest records (operations doc), and additionally in the production build
when the two differ, at every viewport the manifest names. An absent section, or one still carrying
its `UNFILLED` marker, means the same thing: the executor returns `needs_operator` and the
orchestrator sets the slice `pending`. Never assume localhost, the production build, or headless —
and since v36 that last prohibition carries its reason: a browsing agent drives a **visible**
browser, and Aside's headless story is undocumented.

**With what — the instrument (since v36; surface and profile corrected in v37).** Drive that browser
with **[Aside](https://aside.com)**, a local-first Chromium browser agent, **in place of a
pre-written assertion suite**. It is the default wherever a real browser is needed: the functional
sweep, fidelity slices, a design round's mockup when one is built, and the review's gate stages 2-4.

- **Two surfaces, not three.** The **`repl` surface** is one tool, *identical* over `aside mcp` and
  the `aside repl` CLI — the same Playwright-like environment (`page`, `snapshot()`, locators, page
  JS, screenshots), **different transport only** — and the executor holds it and picks each next
  action itself. **`aside exec`** is the other: Aside's own model drives from a natural-language
  instruction. v36's three-way MCP / CLI / REPL split described transports as if they were
  capabilities.
- **The default is `aside repl` over Bash**, executor-driven, and explicitly **not** the MCP
  transport. `aside mcp` exposes that same one tool, and its definition measures 4,974 JSON chars
  (**~1,344 tokens**) paid in **every** session, browser-related or not, with no lazy-load: a
  standing registration taxes every slice for a capability almost none of them use. Bash is already
  in both executor tiers' allowlists, so **nothing ships, nothing registers, nothing is configured**.
  The CLI's one loss — JS scope between invocations — is bought back by a two-line re-attach preamble
  (`listBrowserTabs()` → `attachBrowserTab(targetId)`), written out in full in `design-cowork`, which
  also carries the two sharp edges: over MCP the `repl` tool requires both `title` and `code` (over
  the CLI the code is positional), and snapshot refs are session- and snapshot-scoped, going stale on
  navigation (`RefStaleError`) where `getByRole` survives. An operator who wants Aside's tools as
  native tools in their **own** session may run `claude mcp add -s local aside -- aside mcp` — a
  per-operator **escape hatch** the workspace neither ships nor prescribes, and no slice may assume.
- **Whose browser — a dedicated profile, never the operator's.** `--account <id>` picks a real
  signed-in profile: the probe behind this rule reached one holding the operator's Google session, 49
  imported passwords and 6 passkeys, and an agent there can read mail, spend from saved cards and
  authenticate as the operator. So agent runs pass the flag **per invocation**
  (`aside repl --account <id> "<js>"`) and never rely on `aside account use`, which only moves the
  *default* — and the default is the operator's profile. `## Operator Runtime` records which id is
  the agent's, and a manifest naming Aside with no agent account id, or a machine holding only the
  personal profile, is a **third** halt: `needs_operator`, distinct from the runtime one, resolved by
  neither borrowing the personal profile nor creating an account for the operator.
- **Why the executor drives, and not a pre-written suite.** The surface *is* Playwright — what this
  doctrine rejects was never the library, it is **deciding every check in advance**. A suite tests
  the selectors someone already thought of, and not one demand above is of that shape: "type into it
  and wait", "watch a timer tick for a real interval", "the browser defaults the record never drew".
  The pre-written fidelity slice at the end of thirty slices is precisely what passed while eleven
  failures survived; this instrument is the answer this doctrine could not previously name.
- **Instrument and runtime are different axes.** Aside *drives* the runtime `## Operator Runtime`
  records and never substitutes one of its own. The absent-or-`UNFILLED` → `needs_operator` →
  `pending` rule is about the **runtime**, not the instrument: a manifest naming no instrument is not
  an unfilled manifest.
- **The fallback — the doctrine's demands bind, the instrument does not.** Aside is a macOS desktop
  app and needs an Aside account, so a workspace that cannot install it (Linux, CI, or an operator
  who declines) is **excused nothing**: the same sweep, at the same viewports, in the same manifest
  runtime, through whatever real browser it has — and on a profile of its own there too, since an
  agent never drives a browser profile signed into the operator's accounts, whichever browser it is.
  A pre-written assertion suite is no substitute for an executor that looks at the page and picks the
  next action, and the fallback licenses another browser, never weaker checks.
- **Name the instrument you actually used in `result.md`, and never report a browser run you did not
  make.** Nothing in this workspace installs, bundles, registers or calls Aside; **v36 ships the
  doctrine and v37 corrects it, neither ships an integration**, and no verified Aside run has been
  made from an executor in this repository — the surface facts above were verified by the operator on
  the CLI, and proving the prescription against a real browsable product is deferred job **D12**. A
  machine's Aside availability is recorded in the manifest's optional
  *Browser instrument for the agent* field, and the agent's profile in the companion
  *Agent's Aside account id* field, which is required whenever that instrument is Aside.

**The review's gate stages** — performed by the review executor, conditioned on the phase's
`acceptance.required` being `true` (waived and legacy phases skip all of it), after validating every
slice and before rendering a verdict:

1. Find the manifest (absent or `UNFILLED` → `needs_operator`).
2. **Independent spot-check:** open the running product yourself and verify the phase's headline
   claims — never pass a phase on other slices' reports alone. Driven with the instrument above
   (Aside first, the fallback browser otherwise), which also serves stages 3 and 4.
3. **Fresh-eyes walkthrough, inside the boundary (v41):** reach the surfaces the phase changed the
   way a first-time user would and use them; report everything dead, confusing, or annoying there,
   **explicitly not judged against the design record**. Findings go into the operator's walkthrough
   for a decision — never into silent fixes, and never into overriding an approved design. Surfaces
   the phase did not touch are not walked; what is noticed on the way is an observation, not a
   finding. **Qualified since v34** when the phase's operator-visible surface is a design mockup the
   operator asked for (since v42 the only kind there is): its unwired controls are named as
   deliberate, not filed as defects (see *The one exemption* above).
4. **Re-run the checklist lines inside the boundary (v41)** — this phase's own surfaces plus every
   earlier line whose surface a changed file feeds, the files from `phase-scope <P>` (a shared file
   widens the boundary; an unplaceable line is inside); record the inside/outside classification with
   the outside count and the diff as the proof, never the whole list; then append this phase's
   headline checks. The whole list is an operator-created QA phase's job, never a review's.
5. **Route every `## Operator Questions` entry** — into the walkthrough as a decision to take, or as
   a deferred job listed for the orchestrator to file. An unrouted entry blocks the pass.
6. Return the `walkthrough` beside the verdict; the orchestrator opens the gate with it.

**Evidence stays terse.** The small-test-files rule applies to verification too: headline checks plus
screenshots at the manifest's viewports. A 230-assertion conformance suite is not what makes a phase
safe — the sweep, the operator's runtime, and the operator's own eyes are.

## Test Commands

This repository ships machinery, so its suite is one shell script plus the engine's own validator.
Both are cheap; run them together and treat the pair as the build.

- **Smoke / integration:** `bash tests/retrofit_smoke.sh` — Tests 0-16 over fresh-install, retrofit,
  update, and dual-apply paths, plus Test 0's prose invariants pinned across `CLAUDE.md`, the two
  executor tiers, the design subagent and the driver skills. **"Fresh-install" means the `--at-root`
  path** (P29): a bare install is nested now, so Tests 5 (`$F`, `$H`), 12 (`$W`) and 14 (`$NS/seed`)
  pass `--at-root` to keep the committed at-root layout under test (P28's at-root invariant was Tests
  0-13 passing unchanged; P29 changed only how they install); the nested default is Tests 15-16.
  Test groups worth naming:
  - **Tests 9-12** — **Test 9** covers the v35 phase-notebook shape (template seed, the generated
    `## Slices` block, `finish-slice --outcome`, the marker-less no-op, the embedded-fallback
    equality); **Test 10** the v35/v39 notebook guardrails (budget warning, `## Doc Impact` case
    drift, the `finish-slice` size print, no dashboard timestamp churn); **Test 11** the v41
    `phase-scope` boundary; **Test 12** v43 worktree-on-request.
  - **Test 7** — the committed installer matches `installer/`, and the installer's stdin program
    opens with the utf-8 coding cookie (PEP 263; P27.F3). See *Known Fragile Areas*.
  - **Test 13, the design contract** (v47, P26-P27) — `design-check` names a gap and an unnumbered
    card; its first assertion also fails a `//` and an `http://` reference by name and passes
    `../tokens.css`, `#`, `data:` and `https` references (P26.F1); `design-close` regroups line 1
    only; close and register are idempotent; nothing is written under `~/.config`. Added at v48:
    `claude-design/` is skipped; `design-migrate` writes beside `design.json` (dry run, a
    byte-identical `--apply`, its refusals); the register deck hint; a pre-v47 root is steered to
    `design-migrate` and `design-init` refuses (P27.F2).
  - **Test 14, the nested engine** (P28.S1) — host anchor, host-side `phase-scope` (including the
    host's own `docs/`), the parallel refusal, the convention gate, the agent rename map, and a
    malformed marker failing `validate` and stopping `next`. It reads `workflow/.agentic-nested.json`
    (P28.S2 renamed the marker).
  - **Test 15, the nested install** (P28.S2, P28.F1) — a clean host (status, HEAD,
    `core.hooksPath`); a nested `.git`; no `workflow/.claude` or `workflow/CLAUDE.md`; the
    `commit` → `wf-commit` rename and no unprefixed engine command; the import line outside fences;
    `validate` and `next` showing UNCONFIRMED; `phase-scope` clean after `new-phase`; an idempotent
    rerun; `--update --nested` keeping the confirmation and renames with one exclude block;
    `--into-existing` rejected; a tracked `CLAUDE.local.md` refused with nothing written. The ignore
    guarantee adds three asserts: a `!.claude/skills/**` host installs clean with a per-dir
    `.gitignore` of `*`; a `!CLAUDE*.md` host is refused naming `CLAUDE.local.md` and
    `.gitignore:1:!CLAUDE*.md`; an allowlist host (`*` / `!*/` / `!*.md`) is refused naming
    `workflow/` and `.gitignore:2:!*/`; the refusals write nothing.
  - **Test 16, nested by default** (P29.S1, 9 asserts) — a new dir is `git init`ed and nested with a
    confirmed convention, a clean host status and no UNCONFIRMED; an existing repo nests with HEAD
    and status unchanged; a bare `--update` detects nested and at-root; a bare install over an
    at-root workspace refuses; `--update --at-root` on nested, `--at-root --nested`,
    `--force-empty-ok` alone and a non-empty non-git dir refuse.
  - **P30's rotate asserts** (4, beside Test 5's `docs-debt` fixture) — a debt-only phase gets a
    `rotate-backlog` proposal with the exact create command and stays active; a live covering docs
    phase makes rotate print `docs_phase_covered=` and no proposal; `new-phase --consolidates` of a
    phase owing nothing refuses and writes nothing; `--archive-only` prints no docs-phase line.

  Baseline **239 PASS / 0 FAIL as of v51** (counted at P30). How it rose, each step replacing the
  one before: 123 before P18, 137 at v35, 139 at v36, 140 at v37, 152 at v38 (P21: +12 for the
  consolidation-debt, `consolidation_owed=`, `docs-debt` and oversized-section probes), 158 at v39
  (P22: +6 for the staleness/marker probes), 180 at v44 (counted at P23; the v40-v43 work between
  is not itemized by any owed note, so this doc says that plainly rather than inventing a
  breakdown), 187 through the v45-v46 work (likewise not itemized), 192 at v47 (P26.S1: +5 in Test
  13), 195 at v47 (P26.S2: +1 a fresh install ships `design-drafter` with `Skill` and no
  `DesignSync`, +1 `executor-mode economy` keeps the drafter on the high tier's model and effort, +1
  dual-apply for the new agent file), 203 at v48 (P27: +6 in Test 13 at P27.S1 for `claude-design/`
  skipped, `design-migrate` beside `design.json`, its dry run, its byte-identical `--apply`, its
  refusals and the register deck hint; +1 in Test 7 at P27.F3 for the utf-8 cookie; +1 in Test 13 at
  P27.F2 for the pre-v47 root), 226 at v49 (P28: Tests 14 and 15, no per-test count owed; by
  subtraction 20 across the two plus P28.F1's 3), 235 at v50 (P29.S1: Test 16's 9), 239 at v51
  (P30.S1: +4 rotate asserts). Pin changes that add no PASS line leave the count alone:
  P26.S3, P26.S4, P26.F1, P26.F2, P27.S3 and P27.F1 moved and added pins inside Test 0's existing
  python block, which is why the count moves only when a real check group is added. The v37 Migration
  notes CHANGELOG check stays live: every `## v<N>` section of `CHANGELOG.md` must carry a
  **Migration notes** line, because `/update-workspace` prints exactly those lines to adopting repos.

  Test 0's current pins (counts as of P23.S4; P26-P27 re-pointed and added pins without recounting them):
  - the **contract list** -- 38 positives, 19 negatives, whitespace-sensitive raw substrings against
    `CLAUDE.md`
  - the **do-\* / design-cowork / review-phase / executor-body lists** -- carry the pins the P23
    contract slimming moved out (the docs-slice carve-out and fractional-`--order` help; the Aside,
    worktree and design-style clauses)
  - a **whitespace-normalized `parallel-phase` pin list** -- the eight worktree rules and matching
    negatives
  - Test 1's **3 sidecar greps**
  - the **design pins** (P26-P27): the contract section is pinned against the engine's `DESIGN_*`
    constants (P26.S1). `design-cowork`, the do-\* skills, both executor bodies, `CLAUDE.md`,
    `create-phase`, Test 1's sidecar and the installer banner moved to the drafter loop (P26.S3,
    P26.S4): pins for the drafter, `design-close`, literal signoff, "new visual direction" and the
    bundle import, with the `_ds_manifest`, "never dispatched", "one dispatched span" and push
    phrases retired as negatives. From P27 they are **choice pins**: `create-phase` pins its
    `Design tool:` line (and stays free of `DesignSync`), the drivers name `claude-design`, and
    `CLAUDE.md` and the banner name both tools (P27.S3); each driver's `claude-design` branch names
    `feedback.md` before `DesignSync` (P27.F1). The `design-cowork` frontmatter keeps an unchanged
    trigger and asks for `Agent` and, since P27.S2, `DesignSync` again; `design-drafter` never
    carries `DesignSync`
  - the **drafter and the self-contained rule** (P26.F1, P26.F2): the drafter's `new visual
    direction` licence and the do-\* revision handoff ("write its handoff", "every card still
    carrying the slice's address"), with the old elided feedback step a negative; and the contract's
    Self-contained bullet and `design-drafter` §Do 2 each name every `DESIGN_ALLOWED_REFS` prefix
    (`#`, `data:`, `https:`, read from the engine) plus `../tokens.css` and the `tokens.css` clause,
    with the old "nothing relative except `../tokens.css`." wording a negative

  Test 0's comments describe the ≤ 12 KB stub contract.
- **Workspace state:** `python3 scripts/workflow.py validate` -- exits 0 with warnings by design
  (an over-budget `phase.md`, a case-drifted `## Doc impact` heading, `consolidation_owed=<phases>`
  when a docs phase is owed, `stale_docs=<docs>` when a doc is outrun by an unconsolidated note, and
  `oversized_doc_sections=<n>` when a `docs/current` H2 section passes 10 KB), so read the warning
  lines even on a pass.
- **Installer drift:** `python3 installer/build.py --check` -- the artifact must match `installer/`
  source; the tracked `.githooks/pre-commit` runs it. Enable once per clone with
  `git config core.hooksPath .githooks`.
- **Executor-tier config drift:** `python3 scripts/workflow.py sync-agents --check`, and
  `diff <(tail -n +9 .claude/agents/slice-executor-mid.md) <(tail -n +9 .claude/agents/slice-executor-high.md)`
  must be empty -- the two tier bodies are single-sourced by copy, and `sync-agents` only covers the
  frontmatter.
- **Lint/typecheck:** none beyond `python3 -m py_compile scripts/workflow.py`; the engine is
  dependency-free stdlib Python.

## Acceptance Criteria Style

- <rule>

## Manual QA Missions

### Mission Name

- Route / entry:
- What a real user would try:
- What would feel wrong:
- Evidence to collect:

## Regression Checklist

The product's **cumulative smoke list**: headline behaviours only, one line each, append-only across
phases, in the shape `- [ ] <surface>: <one observable behaviour> (P<N>)`. Each phase's
fidelity/review slice **appends** its surfaces' headline checks and **re-runs the lines inside its
phase's boundary** (v41) — this phase's own surfaces plus every earlier line whose surface a file the
phase changed feeds; `python3 scripts/workflow.py phase-scope <P>` prints those files, a shared file
widens the boundary to everything it feeds, and the lines outside it are recorded by count with the
diff as the proof. That is still what stops a later phase touching a shared surface from silently
invalidating an earlier phase's pass: the shared file is in its diff. The **whole** list is re-run by
a QA phase the operator creates (the `create-phase` skill's *QA-sweep route*), never by a phase
review. If a check needs a paragraph it belongs in a *Manual QA Mission*, not here. (Seeded into
every fresh install from `installer/payloads/doc_bodies/qa.md` as of v32, boundary wording since
v41; existing adopters rewrite their stub themselves.)

This repository ships machinery rather than a browsable product, so its list is machinery
behaviour and it is re-run by `bash tests/retrofit_smoke.sh` plus
`python3 scripts/workflow.py validate`:

- [ ] installer: a fresh install into an empty dir validates and stamps the current `workspace_version` (P16)
- [ ] engine: an undeclared or uncleared acceptance gate refuses `review-phase --verdict pass` (P16)
- [ ] machinery text: Test 0's contract/skill/agent invariants hold, including tier body parity (P16)
- [ ] engine: a fresh phase's `## Slices` block renders from `slice.json` and `finish-slice --outcome` fills its row (P18)
- [ ] engine: a notebook without the `slices:` markers is left byte-identical, and repeated `next` calls do not dirty the dashboards (P18)
- [ ] engine: `new-slice --kind research` succeeds and lands `"kind": "research"`, while an invented kind is still a hard error naming the closed set (P19)
- [ ] installer: a bare install into a new dir `git init`s it as the host and installs nested (`workflow/` + its marker, the convention confirmed), leaving the host's `git status --porcelain --untracked-files=all` empty and `next` free of `UNCONFIRMED` (P29)
- [ ] installer: `--at-root` installs the committed at-root layout (`CLAUDE.md`, `scripts/`, `works/` at the root, no `workflow/`) and the workspace validates (P29)
- [ ] installer: a bare `--update` detects the layout: `(nested, detected)` on a nested host, at-root with no `workflow/` created on an at-root workspace (P29)
- [ ] installer: a bare install over an at-root workspace exits 1 pointing to `--update`, with nothing written (P29)
- [ ] engine: `rotate-backlog` archives the clean phases, then prints a read-only docs-phase proposal for the phases held back only by doc debt (`docs_phase_proposal=`, `phase=`, a copy-pasteable `create:` line) and creates nothing (P30)
- [ ] engine: `rotate-backlog --archive-only` prints exactly the pre-v51 archive-and-report output, with no `docs_phase` line (P30)
- [ ] engine: once the printed `create:` line runs, `new-phase --consolidates` marks the docs phase and the next `rotate-backlog` prints `docs_phase_covered=<P> (pays …)` and no second proposal; `--consolidates` naming a phase that owes nothing refuses and writes nothing (P30)
- [ ] engine: `docs-debt` prints `paid by: <P> (<status>)` under each owing phase a live docs phase covers (P30)

## Known Fragile Areas

- **The installer body under the Mac's system Python 3.9 stdin tokenizer** (recorded at P27.REVIEW).
  The installer's Python program is read from stdin, and system Python 3.9 can reject it on a
  multibyte character that falls on a chunk boundary. The program therefore opens with a utf-8 coding
  cookie (PEP 263; P27.F3), guarded by the cookie itself and by Test 7, which asserts it.

## Open Questions

-
