# P35.S9 — plan: smoke tests for the nested lifecycle and the hook redirect

## Context

S4-S8 built nested parallel worktrees: the start, the teardown, the hook redirect, the Streams view and the text. The contract allows test files **only for very core behavior**, kept very small. The nested worktree lifecycle qualifies: it creates and deletes worktrees, branches and workflow state, which the product cannot afford to break. So does the hook redirect, which runs in every install's compactions. This slice adds **one small block** to `tests/retrofit_smoke.sh`'s **Test 14** (the nested engine test, ≈1806), which S4 left with a single interim refusal assertion. Sources: `../../phase.md` the `(from P35.DECOMP2, for P35.S9)` Note and its `(from P35.S5)` / `(from P35.S6)` addenda (the exact strings to assert), `../P35.S5/result.md` and `../P35.S6/result.md`.

## Change (`tests/retrofit_smoke.sh` only; plus the Test 14 title line)

Keep S4's assertion: `parallel-start` without `--host-branch` refuses and writes nothing. After it, in Test 14's fixture (host `$NH` on `main`, the nested repo at `$NH/workflow`, `nw()` runs the engine from the host root), add the lifecycle. Each step is one `ok`/`bad` line:

1. **Setup:**
   - give the nested repo a git identity and an initial commit if the fixture lacks one;
   - add `temp/` to the nested repo's `info/exclude`;
   - make sure P1 is still `planned` (or create a fresh `P2` for the lifecycle, if the earlier assertions moved P1 on).
2. **Start:** `nw parallel-start <P> --host-branch feat/side` succeeds. Both repos' `git worktree list` show the new worktree, `<host-wt>/workflow` exists, and the host's `git status --short` is empty.
3. **Streams:** from `<host-wt>`, `python3 workflow/scripts/workflow.py next` prints `stream=phase/<P>-…`. From the host root, `nw next` does not select `<P>`, and `nw rebuild` writes a `## Streams` row for `<P>` with `feat/side` in `works/backlog.md`.
4. **Hook redirect:** from the host root, `printf '{"session_id":"t","source":"compact","cwd":"<host-wt>"}' | python3 workflow/scripts/workflow.py compact-resume` prints `stream=phase/<P>-…`.
5. **Teardown guard:**
   - commit one host file on `feat/side` in `<host-wt>`;
   - create the ignored `<host-wt>/workflow/temp/note.txt`;
   - merge the phase branch into the nested default branch from the host root (`git -C workflow merge --no-ff …`), plus whatever minimal state the S5 precondition needs;
   - `nw parallel-teardown <P>` refuses with `parallel-teardown <P> refused -- nothing was removed:` and lists `temp/` under `ignored, worktree-only files would be deleted`. Both worktrees still exist.
6. **Teardown:** `nw parallel-teardown <P> --discard-ignored` succeeds. `removed nested worktree` prints before `removed host worktree`, then `kept host branch feat/side`. `git -C $NH branch --list feat/side` is non-empty, and neither repo lists the worktree or a `prunable` entry.

Update Test 14's title line: "parallel off" becomes "the paired worktree lifecycle". Reuse the file's helpers (`ok`, `bad`, `newtmp`) and its style; no new helper files, no network.

## Verification

- **`bash tests/retrofit_smoke.sh` as the only command in its Bash call.** All earlier PASS lines are unchanged and the new ones PASS. Record the new **total PASS count** in `result.md` and in `phase.md`'s `## Now`: it is **S10's baseline** (292 before this slice).
- Break one new assertion on purpose once (e.g. expect `kept host branch nope`), see it FAIL, then restore it. Say so in `result.md`.
- `python3 installer/build.py --check`: the smoke suite isn't embedded, but confirm no drift. `python3 scripts/workflow.py validate`.

## Doc impact (append to phase.md)

- `qa.md`: the smoke suite's Test 14 covers the nested paired-worktree lifecycle (start → stream claim → the Streams row → the hook redirect → the teardown guard → nested-first teardown keeping the host branch) (P35.S9)

## Must not

Change engine, installer, skill or README behavior; add more than this one block; run the suite chained with anything; bump the version; commit; or move workflow state.

## Dispatch

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
