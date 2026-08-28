# P14.S1 result — Codex visual cowork contract selected

P14 now has one complete, implementable Codex visual-design cowork contract. The selected net-new
default is Codex orchestration plus built-in ImageGen, exact workspace-persisted read-back, a durable
design record, one normal operator signoff gate, separate `DECOMP2` implementation slices, and
real-browser fidelity checks. Exact already-approved references are an optional path; Figma is optional
structured input only; Claude Code retains Claude Design/DesignSync.

## Research and capability checks

Primary sources checked:

- [Get from idea to proof of concept](https://learn.chatgpt.com/use-cases/idea-to-proof-of-concept):
  supports ImageGen visual direction followed by implementation and real-browser verification.
- [Turn Figma designs into code](https://learn.chatgpt.com/use-cases/figma-designs-to-code):
  supports exact existing-design context/screenshots, repository-system reuse, and Playwright
  comparison; it does not justify making Figma mandatory for net-new direction.
- [Make granular UI changes](https://learn.chatgpt.com/use-cases/make-granular-ui-changes):
  supports one focused post-approval mismatch at a time with existing components/tokens/data flow
  preserved and a browser check.

Local contracts checked read-only:

- `/Users/sugang/.codex/skills/.system/imagegen/SKILL.md`: built-in tool first, no API key for that
  path, project-bound output copied from `$CODEX_HOME/generated_images/...`, no silent CLI fallback,
  explicit operator choice plus `OPENAI_API_KEY` for CLI.
- `/Users/sugang/.codex/skills/playwright/SKILL.md`: `npx` prerequisite, bundled wrapper, real-browser
  workflow, `output/playwright/` convention, and exact halt/install guidance.
- Both current `design-cowork` skill bodies and Codex metadata, the Codex `do-next-slice`,
  `do-whole-phase`, and `create-phase` skills, the high executor guardrail, `AGENTS.md`/`CLAUDE.md`,
  current architecture/operations/decisions docs, `installer/build.py`, and targeted retrofit-smoke
  assertions.

Read-only availability checks established only this session's state:

- `image_gen__imagegen` and `view_image` are exposed; neither was invoked.
- No Figma-specific tool is exposed. No plugin was installed or called.
- `npx` resolves to `/opt/homebrew/bin/npx` and the bundled Playwright wrapper exists and is
  executable. No browser was launched and no package was installed.
- This repository declares no project-native browser/E2E command. Adopters must probe their own
  repository first, then use the Playwright fallback when available.

## Contract recorded

The provisional findings and open questions in `phase.md` were replaced with
`### Selected Codex visual cowork contract`, which settles:

- evaluated/default/optional/rejected paths and the explicit Claude/Codex boundary;
- per-run capability probes that distinguish absence from runtime failure and never assume session
  parity for adopters or executors;
- the immutable `docs/reference/design/rounds/<NN>-<slug>/` layout with `handoff.md`, exact references,
  `record.json`, `implementation-contract.md`, `validation.md`, approval-only `SIGNOFF.md`, and later
  fidelity evidence;
- the machine-checkable manifest fields, SHA-256/path/readability checks, exact `view_image` read-back,
  concreteness bar, placeholder/open-question rejection, and untrusted-data boundary;
- the first-run, approval-resume, revision-resume, and capability-need state/commit mechanics;
- project-native-browser-first and Playwright-fallback fidelity semantics, including a hard stop when
  no real-browser route can run;
- separate backing/implementation/fidelity slices cut by `DECOMP2`, with broad new questions routed to
  another design round rather than decided in code.

No workflow choice remains for S2; later slices may choose implementation locations and assertion
mechanics only within this settled behavior.

## Files changed

- `works/phases/active/P14/phase.md`
- `works/phases/active/P14/slices/P14.S1/result.md`

No live skill, contract, installer, generated artifact, current doc, historical doc version, or later
slice file was edited. No image, browser, package/plugin installation, external write, workflow state
transition, commit, or push was performed.

## Validation

- `python3 scripts/workflow.py validate` — passed.
- Focused Python textual assertions over `phase.md` — passed 11 assertions covering the selected
  section, ImageGen default, workspace-persisted reference, optional approved-reference/Figma path,
  one normal signoff gate, explicit missing-capability halts, project-browser/Playwright verification,
  separate `DECOMP2` implementation, untrusted-data handling, Claude Design/DesignSync preservation,
  and the doc-impact entry; also confirmed the provisional `## Open Questions` section is gone. An
  initial ad hoc matcher expected backticks around a code-block path and failed; the corrected matcher
  passed without changing the contract.
- `git diff --check` — passed before the result write and is rerun at final validation.

## Doc impact

- `decisions`, `operations` — establish the harness-specific Codex visual-cowork workflow: built-in ImageGen or an exact approved reference, durable read-back artifacts, one normal signoff gate with explicit capability halts, separate `DECOMP2` implementation, and real-browser fidelity while preserving Claude Design/DesignSync.

## Deviations

None. The slice remained a read-only research/capability investigation apart from its required
`phase.md` and `result.md` records.
