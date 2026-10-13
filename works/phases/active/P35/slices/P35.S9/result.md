- status: done
- tier: mid
- model: sonnet (Sonnet 5.5)
- effort: high
- summary: Added one block to the end of `tests/retrofit_smoke.sh` Test 14 (5 assertions): paired `parallel-start`, stream claim + Streams row, `compact-resume` cwd redirect, teardown guard refusal on `temp/`, nested-first teardown keeping `feat/side`. Smoke is **297 PASS / 0 FAIL** (was 292): S10's baseline.
- validation:
  - `bash tests/retrofit_smoke.sh` (alone): 297 PASS, 0 FAIL, "ALL RETROFIT SMOKE TESTS PASSED".
  - Deliberate break: changed `^kept host branch feat/side:` to `^kept host branch nope:`; the suite failed with `FAIL: paired teardown wrong (rc=0) ...` (only that line); restored by exact reverse sed (grep confirms `nope` count 0).
  - `python3 installer/build.py --check`: in sync. `python3 scripts/workflow.py validate`: passed (pre-existing doc-staleness warnings only).
- deviations:
  - The block sits at the **end** of Test 14, not directly after the S4 refusal assertion: the test later overwrites `.agentic-nested.json` with a truncated one and asserts the compact-gate dirty state on an uncommitted nested repo, both of which a committed nested repo would break. The block restores a valid marker first (confirmed convention) and commits the fixture's nested repo.
  - The three-part header comment mention of "parallel off" (line ~32) was updated too, besides the title line.
  - Extra fixture setup the plan did not list: host `info/exclude` gets `/workflow/` and `/.claude/agents/` (the hand-built fixture has no installer exclude block, so the host status would otherwise show them); nested default branch forced to `main`; the worktree's regenerated `works/` files are discarded and the main checkout's committed before the merge (generated files, no union `.gitattributes` in the fixture, would otherwise conflict or dirty-refuse).
- doc_impact: qa.md line appended to phase.md.

## Detail

Assertions added (all in Test 14, after the malformed-marker assertions):
1. `parallel-start P1 --host-branch feat/side` succeeds; both repos list the host worktree / nested worktree; `<host-wt>/workflow` exists; host `git status --short` empty.
2. From the host worktree `next` prints `stream=phase/P1-…`; the main checkout's `next` does not print `current_phase=P1`; after `rebuild`, backlog.md's `## Streams` has a row with `P1` and `feat/side`.
3. `compact-resume` run from the main checkout engine with stdin `cwd=<host-wt>` prints `stream=phase/P1-…` and `current_phase=P1`.
4. After a host commit on `feat/side`, an ignored `workflow/temp/note.txt`, and a `--no-ff` merge of the phase branch into the nested `main`: `parallel-teardown P1` refuses with `parallel-teardown P1 refused -- nothing was removed:`, names `ignored, worktree-only files would be deleted` and `temp/`; both worktrees remain.
5. `parallel-teardown P1 --discard-ignored` exits 0, prints `removed nested worktree` before `removed host worktree`, then `kept host branch feat/side:`; the host branch is listed; the worktree is gone from both repos; no `prunable` entry.

The block was developed in a harness (setup lines + Test 14 only) in the scratchpad (`scratchpad/s9/`), then inserted and the full suite run once alone. No engine, installer, skill or README change; no version bump; nothing committed.
