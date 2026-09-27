# Kiro sidecar — overrides for running this workspace from Kiro CLI

This workspace is primarily driven from Claude Code. `CLAUDE.md`, `.claude/skills/`, `.claude/agents/`,
`scripts/workflow.py` and `executors.toml` are the source of truth and are **never edited from Kiro**.
Kiro runs a light subset of the same workflow on the same state. Everything in `CLAUDE.md` and the
`.claude/skills/*/SKILL.md` files applies, **except where this file overrides it**. Where they conflict,
this file wins.

## Scope

Supported from Kiro (as `/name` skills in `.kiro/skills/`, each one a thin wrapper around the matching
`.claude/skills/<name>/SKILL.md`):

- `create-phase`, `do-next-slice`, `do-whole-phase` (auto mode only), `defer-job`, `deferred`,
  `promote-deferred`, `commit`
- any plain `python3 scripts/workflow.py <command>` the operator asks for (`next`, `validate`, `docs-debt`, ...)

**Not supported from Kiro. Stop and tell the operator to run these in Claude Code:**

- `gate` and `plan only` modes (Kiro has no plan-mode tool)
- phase worktrees: `worktree` mode, `parallel-start`, the `parallel-phase` integration. If a phase already
  carries an `execution` block with `mode: "parallel"`, don't touch it.
- `co-work` design slices, `design-cowork`, DesignSync (Kiro doesn't have it). If the next slice is
  `kind: co-work`, STOP before starting it and hand off to Claude Code.
- `/explain`, `/retrofit`, `/update-workspace`, `sync-agents`, and editing `executors.toml`

Workflow skills are explicit-invocation only (the operator types `/name`). Never load or run one on your own
initiative. The `create-phase` rule in `CLAUDE.md` still holds.

## Tool translation

| Claude Code (in the skill text) | Kiro |
|---|---|
| Read / Edit / Write / Glob / Grep / Bash | `read` / `write` / `write` / `glob` / `grep` / `shell` |
| Agent tool, background dispatch, completion notification | the `subagent` tool, `mode: "blocking"`, exactly **one stage** per call, `role: "slice-executor-high"` |
| `EnterPlanMode` / `ExitPlanMode` / harness plan file | none. Plan inline and `write` `plan.md` in full |
| `EnterWorktree` / `ExitWorktree` | none (see Scope) |
| `DesignSync` | none (see Scope) |
| Explore / read-only research agent | none. No idle-window preparation in this sidecar |

## Orchestrator overrides

1. **Auto mode, always, including decomposition.** Run every slice the way an explicit `auto` invocation
   does: plan inline, `write` the slice's `plan.md` verbatim and in full, dispatch, validate, finish, commit,
   next. The v40 decomposition gate is **off** here: `DECOMP` / `DECOMP2` are planned inline too, with no
   approval pause. The safety halts all still apply: `pending`, `needs_operator`, `blocked`, a failed or
   empty return, and an open acceptance gate.
2. **Mode words.** If the operator's arguments contain `gate`, `plan only`, `worktree`, `in a worktree`,
   `in parallel` or `on its own branch`, don't run anything. Say this Kiro sidecar only supports auto mode
   on the current checkout, and point them to Claude Code. The words `auto` and `unattended` are fine (they're
   the default here).
3. **No idle-window preparation.** Dispatch is blocking. Wait for the executor, then continue.
4. **One executor tier.** Every delegated slice (decomposition, research, implementation, fix, review) goes
   to `slice-executor-high` (claude-opus-5.5), whatever its `risk` says. There's no `mid` tier and no
   escalation path, so treat an `escalate` verdict as a failed top-tier return. Keep rating `risk`
   deliberately during decomposition exactly as `CLAUDE.md` says, because Claude Code still reads those ratings.
   Record reviews with `--reviewer slice-executor-high`.
5. **How to dispatch.** A single `subagent` call with one stage: `name` = the slice id with dots replaced by
   dashes, `role` = `slice-executor-high`, and a `prompt_template` that gives:
   - the slice id
   - the absolute slice folder path
   - the absolute phase folder path
   - the repo root
   - one line: "Execute this slice per your instructions in `.claude/agents/slice-executor-high.md`: `plan.md` is your spec. Write `result.md` verdict-block-first, edit `phase.md`, then call `summary` with the verdict block verbatim as `taskResult`."

   Don't paste the plan. The executor reads it.
6. **The verdict of record is the head of `result.md`.** After the subagent returns, read the summary it
   gave and the first ~40 lines of the slice's `result.md`. If `result.md` is missing, has no verdict block,
   or the verdict contradicts itself, treat it as a **failed return from `slice-executor-high`**: don't
   finish, don't commit, report it, and STOP. Kiro subagents have a fixed turn limit, so a large slice can
   come back truncated. Say that's the likely cause and suggest re-running the slice (Kiro or Claude Code).
   Never finish a slice on a partial result.
7. **Commits.** The orchestrator commits at every clean slice boundary, following the Commit Convention in
   `CLAUDE.md`. Stage explicit paths only (`git add -- <paths>`, never `git add -A` or `git add .`). No
   trailer is required, and never add a `Co-Authored-By: Claude …` trailer, since Claude Code didn't do the
   work. Never push. `.kiro/` is tracked, but slice commits don't touch it. Change the sidecar only when the
   operator asks, and commit that change on its own as `chore(kiro): ...`.
8. **Sidecar ownership.** `.kiro/` ships with the workspace (since v44), and `/update-workspace` refreshes it:
   the agents, the skill wrappers and this file are overwritten from upstream, while `.kiro/settings/cli.json`
   is only created if it's missing. To keep a local change such as a different executor `model`, re-apply it
   after each update. In the upstream bootstrap repo (where `installer/` exists) `.kiro/` is embedded
   machinery, so `CLAUDE.md`'s rebuild rule applies to it: `python3 installer/build.py`, then commit the
   artifact together with the change.
9. **Retrofitted repos.** When the repo's own `CLAUDE.md` points to `CLAUDE.workspace.md`, that file is the
   workspace contract. Read it wherever this file or a skill says `CLAUDE.md`.
