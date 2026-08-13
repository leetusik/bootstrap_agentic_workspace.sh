# P13.S1 — Determine and land Codex executor tiers

Execute this slice inline under the operator-authorized exception. Use the current official Codex subagent documentation as the decision baseline, then land the two existing workspace tiers on current Codex models without changing Claude's presets or the established `risk` routing.

## Decision

- `slice-executor-mid`: `gpt-5.6-terra` at `high`. This is the faster, lower-cost tier for the workspace's tightly bounded one-line/few-line edits and docs; it retains the existing hair-trigger `mid → high` escalation.
- `slice-executor-high`: `gpt-5.6-sol` at `high`. This is the demanding agentic-coding tier for decomposition, review, essentially all code writing, every cross-file change, and escalation recovery.
- Keep Codex values identical across the workspace's `economy` and `flex` presets; those modes continue to vary Claude only.
- Preserve explicit per-agent `model`, `model_reasoning_effort`, and `sandbox_mode = "workspace-write"` in the project-scoped TOMLs. Preserve the current two-tier routing and one-step escalation semantics.
- Attribution is based on the model that actually performed the work, not on a hard-coded Codex default. Remove the stale GPT-5.5 examples from live policy surfaces.

## Changes

1. Update `scripts/workflow.py` executor presets and `executors.toml`'s seeded commented defaults.
2. Run `python3 scripts/workflow.py sync-agents` so both Codex executor TOMLs receive the selected model/effort values while Claude agent files remain on their current defaults.
3. Update `.codex/config.toml` to describe the new tier defaults and use the official current `agents.max_concurrent_threads_per_session` setting name rather than the legacy alias.
4. Make attribution wording model-neutral in `AGENTS.md`, `CLAUDE.md`, and both shipped `explain` skill copies; update current user-facing executor references in `README.en.md`.
5. Rebuild `bootstrap_agentic_workspace.sh` from live sources.
6. Append the decision and a one-line operations/decisions doc impact note to `phase.md`; write `result.md`.

## Validation

- `python3 scripts/workflow.py sync-agents --check`
- targeted assertions that the two Codex TOMLs, workflow presets, seeded config, Codex config, contracts, and explainer copies contain no live hard-coded GPT-5.5 default/example
- `python3 installer/build.py --check`
- `python3 scripts/workflow.py validate`
- `git diff --check`

Do not change workspace versioning or changelog in this slice; P13.S4 owns the phase's installation/update release boundary. Do not touch visual-design machinery; P14 owns it.
