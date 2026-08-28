# P13.S3 Result

Aligned the non-visual Codex workflow surface with the executor presets from P13.S1/F1 and the automatic-only whole-phase loop from P13.S2.

Replaced `.agents/skills/do-next-slice/SKILL.md` with an independent Codex orchestration body. It accepts bare, explicit `auto`, and unattended/automatic wording; rejects `gate`, `plan only`, and unknown modes before any workflow/state/repository mutation; plans inline; writes the selected slice's complete `plan.md`; spawns the matching project custom agent sequentially; preserves one-step `mid → high` recovery and direct execution of existing `ready` plans; and stops after exactly one slice. Its metadata now identifies automatic mode and remains explicit-only.

Audited all 17 `.agents/skills/*/SKILL.md` and `agents/openai.yaml` files except the P14-owned visual body. Targeted Codex-only corrections removed Claude slash-command and `$ARGUMENTS` assumptions from create/defer/promote/doc/update/retrofit/parallel/review/explain surfaces, retained legitimate `.claude` installation/settings references, and confirmed every command skill has `allow_implicit_invocation: false`. `design-cowork` remains the deliberate model-invocable guide and neither visual skill copy was edited.

Updated the byte-equivalent `AGENTS.md` / `CLAUDE.md` contract bodies so both tools ship both execution skills, Claude retains default-auto plus opt-in `gate` / `plan only`, Codex is automatic-only and sequentially spawns its project agents, compatible `ready` slices still execute directly, the complete economy/flex matrices and the shipped/upstream flex selection are explicit, adopter overrides are acknowledged, and commits/explainers name the model that actually performed the work. Closed matching stale claims in both READMEs and installer-facing comments, then rebuilt `bootstrap_agentic_workspace.sh` without changing `WORKSPACE_VERSION` or `CHANGELOG.md`.

## Audit findings and intentional remaining matches

- No non-visual Codex skill contains `EnterPlanMode`, `ExitPlanMode`, harness plan-file paths/copy mechanics, Claude Agent-tool/background syntax, stale GPT-5.5 defaults, or a live claim that Codex lacks `do-whole-phase`.
- Claude plan-mode, harness-copy, Agent-tool/background, and settings wording remains in `.claude/skills/*` and in explicitly labeled Claude branches of the shared contract; Claude's behavior was intentionally preserved.
- The READMEs still label `gate` as Claude Code only because that is the new cross-tool contract, not a stale whole-phase limitation.
- The review pointer remains exactly `explain: not written — run /explain for this phase` in both tools because the executor/review contract requires that fixed string; Codex operator-facing prose separately names `$explain` / the skill name.
- Both `design-cowork` copies and their metadata remain untouched; their Claude Design / DesignSync assumptions belong exclusively to P14.
- Stale GPT-5.5 and old mode claims in generated `docs/current/operations.md` / historical decisions were not patched in place. The phase's operations/decisions doc-impact lines assign their consolidated replacement to P13.REVIEW.

## Validation

- Targeted Python assertions for Codex `do-next-slice` entry ordering, forbidden plan-mode/copy/tool syntax, `ready` dispatch, tier paths, escalation, and one-slice stop — passed.
- Codex skill inventory/metadata assertion — passed: 17 `SKILL.md` + `agents/openai.yaml` pairs; every non-visual command skill explicit-only; `design-cowork` the deliberate guide exception.
- Contract body parity/content assertions — passed: byte-equivalent bodies and required cross-tool mode, matrix, ready-path, and attribution statements present.
- Targeted `rg` audit across live `.agents/skills`, contracts, `.codex`, READMEs, and installer-facing sources — passed with only the intentional matches listed above.
- `python3 scripts/workflow.py sync-agents --check` — passed under active `flex`: Claude `sonnet/opus @ xhigh`, Codex `gpt-5.6-terra/gpt-5.6-sol @ high`.
- `python3 installer/build.py --check` — passed.
- `bash tests/retrofit_smoke.sh` — passed all eight groups, including fresh install, economy/flex probes, update behavior, live-versus-embedded parity, and installer drift.
- `python3 scripts/workflow.py validate` — passed.
- `git diff --check` — passed.

## Doc impact

- Operations: document the two-tool command-skill inventory, Codex automatic-only execution skills, Claude-only gated modes, sequential Codex project-agent dispatch, `ready` compatibility, explicit invocation metadata, and corrected preset/active-selection wording.
- Decisions: record independent Codex command-skill bodies and rejection-before-mutation for `gate` / `plan only`, while Claude retains its multi-mode workflow and actual-model attribution governs commits and explainers.

No durable docs were versioned. No deviation from `plan.md` was required.
