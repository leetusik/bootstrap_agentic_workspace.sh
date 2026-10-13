# P35.S6 result: compaction hooks follow the session's cwd

- status: done
- tier: high
- model: opus
- effort: high
- summary: Both compaction hooks now read stdin once, walk up from the hook's `cwd` to the engine that owns it (`d/workflow/scripts/workflow.py` or `d/scripts/workflow.py`, with `works/` beside it), and when that is another copy, re-run it with the same stdin under `AGENTIC_HOOK_REDIRECTED=1` and a 12 s timeout, relaying its output. Every failure falls back to today's behavior. A worktree session now resumes on its own stream, and the gate judges its own slice and dirt, nested and at root. The hook commands are unchanged.
- files_changed: `scripts/workflow.py`, `bootstrap_agentic_workspace.sh` (rebuilt), this `result.md`, `../../phase.md`
- validation: nested replays (4 cwd values) PASS; nested gate (slice and dirt) PASS; at-root replays PASS; recursion guard PASS; fail-open (exit-1 stub, a 30 s stub that times out at 12 s, bad `cwd`, non-JSON stdin) PASS; `bash tests/retrofit_smoke.sh` alone: 292 PASS (292 after S5); `python3 installer/build.py --check` OK; `python3 scripts/workflow.py validate` passed (pre-existing warnings only)
- deviations: none
- doc_impact: operations.md: the compaction hooks resolve the engine from the hook's stdin `cwd` (see `phase.md` `## Doc impact`)

## Change

`scripts/workflow.py`:
- New constants `HOOK_REDIRECT_ENV = "AGENTIC_HOOK_REDIRECTED"` and `HOOK_REDIRECT_TIMEOUT = 12`, plus a comment block after `COMPACT_RESUME_LINE` (≈4050).
- `_hook_owning_engine(cwd)` (≈4060) resolves `cwd`. It returns None when that is not a directory. Otherwise it walks `(start, *start.parents)` and at each `d` checks `d/workflow` before `d`. The first `base` with `scripts/workflow.py` and `works/` gives `(engine, d)`.
- `_hook_stdin_or_redirect(subcommand)` (≈4074) reads stdin once and never raises. It returns the text for this engine to handle, or None after a successful redirect. It returns the text when:
  - the guard env var is set;
  - stdin is not a JSON object;
  - `cwd` is not a non-empty string or does not resolve to a directory;
  - no engine is found, or the found engine's `resolve()` equals `Path(__file__).resolve()`;
  - the child raises (a timeout included) or returns non-zero. In that case nothing from the child is relayed.
  
  When the redirect succeeds, the child's stdout goes to stdout and its stderr to stderr, both unchanged. The child runs as `[sys.executable, engine, subcommand]` with `cwd=d` (the host for nested, the repo for at root), the environment plus `AGENTIC_HOOK_REDIRECTED=1`, and the same stdin text.
- `cmd_compact_gate` calls the helper first and returns on None. Otherwise it parses the returned text where it used to read `sys.stdin`. Its decision logic, block counter and stderr trace are untouched. The child computes the same counter path from the same `session_id`.
- `cmd_compact_resume` calls the helper in place of its bare `sys.stdin.read()` and returns on None.
- There is no NESTED branch: the walk finds `workflow/` or `.` by itself. `main()` already exempts both hooks from the malformed-marker refusal.

## Verification (scratch: `scratchpad/p35s6.GPsD`, left on disk because `rm -rf` is denied)

Setup:
- **Nested.** A host git repo on `main` with two commits; `sh bootstrap_agentic_workspace.sh "$S/host"`, using the rebuilt artifact, so the nested engine and its worktree copy carry the change. The nested repo was committed, then phases P1-P3, then `parallel-start P2 --host-branch feat/side`, which created `host/.claude/worktrees/P2-phase_2` with `workflow/` inside it on `phase/P2-phase_2`.
- **At root.** `sh bootstrap_agentic_workspace.sh --at-root "$S/root"`, then `git init`, P1-P2, a commit, and `parallel-start P2`.

Every replay ran the hook as installed: `cd <host|root> && printf '<json>' | python3 [workflow/]scripts/workflow.py compact-…`.

| # | Case | Observed |
|---|---|---|
| 1 | nested resume, `cwd=<host-wt>` | `stream=phase/P2-phase_2 …`, `current_phase=P2`, `current_slice=P2.DECOMP`; one `compaction=done` line; rc 0 |
| 1 | nested resume, `cwd=<host-wt>/workflow/works` | P2, same output (matched by the at-root rule on the nested worktree root) |
| 1 | nested resume, `cwd=<host>` | `current_phase=P1` (the default pointer; the engine found is `__file__`) |
| 1 | nested resume, `cwd=/tmp` | `current_phase=P1` (fallback) |
| 2 | nested gate, `trigger=auto`, `cwd=<host-wt>`, P2.DECOMP `in_progress` (via `start-slice` in the worktree) | `decision=block rule=slice_in_progress slice=P2.DECOMP`, plus the block JSON on stdout |
| 2 | same, after P2.DECOMP was set back to `todo` and committed, with an untracked `product.txt` in the host worktree | `decision=block rule=dirty slice=P2.DECOMP dirty=1`; stdout alone (`2>/dev/null`) is exactly the block JSON |
| 2 | gate, `cwd=<host>` (same moment) | `decision=allow rule=boundary slice=P1.DECOMP dirty=0` |
| 3 | at-root resume, `cwd=<root-wt>` and `<root-wt>/works/phases` | `stream=phase/P2-phase_2 …`, `current_phase=P2` |
| 3 | at-root resume, `cwd=<root>` and `/tmp` | `current_phase=P1` |
| 3 | at-root gate, `cwd=<root-wt>` | `slice=P2.DECOMP status=todo dirty=0 … allow rule=boundary` |
| 4 | `AGENTIC_HOOK_REDIRECTED=1` already set, `cwd=<host-wt>` | `current_phase=P1`: no redirect |
| 5 | `cwd=$S/stub`, where `stub/workflow/scripts/workflow.py` prints `STUB-OUT`/`STUB-ERR` and exits 1 (with `stub/workflow/works/`) | no STUB text relayed; own pointer `P1`; rc 0. The gate printed its own `rule=manual` trace, rc 0 |
| 5+ | `cwd=$S/slow`, a stub that sleeps 30 s | own pointer P1 after 12 s, rc 0 |
| 5+ | `"cwd":5`, `"/no/such/dir"`, no `cwd`, non-JSON stdin | own pointer P1. The gate on garbage stdin gives `rule=error … stdin is not a hook JSON object` (as before), rc 0 |
| 6 | `bash tests/retrofit_smoke.sh` (alone) | `ALL RETROFIT SMOKE TESTS PASSED`, 292 PASS (S5: 292). Log: `scratchpad/p35s6-smoke-after.log` |
| 7 | `python3 installer/build.py` then `--check` | `OK: … in sync` |
| 7 | `python3 scripts/workflow.py validate` | passed (the stale-docs and oversized-sections warnings were there before) |

Instrument: none needed. This slice has no browser surface; every check is a CLI replay of the hook stdin.

Notes:
- The scratch nested worktree's state was moved (`start-slice`, then `set-slice-status`, a commit); this was scratch only.
- A worktree branched before this engine change carries the old engine. When redirected to, it simply answers as today. The guard is set anyway, so it cannot recurse.
