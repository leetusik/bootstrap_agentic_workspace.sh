# Result — P34.S1 (Engine: `compact-gate` and `compact-resume`)

- status: done
- tier: high
- model: opus
- effort: high
- summary: Added the `compact-gate` (PreCompact) and `compact-resume` (SessionStart) engine subcommands: a fail-open veto that blocks an auto-compaction while the current slice is in_progress/in_review or the tree is dirty, bounded by the fill ceiling and the consecutive-block cap. It allows a manual compaction, a subagent's own compaction, an unreadable input and an uncountable block. Also added 14 smoke asserts (suite 280 PASS) and confirmed the retry-after-block reading in the 2.1.296 binary.
- files_changed: scripts/workflow.py, tests/retrofit_smoke.sh, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P34/phase.md, works/phases/active/P34/slices/P34.S1/result.md
- validation: `python3 scripts/workflow.py validate` pass; `python3 installer/build.py` + `--check` pass; `bash tests/retrofit_smoke.sh` pass (ALL RETROFIT SMOKE TESTS PASSED, 280 PASS, 14 new); manual checks in this checkout pass (below)
- deviations: (1) rule (a′) added: a hook carrying `agent_id` allows and leaves the count alone; (2) a block the counter cannot record allows instead; (3) `docs/index.json` added to the dirty exclusions (the plan's conditional); (4) nested dirty check reads two repos, not one with `workflow/` prefixes; (5) trace line gains `dirty=`; (6) `main()`'s malformed-marker refusal exempts both hook commands; (7) no commit in the `cp -R` probe — compared file hashes instead. Reasons below.
- doc_impact: none (the DECOMP assigned the phase's `## Doc impact` lines to S3; the facts are in phase.md's tagged note for S3)

## What was built

`scripts/workflow.py` (new block before `cmd_deferred`, ~l.3575–3790; subparsers after `next` in `main()`):

- Constants: `COMPACT_CEILING_ENV`/`COMPACT_CAP_ENV` (`AGENTIC_COMPACT_CEILING`, `AGENTIC_COMPACT_BLOCK_CAP`), `COMPACT_CEILING_1M = 850_000`, `COMPACT_CEILING_200K = 170_000`, `COMPACT_BLOCK_CAP = 8`, `COMPACT_1M_MODEL_RE = ^claude-[a-z]+-5(?:[-\[]|$)`, `COMPACT_DIRTY_EXCLUDE`, `COMPACT_RESUME_LINE`.
- `_compact_last_usage` (tail-first transcript read, skips sidechain / zero-usage lines), `_compact_counter_path`, `_compact_read_blocks`, `_compact_dirty_count` (at root: the workspace repo minus the exclusions; nested: that plus the host's `_host_pathspec()`), `cmd_compact_gate`, `cmd_compact_resume`.
- Decision order as pinned in phase.md `## Decisions`: manual → subagent → ceiling → cap → slice in_progress/in_review → dirty → boundary. The pointer comes from `all_active_phases` + `current_stream` + `stream_phases` + `resolve_current`, never `cmd_next`, so the gate writes nothing in the tree. The whole body is in `try/except Exception` and returns None, so every path exits 0.
- `compact-resume` prints `compaction=done source=compact`, the `cmd_next` output (inside `try/except BaseException` → `pointer unavailable: …`), and the resume line. 837 characters on this repo.

## Deviations and why

1. **Subagent rule (a′).** The hooks reference documents `agent_id` as a common input field "for the subagent or in-process teammate the hook fires in", and the binary's in-process runner handles a PreCompact block. An executor's slice is `in_progress` for its whole life, so the gate would block every one of its auto-compactions until the cap (8 turns), which risks its window and protects no boundary. The rule allows the compaction and leaves the main thread's count alone, since it shares the session id. Recorded in `## Decisions`. Keying on `agent_id` rather than `agent_type`: `agent_type` is also present on a main thread started with `--agent`.
2. **Uncountable block allows.** The DECOMP plan treated an unwritable counter as harmless, but it is not. If the counter cannot be written, the count stays 0 and the cap never fires; with an unreadable transcript as well, the veto would repeat forever. So the gate writes the counter first, and a failed write turns the block into an allow (`rule=error`, `block counter unwritable`).
3. **`docs/index.json` excluded.** The plan made this conditional. I compared file hashes in a `cp -R` copy (`s1copy` in the scratchpad) before and after each command. The first `next` changed `works/index.json` and `works/state.json`, and a second `next` changed nothing. `validate` changed nothing. `rebuild` changed `docs/index.json` (only `last_rebuilt_at`), and changes it on every run. Because `validate`/`rebuild` regenerate the file, it is excluded and the Decision is amended. A real doc change still shows up as dirty through `docs/versions/` and `docs/current/`.
4. **Nested = two repos.** The plan's `workflow/works/…` prefix assumed one repo. In a nested install `workflow/` is its own git repo (Test 14 `git init`s it), and the host's product is a separate repo, the same split `_phase_scope_nested` uses. So the gate runs `git status` in each with its own pathspec and counts the union by absolute path. That covers a `workflow/` that sits inside the host repo too.
5. **Trace line.** It carries `dirty=<n|->` between `status=` and `fill=`, plus ` error=<text>` on `rule=error`. The final format is pinned in `## Decisions`.
6. **Malformed nested marker.** `main()` refuses every command but `validate` on a malformed marker (exit 1). `compact-gate` and `compact-resume` are now exempt, so the hooks still run and fail open. The hook's `|| true` would have covered the exit code anyway.
7. **No commit in the probe copy.** My first probe command, which committed in the copy, was refused by the permission system. I measured what each command changes by hashing files before and after, which answers the same question without a commit. The smoke fixture does commit, inside its own `mktemp` directory, as every other smoke block does.

## Retry-after-block confirmation (binary reading)

`/Users/sugang/.local/share/claude/versions/2.1.296`, scanned with `re.finditer` plus ±1,500 printable bytes:

- ≈197831803: in the auto-compact function, `catch(Rt){if(l(Rt).startsWith(M7)){if(Pe)G8(n,Pe,{kind:"skipped",reason:"hook_blocked"});return{kind:"hook_blocked",routedThroughReactive:!1}}`. That `return` comes before `Pon(y,!1,…)`, the failure-tracking return every other failure branch takes, and no sticky flag is set. The reactive route also returns `{kind:"hook_blocked",thresholdSource:nt,routedThroughReactive:!0}` before `Pon`. `autoCompactThreshold:E5(r,V)` is built inside the same per-call function.
- ≈75300213: the `[inProcessRunner]` string ` compaction blocked by PreCompact hook; continuing uncompacted` and the event `compact_blocked_by_hook`.
- ≈78289748: the UI string `Compaction blocked by PreCompact hook: ` (+ reason), `compaction-blocked-by-hook`.
- Two later reads of the binary, looking for the callers of `kind==="hook_blocked"`, were refused by the auto-mode classifier. I did not retry them and did not run a live probe. The branch that decides the question, a block versus the failure breaker, was unambiguous.
- Allow form: the hooks reference (code.claude.com/docs/en/hooks) says "The only value for `decision` is `"block"`. To allow the action to proceed, omit `decision` from your JSON, or exit 0 without any JSON at all." So an allow prints nothing. The same page lists `scratchpad_dir` (2.1.257+) and `agent_id`/`agent_type` as common input fields.
- Model ids in this machine's transcripts (`~/.claude/projects/*/*.jsonl`): `claude-opus-5-5`, `claude-opus-5`, `claude-fable-5-1`, `claude-sonnet-5-5`, `claude-sonnet-5`, `claude-haiku-5-5`, `claude-opus-5-5[1m]`, `claude-haiku-4-5-20251001`. All but the last match `COMPACT_1M_MODEL_RE`. Haiku 5.5 is 1M per the operator's memory note.

## Validation

- `python3 scripts/workflow.py validate`: passed (only the existing consolidation/stale/oversized warnings).
- `python3 installer/build.py` then `python3 installer/build.py --check`: `OK: bootstrap_agentic_workspace.sh is in sync`.
- `bash tests/retrofit_smoke.sh` (alone): `ALL RETROFIT SMOKE TESTS PASSED`, **280 PASS** (266 before + 14 new). The plan's "247 at P33" was already 266 at HEAD. The new asserts:
  - Test 5, after the v53 dispatch-record block, on its own fixture (fresh `--at-root` install, `git init`, P1, committed): manual → silent allow; todo slice on a clean tree → boundary allow; `start-slice` → block naming `P1.DECOMP in_progress`, ceiling 850000 for `claude-opus-5-5`, `blocks=1/8`; `agent_id` set → allow, count untouched; `AGENTIC_COMPACT_CEILING=1000` → allow mid-slice, counter file gone; `AGENTIC_COMPACT_BLOCK_CAP=2` → block, block, allow, block; counter path is a directory → allow `rule=error`; nonexistent transcript → still blocks by the boundary, `fill=- ceiling=170000`; `not json` → silent, exit 0; after `finish-slice`, a commit, then `next` and `rebuild` → boundary allow on `P1.REVIEW`, `dirty=0`; untracked `src/wip.py` → block `dirty: 1 file`; `compact-resume` → `current_slice=P1.REVIEW`, the resume line, under 10,000 characters.
  - Test 14, nested: from the host, on the never-committed `workflow/` repo → block, `"reason": "dirty: `, `slice=P1.DECOMP status=todo`, exit 0. After the marker is broken: `compact-gate` (manual) and `compact-resume` still run and exit 0.
- Manual, in this checkout: `printf '{"trigger":"manual"}' | … compact-gate` → 0 bytes of stdout, rc 0. `printf '{"trigger":"auto","session_id":"x"}' | … compact-gate` → `{"decision": "block", "reason": "slice P34.S1 in_progress -- compaction waits for the slice boundary (block 1/8; …)"}`, rc 0. With this session's live transcript: `fill=196443 ceiling=850000` (`claude-fable-5-1`), and `AGENTIC_COMPACT_CEILING=1000` → `rule=ceiling` allow. With a read-only `scratchpad_dir` → `rule=error … block counter unwritable`, allow. `printf '{}' | … compact-resume` → the pointer (`current_slice=P34.S1`) plus the resume line. Counter files deleted afterwards; none remain in the temp dir.
- Side effect: `compact-resume` calls `cmd_next`, which rewrote `works/state.json`/`works/index.json` in this checkout. Both were already modified by the orchestrator, and the Decision accepts this.

## Notebook

phase.md edits: `## Decisions` (block mechanism / allow form, retry confirmation, decision order with a′ and the uncountable block, dirty tree, fill ceiling regex, counter file, trace line, malformed marker); `## Notes for later slices` (consumed the DECOMP→S1 note; added tagged notes for S2 and S3); `## Now` rewritten for S2.
