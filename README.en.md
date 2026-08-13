# bootstrap_agentic_workspace.sh

**English** | [한국어](README.md)

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
- [Example workflow](#example-workflow)
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
- **Review gates** — work isn't "done" until a phase review (run by the executor in a fresh,
  isolated context that never edits source) checks it against the phase's objective and consolidates
  its doc versions. A verdict short of `pass` stops there and hands its findings back.

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

> **You never type a `python3` command yourself.** The one-time bootstrap below is the only
> command you ever run; every workflow command (`python3 scripts/workflow.py …`) is typed and
> run by the **agent**. You drive everything in plain natural language.

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
  --name "My Project" --summary "One sentence."
```

or drive it with an agent via the `/retrofit` skill (`$retrofit` in Codex). See
the **[Retrofit Guide](docs/retrofit-guide.md)** for the full procedure and
collision policy.

### Keeping an adopted workspace up to date

The workspace machinery — the engine, skills, subagents, contract, and templates —
keeps evolving upstream. To pull the latest into a repo that already has it, use the
**update** path. It overwrites only the machinery and **preserves your own work**:
everything under `works/` except templates (your phases, slices, deferred jobs, and
state) and all of `docs/`.

```sh
# preview exactly what would change — writes nothing
sh /path/to/bootstrap_agentic_workspace.sh . --update --dry-run

# apply it
sh /path/to/bootstrap_agentic_workspace.sh . --update
```

Or drive it with an agent via the `/update-workspace` skill (`$update-workspace` in
Codex): it clones the latest upstream, shows you the dry-run change-list, applies on
your approval, runs `validate`, and records the synced commit in
`works/.workspace-version.json`. It never commits — you review the diff and commit
when ready. (For *first-time* adoption use `--into-existing` / `/retrofit` instead.)

### 2. Hand it to your agent

Setup was the last time you needed a terminal. The workspace starts with **no phases** — open the
directory in Claude Code or Codex and create your first one:

```
/create-phase <your first task>      # Claude Code
$create-phase <your first task>      # Codex — the same skill
```

— or just ask in plain language: *"make a phase for X"*. The agent runs the workflow commands,
commits at slice boundaries, and stops at `pending` hand-offs for your review. See
[Example workflow](#example-workflow) for the full loop.

### Options

| Option | Default | Purpose |
|---|---|---|
| `[TARGET_DIR]` | current directory | Where to scaffold the workspace |
| `--name NAME` | `New Project` | Project name |
| `--summary TEXT` | placeholder | One-sentence project summary |
| `--force-empty-ok` | off | Allow scaffolding into a directory that has extra, non-managed files |
| `--into-existing` | off | Non-destructively retrofit into an existing repo (see the [Retrofit Guide](docs/retrofit-guide.md)) |
| `--update` | off | Update an already-installed workspace's machinery to this version (preserves your `works/` and `docs/`) |
| `--dry-run` | off | With `--update`, preview the change-list without writing anything |
| `-h`, `--help` | — | Show help and exit |

Both `--flag value` and `--flag=value` forms work.

### What gets created

- [`CLAUDE.md`](CLAUDE.md) + [`AGENTS.md`](AGENTS.md) — the equivalent per-tool routing contracts.
- [`scripts/workflow.py`](scripts/workflow.py) — the one manager that drives all state.
- `.claude/` + `.agents/` — the 15 core Agent Skills, mirrored for both tools (`do-whole-phase` is
  Claude Code only), plus the two risk-routed `slice-executor`
  tier subagents for each tool (`.claude/agents/slice-executor-{mid,high}.md` — sonnet / opus at tiered efforts by default (the `economy` mode);
  `.codex/agents/` on gpt-5.6-terra / gpt-5.6-sol at high effort), `executors.toml` (seeded tier mode/model/effort config, applied with
  `sync-agents`), and `.codex/config.toml`.
- [`docs/`](docs/) — a versioned, fullstack documentation set (11 categories) with generated
  `current/` snapshots.
- [`works/`](works/) — the state machine, starting with **no phases**: a `deferred/` area,
  generated dashboards, and `state.json`. You create the first phase by talking to your agent
  (`/create-phase`).

**Safety.** The script refuses to scaffold into a non-empty directory unless you pass
`--force-empty-ok` (a few harmless files like `.git`, `README`, and `LICENSE` are tolerated), and
it refuses to overwrite managed workflow files that already exist. It is safe to re-run only into a
fresh workspace. To add the workspace to a repo that *already* has content, use the
non-destructive `--into-existing` retrofit instead — see the
[Retrofit Guide](docs/retrofit-guide.md).

## Example workflow

A typical flow — all of it in conversation with your agent:

```
/create-phase Add refund support to the billing module
```

The agent refines your intent, asks about anything ambiguous, gets your confirmation, and creates
the phase (seeding only `DECOMP` + `REVIEW`) — then stops. No decomposition, no code yet.

Then execute it at whichever pace you prefer:

```
/do-next-slice          # one slice — plans and runs it non-stop, then stops
/do-whole-phase         # the whole phase non-stop — no plan-approval pauses (safety halts still stop it)
/do-whole-phase gate    # the whole phase — pauses for your approval of each slice's plan
```

(`do-whole-phase` is Claude Code only — in Codex, repeat `$do-next-slice`.)

Track progress in [`works/backlog.md`](works/backlog.md) (the generated dashboard) and the active
phase folder under `works/phases/active/` (the phase notebook and slice folders) — or just ask the
agent, *"where are we?"*.

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
| `sync-agents` | Apply the `executors.toml` executor-tier mode/model/effort config to the agent files |
| `parallel-start <P>` … `parallel-teardown <P>` | Run a phase in parallel on its own branch + worktree, then integrate it back (see the `parallel-phase` skill) |
| `validate` | Check workspace integrity |

The full command list lives in [`CLAUDE.md`](CLAUDE.md).

### The same operations as Agent Skills

The common workflows also ship as **16 Agent Skills** in `.claude/skills/` (Claude Code:
`/slash` commands), all but one mirrored in `.agents/skills/` (Codex: `$skill`) — `do-whole-phase`
is Claude Code only — so the same step works natively in either tool:

| Skill | What it does |
|---|---|
| `create-phase` | Capture intent, then create a phase (seeds `DECOMP` + `REVIEW`); stops before decomposition |
| `do-next-slice` | Complete exactly one slice, then stop |
| `do-whole-phase` | Finish the active phase end-to-end, including its review _(Claude Code only — needs plan mode)_ |
| `review-phase` | Review a phase and record a `pass` / `changes_requested` / `blocked` verdict |
| `parallel-phase` | Run a phase in parallel on its own branch + worktree, and integrate it back: PR, quiet-point gate, merge, deferred doc consolidation, teardown |
| `doc-new-version` | Create a new versioned durable doc instead of patching the current one |
| `defer-job` | Park work as a deferred job, outside active selection |
| `deferred` | Rebuild and show the deferred-jobs dashboard |
| `promote-deferred` | Promote a deferred job into an active phase or slice |
| `archive-phase` | Archive review-passed phases (normally batched via `archive-all`) |
| `rotate-backlog` | Archive every currently-done phase, leaving in-progress phases active |
| `rebuild-workflow` | Rebuild generated dashboards, indexes, and doc snapshots, then validate |
| `commit` | Group pending changes into focused conventional commits |
| `retrofit` | Non-destructively adopt this workspace into an existing repo |
| `update-workspace` | Update an adopted workspace's machinery to the latest upstream, preserving your work |

> **Knowledge (phase explainers).** The `explain` skill ships with the workspace, for both tools.
> Explainers are interactive HTML documents saved to the knowledge service — produced on demand, not
> by the review: run `/explain` for a phase when you want one, and a passing review simply reports
> that none was written.
>
> **Setup happens on first use, and it asks first.** Run `/explain`; if no knowledge base is
> configured it offers to create one on the [hosted service](https://knowledge.hi2vi.com) — it asks
> for an email, installs the `knowledge` CLI, signs you up (or logs you in), and writes an org-level
> key to `~/.config/knowledge-kb/config.json` at mode 0600. Creating an account is an outward-facing
> action, so nothing happens until you say yes. One org key serves every repo, and each document's
> project defaults to the repo's directory name.
>
> Already have a knowledge base, hosted or self-hosted? Skip setup by exporting
> `KB_API_BASE_URL="https://knowledge.hi2vi.com"` and `KB_API_TOKEN="vk_..."` in `~/.zshenv`
> (sourced by every zsh invocation). Never a repo `.env` — neither Claude Code nor Codex auto-loads
> it, and a secret in a repo file risks being committed.
>
> **Codex caveat:** its `workspace-write` sandbox blocks outbound network by default, so both the
> setup and the save fail there — opt in with `[sandbox_workspace_write] network_access = true` in
> `~/.codex/config.toml`, which loosens all Codex workspace-write runs (your call); Claude Code needs
> nothing.
>
> **Alternative (Claude Code plugin):** the same feature also lives as a standalone plugin in the
> [knowledge repo](https://github.com/leetusik/knowledge) —
> `/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge` →
> `/knowledge:setup` once, then `/knowledge:explain <topic>`. That is a separate namespace from this
> workspace's `/explain`; you do not need both.

Both tools delegate the heavy lifting to a **`slice-executor`** subagent in one of two capability
tiers, picked by each slice's risk: `slice-executor-mid` (sonnet by default — a one-line, or few-line,
code edit, or docs: slices rated `risk: low`) and `slice-executor-high` (opus — decomposition,
essentially all code writing including every cross-file change, anything not rated `low`, and the phase review, which it runs in
a fresh context that never edits source, validating the phase and — only on a pass — consolidating its
doc versions; a `changes_requested` or `blocked` verdict stops there and hands the findings back).
Risk is two values, `low` and `high`, defaulting to `high` — only an exact `low` routes down, so an
unset or unrecognized value always lands on the thorough tier. When the mid executor hits something
beyond its depth it returns an `escalate` verdict; the orchestrator folds the findings into the plan
and re-dispatches to `slice-executor-high` (once per slice) — so trivial slices run cheap without
capping quality. Tier models and efforts are configurable via the repo-root
`executors.toml` — a top-level `mode` preset (`economy`, the default, at
sonnet@high / opus@high; `flex` raises those to sonnet@xhigh / opus@xhigh) plus
per-tier overrides (seeded with commented defaults; seed-once —
updates never overwrite it), applied with `python3 scripts/workflow.py sync-agents`. Workflow skills are
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

### Parallel phases (opt-in)

By default every phase runs on `main`, one at a time. When a phase and its predecessor genuinely
touch different ground, you can opt a `planned` phase into **parallel mode** instead of queueing it:
its own branch, its own git worktree, and its own orchestrator session, while `main` keeps working
the phase in front of it. This is opt-in per phase and never a default — a workspace that never uses
it behaves exactly as before, and the phase is the unit of parallelism (slices inside one phase stay
strictly sequential).

**The workspace suggests it, never assumes it.** `new-phase` hints when another phase is already
`in_progress`; `next` hints when a `planned` phase is waiting behind one that's mid-flight. Both name
the opt-in command; queueing normally is always a valid answer.

**Opting in.** `parallel-start <P> [--worktree PATH] [--slug S]` stamps the phase, cuts
`phase/P<N>-<slug>` off a commit that carries the stamp, and adds a git worktree for it (never a
plain clone on your own machine — a teammate can instead clone the repo and check the branch out).
From there, open a second agent session in that worktree and drive the phase as usual
(`/do-whole-phase`, `/do-next-slice`) — selection and `pending` are stream-scoped, so each checkout
sees only its own phase.

**Working in two streams.** `parallel-status` shows every stream's state from any checkout — this
one's pointer plus each parallel phase's branch, worktree, and slice progress — without switching
branches. A parallel phase's review defers its doc-version consolidation to a serialized post-merge
step on `main`, instead of versioning docs on the branch.

**Integrating back.** Once a parallel phase's review passes, the agent runs the integration itself:
`parallel-gate <P>` checks the quiet-point (the branch's phase done + `main` between phases), then
push → PR → CI → merge → `parallel-merge-finish` (regenerates the shared dashboards) → doc
consolidation → `parallel-consolidated <P>` → `parallel-teardown <P>` retires the worktree and
branch. A closed gate stops the sequence with a report instead of merging. CI
(`.github/workflows/workspace-ci.yml`) runs `validate` on every push and PR, plus a `parallel-gate`
check on `phase/*` pull requests.

See the [`parallel-phase`](.claude/skills/parallel-phase/SKILL.md) skill (`/parallel-phase` in
Claude Code, `$parallel-phase` in Codex) for the full lifecycle, and [`CLAUDE.md`](CLAUDE.md) for the
command reference.

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
│   ├── skills/                    # 16 Agent Skills (Claude Code)
│   ├── agents/                    # slice-executor tiers mid/high (implement slices + run the review)
│   └── settings.json              # pre-approves workflow.py; denies force-push & rm -rf
├── .agents/skills/                # the same skills, mirrored for Codex (minus do-whole-phase)
├── .codex/
│   ├── agents/                    # slice-executor tiers (Codex, gpt-5.6-terra / gpt-5.6-sol at high effort)
│   └── config.toml                # Codex project config
└── .github/
    └── workflows/
        └── workspace-ci.yml       # CI: validate on push/PR; parallel-gate job on phase/* PRs
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
   `result.md` when it's done, and the phase doesn't close until a fresh-context review checks it
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
phase/slice/deferred state machine, versioned durable docs, mirrored cross-tool `.claude/` +
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
2. Execute it: type `/do-next-slice` or `/do-whole-phase` (Claude Code), `$do-next-slice`
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
