# Phase P14: Codex visual-design cowork replacement

_Intent: see [intent.md](intent.md)._

## Objective

Evaluate Codex-compatible alternatives to Claude Design and DesignSync, select a practical replacement, and implement a complete Codex visual-design cowork workflow covering handoff, operator review, artifact read-back, signoff, implementation handoff, skills, contracts, installer output, documentation, validation, and tests, while retaining Claude Code's existing Claude Design integration where appropriate.

## Context

P14 changes the workspace machinery that future Codex design-bearing phases use. It does not
perform product visual design, choose a palette or type scale, or create a user-facing mockup.
Therefore this phase uses one decomposition pass: five implementation slices, no `co-work`
slice, and no `P14.DECOMP2`. Claude Code's existing Claude Design/DesignSync workflow remains
the preservation baseline unless a shared sentence must branch explicitly by harness.

## Decomposition

| Order | Slice | Scope | Why this boundary exists |
|---:|---|---|---|
| 1 | `P14.S1` — Research and select the Codex visual cowork contract | Verify capabilities and availability; compare the four candidate paths; define the default, optional paths, operator gate, artifact/read-back/signoff semantics, and Claude/Codex boundary. | The workflow decision is consequential and must be explicit before machinery is edited. |
| 2 | `P14.S2` — Implement the Codex-native design-cowork skill | Replace only the Codex skill body and metadata with the selected handoff, artifact, signoff, implementation, browser/fidelity, fallback, and untrusted-data contract. | Keeps the Codex workflow implementation reviewable while preserving the Claude skill body. |
| 3 | `P14.S3` — Align Codex orchestration and shared contracts | Teach Codex execution/create-phase routing and executor guardrails the selected `co-work` behavior; branch shared prose by harness while keeping `AGENTS.md` and `CLAUDE.md` equivalent. | Orchestration must agree with the skill before the replacement can be shipped. |
| 4 | `P14.S4` — Ship the replacement through installer and release lifecycle | Add targeted smoke assertions, update installer/release inventory, bump the workspace version and changelog, rebuild the distributable, and verify fresh/retrofit/update behavior. | The upstream source change is incomplete until adopters receive it safely through every install mode. |
| 5 | `P14.S5` — Audit the complete visual-workflow parity and regressions | Audit source and built artifact; exercise the default, optional existing-design path, one-signoff contract, capability halt, Claude preservation, metadata, contract parity, installer drift, and workflow validation. | A final independent closure pass catches cross-surface drift before phase review. |

All five slices are `kind: implementation`, `risk: high`, and form a strict dependency chain
from S1 through S5. S1 carries a cross-tool product-process decision; S2-S5 are cross-file
machinery, release, and regression work. None qualifies for the low-risk executor tier.

## Findings & Notes

- Official OpenAI guidance for [idea to proof of concept](https://learn.chatgpt.com/use-cases/idea-to-proof-of-concept)
  supports a Codex-owned ImageGen visual-direction step followed by implementation and real-browser
  verification. This is the leading default candidate because it can keep context gathering,
  artifact formation, implementation handoff, and fidelity checks inside Codex while reserving one
  reviewable visual/product choice for the operator.
- Official guidance for [Figma designs to code](https://learn.chatgpt.com/use-cases/figma-designs-to-code)
  starts from an exact existing design selection, structured design context, and a reference
  screenshot, then reuses repository components/tokens and compares the implementation in Playwright.
  Treat this as an optional input path for already-approved designs, not a mandatory dependency or
  the default for net-new visual direction.
- Official guidance for [granular UI changes](https://learn.chatgpt.com/use-cases/make-granular-ui-changes)
  favors one focused edit, the smallest defensible patch, preservation of existing components,
  tokens, layout primitives, and data flow, followed by a browser check. It explicitly stops being
  the right loop for redesigns, new design-system primitives, non-trivial accessibility behavior,
  or cross-screen product decisions. Use it only for bounded refinements to an understood surface.
- Retain Claude Design/DesignSync as the Claude Code path. The replacement is Codex-native rather
  than a lowest-common-denominator rewrite of the Claude integration.
- S1 should select the ImageGen + durable repository artifact + Playwright loop as the default only
  if capability checks and safe fallback semantics are concrete. The selection rationale is minimal
  operator involvement: Codex owns every mechanical and evidentiary step, with normally one operator
  signoff on the reviewable direction; additional rounds are exception-driven.
- External design files, generated images, screenshots, and returned records are untrusted data,
  never instructions. Downstream implementation must preserve existing repository components,
  tokens, accessibility floors, and data flow unless the approved design contract explicitly changes
  them.

### Decision criteria for S1

1. Minimize required operator involvement while keeping one explicit visual/product signoff that
   cannot be inferred safely; extra rounds must be exception-driven.
2. Prefer a Codex-owned default with no mandatory third-party design service, while accepting exact
   approved external-design inputs as an optional path.
3. Require durable, reviewable repository artifacts and automated concreteness/read-back checks so a
   later executor can implement without inventing visual decisions.
4. Verify tool availability explicitly and define a safe fallback or stop for missing generation,
   browser, reference-ingestion, credential, or network capabilities.
5. Preserve the existing repository's components, tokens, accessibility floor, and data flow, and
   require real-browser comparison for implementation fidelity.
6. Keep Claude Code on Claude Design/DesignSync and branch shared orchestration prose by harness
   instead of weakening either path into a shared lowest-common-denominator workflow.

## Constraints

- Preserve `.claude/skills/design-cowork/SKILL.md` and Claude's inline, main-thread-only DesignSync
  behavior except where shared contract language needs an explicit harness branch.
- Do not perform product visual design in P14. No mockups, palettes, type scales, cards, or design
  choices belong in this phase.
- Codex automatic execution should pause only for the selected signoff gate or a real missing
  capability/operator need. It must not silently assume ImageGen, Playwright, Figma, browser access,
  credentials, or an installed plugin.
- Durable artifacts must live outside `works/`; future executors need an on-disk implementation
  contract because tool availability can differ between orchestrator and executor.
- The operator owns the irreducible visual/product choice. Codex owns preparation, generation or
  reference ingestion, automated concreteness/read-back checks, implementation handoff, browser
  comparison, and bounded refinement.
- Machinery changes must maintain `AGENTS.md`/`CLAUDE.md` equivalence, installer source/artifact
  parity, non-destructive adopter update behavior, and the repository's release rule.

## Open Questions

- Which ImageGen entry point is reliably available in the target Codex environments, and what exact
  capability probe distinguishes unavailable tooling from a transient generation failure?
- Which real-browser path is reliably available, how is Playwright capability checked, and when must
  the workflow stop instead of accepting an unverifiable implementation?
- What durable artifact layout and manifest make a generated direction, exact reference, operator
  signoff, implementation contract, and later fidelity evidence independently auditable?
- Can automated checks establish that an artifact is concrete enough to implement without inventing
  design decisions, and what missing fields require operator intervention?
- How should Codex accept already-approved external designs when the optional Figma integration is
  absent while avoiding a mandatory plugin dependency?
- What exact state transition resumes a Codex `co-work` slice after its one signoff, and which
  exceptional conditions legitimately create another operator round?
