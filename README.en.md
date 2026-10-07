# bootstrap_agentic_workspace.sh

**English** | [한국어](README.md)

> An opinionated, portable workspace that makes Claude Code work like a disciplined team:
> **decompose** the work, **remember** what it learns, and **prove** it before moving on.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

One shell script scaffolds a complete workspace: a compact agent **contract**, a persisted
**phase → slice** state machine, **versioned** documentation, and the same operations exposed as
**Agent Skills** in Claude Code.

## Contents

- [What is this?](#what-is-this)
- [Quickstart](#quickstart)
- [Private use in a repo you don't own (`--nested`)](#private-use-in-a-repo-you-dont-own---nested)
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
prompt and improvise — it works under a compact contract ([`CLAUDE.md`](CLAUDE.md)) that says how to
break work down, where to write things, and what "done" means.

**The problem it solves.** Coding agents are capable but forgetful. Across a long task they lose
context when the conversation compacts, redo work they already did, silently overwrite earlier
decisions, and sprawl sideways into whatever looks interesting. Point three different agents (or
three sessions of the same agent) at one repo and you get three different conventions.

**The approach.** This workspace gives agents three things they normally lack:

- **Routing** — there is always a single, machine-checkable answer to "what runs next?"
  ([`works/state.json`](works/) and the generated backlog).
- **Durable, shared memory** — a per-phase notebook plus append-only versioned docs carry what each
  step learned forward to the next, so knowledge survives compaction and hand-offs between sessions.
- **Review gates** — work isn't "done" until a phase review (run by the executor in a fresh,
  isolated context that never edits source) checks it against the phase's objective and verifies
  its list of doc changes; the docs themselves are consolidated later, in a
  [docs phase you start](#durable-docs-a-docs-phase-you-start). A verdict short of `pass` stops
  there and hands its findings back.

**One command surface.** The workflows ship as native Claude Code skills, and the exact same
operations are always reachable as plain `python3 scripts/workflow.py …` commands — so anything that
can run a shell (another agent, a script, CI) drives the same workspace.

**Who runs what.** You — the **operator** — drive everything by talking to your agent: slash
commands like `/do-next-slice`, or plain requests like *"make a phase for X"*. The **agent** types
every actual command — `python3 scripts/workflow.py …`, the git
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

or drive it with an agent via the `/retrofit` skill. See the
**[Retrofit Guide](docs/retrofit-guide.md)** for the full procedure and collision
policy. (Want it for yourself in a repo you don't own, with nothing the team can see? That is
[`--nested`](#private-use-in-a-repo-you-dont-own---nested).)

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

Or drive it with an agent via the `/update-workspace` skill: it clones the latest
upstream, shows you the dry-run change-list, applies on your approval, runs
`validate`, and records the synced commit in `works/.workspace-version.json`. It
never commits — you review the diff and commit when ready. Updates preserve your
existing `executors.toml` but refresh the generated `slice-executor` agent files, so
run `python3 scripts/workflow.py sync-agents` after every update to re-apply your
selected preset and overrides. (For *first-time* adoption use `--into-existing` /
`/retrofit` instead.)

### 2. Hand it to your agent

Setup was the last time you needed a terminal. The workspace starts with **no phases** — open the
directory in Claude Code and create your first one:

```
/create-phase <your first task>
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
| `--nested` | off | Private install into a host repo you don't own: the workspace lives in an untracked nested repo `workflow/`, and the host's tracked files never change (see [Private use](#private-use-in-a-repo-you-dont-own---nested)); combine with `--update` to refresh it, never with `--into-existing` |
| `--dry-run` | off | With `--update`, preview the change-list without writing anything |
| `-h`, `--help` | — | Show help and exit |

Both `--flag value` and `--flag=value` forms work.

### What gets created

- [`CLAUDE.md`](CLAUDE.md) — the compact routing contract every agent session works under.
- [`scripts/workflow.py`](scripts/workflow.py) — the one manager that drives all state.
- `.claude/` — the 18 Agent Skills (`/slash` commands), the two risk-routed `slice-executor` tier
  subagents (`.claude/agents/slice-executor-{mid,high}.md`, with economy/flex model matrices
  selected by `executors.toml` and applied with `sync-agents`), the `design-drafter` design
  subagent (it follows the high tier), and a `settings.json` that pre-approves the workflow script.
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

## Private use in a repo you don't own (`--nested`)

**When to use it.** You work in a company or team repo whose team does not use this workspace, and
you want to use it strictly for yourself. `--nested` leaves **no footprint**: no branch, no tracked
file, no CI file, no `.gitattributes`, no `docs/`, and nothing in any PR diff. (Retrofit, by
contrast, adds the workspace's files to the repo for everyone who clones it.)

**Install.** Point the installer at the host repo's root (a git work tree):

```sh
sh /path/to/bootstrap_agentic_workspace.sh /path/to/host-repo --nested
```

It writes only untracked files, all hidden by the host's `.git/info/exclude` (never its
`.gitignore`):

- `workflow/`: a **nested git repo** holding the engine, `works/`, `docs/`, `executors.toml` and
  the contract (as `CLAUDE.workspace.md`). It is versioned there, separately from the host.
- the 18 skills and 3 agents in the host's `.claude/skills/` and `.claude/agents/`, with every
  path rewritten to reach `workflow/` (`python3 workflow/scripts/workflow.py …`);
- `.claude/settings.local.json`: your personal permissions, merged into any file already there;
- one managed block in `CLAUDE.local.md` that imports the contract and states the nested rules
  (it keeps whatever else you wrote there);
- one managed block in `.git/info/exclude`.

It never touches a tracked file: not `CLAUDE.md`, not `.claude/settings.json`, no CI, no
`.gitattributes`, no `core.hooksPath`, and it makes no commit. If the host already tracks a file
it would write, it refuses and names it. If a skill or agent name clashes with one of the host's
own (skills, commands or agents), ours installs as `wf-<name>` (for example `/wf-commit`) and
the installer reports it; the host's own file is left byte for byte as it was.

**First run.**

1. Make the first commit in the nested repo:
   `git -C workflow add -A && git -C workflow commit -m "chore: install agentic workspace (nested)"`.
2. Start Claude Code **at the host root**, never inside `workflow/` or a subdirectory, and
   accept the trust dialog on the first run.
3. Confirm the commit convention. The installer infers it from the host's `git log` and
   `CONTRIBUTING*` and records it as unconfirmed: `python3 workflow/scripts/workflow.py
   nested-convention` shows it, and `nested-convention --confirm --text "<convention>" --trailers
   allowed|forbidden` records yours, including whether Claude `Co-Authored-By` trailers may appear
   in host commits. Until then `next` prints `host_commit_convention=UNCONFIRMED` and the agent
   asks before the first product commit.

**One ticket, from branch to PR.**

1. `git switch -c <branch> origin/main`, the team's way.
2. `/create-phase <the ticket>`. The phase records the host's current commit as its base.
3. `/do-whole-phase`. **Two commits per slice**: product code goes to the host in its own
   convention, with no phase or slice IDs in the message, and the workflow state goes to
   `workflow/` in this workspace's convention.
4. `/review-phase`. `phase-scope` reads the **host** diff from the recorded base, never `workflow/`.
5. Push and open the PR the usual way. It carries only product commits: no workflow paths and no
   phase or slice IDs.
6. When the team's review asks for changes, turn them into fix slices (`/create-phase`, or a fix
   slice in the same phase) and repeat from step 3.

**Updating.** `/update-workspace`, or
`sh /path/to/bootstrap_agentic_workspace.sh /path/to/host-repo --update --nested` (preview with
`--dry-run`). It keeps your confirmed convention, your renames and everything under `workflow/works/`
and `workflow/docs/`; a plain `--update` at a nested host refuses and points you here. Run
`sync-agents` afterwards and commit the refresh in `workflow/`.

**Caveats.**

- **Parallel worktrees are off** (`parallel-*` refuse): a host worktree would not contain the
  untracked files.
- A company-managed Claude Code policy may disable `bypassPermissions`, which the three subagents
  set. Check that before you rely on unattended runs such as `/do-whole-phase`.
- Engine messages may name a renamed skill by its original name (for example `validate` pointing
  at "the create-phase skill" when it installed as `wf-create-phase`).
- The seeded text under `workflow/docs/` describes paths relative to `workflow/`.
- If you give `workflow/` a remote, keep it **inside your company's organization**: its phase and
  slice files describe the company's code.
- Check your company's AI-tool policy first. `--nested` keeps your use private; it does not make it
  permitted.

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
/do-whole-phase gate    # pauses for your approval of each slice's plan
```

Automatic execution is the default; `gate` (approve each slice's plan) and `plan only` (write the
plan, stop before running it) are opt-in words you add to the command.

### Visual work: one design signoff

`design-cowork` fires automatically when the work changes a product's visual appearance. **The agent
never designs** — a dedicated design subagent (`design-drafter`) drafts each round and you make
every visual decision. The design lives in your repo as plain files under `docs/reference/design/`
(numbered cards such as `cards/01-nav.html`, a `tokens.css`, and a record per round), so no account,
push or external service is involved. That is the `drafter` tool, the default. The other,
`claude-design`, restores the original loop: you design in Claude Design (it needs a claude.ai login
and does not run under `ocx claude`), nothing is copied into the repo, and its records live under
`docs/reference/design/claude-design/`, which the design dashboard does not show. You choose the
tool per phase at `/create-phase` (`Design tool: drafter | claude-design`). The agent opens a round and writes one `handoff.md` asking for
a reviewable card set — every card path numbered in reading order (`01-nav.html`, `02-hero.html`,
…) so you see the design in the right order — then has the drafter draft it and checks the result
itself with `design-check` (the numbered cards, and whether a builder would have any design
decisions left to invent). It stops so you can open the card files in a browser. You sign the round
in your own words when you come back; anything short of a literal approval is recorded as feedback
and a new round of the same slice re-drafts it. If you want to see it running first, ask for a
mockup: the agent builds a throwaway, stubbed route in the project's own frontend and stops again
for you to open it. Approval must be literal, a revision becomes a new round, and implementation is
always a separate slice that follows the approved design faithfully and checks the running result
in a real browser. To list a repo for a design dashboard, run
`python3 scripts/workflow.py design-register` once per product repo (the dashboard is a separate
project outside this repo). A design exported from Claude Design can still be brought in through a
round's `import/` folder, but nothing requires it. A repo whose `docs/reference/design/` still has the
old Claude Design layout (from before v47) moves it under `claude-design/` with
`python3 scripts/workflow.py design-migrate` (a dry run; `--apply` moves it).

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
| `start-slice P1.S1` / `finish-slice P1.S1 --outcome …` | Move a slice through its lifecycle |
| `review-phase P1 --verdict pass` | Record a phase review |
| `accept-gate P1 --require` / `--open --walkthrough …` / `--clear` | Declare, open, and clear a phase's operator acceptance gate |
| `docs` | List each doc's latest version with its last-updated marker, flagging **STALE** docs |
| `doc-new-version --doc backend --summary … --source P1.REVIEW` | Cut a new durable doc version (in a docs phase) |
| `docs-debt` | Print a docs phase's worklist: the phases that owe consolidation, their notes, the docs they touch |
| `docs-consolidated P1` | Record that a phase's doc debt is paid |
| `defer-job --title … --reason … --trigger …` | Park a deferred job |
| `promote-deferred D1 --phase P1 --slice P1.S2` | Promote a deferred job into a slice |
| `sync-agents` | Apply the `executors.toml` executor-tier mode/model/effort config to the agent files |
| `executor-mode` / `executor-mode flex` | Show the executor mode, or switch it in one step (sets `mode` in `executors.toml` and syncs the agent files) |
| `parallel-start <P>` … `parallel-teardown <P>` | Move a phase into its own branch + worktree when you ask for one, then integrate it back with a local merge (see the `parallel-phase` skill) |
| `validate` | Check workspace integrity |

The full command list is `python3 scripts/workflow.py --help` (and `<command> -h` for one command's flags).

### The same operations as Agent Skills

The common workflows also ship as **18 Agent Skills** in `.claude/skills/`, invoked as `/slash`
commands in Claude Code:

| Skill | What it does |
|---|---|
| `create-phase` | Capture intent, then create a phase (seeds `DECOMP` + `REVIEW`); stops before decomposition |
| `do-next-slice` | Complete exactly one slice, then stop |
| `do-whole-phase` | Finish the active phase end-to-end, including its review |
| `review-phase` | Review a phase and record a `pass` / `changes_requested` / `blocked` verdict |
| `parallel-phase` | Run a phase in its own branch + worktree when you ask for one, and integrate it back: quiet-point gate, local merge by default, the review's gate sections, teardown |
| `doc-new-version` | Create a new versioned durable doc instead of patching the current one |
| `defer-job` | Park work as a deferred job, outside active selection |
| `deferred` | Rebuild and show the deferred-jobs dashboard |
| `promote-deferred` | Promote a deferred job into an active phase or slice |
| `archive-phase` | Archive review-passed phases whose doc debt is paid (normally batched via `archive-all`) |
| `rotate-backlog` | Archive every currently-done phase with no doc debt, leaving the rest active |
| `rebuild-workflow` | Rebuild generated dashboards, indexes, and doc snapshots, then validate |
| `executor-mode` | Show the executor mode (`economy` / `flex`), or switch it in one step (`/executor-mode flex`) |
| `commit` | Group pending changes into focused conventional commits |
| `retrofit` | Non-destructively adopt this workspace into an existing repo |
| `update-workspace` | Update an adopted workspace's machinery to the latest upstream, preserving your work |

> **Knowledge (phase explainers).** The `explain` skill ships with the workspace.
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
> (sourced by every zsh invocation). Never a repo `.env` — Claude Code does not auto-load
> it, and a secret in a repo file risks being committed.
>
> **Alternative (Claude Code plugin):** the same feature also lives as a standalone plugin in the
> [knowledge repo](https://github.com/leetusik/knowledge) —
> `/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge` →
> `/knowledge:setup` once, then `/knowledge:explain <topic>`. That is a separate namespace from this
> workspace's `/explain`; you do not need both.

The orchestrator delegates the heavy lifting to a **`slice-executor`** subagent in one of two
capability tiers, picked by each slice's risk. `slice-executor-mid` is the default tier (since v46):
implementation, `fix`, `docs` and `qa` slices rated `risk: low`, real code writing and multi-file
changes included. `slice-executor-high` takes decomposition, `research`, the phase review (which it
runs in a fresh context that never edits source, validating the phase and — only on a pass —
verifying its doc-impact list and writing its two gate sections, leaving the docs themselves to a
docs phase; a `changes_requested` or `blocked` verdict stops there and hands the findings back), a
slice rated `risk: high` for a named trigger (open design, a core invariant, an unlocated root
cause, a wide blast radius), and every second attempt after mid. Haiku is never an executor tier.
Risk is two values, `low` and `high`, defaulting to `high` — only an exact `low` routes down, so an
unset or unrecognized value always lands on the thorough tier, and the decomposition rates every
slice explicitly. When the mid executor needs a design decision the plan did not make, hits a
trigger its rating missed, or fails the same validation twice, it returns an `escalate` verdict; the
orchestrator folds the findings into the plan and re-dispatches to `slice-executor-high` (once per
slice), and a review finding against mid-tier work gets a `high` fix slice — so most slices run on
sonnet while opus takes what is genuinely hard or has already failed once. Tier models and efforts are configurable via the repo-root
`executors.toml` — a top-level `mode` preset (`economy`, the default, at
sonnet@high / opus@high; `flex` uses sonnet@xhigh / opus@xhigh) plus
per-tier `[claude.<tier>]` overrides (seed-once —
updates never overwrite it), applied with `python3 scripts/workflow.py sync-agents`. To change the preset
in one step, run `python3 scripts/workflow.py executor-mode <economy|flex>` (or `/executor-mode flex`): it
rewrites the `mode` line and syncs the agent files, and run bare it shows the current mode. Workflow skills are
**explicit-invocation only** — agents don't fire them on their own. They are the **operator's
interface**: you invoke the slash command; the agent does everything it implies.

### Read order

When an agent picks up work, it reads just in time, in this order — and no further by default:

1. [`works/state.json`](works/state.json) and `next` — the pointer
2. The **active** phase folder (`intent.md` and the bounded `phase.md`) and **active** slice folder
   only
3. Only the [`docs/current/`](docs/current/) **sections** the work touches — never the whole doc set
   up front, and never [`docs/index.json`](docs/index.json). A doc that `workflow.py docs` flags
   **STALE** is evidence to check against the notes that outran it, never current truth

Archived phases and old doc versions are history; they're not read by default.

### Durable docs: a docs phase you start

Ordinary slices don't version docs as they go. A slice that changes durable truth leaves a one-line
note on its phase's `## Doc impact` list, and a passing review only **verifies** that list — beyond
its two gate sections (`## Regression Checklist`, `## Operator Runtime`) it writes no doc. The phase
then **owes** consolidation: it stays in `works/phases/active/` and can't be archived until the debt is
paid. The debt is visible — `next` prints `consolidation_owed=<phases>`, `validate` warns
(`consolidation_owed=`, `stale_docs=`, any doc section past 10 KB) and still exits 0, and
`workflow.py docs` shows each doc's last-updated marker (date, source, commit) and flags a doc an
owed note has outrun as **STALE**. When you choose, say *"consolidate the docs"*
(`/create-phase consolidate the docs`): the agent scopes the phase from `docs-debt`, cuts one slice
per doc so each doc gets exactly one new version, and records `docs-consolidated <P>` for every
phase it pays. A docs phase always runs on the default stream,
[never in a worktree](#phase-worktrees-on-request).

### Phase worktrees (on request)

A phase runs **on the checkout you are already in** — `main`, normally. There is no flag to pass
and nothing to set up. When you want two phases moving at once, **you ask**, and that phase moves
into its own git worktree. Asking looks like either of these:

- the word **`worktree`** alongside the command — `/do-whole-phase worktree`, `/do-next-slice
  worktree` — or the same thing in your own words ("in a worktree", "in parallel", "on its own
  branch");
- **`python3 scripts/workflow.py parallel-start <P>`** run by your own hand, after which execution
  enters the stamped worktree without asking again.

Either way the agent cuts `phase/P<N>-<slug>` and a worktree at `.claude/worktrees/P<N>-<slug>`,
then enters it **in the same session** and drives the phase there. `main` keeps working whatever it
was working, each checkout sees only its own stream, and the phase is the unit of parallelism
(slices inside one phase stay strictly sequential). The agent never starts a worktree on its own
initiative: when another phase is already in flight, `next` *suggests* one for the phase queued
behind it, and acting on that suggestion is your call.

**A dirty `main` does not block it.** The stamp commit carries exactly the phase folder plus the
regenerated `works/` files; whatever else is dirty or staged stays behind on `main`, uncommitted,
and the worktree starts from that commit. `.claude/worktrees/` is written to the repo's
`.git/info/exclude`, never to `.gitignore`, so `main` never shows the nested worktree as untracked.
What still refuses: a phase that is not `planned` or is already stamped, a merge or rebase in
progress, a taken branch or path.

**Staying on `main` takes nothing** — it is the default. The one thing to know: **never ask for a
worktree on a docs phase**, because `doc-new-version` and `docs-consolidated` only work on the
default stream (doc versions come from one shared index). `parallel-skip <P>` and `new-phase
--on-main`, which pinned a phase back when v42 made the worktree the default, are now no-ops kept
only so older habits and scripts still run; they write nothing. `parallel-status` shows every
stream's state from any checkout.

**Integrating back.** Once the branch review passes, the agent runs the integration itself:
`parallel-gate <P>` checks the quiet point (the branch's phase done + `main` between phases), then it
exits the worktree and, on `main`, runs `git merge --no-ff phase/P<N>-<slug>` — a **local merge**
— followed by `parallel-merge-finish` (regenerates the shared dashboards), the doc versions for the
two gate sections the branch review recorded, and `parallel-teardown <P>`, which retires the
worktree and branch. Everything else on the phase's "Doc impact" list waits for a docs phase, as on
`main`. **Push and PR happen only when you ask** — push → PR → CI → merge is the remote variant, and
CI (`.github/workflows/workspace-ci.yml`) runs `validate` on every push and PR plus a
`parallel-gate` check on `phase/*` pull requests for it. A closed gate stops the sequence with a
report instead of merging.

See the [`parallel-phase`](.claude/skills/parallel-phase/SKILL.md) skill (`/parallel-phase`) for the
eight worktree rules and the full lifecycle, and `python3 scripts/workflow.py --help` for the command reference.
(v42 made the worktree the default for every phase; v43 put it back on request, because one phase at
a time is the normal shape of this workspace and a branch per phase made every ordinary run pay for
parallelism it never used. The mechanism itself is unchanged.)

## Project structure

```
.
├── CLAUDE.md                      # the compact routing contract (~12 KB)
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
│   │   ├── active/<P>/            # phase.json, phase.md (bounded notebook), slices/<id>/
│   │   └── archived/             # finished phases
│   └── deferred/                  # one folder per parked job
├── .claude/
│   ├── skills/                    # 18 Agent Skills (/slash commands)
│   ├── agents/                    # slice-executor tiers mid/high + design-drafter (models from executors.toml)
│   └── settings.json              # pre-approves workflow.py; denies force-push & rm -rf
└── .github/
    └── workflows/
        └── workspace-ci.yml       # CI: validate on push/PR; parallel-gate job on phase/* PRs (remote variant)
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
   on the way in and rewrites — under a size budget — on the way out, so it stays the *state* of the
   phase rather than its log; the log is each slice's own `result.md`, and decisions land in
   versioned docs when I consolidate them in a docs phase. The next slice — or the next *session* —
   starts from what the last one learned.

3. **Make every slice prove itself.** A slice writes its `plan.md` before it touches anything and a
   `result.md` when it's done, and the phase doesn't close until a fresh-context review checks it
   against the objective. "It runs" isn't the bar; "it was reviewed and matches what we set out to
   do" is.

4. **Version decisions; never overwrite them.** Docs are append-only versions, not files you edit in
   place — each new version records its source (the phase reviews whose notes it consolidates) and
   the commit it was cut at. So the history of *what we decided and why* is always recoverable, and
   the generated snapshots stay read-only on purpose.

5. **Park distractions; don't chase them.** Mid-slice, every shiny idea is a threat to the slice.
   Instead of following it, I drop it into a deferred job that sits outside the backlog and changes
   nothing until I promote it on purpose. Focus becomes a property of the system, not of my
   willpower.

6. **Commit at every clean boundary.** One slice is one reviewable, conventional commit. A small,
   legible history means the next agent — or future me — can actually read what happened and bisect
   when something breaks.

None of this lives in a conversation: one manager (`scripts/workflow.py`) plus one contract
(`CLAUDE.md`) mean a Claude Code session, a fresh session tomorrow, or a plain CLI agent running the
same commands all follow the same rules — the conventions belong to the repo, not to a chat.

## Related / inspired by

A quick map of the neighborhood. The combination this workspace bundles — a persisted
phase/slice/deferred state machine, versioned durable docs, `.claude/` Agent Skills over a
tool-agnostic CLI, and a single bootstrap script — shows up *piece by piece* across the projects
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
2. Execute it: type `/do-next-slice` or `/do-whole-phase`, or let any agent run the `workflow.py`
   commands directly. The `DECOMP` slice breaks the phase into slices.
3. Review it: the phase closes only on a passing review — the agent records it with
   `python3 scripts/workflow.py review-phase P2 --verdict …`; you read the result and approve.
   On a phase that changes what you can see, the review stops one step earlier: it ends with the
   phase `pending` and a concrete walkthrough, and the pass is recorded only after you have walked
   the running product yourself and cleared the gate (`accept-gate P2 --clear`).
4. Consolidate the docs when you choose: a passing phase leaves its doc changes as notes it owes,
   and a docs phase you start — *"consolidate the docs"* — versions each touched doc once and pays
   the debt (see [Durable docs](#durable-docs-a-docs-phase-you-start)).

A few house rules:

- **Commits** follow `type(scope): summary` — imperative mood, no trailing period (types: `feat`,
  `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`). Commit per completed
  slice; branch off `main` first.
- **Rebuild the artifact whenever you touch machinery.** `bootstrap_agentic_workspace.sh` is a
  build product: after editing `scripts/workflow.py`, `.claude/**`, [`CLAUDE.md`](CLAUDE.md),
  `executors.toml`, `works/templates/**`, or `installer/`, run `python3 installer/build.py` and
  commit the rebuilt artifact in the same commit (`python3 installer/build.py --check` must pass;
  register the tracked hook once with `git config core.hooksPath .githooks`).
- **Never hand-edit `docs/current/*.md`** (they're generated) and never patch old files under
  `docs/versions/`. Create a new version with `doc-new-version` instead, in a docs phase.

The contract in [`CLAUDE.md`](CLAUDE.md) is the source of truth; this README only points at it.

## License

Licensed under the [Apache License 2.0](LICENSE).
