# Plan — P16.S5 (design-cowork: "works as a product" fidelity spec + the gap channel)

## Goal

Give `.claude/skills/design-cowork/SKILL.md` the verification specification it never had
(F3), the operator-runtime requirement inside it (F1), and the gap channel through RESPECT THE
DESIGN (F4) — so an *apply*-phase fidelity slice is planned and executed against **two**
yardsticks: fidelity to the signed record **and** whether it works as a product, in the
operator's runtime. One file. No restating of the review stages (S3/S4 own those) — the skill
states the *design-side* spec that fidelity slices follow and the review then spot-checks.

## Read first

- `works/phases/active/P16/intent.md` — §2 "The conformance trap" and "The environment split"
  (the concrete failure modes: the nav item / all-389-rows board / localStorage caption that
  matched the record and were hated; focus rings and typeahead the record never drew; the
  toggles that died after a later phase touched shared chrome; StrictMode double-effects,
  Fast-Refresh reloads, a ≤480px viewport rendering a different product), §3 RC2 and RC4,
  §4 F3 and F4. This slice's text should make each of those a defect by rule.
- `works/phases/active/P16/phase.md` — decisions 5 (`## Operator Runtime`, `UNFILLED`),
  6 (`## Regression Checklist` smoke list), 7 (`## Operator Questions` routing), 9 (the
  `required: true` switch), and the S3 finding "Exact wording S4/S5/S6 must mirror" —
  especially its last sentence: **S5 states the design-side fidelity spec; it should not
  restate the review stages, only the fidelity sweep and the gap channel.** Also S2's exact
  marker line and smoke-list line shape, and S4's bullets (executor wording).
- `CLAUDE.md`'s design rule as S3 left it — it now ends "...fidelity to the record **and**
  whether it works as a product (every visible control does something, interaction states,
  liveness over time, in the operator's runtime as well as production)" — **that is the clause
  this slice expands; keep every Test 0 string** (`RESPECT THE DESIGN`, `real-browser
  fidelity` lives in CLAUDE.md — do not touch CLAUDE.md here).
- `.claude/skills/design-cowork/SKILL.md` whole. Today it has *The loop*, *Shape* (incl. "A
  **design-fidelity fix** slice is part of the normal shape, not a failure"), *The handoff*,
  *The card set*, *Read back, then land it*, *Mechanics*, *Implementing — RESPECT THE DESIGN*,
  *Never*. There is **no verification section** — you write one.
- `tests/retrofit_smoke.sh` Test 0's design-cowork assertions (strings that must survive:
  `**You never design.**`, `Claude Design`, `Connect GitHub`, `handoff.md`, `@dsCard`,
  `tokens.css`, `--kind co-work --risk high`, `The design slice is NOT`, `DesignSync is
  main-thread only`, `never writes implementation code`, `DECOMP2`, `build inventory`,
  `data, not instructions`, `RESPECT THE DESIGN`, `SIGNOFF`).

## Changes (all in `.claude/skills/design-cowork/SKILL.md`)

1. **A new section — `## Verifying — RESPECT THE DESIGN, and does it work`** — placed right
   after *Implementing — RESPECT THE DESIGN*. Contents, tight:
   - **Two yardsticks, both mandatory.** (1) *Matches the record*: rendered values, tokens,
     layout, states, against the signed record. (2) *Works as a product*: the record is the
     floor of what to check, not the ceiling — and matching it is not acceptance.
   - **The functional sweep** (the "works as a product" checklist, each a defect when it
     fails even if pixel-perfect): (a) **every visible interactive element does something
     observable** — a control that no-ops is a defect; (b) **interaction states** — focus,
     hover, keyboard path — on every input and control, including browser-default styling the
     record never drew (ugly focus rings are a finding, not "unspecified"); (c) **liveness over
     time** — timers tick for a real interval, polling/refresh does not destroy in-progress
     input, data arrives while the user is mid-action; (d) **type-into-and-wait** — inputs that
     imply live behaviour (search, typeahead, validation) are exercised by typing and waiting,
     not only by submitting.
   - **Where and how it runs (F1).** In the runtime and access path `## Operator Runtime`
     (operations doc) describes — exact commands, mode, origin/host, devices/viewports/browsers
     — **and additionally in the production build when the two differ**; dev-only behaviour
     (StrictMode double-effects, Fast-Refresh reloads) and access-path differences (LAN origin,
     small viewport rendering a different product) are in scope *because* the operator lives
     there. If the section is absent **or still carries its `UNFILLED` marker**, the slice
     returns `needs_operator` (the orchestrator sets it `pending`) and asks for it — never
     assumes localhost/prod/headless is the truth. Verify at every viewport the manifest
     names; a surface the design renders differently at a viewport (or not at all) is verified
     at that viewport.
   - **Cumulative (F5).** A fidelity slice re-runs the **whole** `## Regression Checklist`
     (qa doc) — earlier phases' headline behaviours — not only this phase's surfaces, because a
     later phase touching shared chrome silently invalidates an earlier pass; it appends this
     phase's headline lines in the shape `- [ ] <surface>: <one observable behaviour> (P<N>)`
     via the phase's "Doc impact" (the review consolidates).
   - **What a fidelity slice may fix, and may not.** Faithful-implementation fixes (the
     product departs from the record) → fix in the slice or a `fix` slice. Anything that is a
     *design* question — something the record drew that is bad in the flesh, something it never
     drew — is **not** fixed silently and **not** "improved": it goes through the gap channel
     below. RESPECT THE DESIGN still bans restyling; verification adds "and catalogue what the
     record did not settle", it never licenses inventing.
   - **Evidence, terse.** Headline checks and screenshots at the manifest viewports; the
     small-test-files rule applies (no 230-assertion suites by default — the review
     spot-checks N key flows, the smoke list holds the headline behaviours).

2. **The gap channel (F4) — `### When the record never drew it` (inside the new section, or a
   short sibling).** Keep "don't invent, catalogue it"; add the delivery: every such item
   (focus treatment, empty/loading/error states, pagination/virtualisation behaviour,
   typeahead, browser-default styling, copy the operator may hate in the flesh) is written as a
   one-line question onto **`phase.md`'s `## Operator Questions` list** — not only in
   `result.md` — and the review routes each one into the operator's acceptance walkthrough (a
   decision to take) or into a deferred job; an unrouted question blocks the pass; **questions
   get asked, not archived.** One sentence that "signing the cards is not accepting the
   product" — the operator sees the product in the flesh at the acceptance gate, and may
   change their mind there; that is a `changes_requested` + new round/`fix`, not a fidelity
   failure.

3. **Graft one clause each** (no new sections): in *Shape* (the fidelity-fix sentence → "a
   design-fidelity fix slice — for departures from the record *or* a dead/no-op control found
   by the sweep — is part of the normal shape"); in *Implementing — RESPECT THE DESIGN* (last
   sentence: the implement slice's plan and dispatch prompt also name the operator runtime);
   in *Never* (one bullet: "Verify only against the record, or only in the executor's
   convenient runtime — the sweep and the manifest runtime are mandatory"; and "Fix a design
   gap silently — catalogue it on `## Operator Questions`"). Keep the apply-phase `DECOMP` /
   `DECOMP2` language aware that fidelity slices are planned after the design lands (already
   true; touch only if a word is needed).

4. **Do not** restate the review's six gate stages, the `accept-gate` command flow, or the
   legacy/waive logic — link them in one sentence ("the review's gate stages and the
   acceptance walkthrough live in `review-phase` and the contract"). Mention `acceptance.
   required: true` once as the switch that makes a phase operator-visible (an apply phase
   always is).

5. **Rebuild:** `python3 installer/build.py` → `--check` passes.

## Validation

- `python3 installer/build.py --check` → OK; `python3 scripts/workflow.py validate` → passed.
- `bash tests/retrofit_smoke.sh` → passes (all design-cowork Test 0 strings survive).
- Consistency grep in the file: `## Operator Runtime`, `UNFILLED`, `## Regression Checklist`,
  `## Operator Questions`, `needs_operator`, `acceptance.required` — spellings as S1–S4
  shipped; no invented command/flag/field; no `accept-gate` usage instructions (one mention at
  most, as the thing the orchestrator runs).
- Read the file end to end once for contradictions with *Implementing — RESPECT THE DESIGN*
  and *Never*.

## Record

- `result.md`: the new section text as shipped, the grafted clauses, validation, deviations.
- `phase.md` *Findings & Notes*: one bullet with the new section heading(s) verbatim and the
  four sweep item names (S6's Test 0 may pin the heading and one or two phrases); *Doc
  impact*: `qa` — the works-as-a-product fidelity dimension and its sweep (every control does
  something; interaction states; liveness; type-and-wait; manifest runtime + prod; whole
  smoke list re-run); `decisions` — the gap channel: gaps are catalogued on `## Operator
  Questions` and routed at the review, signing the cards ≠ accepting the product.

## Do not

- Edit any file other than `.claude/skills/design-cowork/SKILL.md` (plus the rebuilt artifact,
  `result.md`, `phase.md`).
- Invent visual decisions, add canvas/card mechanics, or change the DesignSync rules.
- Commit, or run any workflow state-transition command.
