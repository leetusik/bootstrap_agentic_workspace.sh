# Intent — P16

- Captured at: 2026-08-23T06:35:44+09:00
- Origin: operator

## Original Input (verbatim)

> /create-phase ---
> see /private/tmp/claude-502/-Users-sugang-projects-personal-Mijual/372795c6-8fec-45dc-8bd3-018ca7507d98/
>
> _(The referenced directory held one file, `scratchpad/bootstrap-inspection-handover.md`, reproduced word-for-word below. That scratchpad path is session-ephemeral; this section is the durable copy of the incident evidence.)_
>
> # Handover prompt — why "done + review pass" shipped a broken product, and what to change in the bootstrap
>
> You are the coding agent for the **bootstrap workspace repo** (the upstream repo that builds
> `bootstrap_agentic_workspace.sh`, embedding `CLAUDE.md`, `scripts/workflow.py`, the
> `.claude/skills/` command-skills — `create-phase`, `do-next-slice`, `do-whole-phase`,
> `review-phase`, `design-cowork`, `parallel-phase` — and the `.claude/agents/slice-executor-*`
> definitions). An adopting workspace just suffered a systemic failure of the process your
> machinery encodes. This document is the incident inspection. **Your task: capture this as
> operator intent and create a phase (or phases) in the bootstrap repo that prevents this
> failure class.** Do not treat the incident's product bugs as your work items — the adopting
> workspace fixes those itself; you fix the machinery that let them through.
>
> ---
>
> ## 1. The incident
>
> The adopting workspace (Mijual — a Korean stock-disclosure monitoring product: Next.js 16
> frontend, FastAPI backend, an LLM answer agent) ran, in order:
>
> - **P3** — design-only phase, 7 Claude Design co-work rounds, each round literally signed by
>   the operator (mockups/cards). Review: pass.
> - **P5** — "Apply — build the signed design", 21 slices, ending with **P5.S19
>   "Design-fidelity verification in a real browser (RESPECT THE DESIGN)"**. Review: pass.
> - **P6** — "Apply — AI 질문 agent", 9 slices, ending with **P6.S7**, the same kind of
>   fidelity slice. Review: pass.
>
> The fidelity slices were **not** sloppy. P5.S19 ran ~230 scripted checks across 11 stages in
> headless Chrome over CDP at 3+ viewports, created and deleted real accounts through the
> product, measured rendered CSS against the signed record value by value, kept 41 screenshots,
> landed 5 faithful-implementation fixes, and catalogued 19 items "for the operator". P6.S7 was
> equally rigorous and found a real production-only SSE gzip-buffering bug. Workflow `validate`
> passed everywhere. Both phase reviews passed. Docs were consolidated.
>
> Then the operator opened the product and filed **11 user-visible failures**, verbatim mood:
> "total messed up right now":
>
> 1. A nav item that shouldn't exist (내 종목 조회 belongs on the landing only).
> 2. Search has no typeahead — nothing appears while typing until submit.
> 3. Ugly blue focus rings on inputs, one partially covered by the adjacent button.
> 4. The board renders **all 389 rows at once**; two "펼치기" (expand) section toggles do
>    nothing.
> 5. **Login is not visible anywhere on the site.**
> 6. The countdown stalls instead of ticking down properly every second.
> 7. Auto-refresh in dev replaces the whole page, wiping text mid-typing.
> 8. The AI 질문 (ask) feature can't send anything in the operator's environment.
> 9. The sample portfolio page looks disorganized; a labeled action button visibly does
>    nothing.
> 10. Self-narrating implementation copy in the UI ("본인 표시 · 이 브라우저(localStorage)에
>     저장" — "shown for you · stored in this browser (localStorage)").
> 11. The AI 질문 widget doesn't render at all for the operator.
>
> ## 2. What inspection found (evidence, verified live)
>
> **The single most instructive bug (item 5, login):** the login link genuinely never renders —
> but only in dev mode. `useAccount()` guards its auth probe with a module-level
> `probedPath === pathname` check inside a `useEffect` with a `live` cleanup flag. Under React
> StrictMode (which `next dev` enables and `next start` does not), the effect runs twice: run 1
> starts the fetch and is immediately cleaned up (`live = false`); run 2 early-returns because
> `probedPath` is already set. The probe resolves into the void; the account slot stays in its
> "not answered yet" state (renders nothing) **forever**. In the production build the effect
> runs once and login works — which is exactly why ~230 checks, including full signup/login
> flows, passed.
>
> **The environment split, from the two fidelity slices' own result records:**
>
> - Verification ran `npm run build && npm run start` on `http://localhost:3000`, headless
>   Chrome over CDP, on the executor's machine.
> - The operator runs `make stack-up` → `next dev -H 0.0.0.0` and browses over Tailscale from
>   another device (the workspace's own Makefile comment says so). Different runtime mode
>   (dev/StrictMode/Fast-Refresh reload semantics), different origin, different device and
>   viewport.
>
> Re-verification during this inspection: on localhost dev, the widget renders, opens, sends,
> and streams a cited answer; the countdown ticks; `/api/auth/me` answers correctly — while the
> operator, in their own environment, sees no widget and can't send (plausibly a ≤480px
> viewport, where the signed design renders **no widget by design**, only a dedicated page —
> or another access-path difference; unconfirmed, because nothing recorded what the operator's
> environment even is). Item 7's full-page reloads are `next dev` Fast-Refresh behavior the
> production-mode verification could never encounter.
>
> **The conformance trap (items 1, 2, 3, 4, 10):** every one of these passed verification
> *because verification's only yardstick was the signed design record*:
>
> - The nav item, the all-rows board, and the "본인 표시 · localStorage" captions are **the
>   signed design's own content** — fidelity verified they render exactly as signed. The
>   operator, seeing them in the flesh for the first time, hates them.
> - Focus rings and typeahead are things **the record never drew** — so no check existed. The
>   ~230 checks measured rendered CSS values, token conformance, and flow outcomes; there was
>   no "every visible control does something" sweep, no focus/hover/keyboard-state pass, no
>   type-into-an-input-and-wait liveness check.
> - The 펼치기 toggles were verified expanding in the production build during P5.S19 — and are
>   dead for the operator now. P6 landed afterward and modified shared chrome; **nothing ever
>   re-ran P5's checks after P6**.
>
> **The buried catalogue:** P5.S19 dutifully catalogued 19 operator-decision items in its
> `result.md` ("do not implement without a signed decision"). That catalogue was consolidated
> into the phase review record — and died there. No mechanism forced those questions in front
> of the operator; the review passed with them unread, and several of the 11 complaints overlap
> that very list.
>
> **The timeline fact that matters most:** across two build phases and 30 slices, **the running
> product was never once put in front of the operator before both reviews passed.** The
> operator signed mockups in P3 and then next saw their product after P6's review. Every gate
> in the machinery — plan gates, executor verdicts, `validate`, fidelity slices, phase reviews —
> sits between agents. None sits between the product and its owner.
>
> ## 3. Root causes, mapped to bootstrap machinery
>
> **RC1 — The operator's runtime is not a concept the machinery has.** Nothing in the
> contract, the skills, or the executor prompts requires recording *how the operator runs and
> views the product* (commands, mode, host, device, viewport), let alone verifying in it.
> Verification defaulted to the executor's most convenient truth (prod build, localhost,
> headless). Dev-only bug classes (StrictMode double-effects, Fast-Refresh reloads) and
> access-path differences (LAN origin, mobile viewport) are structurally invisible.
>
> **RC2 — "Done" is defined as conformance to the signed record, and the record is both
> ceiling and shield.** RESPECT THE DESIGN (design-cowork skill + contract) makes the signed
> record the sole acceptance criterion. Ceiling: whatever the record didn't draw — interaction
> states, focus treatment, typeahead, pagination behavior — is nobody's job and no check's
> subject. Shield: whatever the record did draw is protected verbatim, even when the operator
> loathes it in the running product. The machinery treats **signing pictures as accepting the
> product**. Those are different acts separated by months of implementation.
>
> **RC3 — No operator acceptance gate exists anywhere between decomposition and archive.**
> The machinery *has* the primitive (`pending` halts selection; `set-phase-status <P> pending`)
> but no rule ever requires using it to show the operator the running product before
> `review-phase --verdict pass` is recorded.
>
> **RC4 — Fidelity verification's checklist idiom biases to static conformance.** The
> design-cowork skill mandates "real-browser fidelity" slices but specifies fidelity to *the
> record*. Missing entirely: an every-control-does-something sweep, interaction-state checks
> (focus/hover/keyboard), liveness over time (does the countdown tick for 60 s; what happens to
> in-progress typing when data refreshes), and "verify in every runtime mode the operator
> uses."
>
> **RC5 — No cumulative product smoke across phases.** Each phase verifies its own surfaces
> once, at one commit. A later phase touching shared surfaces (P6 touched the chrome P5 owned)
> silently invalidates the earlier pass. Regressions between a fidelity pass and operator
> contact have no detector.
>
> **RC6 — Operator-decision catalogues have no delivery mechanism.** Executors are told to
> surface questions "for the operator" in `result.md`/`phase.md`, but no rule routes an
> accumulated question catalogue into a `pending` stop or deferred jobs. Questions get
> *recorded* instead of *asked*.
>
> **RC7 — The review slice audits records, not the product.** `review-phase` validates all
> slices together and consolidates docs, but the review executor is not required to
> independently open the running product and spot-check the phase's headline claims in the
> operator's runtime; it trusts the fidelity slice's report.
>
> An honest scoping note: some of the 11 items (remove a nav entry, add typeahead, paginate the
> board) are the operator *changing product decisions after first real contact*. No machinery
> prevents changed minds — the machinery failure is that first real contact happened **after
> two phases** instead of at the end of each one. Fix the contact point, not the mind-changing.
>
> ## 4. Suggested bootstrap changes (shape the phase around these)
>
> - **F1. Operator runtime manifest (RC1).** Make the adopting workspace record, as durable
>   versioned truth (e.g. an operations-doc section the seed scaffolds), how the operator runs
>   and views the product: exact commands/mode (`next dev` vs prod build), host/origin, target
>   devices/viewports/browsers. Contract rule + executor-prompt line: any slice claiming
>   "verified in a real browser" MUST verify in the manifest's runtime and access path — and
>   additionally in the production build when the two differ. If no manifest exists, the
>   fidelity slice's first act is to ask the operator (a `pending` stop), not to assume.
>
> - **F2. Operator acceptance gate before a review can pass (RC2, RC3).** For any phase that
>   changes operator-visible surfaces: the review slice completes its validation, then sets the
>   phase `pending` with a short concrete walkthrough script (URLs to open, actions to try, in
>   the manifest runtime) and STOPS. `review-phase --verdict pass` may only be recorded after
>   the operator clears the walkthrough; operator-reported failures become `fix` slices and the
>   review re-runs. Implement as contract rule + `review-phase` skill procedure; optionally a
>   `phase.json` flag (stamped at creation or decomposition) that `review-phase` enforces so
>   the gate is machine-checked, not remembered.
>
> - **F3. "Works as a product" becomes a named verification dimension beside "matches the
>   record" (RC4).** Extend the design-cowork fidelity-slice specification with a mandatory
>   functional sweep: (a) every visible interactive element does something observable — a
>   control that no-ops is a defect even if pixel-perfect; (b) interaction states — focus,
>   hover, keyboard path — on every input and control; (c) liveness over time — timers tick,
>   polling/refresh does not destroy in-progress user input; (d) run in both dev and prod modes
>   when the manifest differs from prod. Separately, add a fresh-eyes UX walkthrough stage to
>   the review: an agent instructed to use the product as a first-time user and report
>   everything dead, confusing, or annoying — explicitly NOT judged against the design record;
>   findings route to the operator gate (F2), not to silent fixes.
>
> - **F4. A gap channel through RESPECT THE DESIGN (RC2, RC6).** When implementation or
>   verification hits a state the record never drew (focus treatment, empty/loading states,
>   pagination, browser-default styling), the rule today is "don't invent, catalogue it".
>   Keep that — but give catalogues a delivery mechanism: operator-question catalogues MUST be
>   routed (the review folds them into the F2 walkthrough as decisions-to-take, or they become
>   deferred jobs the operator sees in the dashboard) and a review must not pass with an
>   unrouted catalogue. Questions get asked, not archived.
>
> - **F5. Cumulative product smoke (RC5).** Seed a durable, append-only product smoke
>   checklist (or runnable script) in the workspace template; each phase's fidelity/review
>   appends its surfaces' headline checks and **re-runs the whole list**, so a later phase
>   re-verifies what earlier phases shipped. Keep it terse (the contract's small-test-files
>   rule applies) — headline behaviors, not 230 assertions.
>
> - **F6. Review independence (RC7).** One line in the review procedure and the executor
>   prompt: the review executor independently opens the running product in the manifest runtime
>   and spot-checks the phase's headline claims (N key flows) before rendering a verdict — it
>   never passes a phase purely on other slices' reports.
>
> Weigh these yourself against the bootstrap's design principles (lean dashboards, terse
> tests, operator-explicit invocation); F1–F3 carry most of the value. Remember the upstream
> rule: after editing embedded machinery files, rebuild and commit
> `bootstrap_agentic_workspace.sh` in the same commit (`python3 installer/build.py --check`).
>
> ## 5. What to do now
>
> Treat sections 1–4 as the operator's refined intent for a machinery-hardening phase. Follow
> your own `create-phase` procedure (refine → clarify → confirm with the operator → `new-phase`
> → fill `intent.md`, then STOP — no decomposition, no implementation). Cite this document in
> `intent.md` as the incident evidence.

## Confirmed Intent (refined + clarified)

Harden the bootstrap machinery (contract `CLAUDE.md`, `scripts/workflow.py`, the `design-cowork` / `review-phase` / executor skills and agent prompts, the seed templates, and the installer) so that an adopting workspace can no longer reach "phase `done` + review `pass`" on a product the operator has never seen running — the failure class the Mijual incident exposed (P3 design signed → P5/P6 built and review-passed with rigorous record-fidelity verification → operator opens the product and files 11 user-visible failures). The phase's work items are the six machinery fixes from the handover, not the incident's product bugs (the adopting workspace fixes those itself):

- **F1 — Operator runtime manifest.** The adopting workspace records, as durable versioned truth (e.g. an operations-doc section the seed scaffolds), how the operator runs and views the product: exact commands/mode (dev vs prod build), host/origin, target devices/viewports/browsers. Contract rule + executor-prompt line: any slice claiming "verified in a real browser" MUST verify in the manifest's runtime and access path, and additionally in the production build when the two differ. If no manifest exists, the fidelity slice's first act is a `pending` stop asking the operator, not an assumption.
- **F2 — Operator acceptance gate before a review can pass (machine-enforced).** For any phase that changes operator-visible surfaces, the review completes its validation, then sets the phase `pending` with a short concrete walkthrough script (URLs to open, actions to try, in the manifest runtime) and STOPS. `review-phase --verdict pass` may only be recorded after the operator clears the walkthrough; operator-reported failures become `fix` slices and the review re-runs. Enforced by the engine: a `phase.json` flag/gate state (stamped at creation or decomposition) that `review-phase` checks, so the gate is machine-checked rather than remembered. Contract rule + `review-phase` skill procedure + `workflow.py` change.
- **F3 — "Works as a product" as a named verification dimension beside "matches the record".** Extend the design-cowork fidelity-slice specification with a mandatory functional sweep: (a) every visible interactive element does something observable — a no-op control is a defect even if pixel-perfect; (b) interaction states — focus, hover, keyboard path — on every input and control; (c) liveness over time — timers tick, polling/refresh does not destroy in-progress user input; (d) run in both dev and prod modes when the manifest differs from prod. Plus a fresh-eyes UX walkthrough stage in the review: an agent uses the product as a first-time user and reports everything dead, confusing, or annoying — explicitly NOT judged against the design record; findings route to the operator gate (F2), never to silent fixes.
- **F4 — A gap channel through RESPECT THE DESIGN.** Keep "don't invent, catalogue it" for states the record never drew, but give catalogues a delivery mechanism: operator-question catalogues MUST be routed (the review folds them into the F2 walkthrough as decisions-to-take, or they become deferred jobs visible on the dashboard), and a review must not pass with an unrouted catalogue. Questions get asked, not archived.
- **F5 — Cumulative product smoke.** Seed a durable, append-only, terse product smoke checklist (or runnable script) in the workspace template; each phase's fidelity/review appends its surfaces' headline checks and re-runs the whole list, so a later phase re-verifies what earlier phases shipped. Headline behaviors only — the contract's small-test-files rule applies.
- **F6 — Review independence.** One line in the review procedure and the executor prompt: the review executor independently opens the running product in the manifest runtime and spot-checks the phase's headline claims (N key flows) before rendering a verdict; it never passes a phase purely on other slices' reports.

Weigh each against the bootstrap's design principles (lean dashboards, terse tests, operator-explicit invocation); F1–F3 carry most of the value. Ship the result as the next workspace version (CHANGELOG entry, `python3 installer/build.py` rebuilt and committed in the same commit as each machinery edit, adopters able to pick it up via `update-workspace`). The fix is the contact point — first real operator contact at the end of each phase — not the operator changing their mind after seeing the product.

## Clarifications Resolved

- Q: One phase or several? — A: **One phase, all six fixes (F1–F6)**; they edit the same handful of files and ship as one workspace version. `DECOMP` cuts the slices.
- Q: Should the operator acceptance gate (F2) be machine-enforced (a `phase.json` gate state that `review-phase --verdict pass` refuses until the operator clears the walkthrough) or procedural only? — A: **Machine-enforced.**
- Q: Proposed name "Operator acceptance gate and runtime-faithful verification" and the long objective — OK? — A: **Yes, use as proposed.**
- Not asked (assumption stated): this phase does **not** touch product visual design — it edits the design-cowork *skill text*, not any product's look — so no design/apply split and no `co-work` slice applies. `design-cowork` must still be read by whoever plans the F3/F4 slices, because those slices change its invariants.

## Notes

- Incident evidence: `bootstrap-inspection-handover.md` (reproduced verbatim above). Root causes RC1–RC7 there map to F1–F6; RC2/RC3 ("signing pictures ≠ accepting the product"; no owner-facing gate) are the core of the class.
- The machinery already has the primitive (`pending` halts selection; `set-phase-status <P> pending`); what is missing is a rule and engine check that *requires* using it before a review can pass.
- Open deferred job `D2` (slice-executor-mid has no co-work refusal clause) triggers "next time `.claude/agents/slice-executor-*.md` are edited" — this phase will edit them; `DECOMP` should decide whether to promote or fold it in.
