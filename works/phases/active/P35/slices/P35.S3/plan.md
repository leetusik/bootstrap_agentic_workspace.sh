# P35.S3 — plan: research — converting this repo to the nested layout

## Context

The operator confirmed converting **this upstream repo** to the nested layout ("Yes, as described"; `../../intent.md`, item 4 and Clarifications; `../../phase.md` Decisions 4-6). The product source stays tracked here. The workspace's own state (`works/`, the workspace's `docs/`, `executors.toml`) moves into a private, git-excluded `workflow/` nested repo installed by the built installer, **with its history kept**. The workspace is then driven through that installed copy (`python3 workflow/scripts/workflow.py …`) and updated with `--update` after each release. The conversion runs last in P35, after the nested-worktree build lands. This slice is **research**: it designs the conversion and **proves it by a full dry run on a scratch clone**. It writes no product code, and it never touches this checkout's files, branches, index or hooks.

Answer (a)-(g) of `../P35.DECOMP/plan.md` under "S3 must answer". Each answer carries its evidence class: **observed** (run on the scratch clone, with the command and output trimmed into `result.md`), **documented** (a cited doc) or **inferred** (say what would confirm it).

## Facts already in hand (verify; line numbers drift)

- **Build inputs.**
  - `installer/build.py:46-62` `FIXED_LIVE_FILES` embeds these from their **live** paths: `scripts/workflow.py`, `.claude/settings.json`, the four `.claude/agents/*.md`, `executors.toml`, `works/templates/{deferred_brief,intent,phase}.md`, `.github/workflows/workspace-ci.yml` and `.gitattributes`.
  - It also embeds every `.claude/skills/*/SKILL.md` (`EXPECTED_SKILL_COUNT = 18`), the `CLAUDE.md` body (header stripped) and `installer/payloads/doc_bodies/*`.
  - The adopter `executors.toml` seed is derived from the repo-root `executors.toml` (≈82-103).
- **Tracked policy.**
  - `.githooks/pre-commit` (`core.hooksPath .githooks`) matches `^(installer/|scripts/workflow\.py$|CLAUDE\.md$|executors\.toml$|\.claude/|\.github/|\.gitattributes$|works/templates/|bootstrap_agentic_workspace\.sh$)` and runs `installer/build.py --check`.
  - `.github/workflows/workspace-ci.yml` is both **the shipped CI seed** and **this repo's CI**: it runs `scripts/workflow.py validate`, `build.py`, `tests/retrofit_smoke.sh` and `parallel-gate` (≈24/29/37/73).
  - `tests/retrofit_smoke.sh` reads `$REPO_ROOT/executors.toml` and `works/templates` (≈886/1196/1428/1508/1817).
- **The docs tree.**
  - `docs/` tracks `current/` (11 docs), `versions/`, `index.json` and `README.md`: workspace state, which moves.
  - It also tracks `retrofit-guide.md`, a product doc linked from the READMEs and `installer/wrapper.sh`, which stays tracked.
- **The nested installer** (`installer/main.py`).
  - Preflight is ≈670-715. It refuses a host that tracks a `workflow` path or has a non-empty `workflow/`.
  - The rename map (≈970-990) renames a shipped skill or agent that clashes with a host one to `wf-<name>`.
  - It writes host-side `.claude/skills/<name>/SKILL.md` (with a per-skill `.gitignore *`), `.claude/agents/*.md`, `.claude/settings.local.json` (an additive merge), `CLAUDE.local.md` (a managed block importing `@workflow/CLAUDE.workspace.md`) and the `info/exclude` block (≈1053/1095). The marker is `workflow/.agentic-nested.json`, tracked in the nested repo.
  - `--update` needs that marker plus `workflow/scripts/workflow.py` (≈702-705).
  - `installer/README.md:90` and `docs/current/decisions.md:121-132` say "this upstream repo stays at-root". Decision 4 supersedes that for this repo only.
- **The clash that forces relocation** (Decision 5). Today the live paths `.claude/skills/*`, `.claude/agents/*`, `.claude/settings.json` and `CLAUDE.md` **are** the tracked product sources, so installing nested here as is would:
  - rename every skill and agent to `wf-…`;
  - load the at-root `CLAUDE.md` contract beside the nested one;
  - fire the at-root `settings.json` hooks (`python3 scripts/workflow.py compact-*`) beside the nested ones.
- **Environment.** `git filter-repo` is not installed (git 2.45.2): consider `git filter-branch --index-filter` or `--subdirectory-filter`, `git subtree split`, or `pip install git-filter-repo` **into a scratch venv**. `.claude/worktrees/` exists here and is empty; `git worktree list` shows only `main`.
- **State in flight.** Active phases are P32, P33 and P34 (done, owing consolidation) and P35 (this one). P33 ran on a `phase/P33-…` branch, which matters for history and for D57's stale listing.

## What each answer must settle

- **(a) The source tree.**
  - Name it (e.g. `payload/` or `src/`; if only the operator can choose the name, it goes on `## Operator Questions` with a recommendation) and give its full layout.
  - Settle which files must move out of a live path (`.claude/skills`, `.claude/agents`, `.claude/settings.json`, `CLAUDE.md`, `works/templates`, the `executors.toml` seed, `.github/workflows/workspace-ci.yml`, `.gitattributes`) and whether `scripts/workflow.py` must move too. A root `scripts/workflow.py` with no marker beside it runs at-root against a root with no `works/`: harmless, or a trap?
  - Give the exact edits for `build.py`, `.githooks/pre-commit`, `tests/retrofit_smoke.sh`, the upstream CI and the README dev notes, and show on the scratch clone that `build.py` produces a **byte-identical** `bootstrap_agentic_workspace.sh` after the move. The embedded emit paths must not change; only the source paths change.
- **(b) What stays at the root.**
  - The tracked list after conversion.
  - A short upstream `CLAUDE.md` for developing the product: the upstream build and release rules (today the contract's "Upstream repo only" bullet and `installer/README.md:20-28`), and that the workspace is driven through `workflow/`.
  - Whether the shipped contract keeps its "Upstream repo only" bullet.
  - This repo's own CI (a separate upstream workflow, distinct from the shipped seed).
- **(c) Keeping the history.**
  - Extract `works/`, the workspace's `docs/` (not `retrofit-guide.md`) and `executors.toml` with their history into a repo whose root holds them at the same relative paths (the nested layout keeps `works/` and `docs/` at the nested repo root).
  - Settle how the installer's engine, marker, `CLAUDE.workspace.md` and rewritten templates join that history: install first and merge the history in, or build the history first and install over it. Prove one end to end.
  - Settle what happens to `phase/P33-…` and to the P33 execution block (D57).
  - Record the commit counts before and after, and a `git log --follow` spot check on one file in `works/phases/` and one in `docs/versions/`.
- **(d) The install.**
  - Run the **built** installer (from the scratch clone's own relocated build) into the scratch clone as its host. Show that no clash renames happen, the exclude block is written, `CLAUDE.local.md` is written, and `settings.local.json` merges with the existing one.
  - Run the nested engine (`python3 workflow/scripts/workflow.py next`, `validate`, `docs`, `phase-scope P35`) against the moved state, and show it sees P32-P35 as before.
  - Then run `--update` once to prove the release path.
- **(e) The upstream CI after conversion.** Run the new upstream CI's commands by hand on the scratch clone (`build.py --check`, `tests/retrofit_smoke.sh` **as the only command in its Bash call**) and show they pass with no root `works/`.
- **(f) Order of operations.**
  - The exact sequence for the real conversion slice, as numbered steps with the commit after each, so that at every step the pre-commit hook passes and nothing is lost.
  - Where P35's own folder lands (`workflow/works/phases/active/P35`), how the orchestrator drives the rest of P35 (its `REVIEW`) after the switch, and the point where the operator restarts Claude Code at the repo root (a `pending` stop).
  - What the operator's `~/.claude/projects/<this path>/memory` is affected by: nothing, since the path is unchanged? Confirm.
  - Commit attribution in the host repo after conversion (`nested-convention` for this repo: Co-Authored-By allowed).
- **(g) Rollback.**
  - A tag or backup taken before the first step, and the exact commands that restore the at-root layout from any step.
  - Prove one rollback on the scratch clone.

## Setup (scratch only)

`SCRATCH=$(mktemp -d /private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/1f05045c-d99c-4193-ad79-5557ad4128a8/scratchpad/p35s3.XXXX)`, then `git clone /Users/sugang/projects/personal/bootstrap_agentic_workspace.sh "$SCRATCH/repo"`. It is a clone, so this checkout's index, hooks and branches are untouched. Do every experiment there, and set `core.hooksPath .githooks` in the clone to exercise the hook.

**Lessons from P35.S2:**
- This session's permissions deny `rm -rf`. Do not try it or route around it: leave `$SCRATCH` in place (it is inside the session scratchpad) and list it in `result.md`'s deviations.
- Run **no headless `claude -p` probes**. They ran the operator's global Stop hook, which sent ntfy pushes, and this research needs no Claude Code facts.

## Deliverables

- `result.md`: verdict block first, then each of (a)-(g) with its evidence and trimmed command logs, then a **proposed cut for DECOMP2** covering the conversion: slices, kind/risk with the named trigger (deletion and history make the real conversion `high`), order relative to the worktree build and the release, each slice's validation, and the `pending` restart stop.
- `phase.md`, under budget:
  - a `(from P35.S3, for P35.DECOMP2)` Note, the condensed plan (one line per question, plus the numbered order and the rollback);
  - `## Operator Questions` for an operator-only choice (the source-tree name, if it really is one);
  - `## Decisions` only for what the evidence settles beyond doubt;
  - `## Now` rewritten.

## Must not

Edit any product file in this checkout, commit, push, change this checkout's git config, hooks, branches or index, move workflow state beyond your own `phase.md` and `result.md`, install anything outside the scratch dir or a scratch venv, run `claude` (headless or otherwise), chain `tests/retrofit_smoke.sh` with other commands, or pre-fill DECOMP2's `plan.md`.

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
