# P13.F1 — Adjust Codex executor presets and enable flex

Apply the operator's corrected two-preset matrix and select `flex` in this repo:

| Preset | `slice-executor-mid` | `slice-executor-high` |
|---|---|---|
| `economy` (engine default when no mode is selected) | `gpt-5.6-luna` @ `high` | `gpt-5.6-terra` @ `high` |
| `flex` | `gpt-5.6-terra` @ `high` | `gpt-5.6-sol` @ `high` |

## Changes

1. Update `scripts/workflow.py` so both Claude and Codex values are genuinely preset-specific: keep Claude's current economy/flex matrix unchanged, and apply the Codex matrix above.
2. Update the tracked `executors.toml` explanatory table and commented per-tier values to show both Codex presets accurately, then set active top-level `mode = "flex"` for this directory as explicitly requested.
3. Run `python3 scripts/workflow.py sync-agents`. The live Codex agent TOMLs must remain `gpt-5.6-terra @ high` for mid and `gpt-5.6-sol @ high` for high because this directory selects flex. Claude agent TOMLs should move to the existing flex efforts (`sonnet @ xhigh`, `opus @ xhigh`).
4. Update `.codex/config.toml`, current README executor summaries, and the existing concise smoke assertions so they distinguish economy from flex and match the active live files. Do not broaden into S3's contract/skill audit or S5's full regression closure.
5. Rebuild `bootstrap_agentic_workspace.sh`. Keep `WORKSPACE_VERSION` / `CHANGELOG.md` for S4.
6. Correct/append the S1 executor notes in `phase.md` so durable history records the final two-mode matrix and this repo's active flex selection. Write `result.md`; append updated operations/decisions doc-impact notes. Do not version docs.

## Validation

- `python3 scripts/workflow.py sync-agents --check`
- verify active live files are Claude `sonnet/opus @ xhigh` and Codex `terra/sol @ high`
- probe `executors.toml` without active `mode` in a temporary fresh install or equivalent isolated copy to confirm economy resolves to Codex `luna/terra @ high`; preserve the tracked workspace file
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh`
- `python3 scripts/workflow.py validate`
- `git diff --check`

Do not commit or transition workflow state. Preserve P13.S2's new Codex `do-whole-phase` files and all prior work.
