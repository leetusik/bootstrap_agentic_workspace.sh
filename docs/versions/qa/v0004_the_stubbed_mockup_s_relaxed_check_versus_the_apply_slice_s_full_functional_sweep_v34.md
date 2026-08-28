---
doc_id: qa
version: v0004
created_at: 2026-08-29T03:59:28+09:00
source: P17.REVIEW
summary: The stubbed mockup's relaxed check versus the apply slice's full functional sweep (v34)
previous: v0003_works_as_a_product_beside_matches_the_record_the_fidelity_sweep_the_review_gate_stages_and_the_cumulative_smoke_list
---

# QA

## Status

Default testing posture: **keep test files small**. Tests are welcome, but each suite stays terse — minimal high-value cases, no fixture or scaffolding sprawl. The workspace itself follows this with a single committed smoke test (`tests/retrofit_smoke.sh`) plus `python3 scripts/workflow.py validate`.

As of **v32** the workspace also states *what verification has to look at*, not only how much of it to write. Fidelity has **two yardsticks, both mandatory** — *matches the record* and *works as a product* — the phase review performs **gate stages against the running product itself** on any phase that changes operator-visible surfaces, and `## Regression Checklist` below is the product's **cumulative smoke list**, re-run whole by every later phase. Terseness is unchanged and is the point: headline behaviours, not 230 assertions. See *Verification doctrine* below.

As of **v34 the doctrine has one bounded exemption**: a design round's **stubbed mockup** proves *look and states, not wiring*, so the functional sweep does not apply to it. The sweep is an **apply/fidelity** duty on real wiring, and confusing the two is what turns a design gate into the build it was supposed to precede. See *The one exemption* below.

## Purpose

Use this doc for test commands, acceptance criteria style, manual QA missions, browser QA flows, regression checks, and known fragile areas.

## Testing Philosophy

- **Minimal by default.** Prefer lightweight verification — run the code, `validate`, a small smoke check — over broad automated suites.
- **Keep test files small.** When a test is worth committing, keep the file or suite terse: a few high-value cases, no fixture or scaffolding sprawl.
- **Grow on demand.** Expand coverage only when the operator asks or the risk clearly warrants it; note the reason here when you do.

## Verification doctrine — matches the record, and works as a product (since v32)

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
orchestrator sets the slice `pending`. Never assume localhost, the production build, or headless.

**The review's gate stages** — performed by the review executor, conditioned on the phase's
`acceptance.required` being `true` (waived and legacy phases skip all of it), after validating every
slice and before rendering a verdict:

1. Find the manifest (absent or `UNFILLED` → `needs_operator`).
2. **Independent spot-check:** open the running product yourself and verify the phase's headline
   claims — never pass a phase on other slices' reports alone.
3. **Fresh-eyes UX walkthrough:** use the product as a first-time user and report everything dead,
   confusing, or annoying, **explicitly not judged against the design record**. Findings go into the
   operator's walkthrough for a decision — never into silent fixes, and never into overriding an
   approved design. **Qualified since v34** when the phase's operator-visible surface is a design
   mockup: its unwired controls are named as deliberate, not filed as defects (see *The one
   exemption* above).
4. **Re-run the whole smoke list**, not only this phase's lines, then append this phase's headline
   checks.
5. **Route every `## Operator Questions` entry** — into the walkthrough as a decision to take, or as
   a deferred job listed for the orchestrator to file. An unrouted entry blocks the pass.
6. Return the `walkthrough` beside the verdict; the orchestrator opens the gate with it.

**Evidence stays terse.** The small-test-files rule applies to verification too: headline checks plus
screenshots at the manifest's viewports. A 230-assertion conformance suite is not what makes a phase
safe — the sweep, the operator's runtime, and the operator's own eyes are.

## Test Commands

- Unit:
- Integration:
- E2E:
- Lint/typecheck:

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
fidelity/review slice **appends** its surfaces' headline checks and **re-runs the whole list** in the
operator runtime, so a later phase touching shared surfaces cannot silently invalidate an earlier
phase's pass. If a check needs a paragraph it belongs in a *Manual QA Mission*, not here. (Seeded
into every fresh install from `installer/payloads/doc_bodies/qa.md` as of v32; existing adopters
rewrite their stub themselves.)

This repository ships machinery rather than a browsable product, so its list is machinery
behaviour and it is re-run by `bash tests/retrofit_smoke.sh` plus
`python3 scripts/workflow.py validate`:

- [ ] installer: a fresh install into an empty dir validates and stamps the current `workspace_version` (P16)
- [ ] engine: an undeclared or uncleared acceptance gate refuses `review-phase --verdict pass` (P16)
- [ ] machinery text: Test 0's contract/skill/agent invariants hold, including tier body parity (P16)

## Known Fragile Areas

- <area>

## Open Questions

-
