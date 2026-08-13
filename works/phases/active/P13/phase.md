# Phase P13: Codex workflow parity

_Intent: see [intent.md](intent.md)._

## Objective

Make Codex a first-class orchestrator across all non-visual workspace workflow machinery: ship and align applicable command skills including create-phase and do-whole-phase, support automatic execution only with Codex gate and plan-only modes removed or rejected, and achieve parity across executor tiers, routing, escalation, configuration, commit attribution, contracts, installer payloads, documentation, validation, and tests while auditing the workspace for remaining Claude-only assumptions.

## Context

## Decomposition

1. **P13.S1 — Determine and land Codex executor tiers** (`implementation`, `high`) selects the Codex mid/high models and reasoning efforts from the official custom-agent contract, then aligns routing, escalation, configuration, attribution, contracts, and the embedded installer artifact. Depends on `P13.DECOMP`.
2. **P13.S2 — Restore Codex do-whole-phase** (`implementation`, `high`) adds the Codex skill and metadata, implements the sequential auto-only loop through those tiers, explicitly rejects `gate` and `plan only`, and preserves execution of already-`ready` slices. Depends on `P13.S1`.
3. **P13.S3 — Align Codex workflow contracts and command skills** (`implementation`, `high`) makes Codex `do-next-slice` auto-only, audits all non-visual mirrored skills for Claude-only assumptions, and keeps `AGENTS.md` / `CLAUDE.md` equivalent with actual-model attribution. Depends on `P13.S2`.
4. **P13.S4 — Ship Codex parity through installation and updates** (`implementation`, `high`) covers installer inventory, managed paths, update and stale-skill behavior, user-facing output, documentation, workspace versioning, changelog, and the rebuilt artifact across fresh install, retrofit, and update. Depends on `P13.S3`.
5. **P13.S5 — Audit and regression closure** (`implementation`, `high`) adds concise coverage for Codex skill presence and auto-only behavior, executor synchronization, installer/update behavior, and live-versus-embedded parity, then closes remaining non-visual Claude-only assumptions before review. Depends on `P13.S4`.

The slices are deliberately sequential: S1 establishes the executor contract used by S2; S2 establishes the whole-phase loop S3 aligns; S4 packages the settled machinery; S5 audits and closes regressions across the final shipped surface.

## Findings & Notes

- Operator-authorized exception: `P13.DECOMP` is executed directly by the orchestrator instead of a dispatched executor.
- Operator-authorized exception: `P13.S1` is also executed inline by the orchestrator; normal `slice-executor` delegation resumes at `P13.S2`.
- Official Codex custom agents are project-scoped standalone TOML files under `.codex/agents/`; each requires `name`, `description`, and `developer_instructions`, and may pin `model`, `model_reasoning_effort`, and `sandbox_mode`.
- Official guidance currently recommends `gpt-5.6` for demanding multi-step agents and `gpt-5.6-terra` for faster, lower-cost supporting agents. S1 owns the final tier choice and its repository-wide consequences.
- P14 exclusively owns the visual-design cowork replacement. P13 audits and changes only non-visual workflow machinery.
- Codex is automatic-only: `gate` and `plan only` must fail clearly, while legacy/cross-tool slices already in `ready` state remain executable.
- S1 executor decision, operator-corrected by P13.F1: both harnesses have distinct `economy` / `flex` matrices. `economy` (the engine fallback when no mode is selected) maps Claude mid/high to `sonnet@high` / `opus@high` and Codex mid/high to `gpt-5.6-luna@high` / `gpt-5.6-terra@high`; `flex` maps Claude to `sonnet@xhigh` / `opus@xhigh` and Codex to `gpt-5.6-terra@high` / `gpt-5.6-sol@high`.
- S1 kept the existing routing and recovery contract unchanged: only `risk: low` reaches mid; decomposition, review, and every other risk reach high; mid may escalate once to high.
- S1 removed live hard-coded GPT-5.5 attribution examples. Codex commit/explainer attribution names the model that actually performed the work.
- S1 updated `.codex/config.toml` to use the current `agents.max_concurrent_threads_per_session` setting name; the older `agents.max_threads` remains only an upstream-supported legacy alias.
- Doc impact — operations: record both Claude/Codex executor preset matrices, the default no-mode `economy` resolution, this repo's active `flex` selection, the official project-agent schema baseline, and the current concurrency setting name.
- Doc impact — decisions: supersede the Codex GPT-5.5/xhigh tier defaults and S1's identical-preset claim with the operator-corrected `economy` Luna/Terra and `flex` Terra/Sol matrices, plus actual-executing-model attribution.
- S2 restored `.agents/skills/do-whole-phase/` as an independent Codex skill: bare, `auto`, and unattended wording run the same automatic sequential loop; `gate` and `plan only` stop before any mutation.
- S2 preserves direct execution of existing `ready` plans for upgrade/cross-tool compatibility, routes sequentially through the P13.S1 custom tiers with one `mid → high` escalation, and leaves visual `co-work` at the `design-cowork` boundary.
- S2 extended the minimal retrofit smoke coverage for both Codex whole-phase files and their live-versus-embedded installer parity; the workspace version/changelog release boundary remains assigned to S4.
- Doc impact — operations: document the explicit-only Codex `do-whole-phase` skill, its automatic-only entry contract, sequential custom-tier loop, safety halts, `ready` compatibility, escalation, and review/fix behavior.
- Doc impact — decisions: record that Codex whole-phase orchestration is restored independently from Claude's multi-mode skill, with automatic execution accepted and `gate` / `plan only` rejected without mutation.
- P13.F1 selected `mode = "flex"` in this repo, synchronized the live agents to Claude `sonnet/opus @ xhigh` and Codex `terra/sol @ high`, and added a fresh-install no-mode probe proving the engine fallback remains `economy` with Codex `luna/terra @ high`.
- P13.S3 replaced the mirrored Codex `do-next-slice` with an independent automatic-only body: bare/automatic invocations plan inline and dispatch one project custom agent, while `gate`, `plan only`, and unknown modes stop before mutation; existing `ready` plans remain directly executable on visible-no-drift compatibility paths.
- P13.S3's non-visual Codex skill audit found all 17 skill metadata files present. Every workflow command skill is explicit-only; the deliberately model-invocable `design-cowork` guide remains the sole exception and was not edited. Codex command bodies now use `$skill`/tool-neutral invocation wording instead of Claude slash or `$ARGUMENTS` mechanics where those assumptions were live.
- The equivalent contracts now distinguish Claude's default-auto plus opt-in `gate` / `plan only` from Codex's automatic-only execution, document sequential Codex project-agent spawning, both preset matrices, the shipped/upstream `flex` selection versus adopter overrides, `ready` compatibility, and actual-executing-model attribution for commits and explainers.
- Audit searches intentionally still find Claude plan-mode/harness/settings language in Claude-specific surfaces and the shared contract's explicit Claude branch, the fixed `/explain` review pointer required on every verdict, and Claude-only `gate` examples in the READMEs. The excluded visual `design-cowork` copies retain their P14-owned Claude Design / DesignSync language.
- Doc impact — operations: document the two-tool command-skill inventory, Codex automatic-only `do-next-slice` / `do-whole-phase` entry contract, Claude-only gated modes, sequential project-agent dispatch, `ready` compatibility, explicit invocation metadata, and corrected preset/active-selection wording.
- Doc impact — decisions: record independent Codex command-skill bodies and rejection-before-mutation for `gate` / `plan only`, while Claude retains its multi-mode workflow and actual-model attribution governs commits and explainers.
- S4 released the settled parity machinery as workspace v29. The installer now asserts exactly 17 matching Claude/Codex skill packages plus complete Codex metadata, inventories and writes each tool independently, and ships the active flex project-agent files while preserving adopter-owned `executors.toml` on update.
- S4 lifecycle coverage proves fresh and retrofit parity, non-destructive operator-content handling, and a pre-parity update that restores the missing Codex `do-whole-phase` body + metadata without marking the package stale. Update output and both update skills now require `sync-agents` after refresh because generated agents reset while the seed-once config survives.
- Doc impact — operations: consolidate v29 installation/update truth: 17 skills per harness with Codex metadata, automatic-only Codex execution and `ready` compatibility, economy/flex matrices with this seed on flex, non-destructive retrofit, update restoration/stale behavior, preserved `executors.toml`, and the mandatory post-update `sync-agents` step.
- Doc impact — decisions: record v29's release invariant that Claude/Codex skill inventories are matching and complete, installation inventories are independent, Codex whole-phase is managed update machinery, and adopter executor configuration remains seed-once while generated agents are refreshed then re-synchronized.
- S5's final live-tree audit removed obsolete Codex fallback mechanics from the Claude-only execution bodies and made the engine/retrofit/explain directions cross-tool explicit; Claude `gate` / `plan only` behavior and both P14-owned `design-cowork` bodies stayed unchanged.
- S5 made the compact retrofit smoke durable for Codex rejection ordering and forbidden Claude mechanics, all 17 invocation policies, `ready` compatibility, economy/flex synchronization, detectable post-update drift plus resync, complete fixed-payload parity, and unique descending v29 changelog/marker invariants.
- Final audit classification: remaining plan-mode/harness/Agent/background matches are Claude-specific; `/explain` in Codex review output is the required fixed pointer; GPT-5.5/old-mode matches are historical changelog/versioned-doc records awaiting REVIEW consolidation; DesignSync/Claude Design matches are confined to P14-owned visual surfaces or explicit Claude branches.
- Doc impact completeness — operations and decisions: the existing P13 notes cover every durable truth changed by S1–S5 (including the final audit/test closure); P13.REVIEW should consolidate those two docs only, with no additional doc area required.
- P13.REVIEW passed after the complete combined validation: the final v29 live tree meets the confirmed non-visual parity objective, all prerequisite slice briefs, and the P14 visual boundary.
- Review consolidation created operations v0024 and decisions v0032; the former records current automatic-only Codex workflow and v29 lifecycle truth, while the latter records the accepted decision and explicit supersessions of the old GPT-5.5, Claude-only whole-phase, identical-preset, and fixed-attribution claims.

## Constraints

- Every middle slice is `risk: high` because it writes real code or spans multiple machinery files.
- Middle-slice folders are created bare; each owns only `slice.json` until its turn.
- Claude Code's existing modes and visual-design integration remain unchanged in this phase.

## Open Questions

-
