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

## Constraints

- Every middle slice is `risk: high` because it writes real code or spans multiple machinery files.
- Middle-slice folders are created bare; each owns only `slice.json` until its turn.
- Claude Code's existing modes and visual-design integration remain unchanged in this phase.

## Open Questions

-
