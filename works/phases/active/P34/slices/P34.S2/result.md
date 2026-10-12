# Result -- P34.S2 (Ship the hooks: settings, installer hooks merge, smoke)

- status: done
- tier: mid
- model: sonnet
- effort: high
- summary: `.claude/settings.json` now carries the PreCompact(auto)->compact-gate and SessionStart(compact)->compact-resume hooks; the installer gained one pure `_merge_settings_dict` (permissions union + additive hooks merge by `command`) used by the root merge (malformed -> sidecar) and the nested `settings.local.json` present-file path (malformed -> refuse); 9 new smoke asserts.
- files_changed: .claude/settings.json, installer/main.py, tests/retrofit_smoke.sh, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P34/phase.md, this file
- validation (all pass): `python3 scripts/workflow.py validate`; `python3 installer/build.py --check`; `bash tests/retrofit_smoke.sh` (alone) -> ALL RETROFIT SMOKE TESTS PASSED, 289 PASS (280 + 9); checkout settings print the pinned compact-gate command; a fresh `--at-root` install yields settings.json with `PreCompact` and `SessionStart`.
- deviations: none
- doc_impact: none (S3 owns the lines; installer facts left as a tagged note in phase.md)

## What changed

- `installer/main.py`: `import copy`; new `_merge_settings_dict(theirs, ours)` (pure, deep-copies; ValueError on `permissions` not an object, `allow`/`deny` not a list, `hooks` not an object, event not a list of objects, group `hooks` not a list of objects). Hooks rule: per event and our group, append our handler to the target group with equal `matcher` (create event/group if absent) unless that `command` exists anywhere under the event. `_merge_settings_json` calls it inside the same try that sidecars (`.claude/settings.workspace.json`) on a non-dict/unparseable/malformed file (side effect: a non-object `permissions` used to crash with AttributeError, now sidecars). The nested present-file path replaced its inline permissions union with the helper; `_nested_refuse` on ValueError, `merged == theirs` keeps the no-write behaviour.
- Nested post-check (no unprefixed `python3 scripts/workflow.py`) passed: the `NESTED_ENGINE_RE` rewrite catches the space-preceded form, as the plan predicted.

## New smoke asserts (+9, 289 total)

1. Test 1 retrofit onto a settings.json seeded with foreign PreCompact(auto) and PostToolUse handlers: foreign first and unchanged, ours once, env survives.
2. Malformed `hooks` (a string) on retrofit -> settings.json byte-identical, `settings.workspace.json` written (new fixture `HM` after Test 4).
3. Test 5 fresh at-root install carries both hooks with exact commands and timeout 15.
4. `--update` on an up-to-date workspace leaves settings.json byte-identical.
5. `--update` onto a pre-v55 file (hooks replaced by a foreign PreCompact) adds ours, foreign first.
6. A second `--update` after that is byte-identical (the probe's foreign handler is then dropped by copying the repo settings back, so the Test 6 dual-apply diff is unaffected).
7. Test 15 nested: `settings.local.json` carries both hooks with `python3 workflow/scripts/workflow.py ...` commands, exactly one of each after `--update --nested`.
8. Nested second `--update --nested` is byte-identical.
9. Nested present file with a foreign hook and an extra `Stop` event, plus a deleted SessionStart handler: foreign kept, removed one re-added, no duplicates.

## Notes

- An earlier phase.md edit of mine mis-anchored on `## Now` inside the Objective text and was reverted with `git checkout` then redone; the generated slices table was re-synced with `workflow.py rebuild`.
- Not done by design: hooks are not live in this running session (relaunch needed); no commit.
