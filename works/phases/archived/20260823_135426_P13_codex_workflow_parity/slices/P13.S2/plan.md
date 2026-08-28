# P13.S2 — Restore Codex do-whole-phase

Restore `do-whole-phase` as a first-class Codex skill while leaving the Claude skill's existing `auto`, `gate`, and `plan only` behavior unchanged. Codex gets one execution mode only: automatic sequential execution through the two executor tiers established by P13.S1.

## Implementation

1. Add `.agents/skills/do-whole-phase/SKILL.md` and `.agents/skills/do-whole-phase/agents/openai.yaml`.
   - The Codex skill must be an independent auto-only body, not a byte mirror of the Claude skill.
   - At entry, accept a bare invocation, explicit `auto`, or an unattended/automatic wording as the same automatic mode.
   - If the invocation requests `gate` or `plan only`, fail clearly, make no workflow/state/repo mutation, and stop. Do not silently coerce either mode to `auto`.
   - Do not mention or attempt `EnterPlanMode`, `ExitPlanMode`, a harness plan file, or approval-gate mechanics in the Codex body.
   - Keep the skill explicit-invocation only through `agents/openai.yaml` (`allow_implicit_invocation: false`).
2. Implement the full current-phase loop for Codex:
   - read the contract, current docs/state, phase notebook, and confirmed intent;
   - stop on `pending` / `WAITING ON OPERATOR` and never cross into another phase;
   - for a `todo` slice, start it, plan inline, write its own complete free-form `plan.md`, select the executor by `kind` + `risk`, and spawn the matching project-scoped custom agent sequentially;
   - for an existing `ready` slice, preserve upgrade/cross-tool compatibility: start it and dispatch directly from its existing approved `plan.md`, re-planning only on visible workspace drift;
   - route decomposition and review to `slice-executor-high`; exact `risk: low` implementation/fix to `slice-executor-mid`; everything else to high; preserve one-step `mid → high` escalation and every safety halt;
   - trust `done`, run only workflow `validate`, finish and commit each non-review slice, re-read state, and continue through review; record review with `review-phase` and stop after P13's current phase is complete;
   - keep optional read-only next-slice preparation genuinely optional and sequential (never a second executor).
3. Keep visual `co-work` mechanics out of this non-visual slice. Carry only a short routing boundary to the applicable design-cowork workflow; P14 owns its Codex replacement.
4. Update the existing minimal smoke assertions so a fresh install must contain both Codex skill files and the live-versus-embedded parity loop covers both. Do not add broader regression coverage here; P13.S5 owns closure.
5. Rebuild `bootstrap_agentic_workspace.sh`. Do not bump `WORKSPACE_VERSION` or edit `CHANGELOG.md`; P13.S4 owns the phase release boundary.
6. Write `result.md` and append concise cross-slice notes plus operations/decisions doc-impact lines to `phase.md`. Do not create durable doc versions.

## Validation

- Assert the Codex body rejects `gate` and `plan only`, contains no plan-mode tool names or harness-copy mechanics, and preserves the `ready` direct-dispatch path.
- Assert `agents/openai.yaml` is present and explicit-only.
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh`
- `python3 scripts/workflow.py validate`
- `git diff --check`

The executor must not commit or transition slice/phase status. The orchestrator owns `start-slice`, `finish-slice`, validation, and the slice-boundary commit.
