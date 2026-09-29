# Intent — P25

- Captured at: 2026-09-29T19:35:20+09:00
- Origin: operator

## Original Input (verbatim)

> the design cowork, it's not compatible with ocx way right? and not for that reason, I want to replace claude design with some less dependant one. and as you know, our current design-cowork is not how claude suggesting way of using the claude desing isn't it. /create-phase, the first research phase will give me roughly top 3 options for replacement

## Confirmed Intent (refined + clarified)

A **research** phase that returns roughly the **top 3 ranked options for replacing Claude Design** as
the design tool behind the `design-cowork` skill, with each option's trade-offs and a recommendation
on whether Claude Design survives as an optional path. The motive is dependence, not ocx alone: the
current loop needs a claude.ai account and subscription, and `DesignSync` is main-thread only, so
the loop is also out of reach of executor subagents.

**Criteria every option is ranked against:**

1. **Runs in both `claude` and `ocx claude`.** Claude-Code-only is acceptable; tying the loop to one
   model or provider is not.
2. **No vendor SaaS account and no paid subscription.** Local, open-source or self-hostable.
3. **Executor subagents can drive it.** The operator prefers the design work handled by a subagent;
   nothing main-thread only.
4. **A Claude-Design-like surface for the operator.** Frames/cards the operator can view and review;
   no chat surface is needed.
5. **Persistent design memory.** Like a Claude Design design-system project today, the replacement
   keeps the design's working memory (system, prior rounds, decisions) so the design continues across
   rounds and sessions rather than restarting.

**Framing:**

- **Who designs:** the agent may draft variants/mockups; nothing is decided until the operator's
  literal signoff. Anthropic's `frontend-design` plugin may be used, but only where an option actually
  needs it.
- **Fixed (governance):** the three styles (`build-after` / `design-only` / `paired`), rounds, literal
  signoff, the mockup gate, and RESPECT THE DESIGN.
- **Replaceable (the loop):** `handoff.md`, the numbered card contract, the `DesignSync` read-back and
  the SIGNOFF regroup.

**Out of scope:** changing any machinery. Adopting the chosen option is a later phase the operator
creates after reading the ranked options.

## Clarifications Resolved

- Q: Is design-cowork incompatible with `ocx claude`? — A (orchestrator's reading, not yet verified):
  very likely — Claude Design and `DesignSync` ride on the claude.ai login, which an ocx session
  (proxy to Kiro) does not carry; this session was not on ocx, so it was not tested. The operator:
  "not for that reason" — dependence is the motive either way.
- Q: Is the current design-cowork the way Claude Design is meant to be used? — A (orchestrator's
  reading, to be confirmed by the research): no — the native flow runs design in Claude Design →
  handoff bundle → Claude Code builds; ours runs a repo-authored `handoff.md` into Claude Design,
  then a `DesignSync` read-back, a numbered card contract and a card-group rewrite at signoff.
- Q: What must the replacement not depend on? — A: "A vendor SaaS account, One model/provider,
  Main-thread-only tools, Paid subscription, man It's okay to be handled with subagent. I actually
  prefer this way. only in claude code is also acceptable(for both ocx claude and just claude)"
- Q: Does "the agent never designs" still bind the options? — A: "Agent drafts, you decide" — "and
  maybe frontend plugin like one is can be used. but only on if needed. and I need a claude design
  like UX/UI though. only frames/cards visible w/o chat surface is fine." Confirmed "frontend plugin"
  means Anthropic's `frontend-design` plugin: "I meant that."
- Q: What of design-cowork is fixed? — A: "Keep governance, swap the loop"
- Q: Does Claude Design survive the replacement? — A: "Research recommends"
- Q: (added at confirmation) — A: "note that like the current claude design system the replacement
  should got it's work memories so that the design continues."

## Notes

- This phase is workspace machinery, not product visual design: no `## Design Style` section.
- The research should verify the two orchestrator readings above (ocx compatibility of `DesignSync`,
  and Claude Design's native usage) and state what it found, not assume them.
- The deliverable is a ranked report the operator reads to pick one; `DECOMP` decides the acceptance
  gate with that in mind.
