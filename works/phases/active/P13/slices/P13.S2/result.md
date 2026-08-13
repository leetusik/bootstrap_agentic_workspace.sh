# P13.S2 Result

Restored `do-whole-phase` as a first-class Codex skill with its own automatic-only orchestration contract and explicit-invocation metadata. The skill accepts bare, `auto`, and unattended/automatic invocations, rejects `gate` and `plan only` before mutation, and contains no Claude plan-mode or plan-file-copy machinery.

The Codex loop stays within the phase selected at entry, stops on pending/operator and executor safety halts, plans `todo` slices inline, directly dispatches existing `ready` plans unless visible drift requires re-planning, and executes slices sequentially through the P13.S1 custom tiers. It preserves one `mid → high` escalation, trusts completed executor results, validates only workflow integrity at the slice boundary, commits each non-review slice through the orchestrator, handles whole-phase review/fix cycles, and leaves visual `co-work` slices at the `design-cowork` routing boundary.

Updated the retrofit smoke suite so fresh installs require both Codex skill files and the live-versus-embedded parity loop covers both. Rebuilt `bootstrap_agentic_workspace.sh`; the workspace version and changelog remain unchanged as assigned to P13.S4.

## Validation

- Targeted Codex skill assertions — passed: rejects `gate` / `plan only` before mutation, contains none of `EnterPlanMode`, `ExitPlanMode`, harness-plan paths/copy mechanics, preserves direct dispatch for `ready`, and marks the metadata explicit-only.
- `python3 installer/build.py --check` — passed.
- `bash tests/retrofit_smoke.sh` — passed all eight groups, including fresh-install presence and both new live-versus-embedded parity checks.
- `python3 scripts/workflow.py validate` — passed after recording slice context.
- `git diff --check` — passed after recording slice context.

## Doc impact

- Operations: Codex now ships an explicit-only, automatic-only `do-whole-phase` skill with sequential custom-tier dispatch, safety halts, `ready` compatibility, escalation, and review/fix looping.
- Decisions: Codex whole-phase execution is restored independently from Claude's multi-mode skill; bare/automatic invocations run automatically while `gate` and `plan only` are rejected without mutation.

No durable docs were versioned. No deviation from `plan.md` was required.
