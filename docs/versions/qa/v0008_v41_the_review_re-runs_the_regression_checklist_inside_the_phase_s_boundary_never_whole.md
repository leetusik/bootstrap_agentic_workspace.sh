---
doc_id: qa
version: v0008
created_at: 2026-09-06T03:24:09+09:00
commit: 5004346bfb17cca5e4137d19089c1d671a07c11c
source: v41
summary: v41: the review re-runs the regression checklist inside the phase's boundary, never whole
previous: v0007_aside_s_two_real_surfaces_the_aside_repl-over-bash_default_and_its_measured_mcp_cost_the_dedicated_agent_profile_as_a_third_halt_and_the_140-pass_v37_baseline
---

# QA

## Status

Default testing posture: **keep test files small**. Tests are welcome, but each suite stays terse — minimal high-value cases, no fixture or scaffolding sprawl. The workspace itself follows this with a single committed smoke test (`tests/retrofit_smoke.sh`) plus `python3 scripts/workflow.py validate`.

As of **v32** the workspace also states *what verification has to look at*, not only how much of it to write. Fidelity has **two yardsticks, both mandatory** — *matches the record* and *works as a product* — the phase review performs **gate stages against the running product itself** on any phase that changes operator-visible surfaces, and `## Regression Checklist` below is the product's **cumulative smoke list**, re-run by every later phase **inside its own boundary** — the lines its changed files feed, `phase-scope <P>` naming the files; the whole list only by an operator-created QA phase (since v41). Terseness is unchanged and is the point: headline behaviours, not 230 assertions. See *Verification doctrine* below.

As of **v34 the doctrine has one bounded exemption**: a design round's **stubbed mockup** proves *look and states, not wiring*, so the functional sweep does not apply to it. The sweep is an **apply/fidelity** duty on real wiring, and confusing the two is what turns a design gate into the build it was supposed to precede. See *The one exemption* below.

As of **v36 the doctrine finally names its instrument**: **Aside** — a local-first Chromium browser agent — **in place of a pre-written assertion suite**. Since v32 this doctrine has said thoroughly *what* to check and *where*, and never once *with what*, which left the pre-written assertion suite as the default by silence — the very shape of check that let eleven user-visible failures through thirty slices. **v37 makes that prescription true in the particulars v36 got wrong or never said**: Aside has **two** surfaces rather than three, the default is **`aside repl` over Bash** (executor-driven, and explicitly *not* a standing MCP registration, whose one tool definition is paid in every session), and agent runs happen on a **dedicated Aside profile** named per invocation — never the operator's signed-in one, which is a **third** `needs_operator` halt. The fallback keeps the prescription honest without making it a gate: *the doctrine's demands bind, the instrument does not*. See *With what — the instrument* below.

## Purpose

Use this doc for test commands, acceptance criteria style, manual QA missions, browser QA flows, regression checks, and known fragile areas.

## Testing Philosophy

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

**The one exemption — a design round's stubbed mockup (since v34).** A design round ends with a
**throwaway route in the project's own frontend**, built from the landed `build-prompt.md` and opened
by the operator at the round's gate. It carries **stubbed data and does no backing work**, so:

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
- **The review's stage 3 carries the same qualifier.** A phase shipping a mockup takes
  `acceptance.required: true` — a `design-only` phase can no longer be waived — so a gated review now
  meets stubbed surfaces routinely. Its fresh-eyes walk names their unwired controls in the
  walkthrough rather than filing them as defects, and keeps judging what the mockup *is* for. A phase
  shipping real wiring gets the unqualified stage.

Everything else in this doctrine is unchanged: the exemption is one slice-kind wide and one phase
deep, and the wired product still meets the operator at the phase's acceptance gate. **Signing the
round off — the cards, and the stubbed mockup with them — is not accepting the product.**

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
sweep, fidelity slices, a design round's mockup, and the review's gate stages 2-4.

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
   finding. **Qualified since v34** when the phase's operator-visible surface is a design mockup: its
   unwired controls are named as deliberate, not filed as defects (see *The one exemption* above).
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

- **Smoke / integration:** `bash tests/retrofit_smoke.sh` — Tests 0-10 over fresh-install, retrofit,
  update, and dual-apply paths, plus Test 0's prose invariants pinned across `CLAUDE.md`, the two
  executor tiers and the driver skills. Baseline **140 PASS / 0 FAIL** as of v37 (139 at v36, 137 at
  v35, 123 before P18; **Test 9** covers the v35 phase-notebook shape -- template seed, the generated
  `## Slices` block, `finish-slice --outcome`, the marker-less no-op, the embedded-fallback equality
  -- and **Test 10** the guardrails: budget warning, `## Doc Impact` case drift, the `finish-slice`
  size print, and no dashboard timestamp churn). New prose invariants are added as asserts **inside
  Test 0's existing python block**, which is why the count moves only when a real check group is
  added. The **+2 in v36** is exactly that: two new *engine* probes in Test 5, run against the
  throwaway fresh-install workspace — the unknown-kind error must name `research` (so the closed set
  really contains it), and `new-slice --kind research --risk high` must succeed and land
  `"kind": "research"` in the created `slice.json`. The v36 prose invariants (the Aside clauses in
  `design-cowork`, `review-phase`, `CLAUDE.md` and both agent bodies; the research-kind clauses in
  the `do-*` skills and both agent bodies) added no count, as designed. The **+1 in v37** is one new
  `ok`/`bad` block in Test 5: every `## v<N>` section of `CHANGELOG.md` must carry a **Migration
  notes** line, because `/update-workspace` prints exactly those lines to adopting repos and v37's
  sharpest instruction — remove a v36 `claude mcp add -s local aside -- aside mcp` registration —
  reaches an adopter through no other channel. Its v37 prose invariants ride inside existing blocks
  and add no count: the positives (two surfaces, `aside repl` over Bash, the re-attach preamble, the
  dedicated-profile clauses) and, in the idiom v31 and v35 established, **negatives** pinning the
  retired v36 strings so they cannot drift back.
- **Workspace state:** `python3 scripts/workflow.py validate` -- exits 0 with warnings by design
  (an over-budget `phase.md`, a case-drifted `## Doc impact` heading), so read the warning lines even
  on a pass.
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

## Known Fragile Areas

- <area>

## Open Questions

-
