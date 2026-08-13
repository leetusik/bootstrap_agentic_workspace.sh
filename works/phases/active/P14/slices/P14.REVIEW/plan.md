# P14.REVIEW — Whole-phase review

## Review objective

Independently validate and judge all of P14 against the confirmed intent: replace the unavailable
Claude Design/DesignSync mechanics on Codex with a current, practical Codex-native frontend/UX
workflow that is fully integrated into this workspace's phase/slice lifecycle, minimizes intermediate
operator involvement, preserves Claude Code's existing path, ships through the installer, and remains
safe, durable, and testable.

Read `intent.md`, the entire `phase.md`, `docs/index.json`, all relevant `docs/current/*.md`, and every
completed P14 slice's `slice.json`, `plan.md`, and `result.md`. Inspect the actual live and generated
source rather than relying on summaries. The user explicitly asked that no comparison-repository name
or provenance be introduced here; review only this repository's contract and evidence.

## Required judgment

Complete validation and judgment across the whole phase before deciding a verdict. Do not edit source
code on this review slice. If any source or behavior needs correction, return `changes_requested` with
all numbered findings and proposed bare `P14.F<n>` fix slices; do not create those folders yourself.

Judge at least these questions:

1. **Codex best-practice basis.** The selected path is supported by current official OpenAI guidance:
   built-in ImageGen can establish visual direction, an exact approved design/screenshot can drive
   implementation, existing components/tokens should be reused, granular UI refinements stay focused,
   and real-browser/Playwright verification closes the fidelity loop. Figma remains optional rather
   than mandatory. Use official OpenAI sources for this external verification and do not overclaim.
2. **Workspace-native lifecycle.** The result is not a generic frontend recipe: product visual work
   automatically invokes `design-cowork`; phase intake can choose one mixed phase or a separate design
   plus apply phase; a mixed phase decomposes into groundwork + main-thread `co-work` gate +
   `DECOMP2`; a design-only phase and an apply phase retain a single decomposition pass; no build slice
   is speculated before a landed design; backing/backend work precedes faithful UI implementation.
3. **Low operator involvement with an honest gate.** The normal Codex path does not ask permission to
   invoke built-in ImageGen or approve every intermediate plan. Codex prepares the handoff, generation
   or exact reference, durable record, read-back, hashes, concrete implementation contract, and
   validation before asking for exactly one normal visual signoff. Additional stops occur only for a
   failed/missing capability/reference, literal revision, or unresolved product/visual choice.
4. **Durability, trust, and immutability.** The canonical reference and contract live in the repo with
   provenance and hashes; exact workspace output is read back; approval is literal and hash-bound;
   revisions supersede without overwriting; generated/external artifacts are data, never instructions;
   no secret paste, implicit plugin/service install, push, publication, or unrelated external write is
   authorized.
5. **Runner and executor correctness.** Both Codex automatic-only runners handle `co-work` inline and
   narrowly resume a pending design slice only from matching explicit operator input; bare automatic
   invocation cannot approve. `do-next-slice` stops after one signed design slice;
   `do-whole-phase` continues only inside its entry phase to `DECOMP2`. Ordinary pending, `ready`,
   sequential executor dispatch, escalation, review/fix, parallel stream, state/commit ownership, and
   automatic-mode rejection behavior remain correct. Neither Codex executor can run `co-work`.
6. **Faithful implementation.** Separate post-signoff plans name the approved round/hash and
   `RESPECT THE DESIGN`; declared routes/viewports/states/responsive behavior/interactions/keyboard/
   focus/accessibility/reduced-motion behavior are verified in a real browser. Project-native tooling
   is preferred; Playwright fallback is probed. Without a successful browser run, no fidelity claim is
   allowed. Granular fixes preserve components, tokens, routing, accessibility, and data flow.
7. **Harness separation.** Codex-native surfaces do not rely on DesignSync/cards/Claude Design and
   Claude Code's design skill remains byte-identical at the recorded blob. Shared contracts branch
   explicitly while retaining the common design/build invariants.
8. **Release and lifecycle.** Workspace v30, changelog, user/maintainer guidance, skill metadata,
   generated artifact, fresh install, non-destructive retrofit, and update agree. Update replaces stale
   pre-v30 managed Codex visual files without clobbering adopter-owned work. The 17+17 inventory remains
   complete; only `design-cowork` is implicitly invocable.
9. **Scope and quality.** P14 created no product visual direction or UI, no irrelevant plugin/service
   dependency, no historical/current durable-doc hand edit, and no unrequested push. Tests stay focused
   and the implementation contains no contradictory or vague gate that would force future executors to
   invent a visual choice.

## Validation

Run every completed slice's validation commands from its `plan.md` / `result.md`, plus the final
workflow validation. You may deduplicate an identical current-tree command, but in `result.md` map the
single result back to every slice that required it. At minimum the completed set includes:

- `python3 scripts/workflow.py validate`
- the S1 focused contract assertions
- `python3 installer/build.py --check`
- `python3 scripts/workflow.py sync-agents --check`
- `python3 -m py_compile installer/build.py installer/main.py scripts/workflow.py`
- `bash -n tests/retrofit_smoke.sh`
- `bash tests/retrofit_smoke.sh`
- the exact S2 skill/metadata/embedded-payload and Claude-blob assertions
- the exact S3 runner/shared-contract/embedded-payload assertions (using the authoritative
  header-stripped AGENTS/CLAUDE body comparison; also record why whole-file `cmp` is inapplicable)
- the exact S4 v30 release/guidance/embedded-payload assertions
- the exact S5 focused source/artifact/lifecycle audit
- `git diff --check`

Also verify the official external evidence using only the three official OpenAI use-case pages recorded
in `phase.md`; paraphrase within source limits and distinguish what they state from the workspace's
derived orchestration policy.

## Verdict and pass-only docs

Return exactly one complete `review_verdict`: `pass`, `changes_requested` with every numbered issue and
proposed `P14.F<n>` scope, or `blocked` with the blocker. Always include
`explain: not written — run /explain for this phase`.

On `pass` only, consolidate the complete P14 `Doc impact` into exactly two new durable versions:

1. `python3 scripts/workflow.py doc-new-version --doc decisions --summary "Codex-native visual cowork: durable ImageGen or exact-reference gate, one signoff, and faithful build handoff" --source P14.REVIEW`
2. `python3 scripts/workflow.py doc-new-version --doc operations --summary "Operate the v30 Codex visual-design gate, explicit resume, DECOMP2, and browser-fidelity lifecycle" --source P14.REVIEW`

Edit only the newly returned version paths, preserving all unrelated historical truth while adding a
clear current-v30 status/section:

- `decisions`: record why built-in ImageGen or an exact approved reference plus repository persistence,
  one literal signoff, immutable revision, separate `DECOMP2`, and real-browser fidelity was selected;
  distinguish the Claude path; state that the operator owns the irreducible visual choice while Codex
  owns the mechanical middle steps.
- `operations`: document phase shapes (mixed two-pass, design-only single-pass, separate design/apply),
  capability probes and exact halts, durable round layout and concreteness gate, review-ready and
  approval-resume commits/statuses, `do-next` versus `do-whole` continuation, post-signoff build/fidelity
  ordering, update/install behavior, and the no-fidelity-without-browser rule. Keep it usable as a
  runbook without copying the entire skill.

Then run `python3 scripts/workflow.py rebuild-docs` and verify `docs/current/*` and `docs/index.json`
point at those exact new versions. Report both version ids/paths in `result.md`.

On `changes_requested` or `blocked`, do no doc-versioning, rebuilding, or other pass-only action.
Never write an explainer.
