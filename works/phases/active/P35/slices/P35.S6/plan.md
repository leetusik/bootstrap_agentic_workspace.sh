# P35.S6 — plan: compaction hooks follow the session's cwd

## Context

The compaction hooks run `cd "$CLAUDE_PROJECT_DIR" && python3 <engine> compact-gate|compact-resume || true`. After `EnterWorktree`, `$CLAUDE_PROJECT_DIR` stays at the main checkout, while the hook's stdin `cwd` follows the session into the worktree (documented: code.claude.com/docs/en/worktrees and the hooks page). So today a worktree session resumes on the **default stream's** pointer after a compaction, and `compact-gate` judges the wrong slice and the wrong tree's dirt. This is true at root and nested alike (S2 (c), observed; Decision 13; the `(from P35.DECOMP2, for P35.S6)` Note). S2 prototyped the fix in a scratch engine. This slice builds it.

**The hook commands in `settings.json` / `settings.local.json` stay exactly as they are**, so no migration. The fix lives in the engine.

## Change (`scripts/workflow.py`; then `python3 installer/build.py`)

Add one helper, used first by both `cmd_compact_gate` and `cmd_compact_resume`. Re-check the lines after S5.

1. **Read stdin once,** as bytes or text: both hooks already read it, so keep a single read and pass the parsed hook dict on.
2. **If `AGENTIC_HOOK_REDIRECTED` is set** in the environment, never redirect: carry on as today. This is the recursion guard.
3. **Take `cwd`** from the hook JSON. If it is missing, not a string or not an existing directory, carry on as today.
4. **Walk up** from `cwd` (resolved) through its parents to `/`. At each directory `d`, the owning engine is the first match of:
   - `d/workflow/scripts/workflow.py` with `d/workflow/works/` beside it (nested);
   - `d/scripts/workflow.py` with `d/works/` beside it (at root).

   Stop at the first `d` that matches.
5. **If no engine was found, or it is this file** (compare `Path(...).resolve()` with `Path(__file__).resolve()`), carry on as today.
6. **Otherwise re-run that engine:**
   - `[sys.executable, <engine>, <same subcommand>]` with the **same stdin text**;
   - the environment plus `AGENTIC_HOOK_REDIRECTED=1`;
   - `cwd` = the engine's host or repo root;
   - `timeout=12` (the hook's own timeout is 15 s);
   - relay its stdout to stdout and its stderr to stderr unchanged (`compact-gate`'s block decision is JSON on stdout);
   - exit 0.

   **On any exception or a non-zero return, fail open:** print nothing extra and carry on as today with the already-read stdin. The hooks must never fail, which matches today's guarantees (`compact-gate` "fails open: exit 0 always"; `compact-resume` "never fails").
7. **The gate's block counter** (`_compact_counter_path`) needs nothing: the child computes the same path from the same `session_id`.

Keep the change mode-agnostic: no `NESTED` branch is needed, since the walk finds `workflow/` or `.` by itself.

## Doc impact (append to phase.md)

- `operations.md`: the compaction hooks resolve the engine from the hook's stdin `cwd` (walking up to the nearest `workflow/scripts/workflow.py` or `scripts/workflow.py` with `works/` beside it). A worktree session resumes on its own stream and the gate judges its own slice, at root and nested; the hook commands are unchanged (P35.S6)

## Verification

All on scratch installs in the session scratchpad (no `claude -p`; `rm -rf` is denied, so leave scratch):

1. **Nested:** S2's recipe plus S4's `parallel-start P2 --host-branch feat/side`. Replay the hook as installed:

   ```
   cd <host> && printf '%s' '{"session_id":"t1","hook_event_name":"SessionStart","source":"compact","cwd":"<X>"}' | python3 workflow/scripts/workflow.py compact-resume
   ```

   with `<X>` set to:
   - `<host-wt>` → `stream=phase/P2-…`, `current_phase=P2`;
   - `<host-wt>/workflow/works` → P2;
   - `<host>` → the default pointer;
   - `/tmp` → the default pointer (fallback).
2. **`compact-gate`** with `"trigger":"auto"`, plus a `transcript_path` stub if needed, and `cwd=<host-wt>` while P2's slice is `in_progress`: it judges **P2's** slice and **that worktree's** dirt (block JSON), not P1's.
3. **At root:** a scratch at-root install with `parallel-start` → the same replay from a root worktree prints that worktree's stream.
4. **Recursion guard:** with `AGENTIC_HOOK_REDIRECTED=1` already set and `cwd=<host-wt>`, the hook does **not** redirect; it prints the default pointer.
5. **Fail-open:** point `cwd` at a directory whose `workflow/scripts/workflow.py` is a stub that exits 1. The hook still prints its own pointer and exits 0.
6. **`bash tests/retrofit_smoke.sh` as the only command in its Bash call:** the same PASS count as after S5. Record both counts.
7. `python3 installer/build.py --check` and `python3 scripts/workflow.py validate`.

## Must not

Change the hook commands or any settings file, the teardown, the backlog, the skills, the installer or the READMEs; bump the version; commit; or move workflow state.

## Dispatch

route=high
reason=risk high (not low)
tier=high
subagent_type=slice-executor-high
model=opus
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Opus 5.5
explore_model=haiku
explore_effort=high
