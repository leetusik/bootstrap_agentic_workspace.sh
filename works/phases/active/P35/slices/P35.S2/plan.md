# P35.S2 — plan: research — paired worktrees for a nested install

## Context

P35 makes parallel worktrees work in a nested personal install (`../../intent.md`; `../../phase.md` Decisions 2, 3, 6, 9 and the `(for P35.S2)` Notes). This slice is **research**: findings only, proven by experiment in scratch repos. It writes no product code: no edit to `scripts/workflow.py`, `.claude/`, `installer/`, `tests/`, the READMEs or `CLAUDE.md`. Prototype patches are fine **inside the scratch install's own copy** of the engine (`<scratch-host>/workflow/scripts/workflow.py`), since that copy is the experiment, not the product. DECOMP2 cuts the build from what you land, so your findings must be concrete enough to cut slices and rate them.

Answer the nine questions (a)-(i) in `../P35.DECOMP/plan.md` under "S2 must answer". Each answer carries its evidence class: **observed** (you ran it, and the command and output are in `result.md`), **documented** (a Claude Code or git doc you cite by URL or man page), or **inferred** (a reasoned claim nothing confirmed; say what would confirm it). Prefer designs that hold whichever way an unconfirmable fact falls.

## Setup (scratch only)

1. `SCRATCH=$(mktemp -d)`. Make a host repo there with a few commits and a `main` branch, plus one **tracked** `CLAUDE.md` and one **operator-excluded** path written into `.git/info/exclude` (e.g. `temp/`) holding a file.
2. Install the workspace nested from this repo's built artifact: `sh /Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh "$SCRATCH/host"` (nested is the default). Read what it wrote: `workflow/`, `.claude/agents`, `.claude/skills`, `.claude/settings.local.json`, `CLAUDE.local.md` and the exclude block. Also add an operator-excluded `temp/` inside the **nested** repo's `info/exclude`, as glide-ilab has.
3. Create a phase there (`python3 workflow/scripts/workflow.py new-phase …`) to drive the experiments.

Never touch this checkout's git state or files outside the slice folder and `phase.md`, and never write to glide-ilab (read-only over `ssh node` is fine, as a reference for a real install's wiring).

## What each answer must settle (beyond the DECOMP list)

- **(a) The paired cut.**
  - Prototype it by hand, or with a patched scratch engine: the stamp commit in the nested repo, then the host worktree (`git -C <host> worktree add …` under `<host>/.claude/worktrees/P<N>-<slug>`), then the nested worktree at `<host-worktree>/workflow` on `phase/P<N>-<slug>`.
  - Confirm that the engine run from `<host-worktree>/workflow/scripts/workflow.py` resolves `HOST_ROOT` to the host worktree, sees `stream=phase/…` once `current_stream`'s nested early return is lifted, and that `next` there sees only that phase.
  - Confirm that the main checkout's `next` skips it.
  - State the exact order, every failure point and what each leaves behind, and whether the host's `info/exclude` must gain `/.claude/worktrees/` (and where `_ensure_worktrees_excluded` must point).
- **(b) Host-side wiring.**
  - Which of `CLAUDE.local.md`, `.claude/settings.local.json`, `.claude/agents/*` and `.claude/skills/*` must exist inside the host worktree, and for whom: the session after `EnterWorktree`, background executors whose cwd is the worktree, the engine (`CLAUDE_AGENTS = HOST_ROOT/.claude/agents`, used by `executor-route` / `sync-agents` / `validate`).
  - Weigh that Claude Code walks **up** from the cwd for `CLAUDE.md` / `CLAUDE.local.md` / `.claude/`. A worktree under `<host>/.claude/worktrees/` therefore has the **main** checkout's `<host>/CLAUDE.local.md` as an ancestor, and its `@workflow/…` import resolves against the main checkout. Say whether that double-loads or mis-points the contract, and recommend symlink vs copy vs nothing for each file, with `--update` and teardown in mind.
- **(c) The session and hooks.**
  - What `EnterWorktree` accepts in a nested host (a host worktree path under `.claude/worktrees/`), and what `$CLAUDE_PROJECT_DIR` and the hook stdin `cwd` are after it. Documented where possible; a cheap headless probe only if it is clearly harmless.
  - Design `compact-resume` / `compact-gate` so that a worktree session resumes on its own stream whatever `$CLAUDE_PROJECT_DIR` turns out to be (e.g. read stdin `cwd` and run the engine of the checkout that contains it). Say whether the at-root layout needs the same fix.
- **(d) The host branch.**
  - Options: the operator names it, the orchestrator derives it from the host's convention (`nested-convention` text) without workspace IDs, or detached until the first host commit. Recommend one.
  - Settle the base ref (the default checkout's HEAD? the host default branch?), what teardown does with the host branch (kept for the operator's PR; deleted only when it carries no commits beyond its base), and the guard against unbranched host commits.
  - If the choice is truly the operator's, write it on `## Operator Questions`.
- **(e) Ignored/excluded paths.**
  - Show by experiment what `git worktree remove` does with ignored files in the host worktree and in the nested worktree (expected: deleted without refusal).
  - Recommend: a pre-teardown check listing ignored files that exist only in the worktree, a configured list of shared scratch paths symlinked from the main checkout (e.g. nested `temp/`), or both. Say where such a list would live (the marker? `executors.toml`?).
- **(f) Host anchors.** Re-stamp `host_anchors.created` at `parallel-start` to the host worktree's base, take `review_pass` from the worktree's HEAD, and say how `_phase_scope_nested` (≈3346-3438) handles a worktree phase. Weigh D35 (merge-base after a rebase): fold it in or keep it deferred, with the reason.
- **(g) The Streams view.**
  - Specify the `backlog.md` section: its position, its columns (phase, stream or branch, host branch when nested, worktree path, status, current slice, n/m done, source: branch, local copy or working tree) and its at-root and nested behaviour, reusing `_phase_json_at_ref` / `_slices_at_ref` / `_parallel_verdict`.
  - Settle when git is consulted: only when a phase is stamped, as `current_stream` does. Settle what the default stream's own row shows.
  - Weigh D57 (a merged P33 still listed as parallel elsewhere): fold it in or not.
- **(h) Shared external resources.** A worktree doesn't isolate docker containers, ports or DBs. One caveat line in the `parallel-phase` skill, or nothing; say which and why.
- **(i) The command and text surface.** List every engine function, skill paragraph, `CLAUDE.local.md` line (`installer/main.py` ≈903), README passage (`README.md` 59/128/211-212/407, `README.en.md` 111-112/244/325-327/546) and smoke-test assertion (Test 14's "parallel off") that changes. List the `parallel-phase` lifecycle steps that need a host counterpart or a `git -C workflow` form. Weigh D37 (a claude-design round push targets the host branch).

## Deliverables

- `result.md`: verdict block first, then each of (a)-(i) with its evidence class and the commands and outputs that back it (trimmed), then a **proposed cut for DECOMP2** covering the worktree part: slices, kind/risk with the named trigger, order and dependencies, and what each one's validation must show.
- `phase.md`, edited under budget:
  - a `(from P35.S2, for P35.DECOMP2)` Note with the condensed design, one line per question, the recommendations and the proposed cut;
  - `## Decisions` lines only for what the evidence settles beyond doubt;
  - `## Operator Questions` for any operator-only choice;
  - `## Doc impact` only if you change durable truth (you should not);
  - `## Now` rewritten.
- Remove the scratch dirs at the end (`rm -rf` on the `mktemp` path you created, by its exact variable, never a broader glob). Say so in `result.md`.

## Must not

Edit product files, commit, move workflow state (beyond your own `phase.md` and `result.md`), run `tests/retrofit_smoke.sh` chained with anything else (if you run it at all, it is the only command in its Bash call), write to glide-ilab, or pre-fill DECOMP2's `plan.md`.

## Dispatch

route=research
reason=kind research
tier=high
subagent_type=slice-executor-high
model=opus
pass_model=yes
effort=medium
pass_effort=yes
attribution=Claude Opus 5.5
explore_model=haiku
explore_effort=high
