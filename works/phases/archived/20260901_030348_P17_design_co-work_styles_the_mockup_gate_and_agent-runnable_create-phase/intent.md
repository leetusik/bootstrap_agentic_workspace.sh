# Intent — P17

- Captured at: 2026-08-29T03:06:58+09:00
- Origin: operator

## Original Input (verbatim)

> the design cowork pattern, there will be three kind of cowork.
> --
> 1. decomp2 style. one or more design work on one phase, decomp2 after the design for the implememnting.
> 2. design only style. one or more phase that only for the design. apply phase follows.
> 3. one design and one apply style. in one phase, the design and apply slice comes as combo. so like design 1, apply 1, design 2, apply 2.
> --
> the agent will ask what style of design work will be executed.
> and one more thing. after the claude design work on the design slice, the agent should create mockup that written with the project's frontend language. and then one gate for operator approval to close the design slice.

And, on invoking `/create-phase`:

> and make it possible to agent run the create-phase

## Confirmed Intent (refined + clarified)

Two changes, shipping together as **workspace v34**.

### 1. Design co-work gets three named styles

Named, operator-chosen, replacing today's implicit two-shape choice:

- **`build-after`** — today's two-pass shape: `DECOMP` → groundwork → design round(s) → `DECOMP2` → build slices.
- **`design-only`** — a design phase, then a separate apply phase. **Must** be chosen at `create-phase`, because the `DECOMP` executor is forbidden from running `new-phase`.
- **`paired`** (new) — one phase, alternating: design 1 → apply 1 → design 2 → apply 2. `DECOMP` cuts the pairs as **bare folders**; **no `DECOMP2`**. The apply-slice count equals the design-round count, which `DECOMP` already knows from the build inventory; each apply slice's `plan.md` is written at its turn from the round that just landed, so the "do not pre-plan past the design gate" ban holds unchanged. Anything a round reveals that the pairs miss is cut at a fractional order.

The agent **suggests** a style with a reason; the operator confirms or overrides. Asked at `create-phase` by default; `DECOMP` asks it instead (stopping `pending`) when the phase was created before its visual nature was clear. The confirmed style is recorded in the phase's `intent.md` under a `## Design Style` section that `DECOMP` reads.

### 2. A runnable mockup, and one gate per round

A design round becomes **one `co-work` slice with two `pending` windows and one dispatched span**:

```
[inline]     write handoff.md → push → commit
             → PENDING #1 (mechanical wait, NOT an approval)
[inline]     → DesignSync read-back → card-contract check → concreteness check
             → land the record AS-IS → commit
[DISPATCHED] → slice-executor-high builds the runnable mockup route
               from build-prompt.md, in the project's own frontend stack,
               verified in the ## Operator Runtime → commit
[inline]     → PENDING #2 — THE ONE GATE: the operator opens the route and clicks it
             → literal approval → SIGNOFF → regroup → finish-slice → commit
```

- **Only PENDING #2 is an approval.** The operator confirms the design inside the Claude Design session itself; that session ending *is* the confirmation, so PENDING #1 is a mechanical wait. **SIGNOFF moves** from the read-back to after the mockup approval.
- **The mockup** is a throwaway route in the project's own router, namespaced and addressed by round; built with the project's real stack, components and tokens under RESPECT THE DESIGN; **stubbed data, no backing work**. It proves **look and states, not wiring** — non-functional controls are acceptable and **must be named as such in the gate walkthrough**. It is therefore **exempt from the full functional sweep**, which stays with apply/fidelity slices. Without that bound the mockup slice grows into the apply slice it is meant to precede.
- Verified in the `## Operator Runtime` manifest's runtime and access path; absent or `UNFILLED` → `needs_operator` → `pending`.
- **Throwaway lifecycle:** whichever slice later implements the surface for real deletes the mockup route. In `design-only` the mockup deliberately survives into the apply phase. The review checks no orphaned design routes remain.
- **Why dispatched:** DesignSync is main-thread-only, so read-back and regroup stay inline, but the mockup is real code and the orchestrator does not write code. Narrow amendment to "the design slice is NOT dispatched" — the *DesignSync* work is never dispatched; the mockup build is the one dispatched span.
- **The agent may still raise.** The two existing `needs_operator` conditions (cards missing / round came back as prose; concreteness bar unmet) are unchanged, and the mockup build adds a third: if building it proves the record wrong, inconsistent, or too thin to build without inventing, the executor returns `needs_operator` and the orchestrator raises rather than filling the gap.
- **Rejection at the gate** splits as the skill already splits findings: a departure from the record is fixed in-slice; a design question starts a **new immutable superseding round**.
- **Consequence:** a phase shipping a mockup changes operator-visible surfaces, so its phase gate is `accept-gate <P> --require`. A design-only phase can no longer be waived.
- **Side benefit:** the concreteness check stops being a judgment call — the mockup either builds from `build-prompt.md` without inventing, or it does not.

### 3. Close the `--kind` hole

`workflow.py` has no `SLICE_KINDS` constant and no validation — `--kind` is a free-form string, so `--kind cowork` silently creates a slice that reads as ordinary implementation and gets dispatched to an executor with no DesignSync, the exact failure the prose apparatus exists to prevent, and `validate()` passes it clean. Add the closed set, **hard-error** at `new-slice` and `promote-deferred`, and **warn (not error)** in `validate()` so adopting repos carrying invented kinds survive an update. No new kind for the mockup — it is a span inside the `co-work` slice.

### 4. Agent-runnable `create-phase`

`create-phase` carries `disable-model-invocation: true`, so the Skill tool refuses it — an approved plan that says "create phase P17" cannot be executed by the agent. Remove the flag so the agent can **call it when instructed**. The contract's "workflow command-skills are explicit-invocation only; agents should not fire them autonomously" **stays**, so `create-phase` becomes a second, narrower exception than `design-cowork`: callable on instruction, never fired on its own initiative. **The operator-confirmation gate at step 3 does not move** — whoever starts the intake, `new-phase` runs only after the operator explicitly confirms name and objective. Invocation is not the gate; confirmation is.

## Clarifications Resolved

- Q: Where should the mockup live — a runnable route in the real app, static component files, or production-quality components in their final home? — A: **A runnable route in the real app**, in the project's real stack, opened by the operator in their own runtime.
- Q: Who chooses the design style, and when? — A: **Flexible — the agent can suggest, and it can be asked at phase creation or at `DECOMP`.**
- Q: Where does the mockup get built, given a `co-work` slice is orchestrator-inline and forbidden from writing implementation code? — A: **Inside the design slice, but dispatched for the mockup** — inline / dispatched / inline.
- Q: With a mockup in the loop, where does approval land — one approval on the running mockup, or two (cards, then mockup)? — A: **At the mockup.** The Claude Design session ended because the operator confirmed the design there. Caveat: **if the design is wrong or needs correcting, the agent can raise.**
- Q: Add a validated `--kind` set to the engine, or keep it free-form? — A: **Yes, add a validated kind set.**
- Q: One phase or two for the design rework and the `create-phase` change? — A: **One phase, decomposed into 3 slices.**
- Q: Should removing `disable-model-invocation` make `create-phase` fully autonomous like `design-cowork`, or callable-when-instructed only? — A: **Callable when instructed, not autonomous.**
- Q: When the agent invokes `create-phase`, does the step-3 operator-confirmation gate stay? — A: **Always confirm, no exceptions.**

## Notes

- **Operator constraint for `DECOMP`: cut exactly 3 middle slices.** The grouping presented at confirmation, as guidance rather than instruction: (1) the `design-cowork/SKILL.md` spec — three styles, the mockup, the one gate, the two re-cut `Never` bans; (2) everything that must agree with it — `SLICE_KINDS` in `workflow.py`, `create-phase` (three-way style question **and** the model-invocation change), both drivers, both executor agents, `CLAUDE.md`; (3) release — version bump to v34, CHANGELOG, `installer/build.py` rebuild. Spec first, then propagation, then release.
- **The `co-work` invariants are restated in six files and enforced in zero** — `CLAUDE.md`, `design-cowork/SKILL.md`, both drivers, both executor agents. All six must move together; the phase needs a closing grep sweep for superseded wording.
- **Two `Never` bans must be re-cut precisely, not deleted** — this is the sharpest edit in the phase. "Author mockups … yourself" becomes "author a mockup **before the round has come back**" (the mockup *transcribes* an approved design; inventing one is designing); "write implementation code in a design slice" becomes "write **product** implementation code in a design slice". The bans on authoring palettes, type scales, cards, "proposals" and options-to-pick-from are unchanged.
- This phase changes workspace machinery, not an operator-visible product surface — expect `accept-gate P17 --waive` at the `DECOMP` boundary.
- Planning session for this phase: `/Users/sugang/.claude/plans/the-design-cowork-pattern-wiggly-brook.md`.
