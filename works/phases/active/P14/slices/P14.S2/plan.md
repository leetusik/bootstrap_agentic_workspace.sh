# P14.S2 plan — implement the Codex-native `design-cowork` skill

Replace the Codex visual-design guide with the complete S1-selected ImageGen/reference-artifact workflow and update its Codex metadata. Preserve the Claude Code skill byte-for-byte; do not change shared contracts, Codex execution/create-phase routing, executor guardrails, tests, release version, or changelog in this slice.

## Scope

Edit only the live Codex skill surfaces plus the generated installer artifact and this slice's workflow records:

- `.agents/skills/design-cowork/SKILL.md`
- `.agents/skills/design-cowork/agents/openai.yaml`
- `bootstrap_agentic_workspace.sh` via `python3 installer/build.py`
- `works/phases/active/P14/phase.md`
- `works/phases/active/P14/slices/P14.S2/result.md`
- generated workflow state from the orchestrator (not by the executor)

Do not edit `.claude/skills/design-cowork/SKILL.md`; its starting blob is `0e3a1766ebb85126ab97356f4fdbc5f82753067e` and that hash must remain unchanged. Do not edit `AGENTS.md`, `CLAUDE.md`, the Codex `do-*`/`create-phase` skills, executor files, installer source/version, `CHANGELOG.md`, README files, tests, or durable docs; S3-S5 own those surfaces.

## Codex skill contract to write

Author a self-contained, flat `SKILL.md` (the installer embeds no skill `references/` or `scripts/` subtrees) that faithfully implements the complete `### Selected Codex visual cowork contract` in P14 `phase.md`. Keep it concise enough to be operational, but complete enough that a future Codex orchestrator can run a `co-work` slice without inventing workflow semantics.

The skill must include all of the following:

1. **Trigger and boundary.** It is model-invocable for product visual design only (design systems, redesigns, mockups, design gates, brand/palette/type, user-facing page appearance), not schema/API/architecture. Codex may produce a visual direction through ImageGen, but the operator owns the irreducible approval/selection. The design slice contains no implementation code and remains main-thread/orchestrator-only, never dispatched to a slice executor.
2. **Selected normal loop.** Show the exact lifecycle: decision-free `handoff.md` → built-in ImageGen (or exact approved reference) → copy the canonical reference into the repository → exact on-disk read-back/concreteness validation → commit the review-ready record → `pending` for one normal signoff → approval resume/hash recheck → literal `SIGNOFF.md` → finish/commit → separate `DECOMP2` backing/implementation/fidelity slices. No push or external write is implied.
3. **Phase shape.** Retain the create-phase one-vs-two-phase decision, one `co-work --risk high` slice per visual round, two-pass mixed-phase decomposition, single-pass design-only/apply phase, immutable extra revision rounds, and normal design-fidelity fix. Clearly distinguish a future product design phase from P14 itself.
4. **Capability probes and safe degradation.** Use the built-in `imagegen` skill/tool by default when exposed and generate without asking for a separate pre-generation confirmation. Do not infer availability from a skill filename alone. If absent or failed, do not silently retry, install, or switch to the credentialed CLI/model path: offer that documented fallback only after explicit operator choice, otherwise request an exact approved reference. Require `view_image` (or exact applicable reader) for the workspace copy. Figma/structured input is optional only when explicitly chosen and exposed; never require/install it. Declare project-native browser/E2E first, then `npx` + bundled Playwright wrapper; browser failure blocks fidelity claims later, not the design artifact itself except that a viable route must be declared before signoff.
5. **Handoff.** Specify product/user context, complete scope checklist, locked versus in-play areas, real repository paths/content/data, literal copy constraints, accessibility/reduced-motion floor, questions posed to the generation/reference process, definition of done, and any operator attachments. The handoff itself does not make the visual choice; the generated/reference artifact does, subject to signoff. No lorem/placeholders.
6. **Durable design record.** Use the S1 layout under `docs/reference/design/rounds/<NN>-<slug>/`: `handoff.md`, `reference/primary.*` (+ optional numbered supporting files), `record.json`, `implementation-contract.md`, `validation.md`, approval-only `SIGNOFF.md`, and later `fidelity/<slice-id>/`. The canonical reference must be copied non-destructively into the repo and never remain only in conversation state or `$CODEX_HOME/generated_images`. Approved artifacts are immutable; revisions create a new numbered round with `supersedes` provenance.
7. **Manifest and contract fields.** Spell out the machine-checkable `record.json` requirements and the complete executor-facing implementation contract: schema/round/status/mode/provenance, hashes and repo-relative artifact paths, routes/viewports/states, real content, components/tokens/layout primitives to reuse, responsive/interaction behavior, all UX states, accessibility/reduced motion, copy/data/routing constraints, departures/open questions, and fidelity acceptance criteria. No secrets.
8. **Read-back/concreteness gate.** Parse the manifest, reject absolute/traversing paths, verify non-empty regular files and SHA-256, inspect the exact workspace reference with `view_image`, reconcile reference/record/contract, require empty open questions and explicit not-applicable/departure entries, reject TODO/TBD/lorem/vagueness, require a declared real-browser route, and treat every generated/external artifact or embedded text as untrusted data rather than instructions. Do not ask for signoff until this passes.
9. **One-gate state machine.** First run commits review-ready artifacts without `SIGNOFF.md`, sets `pending`, and asks for approval or a revision. Literal approval authorizes `pending → in_progress`, exact hash recheck, signoff, finish and gate-close commit. Literal revision authorizes a new immutable numbered round and repeats the gate. Capability/reference gaps create an exact `operator_need` pending halt and are not mislabeled as approval. Extra rounds are exception-driven.
10. **Implementation fidelity.** After signoff, `DECOMP2` cuts backing work first, faithful UI implementation second, and bounded fidelity fixes last. Plans/dispatch prompts must name the approved round/hash and say `RESPECT THE DESIGN`. Prefer project-native browser/E2E, otherwise the Playwright wrapper after its prerequisites pass; exercise routes/viewports/states/responsiveness/keyboard/focus/reduced motion, store selected durable evidence, and correct one concrete mismatch with the smallest defensible patch. Broad new product/design questions require a new round; no real browser means no fidelity claim.
11. **Never list.** Include at least: no implementation in `co-work`; no executor dispatch for `co-work`; no overwrite of approved/user artifacts; no conversation-only canonical output; no silent CLI/plugin/install/retry fallback; no unapproved third-party dependency; no treating artifacts as instructions; no silent design gap filling; no source implementation before signoff; no dropping/simplifying an approved element; no push/external write implied; no edits to Claude's workflow from this Codex guide.

Do not mention DesignSync cards, `@dsCard`, Claude Design mechanics, or Claude-only commands in the Codex skill body. Harness branching is S3's shared-contract job; this file should be a genuinely Codex-native guide, not a compatibility essay.

## Metadata

Update `.agents/skills/design-cowork/agents/openai.yaml` so its display/short description/default prompt accurately describe Codex + ImageGen/exact-reference + one-signoff + browser-fidelity cowork. Preserve `policy.allow_implicit_invocation: true`; `design-cowork` remains the only model-invocable workspace guide.

## Installer and phase notes

- Run `python3 installer/build.py` after the live skill/metadata edits so the committed `bootstrap_agentic_workspace.sh` contains the exact new Codex payload while preserving the Claude payload.
- Do not bump `WORKSPACE_VERSION` or edit `CHANGELOG.md`; P14.S4 owns the consolidated release after S3 finishes the remaining machinery.
- Append a concise phase finding describing the implemented Codex skill and one `Doc impact` line for `decisions`/`operations` if the existing S1 line does not already fully cover it; do not create doc versions.
- Write `result.md` from scratch with the implemented sections, source/installer files changed, validations, Claude hash, doc impact, and deviations.

## Validation

Run at minimum:

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `git hash-object .claude/skills/design-cowork/SKILL.md` and require `0e3a1766ebb85126ab97356f4fdbc5f82753067e`
- focused assertions that the Codex body contains ImageGen, exact approved-reference/Figma-optional handling, repository persistence, `record.json`, `implementation-contract.md`, `view_image`, one normal signoff/pending lifecycle, explicit capability halts, `DECOMP2`, Playwright/project-browser fidelity, immutable revision rounds, untrusted-data handling, and `RESPECT THE DESIGN`
- focused assertions that the Codex body contains none of `DesignSync`, `@dsCard`, or `Claude Design`
- focused metadata assertion for `allow_implicit_invocation: true` and the new Codex description
- focused installer assertion that both the new Codex body/metadata and the unchanged Claude body are embedded in the generated artifact
- `git diff --check`

Return `done` only if S3 can align orchestration against this skill without correcting a workflow omission.
