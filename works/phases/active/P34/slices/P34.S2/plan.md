# Plan — P34.S2 (Ship the hooks: settings, installer hooks merge, smoke)

## Context

S1 landed the two engine commands (`compact-gate`, `compact-resume`). This slice makes them run: the project `.claude/settings.json` gains the two Claude Code hooks, and the installer learns to carry a `hooks` key additively on every path that merges settings (today it unions only `permissions` and silently drops everything else in the payload). Both hooks ship **on for everyone** (the operator's confirmed intent). Read `works/phases/active/P34/phase.md` first: `## Decisions` (the hook command form, the additive merge rule), the two tagged notes for S2 under `## Notes for later slices` (the exact command lines, the env names, where the smoke asserts sit), and `## Now`. S3 writes the texts and doc notes; S4 releases v55. This slice touches `.claude/settings.json`, `installer/main.py`, `tests/retrofit_smoke.sh` and the rebuilt artifact only.

Risk `low`: the merge rule and the command form are pinned; the smoke test asserts them.

## What the orchestrator read (2026-10-12)

- `.claude/settings.json`: `permissions.allow` / `deny` only; no `hooks` key. Embedded verbatim by `installer/build.py` (`FIXED_LIVE_FILES`), rewritten for nested installs by `nested_rewrite` (`installer/main.py` ~l.517; `NESTED_ENGINE_RE` l.504 rewrites a space-preceded `scripts/workflow.py` → `workflow/scripts/workflow.py`, which is why the pinned command form is `cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-gate || true`). The nested post-check (~l.968–985) refuses the install if `python3 scripts/workflow.py` survives unprefixed in `settings_ours` — the pinned form passes because the rewrite catches it; verify in the nested smoke fixture.
- `_merge_settings_json(text)` ~l.301–321: parses the target; unparseable → sidecar `.claude/settings.workspace.json`; unions `permissions.allow/deny`; writes back; records `RETROFIT_SUMMARY["merged"]`. Callers: `_retrofit_handle` ~l.356 (retrofit, file exists) and `_update_handle` ~l.435 (`--update`, file exists; `DRY_RUN` skips the write). Fresh root install writes the payload verbatim (~l.1352). Nested: the host's `settings.json` is never touched; `settings.local.json` (~l.1021–1038) — absent → the whole rewritten payload (hooks included for free); present → an inline copy of the `permissions` union with its own refusal on a malformed file (`_nested_refuse`, nothing written) and `settings_text = existing if merged == theirs` (no rewrite when nothing changes).
- Claude Code: hooks shape `hooks → <Event> → [{matcher, hooks:[{type:"command", command, timeout}]}]`; hooks from user/project/local settings add up; the same handler defined twice runs once. `PreCompact` matchers `manual`|`auto`; `SessionStart` matchers `startup`|`resume`|`clear`|`compact`|`fork`.
- `tests/retrofit_smoke.sh` (280 PASS after S1): retrofit settings-merge assertion ~l.683 (seeds a `settings.json` with a custom perm and an `env` key) and ~l.719–727 (a Python heredoc asserting the union and that `env` survives) — extend this pattern; `--update` block ~l.1285 onwards runs on `$F`; nested host fixture ~l.1752–1777 seeds the host's own `.claude/settings.json` and asserts `settings.local.json` carries `python3 workflow/scripts/workflow.py`; S1's compaction asserts sit ~l.1196–1262 (Test 5) and ~l.1810–1823 (Test 14) — add yours after them. The suite runs alone in its Bash call.

## Do

1. **`.claude/settings.json`**: add, keeping `permissions` as is and the file's 2-space JSON style:
   ```json
   "hooks": {
     "PreCompact": [{"matcher": "auto", "hooks": [{"type": "command", "command": "cd \"$CLAUDE_PROJECT_DIR\" && python3 scripts/workflow.py compact-gate || true", "timeout": 15}]}],
     "SessionStart": [{"matcher": "compact", "hooks": [{"type": "command", "command": "cd \"$CLAUDE_PROJECT_DIR\" && python3 scripts/workflow.py compact-resume || true", "timeout": 15}]}]
   }
   ```
   (the exact command strings are in the S1 note; copy them verbatim).
2. **Installer, one shared merge helper**: factor the `permissions` union plus the new hooks merge into one function on parsed dicts (e.g. `_merge_settings_dict(theirs: dict, ours: dict) -> dict`, pure, raising `ValueError` on a malformed shape), and use it from `_merge_settings_json` (root: unparseable/malformed → the existing sidecar behaviour) and from the nested `settings.local.json` present-file path (malformed → the existing `_nested_refuse`). **Hooks rule, as decided:** for each event in `ours["hooks"]` and each matcher group, append our handler to the target's group with the same `matcher` (create the event list / the group when absent) unless a handler with the same `command` already exists **anywhere under that event**; never remove, reorder or rewrite an adopter's entries; a target `hooks`/event/group of the wrong shape → `ValueError` (sidecar / refuse, never clobber). Idempotent: a second merge changes nothing (`merged == theirs` keeps the nested path's no-write behaviour). `--update --dry-run` still reports `merged` without writing. Keep every other target key untouched.
3. **Smoke assertions** (count them; report the new PASS total):
   - fresh at-root install: `.claude/settings.json` carries both hooks with the exact commands and `timeout` 15 (Python heredoc, as l.719 does);
   - retrofit onto the seeded `settings.json` (l.683): seed it additionally with a foreign `hooks.PreCompact` handler (a different `command`, matcher `auto`) and a foreign `hooks.PostToolUse` entry; after retrofit the foreign entries survive unchanged, ours are present exactly once (`PreCompact` `auto` group holds two handlers, foreign first), `env` still survives;
   - `--update` on a workspace that already has the hooks: a second `--update` leaves `settings.json` byte-identical (idempotent) and reports it `unchanged`/`merged` consistently with the existing summary wording; and `--update` on a pre-v55 `settings.json` (strip the `hooks` key in a copy) adds them;
   - nested install (Test 14 fixture): `settings.local.json` carries both hooks whose commands read `cd "$CLAUDE_PROJECT_DIR" && python3 workflow/scripts/workflow.py compact-gate || true` (the rewrite applied, the post-check passed), and a nested `--update` is idempotent; a present `settings.local.json` with a foreign hook keeps it;
   - a `settings.json` whose `hooks` is not an object (e.g. a string) → the sidecar `.claude/settings.workspace.json` path on retrofit, nothing clobbered.
4. `python3 installer/build.py`, then `--check`.
5. **`phase.md`**: consume the two S2 notes; add any Decision this slice settles (the helper's name and the exact malformed-shape behaviour); leave S3 the installer facts its doc notes need (`operations.md` *Updating / Adopting* sections: hooks merge additively on update/retrofit/nested, idempotent, foreign hooks kept; the sidecar on a malformed file) as a tagged note; rewrite `## Now` for S3. No `## Doc impact` lines (S3 owns them).

## Validate

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh` — alone in its Bash call; `ALL RETROFIT SMOKE TESTS PASSED` with the new count.
- In this checkout: `python3 -c 'import json;d=json.load(open(".claude/settings.json"));print(d["hooks"]["PreCompact"][0]["hooks"][0]["command"])'` prints the pinned command; `sh bootstrap_agentic_workspace.sh <mktemp -d> --at-root --force-empty-ok` (or the suite's fresh-install form) yields a `settings.json` with both hooks.

## Not in this slice

No engine changes (S1 done); no `CLAUDE.md`, skill or doc edits (S3); no version bump or CHANGELOG (S4); no commit; no edits to the operator's `~/.claude/settings.json`; the hooks are not loaded into this running session (that needs a relaunch — the review's job to verify).

## Dispatch

slice=P34.S2
phase=P34
kind=implementation
risk=low
attempt=1
route=mid
reason=kind implementation rated low
tier=mid
subagent_type=slice-executor-mid
model=sonnet
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Sonnet 5.5
explore_model=haiku
explore_effort=high
