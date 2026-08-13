# P13.S1 Result

Landed the operator-selected Codex executor defaults:

- `slice-executor-mid`: `gpt-5.6-terra` at `high`
- `slice-executor-high`: `gpt-5.6-sol` at `high`

The workspace's two-tier routing and escalation policy is unchanged: an exact `risk: low` selects mid, every other slice selects high, and mid may escalate once to high. Codex defaults remain identical in `economy` and `flex`; those presets continue to vary Claude only.

Updated `scripts/workflow.py`, the seeded `executors.toml`, both project-scoped Codex executor TOMLs through `sync-agents`, and `.codex/config.toml` (including the current `agents.max_concurrent_threads_per_session` setting name). Removed live hard-coded GPT-5.5 attribution examples from both contracts and both shipped explain skills, refreshed README executor references, aligned the existing fresh-install smoke assertion, and rebuilt the generated installer artifact.

The official Codex custom-agent contract informed the shape: standalone project TOMLs with required identity/instructions and supported per-agent `model`, `model_reasoning_effort`, and `sandbox_mode` overrides. The operator's explicit model choice superseded the initial generic `gpt-5.6`/`xhigh` draft in the plan; the persisted plan was corrected before implementation.

## Validation

- `python3 scripts/workflow.py sync-agents --check` — passed; reports `gpt-5.6-terra @ high` / `gpt-5.6-sol @ high` and all four agent files in sync.
- Targeted `rg` over current live Codex, contract, README, config, executor, and mirrored skill surfaces — passed; no live hard-coded `gpt-5.5` / `GPT-5.5` remains in those surfaces.
- `python3 installer/build.py --check` — passed.
- `python3 scripts/workflow.py validate` — passed.
- `bash tests/retrofit_smoke.sh` — passed, including fresh install, update/reset, sync-agents, live-versus-embedded parity, and installer drift checks.
- `git diff --check` — run at handoff.

## Doc impact

- Operations: Codex executor defaults, preset behavior, custom-agent schema baseline, and current concurrency setting name.
- Decisions: the selected Codex 5.6 tier pair and actual-executing-model attribution supersede the old GPT-5.5/xhigh defaults and fixed example.

No durable docs were versioned; P13.REVIEW owns consolidated doc versions. No visual-design machinery was touched.
