# P13.S4 — Ship Codex parity through installation and updates

Turn the settled P13 machinery into one coherent workspace release. Ensure fresh installs, non-destructive retrofits, and in-place updates all carry the restored Codex execution skills, independent auto-only bodies/metadata, final executor preset matrix, and current project-agent configuration without disturbing adopting repos' work or operator-owned tier overrides.

## Release and installer work

1. Audit `installer/build.py` payload discovery and `installer/main.py` inventories/write policies end to end:
   - both Claude and Codex should expose the complete 17-skill inventory, with Codex `do-next-slice` / `do-whole-phase` intentionally independent bodies;
   - every Codex skill must ship both `SKILL.md` and `agents/openai.yaml` in fresh, retrofit, and update flows;
   - `do-whole-phase` must no longer be described or treated as Claude-only by inventory, managed-path, stale-skill, write-loop, or user-facing installer text;
   - update must add/refresh the Codex whole-phase skill and must not flag it stale; retrofit remains non-destructive on pre-existing operator content;
   - executor TOMLs/config and active tracked `executors.toml` flex selection must ship consistently, while update preserves an adopter's existing seed-once `executors.toml` and instructs them to re-run `sync-agents` after machinery refresh.
2. Update installer/user-facing documentation needed for those installation/update semantics, including `docs/retrofit-guide.md` and any remaining current README/installer text not settled in S3. Keep language accurate for Claude multi-mode versus Codex automatic-only execution, `ready` compatibility, both preset matrices, and this upstream repo's tracked flex selection.
3. Add focused smoke coverage for installation lifecycle gaps this slice owns:
   - fresh and retrofit presence/parity for the restored Codex whole-phase skill and metadata;
   - an update probe representing a pre-parity workspace where the Codex whole-phase files are missing, proving update restores them and does not mark the skill stale;
   - version-marker and installer version consistency for the new release.
   Keep the suite concise and reuse its existing scratch workspaces.
4. Release as workspace **v29**:
   - bump `WORKSPACE_VERSION` in `installer/main.py` from 28 to 29;
   - add newest-first `## v29 — 2026-08-13` to `CHANGELOG.md` covering Codex automatic-only execution skills, project custom-agent tiers/presets, actual-model attribution, install/update behavior, and concise migration notes;
   - migration notes must state that updates preserve existing `executors.toml`, reset agent files to upstream machinery, and therefore require `python3 scripts/workflow.py sync-agents`; Codex `gate`/`plan only` are now rejected, existing `ready` slices still execute, and any hand-maintained path colliding with the newly managed Codex whole-phase skill should be reviewed via `--update --dry-run` first.
5. Rebuild `bootstrap_agentic_workspace.sh` after all machinery/release edits.
6. Write `result.md`; append concise findings and operations/decisions doc-impact lines to `phase.md`. Do not create durable doc versions.

## Validation

- manifest/inventory assertions for all 17 Claude + 17 Codex skill packages and complete Codex metadata
- fresh/retrofit/update lifecycle assertions above, including no stale flag for Codex `do-whole-phase`
- `python3 scripts/workflow.py sync-agents --check`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh`
- `python3 scripts/workflow.py validate`
- verify `WORKSPACE_VERSION == 29`, top changelog heading is v29, and a fresh marker records 29
- `git diff --check`

Do not touch P14-owned visual skill bodies. Do not commit or transition workflow state. Preserve all prior slice work and unrelated user changes.
