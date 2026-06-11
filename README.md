# bootstrap_agentic_workspace.sh

> An opinionated, portable workspace that makes coding agents — Claude Code, Codex, or any CLI
> agent — work like a disciplined team: **decompose** the work, **remember** what they learn, and
> **prove** it before moving on.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

One shell script scaffolds a complete workspace: a compact agent **contract**, a persisted
**phase → slice** state machine, **versioned** documentation, and the same operations exposed as
**Agent Skills** in both Claude Code and Codex.

## Contents

- [What is this?](#what-is-this)
- [Quickstart](#quickstart)
- [How it works](#how-it-works)
- [Project structure](#project-structure)
- [How I work with coding agents](#-how-i-work-with-coding-agents)
- [Related / inspired by](#related--inspired-by)
- [Contributing](#contributing)
- [License](#license)

## What is this?

`bootstrap_agentic_workspace.sh` is a single, dependency-light script that turns any empty
directory into a structured home for agent-driven work. Inside, a coding agent doesn't just get a
prompt and improvise — it works under a compact contract ([`CLAUDE.md`](CLAUDE.md) /
[`AGENTS.md`](AGENTS.md)) that says how to break work down, where to write things, and what "done"
means.

**The problem it solves.** Coding agents are capable but forgetful. Across a long task they lose
context when the conversation compacts, redo work they already did, silently overwrite earlier
decisions, and sprawl sideways into whatever looks interesting. Point three different agents (or
three sessions of the same agent) at one repo and you get three different conventions.

**The approach.** This workspace gives agents three things they normally lack:

- **Routing** — there is always a single, machine-checkable answer to "what runs next?"
  ([`works/state.json`](works/) and the generated backlog).
- **Durable, shared memory** — a per-phase notebook plus append-only versioned docs carry what each
  step learned forward to the next, so knowledge survives compaction and hand-offs between tools.
- **Review gates** — work isn't "done" until a read-only reviewer checks it against the phase's
  objective.

It is **cross-tool by design**: the same commands and skills work natively in Claude Code and in
Codex, with a plain `python3 scripts/workflow.py …` fallback that works anywhere (including CI).

**Who runs what.** You — the **operator** — drive everything by talking to your agent: slash
commands like `/do-next-slice` (`$do-next-slice` in Codex), or plain requests like *"make a phase
for X"*. The **agent** types every actual command — `python3 scripts/workflow.py …`, the git
commits, the validation runs (`.claude/settings.json` pre-approves the workflow script, so none of
it prompts). Your job is judgment: review results, clear `pending` hand-offs, decide when to
archive. Every shell block in this README is something the agent runs on your behalf — except the
one-time bootstrap below, the only command you might ever type yourself.

> This repo runs on its own workflow. The [`works/`](works/) and [`docs/`](docs/) trees you see
> here are it dogfooding the very system it scaffolds — this README was itself written as a phase.

## Quickstart

**Prerequisites:** `python3 >= 3.8` and a POSIX shell (`sh`, `bash`, or `zsh`). `git` is optional
(only needed to clone). No other dependencies.

### 1. Get the script and scaffold a workspace (recommended)

```sh
# get the script
git clone https://github.com/leetusik/bootstrap_agentic_workspace.sh.git

# scaffold a fresh workspace into an empty directory
mkdir my-project && cd my-project
sh ../bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh . \
  --name "My Project" \
  --summary "What this project is, in one sentence."
```

`TARGET_DIR` (the `.` above) is where the workspace is created; it defaults to the current
directory.

### Or, the one-liner convenience

Pipes the script straight from GitHub into your shell — convenient, but read it first if you're
cautious about piping remote scripts:

```sh
mkdir my-project && cd my-project
curl -fsSL https://raw.githubusercontent.com/leetusik/bootstrap_agentic_workspace.sh/main/bootstrap_agentic_workspace.sh | sh -s -- .
```

### Already have a project? Retrofit it

The plain bootstrap is for an **empty** directory. To add the workspace to a repo
that already has code, docs, or git history, use the **non-destructive retrofit**
path — it only adds the workspace's files, skips anything you already have, and
never clobbers your work:

```sh
# from the root of your existing repo
sh /path/to/bootstrap_agentic_workspace.sh . --into-existing \
  --name "My Project" --summary "One sentence." \
  --phase-name "Adopt workspace + capture current state" \
  --phase-objective "Install the workspace and decompose the first real change, building on the existing code."
```

or drive it with an agent via the `/retrofit` skill (`$retrofit` in Codex). See
the **[Retrofit Guide](docs/retrofit-guide.md)** for the full procedure,
collision policy, and how the first phase is seeded from your project's current
state.

### 2. Hand it to your agent

Setup was the last time you needed a terminal. Open the directory in Claude Code or Codex and
drive by talking:

```
/do-next-slice      # Claude Code — complete exactly one slice, then stop
$do-next-slice      # Codex — the same skill
```

— or just ask in plain language: *"make a phase for X"*, *"archive the done phases"*. The agent
runs the workflow commands, commits at slice boundaries, and stops at `pending` hand-offs for your
review.

### Options

| Option | Default | Purpose |
|---|---|---|
| `[TARGET_DIR]` | current directory | Where to scaffold the workspace |
| `--name NAME` | `New Project` | Project name |
| `--summary TEXT` | placeholder | One-sentence project summary |
| `--phase-name NAME` | `Bootstrap Intake` | Name of the seeded `P1` phase |
| `--phase-objective TEXT` | placeholder | Objective of the seeded `P1` phase |
| `--force-empty-ok` | off | Allow scaffolding into a directory that has extra, non-managed files |
| `--into-existing` | off | Non-destructively retrofit into an existing repo (see the [Retrofit Guide](docs/retrofit-guide.md)) |
| `-h`, `--help` | — | Show help and exit |

Both `--flag value` and `--flag=value` forms work.

### What gets created

- [`CLAUDE.md`](CLAUDE.md) + [`AGENTS.md`](AGENTS.md) — the equivalent per-tool routing contracts.
- [`scripts/workflow.py`](scripts/workflow.py) — the one manager that drives all state.
- `.claude/` + `.agents/` — the 12 Agent Skills, mirrored for both tools (plus a read-only
  `phase-reviewer` subagent for Claude Code), and `.codex/config.toml`.
- [`docs/`](docs/) — a versioned, fullstack documentation set (11 categories) with generated
  `current/` snapshots.
- [`works/`](works/) — the state machine: phase **`P1`** seeded with a `DECOMP` and a `REVIEW`
  slice, a `deferred/` area, generated dashboards, and `state.json`.

**Safety.** The script refuses to scaffold into a non-empty directory unless you pass
`--force-empty-ok` (a few harmless files like `.git`, `README`, and `LICENSE` are tolerated), and
it refuses to overwrite managed workflow files that already exist. It is safe to re-run only into a
fresh workspace. To add the workspace to a repo that *already* has content, use the
non-destructive `--into-existing` retrofit instead — see the
[Retrofit Guide](docs/retrofit-guide.md).

## How it works

Everything is organized as **phases** made of **slices**, driven by one script.

- **Phase** (`P1`, `P2`, …) — a unit of work with an objective. A new phase starts with only two
  slices: a `DECOMP` (decomposition) and a `REVIEW`.
- **Slice** (`P1.DECOMP`, `P1.S1`, `P1.F1`, `P1.REVIEW`) — an ordered step within a phase. The
  `DECOMP` slice is what breaks the phase into the middle slices; each slice fills its own `plan.md`
  before working and writes a `result.md` when done.
- **Deferred job** (`D1`, `D2`, …) — a parked idea. It sits outside the active backlog and never
  changes what runs next until you explicitly promote it.

The contract boils down to one line:

> **Backlog routes. Slice folder explains. Result summarizes. Docs are versioned durable truth.**

### One manager

Every operation runs through [`scripts/workflow.py`](scripts/workflow.py) — typed by the
**agent**, not by you. The bare CLI is the universal fallback: anything that can run a shell —
another agent, CI — drives the workspace with the exact same commands:

| Command | What it does |
|---|---|
| `next` | Show the current / next slice |
| `new-phase --phase P2 --name … --objective …` | Create a phase (seeds `DECOMP` + `REVIEW`) |
| `new-slice --phase P1 --slice P1.S1 --name …` | Add a slice |
| `start-slice P1.S1` / `finish-slice P1.S1` | Move a slice through its lifecycle |
| `review-phase P1 --verdict pass` | Record a phase review |
| `doc-new-version --doc backend --summary … --source P1.S1` | Cut a new durable doc version |
| `defer-job --title … --reason … --trigger …` | Park a deferred job |
| `promote-deferred D1 --phase P1 --slice P1.S2` | Promote a deferred job into a slice |
| `validate` | Check workspace integrity |

The full command list lives in [`CLAUDE.md`](CLAUDE.md).

### The same operations as Agent Skills

The common workflows also ship as **12 Agent Skills**, mirrored in `.claude/skills/` (Claude Code:
`/slash` commands) and `.agents/skills/` (Codex: `$skill`), so the same step works natively in
either tool:

| Skill | What it does |
|---|---|
| `do-next-slice` | Complete exactly one slice, then stop |
| `do-whole-phase` | Finish the active phase end-to-end, including its review |
| `review-phase` | Review a phase and record a `pass` / `changes_requested` / `blocked` verdict |
| `doc-new-version` | Create a new versioned durable doc instead of patching the current one |
| `defer-job` | Park work as a deferred job, outside active selection |
| `deferred` | Rebuild and show the deferred-jobs dashboard |
| `promote-deferred` | Promote a deferred job into an active phase or slice |
| `archive-phase` | Archive review-passed phases (normally batched via `archive-all`) |
| `rotate-backlog` | Archive every currently-done phase, leaving in-progress phases active |
| `rebuild-workflow` | Rebuild generated dashboards, indexes, and doc snapshots, then validate |
| `commit` | Group pending changes into focused conventional commits |
| `retrofit` | Non-destructively adopt this workspace into an existing repo |

In Claude Code, a read-only **`phase-reviewer`** subagent performs phase reviews. Skills are
**explicit-invocation only** — agents don't fire them on their own. They are the **operator's
interface**: you type the slash command; the agent does everything it implies.

### Read order

When an agent picks up work, it reads in this order — and no further by default:

1. [`docs/current/*.md`](docs/current/) — the fullstack doc set
2. [`docs/index.json`](docs/index.json)
3. [`works/state.json`](works/state.json), [`works/backlog.md`](works/backlog.md), and
   [`works/deferred.md`](works/deferred.md)
4. The **active** phase folder and **active** slice folder only

Archived phases and old doc versions are history; they're not read by default.

## Project structure

```
.
├── CLAUDE.md / AGENTS.md          # equivalent per-tool routing contracts
├── bootstrap_agentic_workspace.sh # the scaffolding script (self-contained)
├── scripts/
│   └── workflow.py                # the one manager that drives all state
├── docs/
│   ├── current/                   # generated snapshots — never hand-edit
│   ├── versions/<doc>/vNNNN_*.md  # append-only durable doc history (11 categories)
│   └── index.json                 # maps each doc to its latest version
├── works/
│   ├── state.json                 # current / next pointer (canonical)
│   ├── backlog.md / deferred.md   # generated dashboards (lean: IDs & pointers only)
│   ├── phases/
│   │   ├── active/<P>/            # phase.json, phase.md (notebook), slices/<id>/
│   │   └── archived/             # finished phases
│   └── deferred/                  # one folder per parked job
├── .claude/
│   ├── skills/                    # 12 Agent Skills (Claude Code)
│   ├── agents/phase-reviewer.md   # read-only review subagent
│   └── settings.json              # pre-approves workflow.py; denies push & rm -rf
├── .agents/skills/                # the same 12 skills, mirrored for Codex
└── .codex/config.toml             # Codex project config
```

## ⭐ How I work with coding agents

I don't hand an agent a vague task and hope. The whole reason this workspace exists is to force a
few habits that make agents reliable on long, real work — not just impressive in a demo. These are
the ones I lean on; the [contract in `CLAUDE.md`](CLAUDE.md) is how they're actually enforced.

1. **Decompose before you build.** The first move on any phase is a decomposition slice, not code.
   I make the agent break the work into small, ordered slices and write the plan down — planning is
   its own step with its own artifact. A task you can't slice is a task you don't understand yet.

2. **Give agents durable, shared memory.** Conversations compact and agents forget, so I never keep
   important context only in the chat. Every phase has a notebook (`phase.md`) that each slice reads
   on the way in and appends to on the way out, and decisions land in versioned docs. The next
   slice — or the next *tool* — starts from what the last one learned.

3. **Make every slice prove itself.** A slice writes its `plan.md` before it touches anything and a
   `result.md` when it's done, and the phase doesn't close until a read-only reviewer checks it
   against the objective. "It runs" isn't the bar; "it was reviewed and matches what we set out to
   do" is.

4. **Version decisions; never overwrite them.** Docs are append-only versions, not files you edit in
   place — each new version carries the slice that produced it. So the history of *what we decided
   and why* is always recoverable, and the generated snapshots stay read-only on purpose.

5. **Park distractions; don't chase them.** Mid-slice, every shiny idea is a threat to the slice.
   Instead of following it, I drop it into a deferred job that sits outside the backlog and changes
   nothing until I promote it on purpose. Focus becomes a property of the system, not of my
   willpower.

6. **Commit at every clean boundary.** One slice is one reviewable, conventional commit. A small,
   legible history means the next agent — or future me — can actually read what happened and bisect
   when something breaks.

None of this is tool-specific: one manager (`scripts/workflow.py`) plus skills mirrored into
`.claude/` and `.agents/` mean Claude Code, Codex, or a plain CLI agent all follow the same
contract — so switching tools never means switching conventions.

## Related / inspired by

A quick map of the neighborhood. The combination this workspace bundles — a persisted
phase/slice/deferred state machine, versioned durable docs, parallel cross-tool `.claude/` +
`.agents/` skills, and a single bootstrap script — shows up *piece by piece* across the projects
below, but I wanted them together in one place. (That framing is my own editorial positioning, not a
scorecard, and star counts move too fast to quote.)

- **Workflow / spec-driven development**
  - [GitHub Spec Kit](https://github.com/github/spec-kit) — spec-driven scaffolding for agent workflows.
- **Cross-tool skills**
  - [wshobson/agents](https://github.com/wshobson/agents) — a collection of reusable agent subagents/skills.
- **The `oh-my-X` lineage** (config/framework kits in the oh-my-zsh tradition)
  - [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
  - [claude-forge](https://github.com/sangrokjung/claude-forge)
  - [oh-my-openagent](https://github.com/code-yeongyu/oh-my-opencode)
  - [oh-my-customcode](https://github.com/baekenough/oh-my-customcode) — name-lineage kin.
  - [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) — the shell-framework original the naming riffs on.
- **Subagent & config kits**
  - [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — a curated catalog of Claude Code subagents.
  - [dotclaude](https://github.com/poshan0126/dotclaude) — a personal Claude Code config kit.
  - [centminmod/my-claude-code-setup](https://github.com/centminmod/my-claude-code-setup) — a personal Claude Code setup.

## Contributing

This repo dogfoods its own workflow, so contributing means *using* it — through your agent:

1. Open a phase: ask your agent — *"make a phase for \<your change\>"*. It runs
   `python3 scripts/workflow.py new-phase …`, which seeds only `DECOMP` + `REVIEW`, and stops there.
2. Execute it: type `/do-next-slice` or `/do-whole-phase` (Claude Code), the matching `$skill`
   (Codex), or let any agent run the `workflow.py` commands directly. The `DECOMP` slice breaks the
   phase into slices.
3. Review it: the phase closes only on a passing review — the agent records it with
   `python3 scripts/workflow.py review-phase P2 --verdict …`; you read the result and approve.

A few house rules:

- **Commits** follow `type(scope): summary` — imperative mood, no trailing period (types: `feat`,
  `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`). Commit per completed
  slice; branch off `main` first.
- **Keep [`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) in sync** — they're equivalent
  contracts, one per tool. If you change a workflow rule, change both.
- **Never hand-edit `docs/current/*.md`** (they're generated) and never patch old files under
  `docs/versions/`. Create a new version with `doc-new-version` instead.

The contract in [`CLAUDE.md`](CLAUDE.md) is the source of truth; this README only points at it.

## License

Licensed under the [Apache License 2.0](LICENSE).
