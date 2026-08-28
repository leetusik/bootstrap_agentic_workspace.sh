# P13.S5 Result

Completed the final independent non-visual audit of the v29 live tree and closed the remaining current contradictions.

The Claude-specific `do-next-slice` body still described Codex as participating in Claude's `gate`, `plan only`, harness-plan copy, background Agent, executor, review, and DesignSync fallback paths; `do-whole-phase` carried the same obsolete Codex DesignSync fallback. Those cross-tool branches were removed while preserving Claude's actual auto/gate/plan-only behavior. The parallel-worktree engine hint, two retrofit-guide directions, and the README explain call-to-action now name both Claude slash commands and Codex `$skill` invocations. Both P14-owned `design-cowork` skill bodies are unchanged.

Extended only `tests/retrofit_smoke.sh`. Its persistent checks now prove:

- exactly 17 matching skill packages, metadata on all Codex packages, explicit-only policy on every non-visual command skill, and the deliberate implicit visual-guide exception;
- both Codex execution skills reject `gate`, `plan only`, and unknown modes before the first workflow command, exclude Claude plan-mode/harness-copy/Agent/background/DesignSync mechanics, and retain the direct `ready` dispatch path;
- active `flex` and isolated no-mode `economy` matrices;
- pre-parity update restoration without a stale flag, preservation of `executors.toml`, detectable generated-agent drift, and successful resynchronization;
- unique descending changelog versions with v29 aligned across source and fresh marker;
- every fixed live payload source, including settings, Codex config, templates, skills, metadata, agents, policies, contracts, and workflow engine, matches the installed artifact.

## Audit match classification

- **Fixed current contradictions:** stale `In Codex` fallback mechanics in `.claude/skills/do-next-slice/SKILL.md` and `.claude/skills/do-whole-phase/SKILL.md`; slash-only cross-tool directions in `scripts/workflow.py`, `docs/retrofit-guide.md`, and the README explain prompt.
- **Intentional Claude-specific branches:** `EnterPlanMode`, `ExitPlanMode`, harness-plan copying, Agent-tool/background dispatch, `DesignSync`, and `.claude/settings.json` remain in Claude-only skill/contract/installer contexts where they describe real Claude behavior. Installer/update Codex skills legitimately mention `.claude/*` because the cross-tool updater manages both harnesses.
- **Fixed cross-tool review pointer:** Codex execution/review bodies and the shared contract retain exactly `explain: not written — run /explain for this phase`; this is required structured review output, not invocation guidance.
- **Historical changelog/versioned docs:** older GPT-5.5, Claude-only whole-phase, plan-mode, and preset claims remain in `CHANGELOG.md`, immutable `docs/versions/*`, and their `docs/index.json` history. The generated `docs/current/operations.md` / `decisions.md` still reflect their pre-P13 versions until P13.REVIEW creates the consolidated operations and decisions versions; they were not patched directly.
- **P14-owned visual surface:** Claude Design / DesignSync / `/create-phase` matches in both `design-cowork` packages and metadata are intentionally untouched for P14. The final diff guard confirms neither visual skill body changed.
- **No stale live model claim:** targeted searches outside historical/generated doc state found no hard-coded GPT-5.5 or “current model” attribution claim.

## Validation

- `bash -n tests/retrofit_smoke.sh` — passed.
- `python3 -m py_compile scripts/workflow.py installer/build.py installer/main.py` — passed.
- `python3 scripts/workflow.py sync-agents --check` — passed under active `flex`: Claude Sonnet/Opus at `xhigh`, Codex GPT-5.6 Terra/Sol at `high`.
- `python3 installer/build.py --check` — passed after rebuilding `bootstrap_agentic_workspace.sh` from the edited embedded sources.
- `bash tests/retrofit_smoke.sh` — passed all lifecycle, semantic, update/resync, inventory, release, and live-versus-installed parity checks.
- `python3 scripts/workflow.py validate` — passed before result handoff.
- Targeted `rg` searches across all specified live sources — passed; remaining matches classified above.
- `cmp` of the `AGENTS.md` / `CLAUDE.md` contract bodies — passed.
- `git diff --quiet -- .agents/skills/design-cowork/SKILL.md .claude/skills/design-cowork/SKILL.md` — passed; no visual-skill diff.
- `git diff --check` — passed before result handoff.

## Doc impact

Operations and decisions already carry complete P13 running notes for the two-tool skill inventory, Codex automatic-only execution, Claude-only gated modes, custom executor matrices/routing/escalation, v29 installation/update behavior, and post-update resynchronization. The final completeness note in `phase.md` confirms P13.REVIEW should consolidate those two docs only. No doc versions were created.

No deviations from `plan.md`. No workflow state transition or commit was performed.
