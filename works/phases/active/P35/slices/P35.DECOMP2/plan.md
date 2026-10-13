# P35.DECOMP2 — plan: cut the build from S2, S3 and the operator's answers

## Context

P35's research has landed. S2 proved paired host + nested worktrees on a scratch nested install (Decisions 10-14, its `(from P35.S2, for P35.DECOMP2)` Note, and a 7-slice proposed cut in `slices/P35.S2/result.md`). S3 proved this repo's conversion to the nested layout on scratch clones (Decisions 15-16, a runbook Note, a C1/C2 proposed cut and reusable patches in `scratchpad/p35s3.OEAp/patches/`). The operator then answered all five open questions; the two `(operator, 2026-10-13)` entries in `## Operator Questions` and `intent.md`'s Clarifications hold them verbatim:

- **PR policy is the host's custom.** The engine stays policy-neutral in nested: it never pushes, opens a PR or merges into the host default. The custom lives in `nested-convention`'s text, broadened from commits to **commits, branches and PRs**. The orchestrator follows it (one PR per phase, or a ticket's phases folded by rebase) and asks where it is silent. At-root keeps the local merge into main. The operator: "this repo is not only for my use case."
- **Host branch:** `--host-branch` is required in nested. The orchestrator proposes a name from the custom, and the operator confirms. The engine never invents one.
- **Host base:** the default is the host's default branch (`origin/HEAD`, else the local default branch), with `--host-base` to override. The skill fetches first when the custom says to. This **replaces S2's pick** (the main checkout's HEAD).
- **Source tree:** `payload/`, with undotted inner names (Decision 15).
- **The switch:** the conversion slice's executor does the working-tree part, and the **orchestrator runs S3's steps 3-8 inline with the operator present**, as a one-time exception to "every slice is delegated".
- **Host subjects drop phase IDs after the conversion** (`docs(engine): …`); the IDs stay in the nested repo's commits.

`P35.DECOMP2` (decomposition, `slice-executor-high`) creates the build slices with `new-slice` as bare folders, turns the answers into Decisions, consumes the S2/S3/DECOMP Notes into per-slice Notes, rewrites `## Now` and writes `result.md`. It changes no source.

## The breakdown (the executor confirms or amends with reasons)

| Slice | Name | Kind / risk (trigger) | Order | Depends on |
|---|---|---|---|---|
| `P35.S4` | nested paired parallel-start, stream claim and host wiring | implementation / high (core invariant: worktrees, stamp, anchors, execution fields) | 50 | P35.DECOMP2 |
| `P35.S5` | nested paired teardown, merge-finish and consolidation | implementation / high (deletion) | 60 | P35.S4 |
| `P35.S6` | compaction hooks follow the session's cwd | implementation / high (wide blast radius: every install's compactions, at-root included) | 70 | P35.S5 |
| `P35.S7` | Streams view in backlog.md and the in-flight filter for next (D57) | implementation / low (design pinned in S2 (g)) | 80 | P35.S6 |
| `P35.S8` | skills, installer and text for nested parallel and the host custom | implementation / low (pinned wording plus installer lines) | 90 | P35.S7 |
| `P35.S9` | smoke tests for the nested lifecycle and the hook redirect | implementation / low (core behavior, kept small) | 100 | P35.S8 |
| `P35.S10` | convert this repo to the nested layout | implementation / high (deletion and history; wide blast radius: build, hook, smoke, CI) | 110 | P35.S9 |
| `P35.S11` | v58 release in the new layout | implementation / low | 120 | P35.S10 |
| `P35.REVIEW` | (exists, order 9999) | review, gated | — | — |

**Each slice's scope:**

- **S4 (from S2 (a), (b), (d), (f)).**
  - Lift `_refuse_parallel_when_nested` for start, status and gate, `current_stream`'s nested early return, and `parallel_start_hint`.
  - The start order is S2's seven steps.
  - `--host-branch` is required in nested. Reuse an existing branch only if it is not checked out, and record `host_branch_created`.
  - `--host-base` defaults to the host default branch. Pin the resolution order: `git symbolic-ref refs/remotes/origin/HEAD`, else `init.defaultBranch` if it exists locally, else `main`, then `master`, else refuse with "pass --host-base". The engine itself never fetches.
  - New execution fields (`host_branch`, `host_base` ref + sha, `host_worktree`, `host_branch_created`) plus their `validate` checks.
  - Re-stamp `host_anchors.created`; ensure the host's `/.claude/worktrees/` exclude; copy `CLAUDE.local.md`; resolve `CLAUDE_AGENTS` through the host's git-common-dir.
  - At-root behavior stays byte-for-byte unchanged.
- **S5 (from S2 (d), (e)).**
  - Teardown removes the nested worktree first, then refuses on worktree-only ignored or untracked files unless `--discard-ignored` (S2's `ls-files` form), refuses detached host commits, then removes the host worktree.
  - **The host branch is kept**; it is deleted only when the engine created it and it has 0 commits beyond its base.
  - `parallel-merge-finish` and `parallel-consolidated` work in nested; the merge runs in `git -C workflow`. No host merge, ever.
- **S6 (from S2 (c)).** In `cmd_compact_gate` and `cmd_compact_resume`, read stdin, walk up from `cwd` to the owning engine, and re-run it under the `AGENTIC_HOOK_REDIRECTED` guard. At-root and nested alike; the hook commands stay as they are.
- **S7 (from S2 (g)).** `## Streams` after `## Pointer`, with the columns, the in-flight filter and the git-only-when-stamped rule as S2 pinned them, plus the same filter on `next`'s `parallel_phases_elsewhere` (folds D57).
- **S8 (from S2 (h), (i) and the answers).**
  - `installer/main.py`: the `CLAUDE.local.md` rule lines (≈903) and the exclude line (≈1053); a nested `workflow/.gitattributes` with `events.jsonl merge=union`.
  - The `nested-convention` scope broadened to commits, branches and PRs, in its help, the `CLAUDE.local.md` text and the skills.
  - The `parallel-phase` skill for nested:
    - the start: propose the host branch from the custom, confirm, choose the base, fetch per the custom;
    - the integration: the workflow merge in `git -C workflow`; the host side by the recorded custom (one PR per phase, or fold by rebase and re-run the checks on the combined commit); never push, open or merge without the operator's word;
    - the (h) caveat on docker, ports and DBs.
  - `do-next-slice` and `do-whole-phase`: the worktree paragraphs ("parallel" now works in nested).
  - The READMEs (KO and EN): nested parallel is available.
  - `installer/build.py` rebuild. No version bump.
- **S9.** Replace Test 14's "parallel off" with a small nested lifecycle check: start → `next` shows `stream=` in the worktree and the main checkout skips the phase → teardown guards → host branch kept. Add one hook-redirect assertion and one Streams-row assertion. `tests/retrofit_smoke.sh` runs **alone** in its Bash call.
- **S10 (S3's C1).**
  - Its plan is made **at the gate** (plan mode, operator approval) whatever the run's mode, because the operator is present for the switch.
  - The executor does S3 (f) step 2 (the `git mv` into `payload/`, the build/hook/smoke/CI edits, the dev `CLAUDE.md`, the upstream CI). It regenerates S3's patches against the post-S9 tree.
  - The orchestrator runs steps 0, 1 and 3-8 inline per the runbook, with a tag and bundle backup and the move-only rollback ready. The slice ends `pending` for the operator to restart Claude Code at the repo root.
  - The host commit subject carries no phase ID.
- **S11 (S3's C2).**
  - Bump `WORKSPACE_VERSION` to 58, add a CHANGELOG v58 entry with migration notes, and drop or reword the shipped contract's "Upstream repo only" bullet. Rebuild.
  - Then `sh bootstrap_agentic_workspace.sh --update .` and a nested commit: the first real dogfood of the release path.
  - Host subject: `build(release): workspace v58 — …`.

## Decisions the executor records in phase.md

17. **The build breakdown** above, with each rating's reason and the estimate: four high dispatches (S4, S5, S6, S10), four mid (S7, S8, S9, S11), then the review.
18. **PR policy is the host's custom; the engine is policy-neutral in nested.** It never pushes, opens a PR or merges into the host default. `nested-convention`'s text covers commits, branches and PRs. The orchestrator follows it and asks where it is silent. At-root is unchanged.
19. **Host branch and base.** `--host-branch` is required in nested; the orchestrator proposes from the custom and the operator confirms. `--host-base` defaults to the host default branch (resolution order as in S4), overriding S2's HEAD pick for the reason in the answer. Teardown keeps the host branch, deleting only an engine-created branch with no commits.
20. **The conversion's execution** (S10): plan at the gate; the executor does the working tree; the orchestrator runs the switch inline with the operator present (a one-time exception, stated in S10's plan); host subjects drop phase IDs from the conversion commit on; the REVIEW and S11 run in the restarted session from `workflow/`.
21. **Deferred:** D57 folds into S7; D35 and D37 stay deferred (S2's reasons). A new deferred-job candidate, "shared scratch paths linked into phase worktrees" (S2 (e)), goes in `result.md` for the orchestrator to file.

## Notes for later slices

One `(from P35.DECOMP2, for P35.S<n>)` Note per slice, carrying the S2/S3 detail that slice needs: line refs, the exact validations from S2's and S3's last sections, the patches' path for S10, and "smoke runs alone". Consume (remove) the S2, S3 and DECOMP Notes for DECOMP2, keeping their detail in the per-slice Notes. Doc impact stays one line per change, written by each slice when it lands.

## Must not

Edit any source, run the installer here, touch glide-ilab, pre-fill a slice's `plan.md`, run `accept-gate` or `defer-job`, or commit.

## Orchestrator steps

- **Before dispatch:** `start-slice P35.DECOMP2`, `executor-route P35.DECOMP2` and `--explore`, and pin `## Dispatch`.
- **After:**
  1. `record-dispatch` → `finish-slice P35.DECOMP2 --outcome "…"` → file the deferred-job candidate with `defer-job` → `validate` → one commit `chore(P35): cut the build …`.
  2. Run S4-S9 in the default `auto` loop.
  3. S10 plans at the gate.

## Verification

- `python3 scripts/workflow.py validate` passes.
- `## Slices` shows S4-S11 `todo` with the kinds, risks, orders and dependencies above, each holding only `slice.json`.
- Decisions 17-21 are present; the S2/S3/DECOMP Notes for DECOMP2 are consumed into per-slice Notes; `## Now` is at most 15 lines; `phase.md` is under budget.
- `git status` shows only P35's folder and the generated `works/` files.

## Dispatch

route=high
reason=kind decomposition
tier=high
subagent_type=slice-executor-high
model=opus
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Opus 5.5
explore_model=haiku
explore_effort=high
