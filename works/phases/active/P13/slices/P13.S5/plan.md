# P13.S5 — Audit and regression closure

Perform the final independent non-visual parity audit against the complete v29 tree, close any remaining live gaps, and leave concise committed regression coverage that proves the intended Codex behavior rather than relying only on one-off slice assertions. P14 exclusively owns visual `design-cowork`; do not edit either visual skill body.

## Audit

1. Search all current live machinery and user-facing sources—not historical docs/versions or archived work—including:
   - `.agents/skills/**`, `.claude/skills/**`, `.codex/**`, `.claude/agents/**`;
   - `AGENTS.md`, `CLAUDE.md`, both READMEs, `docs/retrofit-guide.md`;
   - `installer/{build.py,main.py,README.md,payloads/**}`, current tests/hooks/CI, `executors.toml`, and `scripts/workflow.py`.
2. Find and resolve remaining non-visual assumptions or contradictions around:
   - Codex skill presence and invocation (`$skill` / tool-neutral wording vs Claude-only slash commands);
   - Codex `do-next-slice` / `do-whole-phase` automatic-only entry, pre-mutation rejection of `gate` / `plan only` / unknown modes, and legacy `ready` execution;
   - plan mode, harness plan copying, Agent-tool/background flags, `DesignSync`, or Claude settings mistakenly described as Codex mechanics;
   - project custom-agent files, economy/flex model matrices, active flex selection, risk routing, one-step escalation, and post-update `sync-agents`;
   - hard-coded model attribution or stale GPT-5.5/current-model claims;
   - installer inventory, managed/update/stale behavior, release version, and live-versus-embedded parity.
3. Classify every remaining search match explicitly in `result.md`: fix a current contradiction, or document why it is intentional (Claude-specific branch, fixed cross-tool review pointer, historical changelog/versioned doc, or P14-owned visual surface). Do not patch historical doc versions or generated `docs/current`; REVIEW will consolidate the phase's doc-impact notes.

## Persistent regression coverage

Extend the existing compact `tests/retrofit_smoke.sh` only where coverage is still missing. At minimum, leave durable assertions that prove:

- both execution skills exist for Codex with explicit-only metadata;
- their bodies reject `gate`, `plan only`, and unknown modes before the first mutating workflow/state/repository step, contain no Claude plan-mode/harness-copy/Agent-tool mechanics, and preserve the `ready` direct-dispatch path;
- all 17 Codex skill packages carry metadata and the non-visual workflow command skills remain explicit-only;
- active flex and isolated no-mode economy executor synchronization resolve the final matrices;
- pre-parity update restores Codex whole-phase without stale flags while preserving `executors.toml` and requiring resync;
- all live payload machinery matches the generated artifact and v29 version/changelog/marker invariants.

Reuse current helpers/scratch workspaces and avoid fixture or test-file sprawl. If all points already have persistent coverage, strengthen only the missing semantic assertions instead of duplicating checks.

## Handoff

1. Apply any narrowly required live fixes discovered by the audit, mirroring contracts where required.
2. Rebuild `bootstrap_agentic_workspace.sh` after any embedded machinery change. v29 is already the phase release; do not bump the version again unless a genuinely separate adopter-facing release is unavoidable (prefer keeping one release).
3. Write `result.md`; append final audit findings and doc-impact completeness notes to `phase.md`. Do not version durable docs.

## Validation

- `bash -n tests/retrofit_smoke.sh`
- `python3 -m py_compile scripts/workflow.py installer/build.py installer/main.py`
- `python3 scripts/workflow.py sync-agents --check`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh`
- `python3 scripts/workflow.py validate`
- targeted final searches and intentional-match classification
- assert `AGENTS.md` / `CLAUDE.md` bodies remain equivalent and P14-owned visual skill bodies have no diff
- `git diff --check`

Do not commit or transition workflow state. Preserve all prior/operator/orchestrator changes.
