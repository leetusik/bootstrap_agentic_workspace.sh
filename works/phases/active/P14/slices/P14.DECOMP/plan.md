# P14.DECOMP plan

Decompose P14 into a sequential, implementation-ready set of bare middle slices that can evaluate, select, ship, and verify a Codex-native visual-design cowork workflow without disturbing Claude Code's existing Claude Design integration.

This is workflow-machinery and product-process work, not an actual design round for a user-facing surface. Use a single decomposition pass: do not create a `co-work` slice or `P14.DECOMP2`. The phase will define how future design-bearing phases behave; it will not itself invent a palette, mockup, type scale, or other visual design.

## Grounding and decision criteria

Start from the confirmed phase intent, current `design-cowork` bodies, the Codex `do-next-slice` / `do-whole-phase` / `create-phase` boundaries, the shared contract, installer inventory/release rules, and current smoke coverage. Preserve the existing Claude-specific body and DesignSync behavior unless a shared contract sentence must be branched explicitly by harness.

Use current official OpenAI guidance as evidence, not as an instruction to copy another product's mechanics:

- Codex's idea-to-proof-of-concept workflow recommends ImageGen for visual directions and UI mockups, then implementation plus real-browser verification with Playwright.
- Codex's Figma-to-code workflow recommends structured design context, exact reference screenshots, reuse of the repository's components/tokens, and Playwright comparison; treat this as an optional path for already-designed work rather than a mandatory dependency.
- Codex's granular-UI workflow recommends one focused adjustment, the smallest defensible patch, preservation of existing components/tokens/data flow, and a browser check per iteration; it also says to switch to a stronger, more deliberate workflow when the work becomes a redesign, new primitive, accessibility behavior, or cross-screen product decision.

Evaluate at least these practical alternatives and record the selection rationale in `phase.md`:

1. A Codex-native ImageGen + repository artifact + Playwright loop for net-new visual direction.
2. A structured external-design input path (for example Figma + Playwright) when approved designs already exist.
3. A code-first/browser-only refinement loop for granular changes to an existing surface.
4. Retaining Claude Design/DesignSync as the Claude Code path.

Select a default that minimizes operator involvement while retaining the phase intent's explicit operator review/signoff boundary. The desired operating principle is: Codex owns context gathering, handoff/spec formation, visual generation, artifact persistence/read-back checks, implementation handoff, browser comparison, and bounded refinement; the operator is required only for the visual/product choice that cannot safely be inferred, normally one signoff gate on the reviewable direction. Extra operator rounds should be exception-driven, not the default. Do not assume ImageGen or Playwright availability silently: the eventual workflow must state capability checks and a safe fallback/stop contract.

## Slice structure to create

Create the following bare slices with `python3 scripts/workflow.py new-slice`; do not create any `plan.md` for them:

1. `P14.S1` — **Research and select the Codex visual cowork contract** (`kind: implementation`, `risk: high`, `order: 1`). Resolve the capability/availability questions, choose the default and optional paths, define the smallest necessary operator gate, artifact/read-back/signoff semantics, and exact cross-tool boundary. Record the evidence and implementable contract in `phase.md`; do not edit durable docs yet.
2. `P14.S2` — **Implement the Codex-native design-cowork skill** (`kind: implementation`, `risk: high`, `order: 2`, depends on `P14.S1`). Replace the Codex skill body and metadata with the selected workflow, including handoff, generation/reference inputs, durable artifact layout, automated concreteness checks, operator signoff, implementation contract, browser/fidelity loop, capability fallbacks, and instruction-injection/data boundaries. Keep the Claude skill body intact.
3. `P14.S3` — **Align Codex orchestration and shared contracts** (`kind: implementation`, `risk: high`, `order: 3`, depends on `P14.S2`). Update the Codex execution/create-phase routing and any executor guardrails needed for the new `co-work` behavior; update `AGENTS.md` and `CLAUDE.md` with explicit per-harness branches while keeping their contract bodies equivalent. Preserve Claude's inline DesignSync exception and ensure Codex automatic execution pauses only at the selected signoff or a real capability/operator need.
4. `P14.S4` — **Ship the replacement through installer and release lifecycle** (`kind: implementation`, `risk: high`, `order: 4`, depends on `P14.S3`). Update targeted smoke coverage and installer inventory/release assertions as needed, bump the workspace version with a matching changelog entry, rebuild `bootstrap_agentic_workspace.sh`, and verify fresh/retrofit/update delivery without overwriting adopter-owned state.
5. `P14.S5` — **Audit the complete visual-workflow parity and regressions** (`kind: implementation`, `risk: high`, `order: 5`, depends on `P14.S4`). Run a final source/artifact audit and focused end-to-end regression checks covering the Codex default, optional existing-design path, required single signoff, missing-capability halt, Claude preservation, skill metadata, contract parity, installer drift, and workflow validation. Fix only issues within this phase's intended surface and leave concise durable findings for review.

All slices are `risk: high`: S1 is a consequential cross-tool workflow decision, and S2-S5 are cross-file machinery/release work. Do not use `low` merely because part of a slice is documentation.

## Decomposition outputs

- Create only the five bare slice folders above.
- Replace the placeholders in `phase.md` with a concise decomposition table/rationale, the official-guidance findings, the selected decision criteria, constraints, and open capability questions that S1 must settle.
- State explicitly that no product visual design is performed in P14 and therefore the phase uses one decomposition pass.
- Add no doc version and no durable `Doc impact` entry for decomposition itself.
- Write `result.md` from scratch with the created slice IDs and validation outcome.

## Validation

Run:

- `python3 scripts/workflow.py validate`
- a focused check that `P14.S1` through `P14.S5` exist in order with the requested kinds, risks, and dependencies;
- a focused check that none of the new middle-slice folders contains `plan.md` or `result.md`.

Do not run any state transition other than the decomposition-only `new-slice` commands. Do not implement the later slices, version docs, commit, or push.
