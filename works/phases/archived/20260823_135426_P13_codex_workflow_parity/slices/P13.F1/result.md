# P13.F1 Result

Corrected the two executor presets and selected `mode = "flex"` for this repository.

- `economy` remains the engine fallback when no mode is selected: Claude mid/high resolve to `sonnet@high` / `opus@high`, while Codex resolves to `gpt-5.6-luna@high` / `gpt-5.6-terra@high`.
- `flex` resolves Claude to `sonnet@xhigh` / `opus@xhigh` and Codex to `gpt-5.6-terra@high` / `gpt-5.6-sol@high`.
- The tracked `executors.toml` now actively selects `flex`; `sync-agents` updated the two live Claude agent files to `xhigh`, while the live Codex agent files correctly remained Terra/Sol at `high`.

Updated the engine preset source, tracked executor configuration, project Codex summary, both current README executor summaries, and the existing concise retrofit smoke assertions. The smoke suite now checks the installed active `flex` matrix and then removes the active mode in its isolated fresh workspace to prove the complete default `economy` matrix. Rebuilt the generated `bootstrap_agentic_workspace.sh` without changing `WORKSPACE_VERSION` or `CHANGELOG.md`, which remain assigned to P13.S4.

## Validation

- `python3 scripts/workflow.py sync-agents --check` — passed; active live files report Claude `sonnet@xhigh` / `opus@xhigh` and Codex `gpt-5.6-terra@high` / `gpt-5.6-sol@high` under `mode flex`.
- Fresh-install no-mode probe, implemented in `tests/retrofit_smoke.sh` — passed; after replacing the isolated installed `executors.toml` with a no-mode file and applying `sync-agents`, Claude resolved to `sonnet/opus @ high` and Codex to `gpt-5.6-luna/gpt-5.6-terra @ high`.
- `python3 installer/build.py --check` — passed; generated installer matches source.
- `bash tests/retrofit_smoke.sh` — passed all eight groups, including active `flex`, no-mode `economy`, update/reset, and live-versus-embedded parity assertions.
- `python3 scripts/workflow.py validate` — passed.
- `git diff --check` — passed.

## Doc impact

- Operations: document both Claude/Codex executor preset matrices, the no-mode `economy` fallback, this repo's active `flex` selection, the official project-agent schema baseline, and the current Codex concurrency setting name.
- Decisions: supersede S1's identical-Codex-preset statement with the operator-corrected `economy` Luna/Terra and `flex` Terra/Sol matrices; retain actual-executing-model attribution.

No durable docs were versioned. No deviation from `plan.md` was required. P13.S2's Codex `do-whole-phase` files and all workflow state changes were preserved.
