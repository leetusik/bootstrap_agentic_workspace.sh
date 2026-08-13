# P13.S4 Result

Released the settled Codex workflow parity as workspace v29 across fresh install, non-destructive retrofit, and in-place update.

The installer build now enforces a release manifest of exactly 17 matching Claude/Codex skill packages and requires `agents/openai.yaml` for every Codex package. Runtime managed-path and write loops inventory the two harnesses independently, so all Codex skill bodies and metadata—including the restored independent automatic-only `do-whole-phase`—are created or refreshed in every lifecycle. The tracked flex executor selection and current project-agent files ship together; update continues to preserve an adopter's seed-once `executors.toml`, refreshes generated agent files, and now explicitly instructs the adopter to run `sync-agents` before continuing.

Updated both update-workspace skill bodies, the English and Korean READMEs, the retrofit guide, and installer maintainer documentation with the cross-tool inventory, Codex auto-only/`ready` compatibility, economy/flex matrices, active flex seed, collision/update semantics, and mandatory post-update synchronization. Added newest-first v29 release notes and bumped `WORKSPACE_VERSION` to 29. Rebuilt `bootstrap_agentic_workspace.sh` from source; no P14 visual skill body was edited.

Extended the existing concise lifecycle smoke rather than adding a new suite. It now checks the live manifest, all installed 17+17 packages and Codex metadata, retrofit parity/non-destructiveness, v29 source/changelog/fresh-marker consistency, every live skill against the embedded artifact, and a simulated pre-parity update with the Codex whole-phase directory missing. That update restores both files, preserves the edited executor config, resets generated agents, does not report the package stale, and prints the post-update `sync-agents` instruction.

## Validation

- `python3 -m py_compile installer/build.py installer/main.py` — passed.
- `bash -n tests/retrofit_smoke.sh` — passed.
- `python3 scripts/workflow.py sync-agents --check` — passed under active flex: Claude Sonnet/Opus at `xhigh`, Codex GPT-5.6 Terra/Sol at `high`.
- `python3 installer/build.py --check` — passed; the committed artifact matches installer source.
- `bash tests/retrofit_smoke.sh` — passed all lifecycle and parity checks, including 17+17 inventories, complete Codex metadata, fresh/retrofit presence, pre-parity update restoration/no-stale behavior, preserved executor config, v29 marker consistency, and full live-versus-embedded skill parity.
- `python3 scripts/workflow.py validate` — passed.
- `git diff --check` — passed.

## Doc impact

- Operations: consolidate v29 installation/update truth: 17 skills per harness with Codex metadata, automatic-only Codex execution and `ready` compatibility, economy/flex matrices with this seed on flex, non-destructive retrofit, update restoration/stale behavior, preserved `executors.toml`, and the mandatory post-update `sync-agents` step.
- Decisions: record v29's release invariant that Claude/Codex skill inventories are matching and complete, installation inventories are independent, Codex whole-phase is managed update machinery, and adopter executor configuration remains seed-once while generated agents are refreshed then re-synchronized.

No durable doc version was created. There were no deviations from `plan.md`.
