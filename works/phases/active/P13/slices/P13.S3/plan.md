# P13.S3 — Align Codex workflow contracts and command skills

Make the Codex non-visual workflow surface internally consistent with S1/F1's executor tiers and S2's automatic-only whole-phase loop. Keep Claude Code's existing modes and behaviors unchanged. P14 exclusively owns the visual `design-cowork` replacement; do not edit either `design-cowork` skill in this slice.

## 1. Make Codex `do-next-slice` automatic-only

Rewrite `.agents/skills/do-next-slice/SKILL.md` as an independent Codex body rather than a mirror of Claude's multi-mode skill.

- Accept a bare invocation, explicit `auto`, or unattended/automatic wording as automatic execution.
- Reject `gate` and `plan only` clearly before any workflow/state/repo mutation; never silently coerce them.
- Remove `EnterPlanMode`, `ExitPlanMode`, harness-plan-file copying, Claude Agent-tool/background syntax, and any claim that Codex presents a readied approval gate inline.
- Preserve execution of an already-`ready` slice: start it and dispatch directly from its approved `plan.md`, re-planning only on visible drift.
- Preserve all established selection, pending, parallel-stream, tier routing, one-step `mid → high` escalation, review verdict, doc consolidation, validation, state transition, commit, and one-slice-stop rules.
- Keep `.agents/skills/do-next-slice/agents/openai.yaml` explicit-only and accurate.
- Do not alter `.claude/skills/do-next-slice/SKILL.md` beyond an independently justified Claude-only correction; Claude retains `auto`, `gate`, and `plan only`.

## 2. Audit every other non-visual Codex command skill

Audit `.agents/skills/*/SKILL.md` and `agents/openai.yaml`, excluding `design-cowork`, against its `.claude` counterpart and actual Codex capabilities. Use targeted edits, not blind mirroring.

Close live assumptions such as:

- Claude slash-command-only invocation syntax where Codex should say `$skill`, the skill name, or tool-neutral wording;
- Claude-only plan mode, harness plan files, tool names, background flags, subagent API language, settings paths, or permission assumptions;
- stale claims that `do-whole-phase` is absent/Claude-only;
- stale executor models/efforts, routing, escalation, or hard-coded commit-attribution examples;
- metadata that is missing, inconsistent, or permits implicit invocation for workflow command skills.

Do not change product visual-design policy or invent a Codex design workflow; leave a precise P14 boundary wherever necessary. Preserve legitimate tool-specific differences (for example Claude permission settings or tool names inside the Claude copy). Keep command skills explicit-invocation only.

## 3. Update the equivalent contracts

Update `AGENTS.md` and `CLAUDE.md` with byte-equivalent bodies so they state the actual cross-tool contract:

- both tools ship `do-next-slice` and `do-whole-phase`;
- Codex runs both in automatic-only mode and rejects `gate` / `plan only` without mutation;
- Claude retains automatic default plus opt-in `gate` / `plan only`;
- Codex plans inline, writes `plan.md`, and sequentially spawns project custom agents; existing `ready` slices remain executable for compatibility;
- the final two preset matrices and this repo's active flex selection are described accurately where the contract names tier defaults;
- commits and explainers attribute the actual executing model, never a hard-coded default.

Do not weaken the orchestrator/executor split, phase/slice state ownership, safety halts, or visual-design boundary.

## 4. Verification and handoff

- Update existing concise smoke/parity assertions only as required by changed live machinery; leave broad regression closure to S5.
- Rebuild `bootstrap_agentic_workspace.sh` after all machinery edits. Do not bump `WORKSPACE_VERSION` or edit `CHANGELOG.md`; S4 owns the release boundary.
- Write `result.md` and append concise audit findings plus operations/decisions doc-impact lines to `phase.md`. Do not create doc versions.

## Validation

- targeted searches across current live `.agents/skills`, contracts, `.codex`, README/installer-facing text for non-visual `Claude Code only`, missing `do-whole-phase`, `EnterPlanMode`/`ExitPlanMode`, harness-plan copy, stale GPT-5.5/tier claims, and hard-coded attribution examples; explain every intentional remaining match
- assert Codex `do-next-slice` rejects `gate` / `plan only` before mutation and contains no plan-mode/copy mechanics while preserving `ready` direct dispatch
- assert every `.agents/skills/*/agents/openai.yaml` exists and all workflow command skills are explicit-only (excluding any deliberately model-invocable non-command guide)
- `python3 scripts/workflow.py sync-agents --check`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh`
- `python3 scripts/workflow.py validate`
- `git diff --check`

Do not commit or transition workflow state. Preserve all completed slice work and unrelated user changes.
