# Result — P16.S5 (design-cowork: "works as a product" fidelity spec + the gap channel)

**Status: done.** One file edited (`.claude/skills/design-cowork/SKILL.md`) plus the rebuilt
artifact. F3, F4 and F1-inside-fidelity now have a written specification where the skill previously
had none.

## What landed

### 1. New section `## Verifying — RESPECT THE DESIGN, and does it work` (line 234)

Placed immediately after *Implementing — RESPECT THE DESIGN* and before *Never*. Structure: a
numbered two-yardstick opener, four bold-lead paragraphs, and one `###` sub-section (the gap
channel). Bold lead-ins rather than five `###`s, to match the file's prevailing style and keep the
outline scannable.

- **Two yardsticks, both mandatory.** (1) *Matches the record* — rendered values, tokens, layout,
  states against the signed record. (2) *Works as a product* — "the record is the **floor** of what
  to check, never the ceiling, and **matching it is not acceptance**. A screen can be pixel-perfect
  and dead; an element the record drew is not thereby a good element in the flesh." Then the one
  sanctioned mention of the switch: an apply phase is operator-visible by definition, so its gate is
  `acceptance.required: true`, and **the review's gate stages and the acceptance walkthrough are
  linked, not restated** — "live in the `review-phase` skill and the contract — this section is the
  **design-side** spec the fidelity slice itself follows, and what the review then spot-checks."
- **The functional sweep** — four items, each framed as "a defect when it fails even if the pixels
  are perfect": *every visible interactive element does something observable* (a no-op control is a
  defect, "not a 'not wired yet'"); *interaction states* (focus/hover/keyboard, **including the
  browser defaults the record never drew** — an ugly focus ring, or one the adjacent button covers,
  is a finding, not "unspecified"); *liveness over time* (watch a timer tick for a real interval
  instead of reading its code; refresh must not destroy in-progress input); *type into it and wait*
  (search/typeahead/validation/autosave exercised by typing and waiting, not only by submitting —
  "'Nothing happens while I type' is a finding no submit-only check can make").
- **Where it runs (F1).** The manifest runtime and access path from `## Operator Runtime` (run
  command(s), mode, origin/host, devices/viewports/browsers) **and additionally the production build
  when the two differ**; the two named bug classes are called out as *why* — dev-only behaviour
  (StrictMode double-effects that strand a probe, Fast-Refresh reloads that wipe in-progress typing)
  and access-path differences (a LAN or tunnel origin, a small viewport rendering a different
  product — or none of it). Every viewport the manifest names is verified, including one where the
  design renders a surface differently or deliberately not at all. Absent **or** still carrying the
  `UNFILLED` marker → `needs_operator`, orchestrator sets it `pending`; "Never assume localhost,
  never assume the production build, never assume headless."
- **Re-run the whole list (F5).** All of `## Regression Checklist`, every earlier phase's headline
  behaviours, with the reason stated (a later phase touching shared chrome silently invalidates an
  earlier pass, and nothing else is looking); append this phase's lines in the shipped shape
  `- [ ] <surface>: <one observable behaviour> (P<N>)` via the phase's "Doc impact" list.
- **What a fidelity slice may fix, and what it may not.** Departure from the record → faithful-
  implementation fix in the slice or a `fix` slice. A *design* question — something the record drew
  that is bad in the flesh, or something it never drew — is **not fixed silently and not
  "improved"**, it goes through the gap channel. "RESPECT THE DESIGN does not move here:
  verification adds *'and catalogue what the record never settled'*, it never licenses inventing."
- **Evidence, terse.** Headline checks + screenshots at the manifest's viewports; the small-test-
  files rule applies to verification too — "A 230-assertion conformance suite is not what makes a
  phase safe; the sweep, the operator's runtime, and the operator's own eyes are."

### 2. The gap channel — `### When the record never drew it` (line 296)

Keeps "catalogued, never invented" and adds the delivery: **"Catalogued means delivered"** — each
item (focus treatment, empty/loading/error states, pagination or virtualisation behaviour,
typeahead, browser-default styling, copy that reads fine in a mockup and wrong in the product) is a
one-line question on **`phase.md`'s `## Operator Questions` list**, "not only in `result.md`, where a
catalogue quietly dies unread"; the review routes each entry into the acceptance walkthrough or a
deferred job, and **an unrouted entry blocks the pass**; **"Questions get asked, not archived."**
Closing paragraph carries the sentence the plan asked for: **"signing the cards is not accepting the
product"** — the operator meets the thing itself at the acceptance gate and may change their mind
there, which is a `changes_requested` plus a new round or `fix` slice, "not a fidelity failure, and
never something to argue out of with the record."

### 3. Three grafted clauses (no other new sections)

- *Shape*, last bullet: "A **design-fidelity fix** slice — for a departure from the record *or* a
  dead, no-op or unreachable control the functional sweep found (*Verifying*, below) — is part of
  the normal shape, not a failure."
- *Implementing — RESPECT THE DESIGN*, last sentence now ends: "…**and** the executor's dispatch
  prompt — and name the operator's runtime (`## Operator Runtime` in the operations doc) in both,
  because an implement slice that claims a real browser has to have used the operator's."
- *Never*, two new bullets after "Write implementation code in a design slice.": "Verify only
  against the record, or only in whichever runtime is convenient for you — the functional sweep and
  the manifest's runtime are both mandatory." and "Fix a design gap silently, or \"improve\" it —
  catalogue it on `## Operator Questions` so the operator is actually asked."

### 4. Rebuild

`python3 installer/build.py` → `wrote bootstrap_agentic_workspace.sh (371539 bytes)`.

## Validation

| Command | Outcome |
|---|---|
| `python3 installer/build.py` | wrote the artifact (371539 bytes) |
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **Workflow validation passed.** |
| `bash tests/retrofit_smoke.sh` | **ALL RETROFIT SMOKE TESTS PASSED** (Test 0's 15 design-cowork strings all survive; dual-apply confirms the embedded copy matches) |
| Consistency grep in the edited file | `## Operator Runtime` ×2, `UNFILLED` ×1, `## Regression Checklist` ×1, `## Operator Questions` ×2, `needs_operator` ×3, `acceptance.required` ×1 — all spelled as S1–S4 shipped; **`accept-gate` appears 0 times** (no usage instructions), no invented command/flag/field |
| End-to-end read for contradictions | none found against *Implementing — RESPECT THE DESIGN*, *The design record* ("catalogue nits as apply-time to-dos" is compatible with the new delivery rule), or *Never* |

Line widths stay in the file's existing ~100–105 column band.

## Deviations from `plan.md`

- **Sub-structure of the new section.** The plan sketched the contents as five bullet groups; they
  landed as four **bold-lead paragraphs** plus one `###` sub-heading (the gap channel) rather than
  five `###` sub-headings, so the file's outline stays at 11 headings. Content is 1:1 with the plan.
- Nothing else. No file other than `.claude/skills/design-cowork/SKILL.md`, the rebuilt artifact,
  this `result.md` and `phase.md` was touched; no commit and no state-transition command was run.

## Notes for S6

- Stable Test 0 strings this slice introduces (all present exactly once): the heading
  `## Verifying — RESPECT THE DESIGN, and does it work`, the sub-heading
  `### When the record never drew it`, `matching it is not acceptance`,
  `Questions get asked, not archived.`, `signing the cards is not accepting the product`. The
  existing 15 design-cowork assertions are untouched.
- The section deliberately holds **no** `accept-gate` command line — S6 should not add one here; the
  gate's command surface is documented in `review-phase` and the contract.
