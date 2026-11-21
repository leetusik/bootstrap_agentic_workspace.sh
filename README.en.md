# bootstrap_agentic_workspace.sh

> **This project moved to sikstack.** The workflow engine now ships as the sikstack plugin for Claude Code,
> developed at <https://github.com/leetusik/sikstack>. This repository is no longer updated; install from
> sikstack instead (`/plugin marketplace add leetusik/sikstack`).

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
- [Private use in a repo you don't own (the default install)](#private-use-in-a-repo-you-dont-own-the-default-install)
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
prompt and improvise — it works under a one-screen contract ([`CLAUDE.md`](payload/contract.md)) of four invariants and
the rules the engine enforces, with short playbooks that say how to break work down, where to write
things, and what "done" means.

**The problem it solves.** Coding agents are capable but forgetful. Across a long task they lose
context when the conversation compacts, redo work they already did, silently overwrite earlier
decisions, and sprawl sideways into whatever looks interesting. Point three different agents (or
three sessions of the same agent) at one repo and you get three different conventions.

**The approach.** This workspace gives agents three things they normally lack:

- **Routing** — there is always a single, machine-checkable answer to "what runs next?"
  (`works/state.json` and the generated backlog).
- **Durable, shared memory** — a per-phase notebook plus append-only versioned docs carry what each
  step learned forward to the next, so knowledge survives compaction and hand-offs between sessions.
- **Review gates** — work isn't "done" until a phase review (run by the executor in a fresh,
  isolated context that never edits source) checks it against the phase's objective and runs the
  walkthrough the phase was cut against. A verdict short of `pass` stops there and hands its
  findings back.

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

> This repo runs on its own workflow, from a private install outside the repo — it dogfoods the
> very system it scaffolds, and this README was itself written as a phase.

## Quickstart

**Prerequisites:** `python3 >= 3.8`, a POSIX shell (`sh`, `bash`, or `zsh`), and `git` (the default
install makes the target a git repo, so it needs git on `PATH`; with `--at-root`, `git` is only
needed to clone). No other dependencies.

> **You never type a `python3` command yourself.** The one-time bootstrap below is the only
> command you ever run; every workflow command (`python3 scripts/workflow.py …`) is typed and
> run by the **agent**. You drive everything in plain natural language.

### 1. Get the script and scaffold a workspace (recommended)

```sh
# get the script
git clone https://github.com/leetusik/bootstrap_agentic_workspace.sh.git

# scaffold a workspace into a new or empty directory
mkdir my-project && cd my-project
sh ../bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh . \
  --name "My Project" \
  --summary "What this project is, in one sentence."
```

`TARGET_DIR` (the `.` above) is where the workspace is created; it defaults to the current
directory.

**With no flag, the install is private and nested.** A new or empty directory is `git init`-ed as
the **host** repo, and the engine and all workflow state go to a nested git repo inside it,
`workflow/`. The skills and agents sit untracked in the host's `.claude/`, and the installer makes
no commit and writes no tracked file. A host the installer just created gets this workspace's own
commit convention (`type(scope): summary`, imperative, no trailing period) recorded as confirmed,
with Claude `Co-Authored-By` trailers allowed. Details are in
[Private use in a repo you don't own](#private-use-in-a-repo-you-dont-own-the-default-install).

To get the **committed, team-visible layout** instead (`CLAUDE.md`, `.claude/`, `scripts/`,
`works/` and `docs/` at the root of the repo, for everyone who clones it), add `--at-root`:

```sh
mkdir my-project && cd my-project
sh ../bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh . --at-root \
  --name "My Project" \
  --summary "What this project is, in one sentence."
```

`--at-root` is for an empty directory; add `--force-empty-ok` for one that holds extra files
(`--force-empty-ok` is accepted only together with `--at-root` or `--into-existing`).

### Or, the one-liner convenience

Pipes the script straight from GitHub into your shell — convenient, but read it first if you're
cautious about piping remote scripts (use `sh -s -- . --at-root` for the committed layout):

```sh
mkdir my-project && cd my-project
curl -fsSL https://raw.githubusercontent.com/leetusik/bootstrap_agentic_workspace.sh/main/bootstrap_agentic_workspace.sh | sh -s -- .
```

### Already have a project? Retrofit it

The plain bootstrap also works in a repo that already has code, docs, or git history: run from
the repo's root, it installs the private, nested layout and changes no tracked file, which is right
when only you will use the workspace. To put the workspace's files **in the repo itself**, so
everyone who clones it gets them, use the **non-destructive retrofit** path (the at-root
retrofit) — it only adds the workspace's files, skips anything you already have, and never
clobbers your work:

```sh
# from the root of your existing repo
sh /path/to/bootstrap_agentic_workspace.sh . --into-existing \
  --name "My Project" --summary "One sentence."
```

or drive it with an agent via the `/retrofit` skill. See the
**[Retrofit Guide](docs/retrofit-guide.md)** for the full procedure and collision
policy. (Want it for yourself in a repo you don't own, with nothing the team can see? That is the
default bare install, [described below](#private-use-in-a-repo-you-dont-own-the-default-install).)

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

`--update` **detects the installed layout** (nested or at-root) and refreshes it in that layout, so
the same command serves both and neither `--nested` nor `--at-root` is needed. Run it from the
host repo's root for a nested install. If a directory holds both layouts, so the layout is
ambiguous, or a flag you add contradicts the one found, it refuses and writes nothing. An existing
at-root workspace keeps updating at-root; nothing migrates it. A per-repo nested install, by
contrast, can become a multi-repo host that serves several repos, with `--to-multi-repo <repo>`
(see [Several repos under one host](#several-repos-under-one-host)); that converts a nested install,
never an at-root one.

Or drive it with an agent via the `/update-workspace` skill: it clones the latest
upstream, shows you the dry-run change-list, applies on your approval, runs
`check`, and records the synced commit in `works/.workspace-version.json`. It
never commits — you review the diff and commit when ready. Updates preserve your
existing `executors.toml` but refresh the generated `slice-executor` agent files, so
run `python3 adapters/claude_code/adapter.py sync-agents` after every update to re-apply your
per-row overrides. (For *first-time* adoption use a bare install, or
`--into-existing` / `/retrofit` for the committed layout, instead.)

### 2. Hand it to your agent

Setup was the last time you needed a terminal. The workspace starts with **no phases** — open the
directory in Claude Code (for the default nested install, **at the host root**; see
[First run](#private-use-in-a-repo-you-dont-own-the-default-install)) and create your first one:

```
/create-phase <your first task>
```

— or just ask in plain language: *"make a phase for X"*. The agent runs the workflow commands,
commits at slice boundaries, and stops at `pending` hand-offs for your review. See
[Example workflow](#example-workflow) for the full loop.

### Options

| Option | Default | Purpose |
|---|---|---|
| `[TARGET_DIR]` | current directory | Where to scaffold the workspace (the host repo's root, for the default nested install) |
| `--name NAME` | `New Project` | Project name |
| `--summary TEXT` | placeholder | One-sentence project summary |
| *(default)* | — | The private, nested install: the workspace lives in an untracked nested repo `workflow/` and the host's tracked files never change; a new or empty directory is `git init`-ed as the host (see [Private use](#private-use-in-a-repo-you-dont-own-the-default-install)) |
| `--at-root` | off | Install the committed, team-visible layout into a fresh directory instead (`CLAUDE.md`, `.claude/`, `scripts/`, `works/`, `docs/` at its root); never with `--nested` |
| `--force-empty-ok` | off | With `--at-root` (or `--into-existing`): allow scaffolding into a directory that has extra, non-managed files; refused without one of them, on `--update` too |
| `--into-existing` | off | Non-destructively retrofit into an existing repo, in the at-root layout (see the [Retrofit Guide](docs/retrofit-guide.md)) |
| `--update` | off | Update an already-installed workspace's machinery to this version (preserves your `works/` and `docs/`); the layout, nested or at-root, is detected |
| `--to-multi-repo REPO` | — | Convert the per-repo nested install at `REPO` into a multi-repo host at `REPO`'s parent folder; takes no target and combines with nothing but `--dry-run`, which prints every step (or every refusal) and writes nothing (see [Several repos under one host](#several-repos-under-one-host)) |
| `--nested` | — | Accepted and redundant: the nested layout is the default. On `--update` it must match the layout found; never with `--at-root` or `--into-existing` |
| `--dry-run` | off | With `--update`, preview the change-list without writing anything |
| `-h`, `--help` | — | Show help and exit |

Both `--flag value` and `--flag=value` forms work.

### What gets created

This is the **`--at-root`** layout. The default nested install puts the engine, `works/` and `docs/`
under `workflow/` instead and the skills and agents untracked in the host's `.claude/` (see
[Private use](#private-use-in-a-repo-you-dont-own-the-default-install)).

- [`CLAUDE.md`](payload/contract.md) — the compact routing contract every agent session works under.
- [`scripts/workflow.py`](payload/scripts/workflow.py) — the engine that drives all state (its `wf_*.py` modules beside it).
- [`adapters/claude_code/`](payload/adapters/claude_code/adapter.py) — the Claude Code adapter: the route table, `sync-agents`, the meter and the resume hook.
- `.claude/` — the 18 Agent Skills (`/slash` commands), the `slice-executor` subagent (`.claude/agents/slice-executor.md`, a short card that points each slice at the playbook for its kind of work in `.claude/skills/do-whole-phase/playbooks/`, dispatched on the model and effort the engine's route table resolves per slice — `executor-route` — with per-row overrides in `executors.toml` applied by `sync-agents`), the `design-drafter` design subagent (on its own `design` row), the `design-critic` that judges each draft (the `critic` row; in judge mode the `judge` row), the `code-reader` that reads a phase's code change blind, from the diff and the files at head alone, dispatched by the review's own executor and by `/read-code` (the `code` row), the `pr-reader` that reads a draft PR with fresh eyes only when you ask, or for a team repo with PR rules (the `reader` row), the read-only `Explore` lookup agent on Haiku, and a `settings.json` that pre-approves the workflow script, `playwright-cli` and the close's cleanup commands (`docker rm -fv`, `docker volume rm`, `lsof -ti`, `kill`, `git branch -d`, `git push origin --delete`).
- `docs/` — the durable docs, plain files under `docs/current/` that the slice changing them edits.
- `works/` — the state machine, starting with **no phases**: a `deferred/` area, an `agenda/` area,
  generated dashboards, and `state.json`. You create the first phase by talking to your agent
  (`/create-phase`).

**Safety.** A fresh install never overwrites an installed workspace: a bare install over an
at-root workspace refuses (use `--update`), and so does a bare install or an `--update` on a nested
install's own `workflow/` directory. The at-root install refuses to scaffold into a non-empty directory unless you pass
`--force-empty-ok` (a few harmless files like `.git`, `README`, and `LICENSE` are tolerated), and
it refuses to overwrite managed workflow files that already exist. The default nested install
refuses a non-empty directory that is not a git repo (`git init` it yourself, or use `--at-root`),
unless every entry in it is a git repo, which it installs as a multi-repo host (see
[Several repos under one host](#several-repos-under-one-host)), and writes nothing when it refuses. To add the workspace's files to a repo that *already* has
content, in the committed layout, use the non-destructive `--into-existing` retrofit instead — see
the [Retrofit Guide](docs/retrofit-guide.md).

## Private use in a repo you don't own (the default install)

**This is the default install.** You work in a company or team repo whose team does not use this
workspace, and you want to use it strictly for yourself: run the bare command. It leaves **no
footprint**: no branch, no tracked file, no CI file, no `.gitattributes`, no `docs/`, and nothing
in any PR diff. (Retrofit, by contrast, adds the workspace's files to the repo for everyone who
clones it.) `--nested` is what v49 used to pick this install; it is still accepted, but it is the
default now, so you never need to add it.

**A new personal project is nested too, and private by default.** Install into a new or empty
directory with no flag and the installer `git init`s it as the host repo and puts `workflow/` inside
it. If collaborators should receive the workspace through the repo, install with `--at-root`
instead. Parallel worktrees work in a nested install too (see [Phase worktrees](#phase-worktrees-on-request)).

**Choose nested for any repo whose PRs must stay clean.** Under the PR rule every phase opens a
draft PR. An at-root install's PR carries the workspace's state (`works/` and the workspace's
`docs/` files), which GitHub folds as generated; a nested install's state never enters the PR at
all, so pick nested for a team repo or any repo whose PRs must show product changes only.

**Install.** Point the installer at the host repo's root (a git work tree):

```sh
sh /path/to/bootstrap_agentic_workspace.sh /path/to/host-repo
```

A directory that holds extra files and is not a git repo is refused with nothing written (`git init`
it yourself and re-run, or use `--at-root`), unless it holds only git repos (see
[Several repos under one host](#several-repos-under-one-host)). So is a new directory inside another repo's work tree:
name that repo's root instead, or `git init` the directory first and re-run. A bare install over a
directory that already holds an at-root workspace is refused (use `--update`), and so is a bare
install or an `--update` on a nested install's own `workflow/` directory (run it at the host root).

It writes only untracked files, all hidden by the host's `.git/info/exclude` (never its
`.gitignore`):

- `workflow/`: a **nested git repo** holding the engine, `works/`, `docs/`, `executors.toml` and
  the contract (as `CLAUDE.workspace.md`). It is versioned there, separately from the host.
- the 18 skills and 6 agents in the host's `.claude/skills/` and `.claude/agents/`, with every
  path rewritten to reach `workflow/` (`python3 workflow/scripts/workflow.py …`);
- a `.gitignore` of `*` in each of those skill directories, so a skill directory hides itself
  even where the host's `.gitignore` re-includes `.claude/skills/`;
- `.claude/settings.local.json`: your personal permissions, merged into any file already there;
- one managed block in `CLAUDE.local.md` that imports the contract and states the nested rules
  (it keeps whatever else you wrote there);
- one managed block in `.git/info/exclude`.

It never touches a tracked file: not `CLAUDE.md`, not `.claude/settings.json`, no CI, no
`.gitattributes`, no `core.hooksPath`, and it makes no commit. If the host already tracks a file
it would write, it refuses and names it. A host `.gitignore` ranks above `.git/info/exclude`, so
before writing anything the installer asks git whether every file it would write will be ignored.
If the host's `.gitignore` would re-include one (for example `!CLAUDE*.md`, or an allowlist such as
`*` / `!*/` / `!*.md`), it refuses with nothing written and names each file with the deciding
`.gitignore` line; `--update` checks the same way. After writing, it confirms that the
host's `git status` lists none of its files before it reports the status clean.

If a skill or agent name clashes with one of the host's own (skills, commands or agents), ours
installs as `wf-<name>` (for example `/wf-commit`) and the installer reports it; the host's own
file is left byte for byte as it was.

**First run.**

1. Make the first commit in the nested repo:
   `git -C workflow add -A && git -C workflow commit -m "chore: install agentic workspace (nested)"`.
   (A host the installer `git init`-ed has no commits yet. The installer makes no commit in the
   host, and the workspace's files stay untracked there, so a `git add -A` in the host stages only
   your own files.)
2. Start Claude Code **at the host root**, never inside `workflow/` or a subdirectory, and
   accept the trust dialog on the first run.
3. Confirm the commit convention. For an existing host the installer infers it from the host's
   `git log` and `CONTRIBUTING*` and records it as unconfirmed: `python3 workflow/scripts/workflow.py
   repo convention` shows it, and `repo convention --confirm --text "<convention>" --trailers
   allowed|forbidden` records yours, including whether Claude `Co-Authored-By` trailers may appear
   in host commits. Until then `next` prints `host_commit_convention=UNCONFIRMED` and the agent
   asks before the first product commit. A host the installer `git init`-ed starts out confirmed
   with this workspace's own convention and trailers allowed, so `next` never prints
   `UNCONFIRMED` there; use the same command only to change it.

**One ticket, from branch to PR.**

1. `git switch -c <branch> origin/main`, the team's way.
2. `/create-phase <the ticket>`. The phase records the host's current commit as its base.
3. `/do-whole-phase`. **Two commits per slice**: product code goes to the host in its own
   convention, with no phase or slice IDs in the message, and the workflow state goes to
   `workflow/` in this workspace's convention.
4. `/review-phase`. `phase scope` reads the **host** diff from the recorded base, never `workflow/`. The review's executor dispatches the `code-reader` agent's blind read of that diff (no workspace records) and rules on each finding.
5. When the review passes, the `pr` skill opens the phase's draft PR, with no stop and no word to say; on a gated phase you read the draft on GitHub and one `accept` clears the gate and closes the PR: Ready, then the merge in a repo that is yours alone (a team repo's merge stays the team's). It carries only product commits: no workflow paths and no
   phase or slice IDs.
6. A change request after the phase is done (the team's review, or your own) reopens the same
   phase on its open PR (`phase reopen`); repeat from step 3, and the fix is pushed to the same PR,
   never a second PR or a force-push.

**Updating.** `/update-workspace`, or
`sh /path/to/bootstrap_agentic_workspace.sh /path/to/host-repo --update` (preview with
`--dry-run`). The installer detects the layout, so `--nested` is not needed (the v49 form,
`--update --nested`, still works). It keeps your confirmed convention, your renames and everything
under `workflow/works/` and `workflow/docs/`. Run `sync-agents` afterwards and commit the refresh in
`workflow/`.

**Caveats.**

- **Parallel worktrees are opt-in.** In a nested install a phase worktree is a pair: a host worktree
  with the `workflow/` worktree inside it (see [Phase worktrees](#phase-worktrees-on-request)).
- A company-managed Claude Code policy may disable `bypassPermissions`, which five of the six
  subagents set (`Explore` sets none). Check that before you rely on unattended runs such as `/do-whole-phase`.
- Engine messages may name a renamed skill by its original name (for example `check` pointing
  at "the create-phase skill" when it installed as `wf-create-phase`).
- The seeded text under `workflow/docs/` describes paths relative to `workflow/`.
- If you give `workflow/` a remote, keep it **inside your company's organization**: its phase and
  slice files describe the company's code.
- Check your company's AI-tool policy first. The private (nested) install keeps your use private; it
  does not make it permitted.

### Several repos under one host

When one piece of work spans several repos (a backend, a frontend, a deploy repo), install into the
folder that holds them instead of into one of them:

```sh
sh /path/to/bootstrap_agentic_workspace.sh /path/to/folder-of-repos
```

A folder that is not a git repo and holds only git repos (at depth 1; a single repo counts) becomes a
**multi-repo host**. The installer `git init`s the folder and makes its one empty commit,
`chore: start the host history` (the base `phase new` and `worktree start` measure from), hides each
repo with a `/<repo>/` line in the host's `.git/info/exclude`, and records the repos in a registry
(`python3 workflow/scripts/workflow.py repo list` lists it, with each repo's rules files such as
`AGENTS.md`). It writes nothing into any repo, and the host folder tracks nothing. If git has no
identity, the installer keeps the `git init`, makes no commit, still exits 0 and prints the two
commands to run instead: `git config --global user.name "<your name>"` and `user.email
"<you@example.com>"`, then `git -C <folder> commit --allow-empty -m "chore: start the host history"`.

Each repo has **its own** commit, branch and pull-request conventions. Confirm them one by one with
`repo convention --confirm --repo <name> --text "<conventions>" --trailers allowed|forbidden`
(without `--repo`, it records the rules that bind every repo); until then `next` prints
`repo_conventions=` with the repos still UNCONFIRMED. A slice then commits once in each repo it
changed (`git -C <repo> ...`, in that repo's conventions) and once in `workflow/`; `phase scope`
and the review read each repo's own range, and the review runs a read-only team-rules check over each
repo's commits, branch and pull request. A phase worktree becomes a **set**: the host worktree, the
`workflow/` worktree and one worktree per repo the phase changes (see
[Phase worktrees](#phase-worktrees-on-request)).

**Already installed in one repo?** Convert it in place:

```sh
sh /path/to/bootstrap_agentic_workspace.sh --to-multi-repo /path/to/repo --dry-run   # every step, or every refusal; writes nothing
sh /path/to/bootstrap_agentic_workspace.sh --to-multi-repo /path/to/repo
```

The nested repo at `repo/workflow/` moves up to the repo's parent folder, which becomes the
multi-repo host, and the other repos in that folder join the registry. Before writing anything it
refuses an install that is not at this version, a dirty nested repo, an in-flight phase worktree and
a parent folder that is not clean; `--dry-run` shows every refusal at once. The old repo's
convention becomes that repo's own, each phase's recorded anchors move to the repo (`phase scope`
reads the same range as before), and only workspace files in the old repo that are byte-identical to
what the installer writes are deleted: anything you edited stays and is listed. The run ends with the
nested commit to make, the conventions to confirm and the exact rollback (revert that commit, move
`workflow/` back, `--update` the repo). From then on start Claude Code at the parent folder. This
converts a per-repo **nested** install only; nothing migrates an at-root one.

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

Slices the decomposition declared independent (what each depends on, and files that don't overlap) run
together under `/do-whole-phase`, in the same checkout. A phase that declares nothing runs one slice at a
time, as before, and `/do-next-slice` always runs exactly one.

### Visual work: you sign each design round

`design-cowork` fires automatically when the work changes a product's visual appearance. **The agent
never designs** — a dedicated design subagent (`design-drafter`) drafts, a separate critic
(`design-critic`) judges the draft when it is switched on, and you make every visual decision. A design
slice designs one connected group of related surfaces (one tab, one flow, the views a user moves
between) as one **job**; a small unrelated surface may share its canvas, drawn unlinked, and
a bigger unrelated group is a design slice of its own. Each round drafts a frame of shared choices
first, then the pages at once, then a join into one connected canvas. The job is one **working
canvas** written as plain files under `docs/reference/design/jobs/`: a prototype first, an entry Page
whose clicks reach every surface of the group, every screen as a clickable Page with real or
realistic data (a flow carries the item you clicked onto the next screen, and a grey "Prototype only"
bar on each Page jumps to that page's other states), and every component on its own board in all its
states, in one direction unless you ask for options. The agent writes one brief for the slice and a short
handoff per round from your repo (every screen and state with a check, the data, the components, your
taste words and your standing design rules quoted), the drafter builds the canvas and checks it with a local render that
clicks, types and hovers through it, and — when the decomposition turned critique on for that job —
the critic gives it one fresh-eyed pass against your bar and the drafter fixes or rebuts each finding
once (a stronger judge rules on the calls the critic is unsure of). The agent then publishes the round's
one connected canvas as one Design canvas Artifact, which you open in the Claude app, and stops once with
a short report: a handful of decisions, and a "decided as drawn" list to skim. One literal word in the
session ("accept") signs the round, and the engine records it; anything short of a literal
approval — including comments you send to Claude and edits you make in the canvas, copied word for
word — becomes the next round of that job, a new version of the same canvas. If you want to see it running inside your product first, ask
for a mockup: the agent builds a throwaway, stubbed route in the project's own frontend and stops
again. Implementation is always a separate slice that follows the signed design faithfully and checks
the running result in a real browser (the agent's own `playwright-cli`); built canvases are offered for deletion at the phase review.
The `drafter` is the only design tool; the earlier `claude-design` tool and its viewer are retired.
Older records stay readable as history: a v47 card record moves under `schema1/` with
`python3 scripts/workflow.py design-migrate --to 2`, and a pre-v47 Claude Design layout under
`claude-design/` with `python3 scripts/workflow.py design-migrate` (each a dry run; `--apply` moves it).

Track progress in `works/backlog.md` (the generated dashboard) and the active
phase folder under `works/phases/active/` (the phase notebook and slice folders) — or just ask the
agent, *"where are we?"*.

## How it works

Everything is organized as **phases** made of **slices**, driven by one script.

- **Phase** (`P46-k2`: the next number and a short tail, minted by the engine; say or type just `46`. Older workspaces have `P1`, `P2`, … and `P-7kq2`) — a unit of work with an objective. A new phase starts with only two
  slices: a `DECOMP` (decomposition) and a `REVIEW`.
- **Slice** (`P46-k2.DECOMP`, `P46-k2.S1`, `P46-k2.F1`, `P46-k2.REVIEW`) — an ordered step within a phase. The
  `DECOMP` slice is what breaks the phase into the middle slices; each slice fills its own `plan.md`
  before working and writes a `result.md` when done.
- **Deferred job** (`D92-x4`, minted likewise; older workspaces have `D1`, `D2`, … and `D-m3xa`) — a parked idea. It sits outside the active backlog and never
  changes what runs next until you explicitly promote it.
- **Agenda item** (`A7-m3`, minted on its own sequence) — something you want to discuss or decide, kept in your own order: Open, Deferred, Solved or Dropped; an Open item reads In progress while a phase linked to it (`phase new --agenda`) is not done. It never changes what runs next.

The contract ([`CLAUDE.md`](payload/contract.md)) fits one screen. Four invariants always hold:

> Nothing is pushed, merged or paid for without your word. A sign-off is your literal words. Your own work is never touched. Reports are truthful.

The rest is a few principles you can steer with by name ("prove it works", "subtract before you add", …) and a table of the rules that stay, each beside the engine refusal, check or test that enforces it. How the work usually goes lives in the skills and the executor card.

### One manager

Every operation runs through [`scripts/workflow.py`](payload/scripts/workflow.py) — typed by the
**agent**, not by you. The bare CLI is the universal fallback: anything that can run a shell —
another agent, CI — drives the workspace with the exact same commands:

| Command | What it does |
|---|---|
| `next` (`next --card` for the resume card) | Show the current / next slice, or the typed stop that halts the run |
| `phase new --name … --objective …` | Create a phase (seeds `DECOMP` + `REVIEW`); the engine mints its id, e.g. `P46-k2` |
| `phase status` / `phase archive <P>` (`--all`) / `phase rotate` / `phase reopen` / `phase scope` / `phase rounds` | Move, archive, reopen or read a phase: its boundary in git, its slice rounds |
| `slice new --phase 46 --slice S1 --name …` | Add a slice (`P46-k2.S1`; the full id works too) |
| `slice start 46.S1` / `slice finish 46.S1 --outcome …` | Move a slice through its lifecycle |
| `slice status 46.S1 pending --stop-kind … --on-words …` | Stop for you: `next` prints `WAITING ON OPERATOR` until your words move it out of `pending` |
| `section 46 [<name>] [--append \| --entry K --replace …]` | Read or write one section of a phase's notebook |
| `review 46 --verdict pass` | Record a phase review |
| `gate 46 require` / `open --walkthrough …` / `clear --words …` | Declare, open, and clear a phase's operator acceptance gate |
| `pr branch\|record\|sync\|team\|check\|rules` | Branch, record and track a phase's pull requests |
| `close <P>` | Close an accepted phase by its fixed order of steps; repeat it after each named stop |
| `defer-job --title … --reason … --trigger …` | Park a deferred job; the engine mints its id, e.g. `D92-x4` |
| `agenda` / `agenda-add --title …` / `agenda-solve A7 …` | List the agenda, add an item (the engine mints its id, e.g. `A7-m3`), or move items through their statuses (`agenda-edit`, `-move`, `-defer`, `-drop`, `-reopen`, `-delete`, `-link`, `-unlink`) |
| `promote-deferred 92 --phase 46 --slice S2` | Promote a deferred job into a slice (`--create-phase` without `--phase` mints the phase) |
| `worktree start <P>` … `worktree teardown <P>` | Move a phase into its own branch + worktree when you ask for one; the close integrates it back (see the `parallel-phase` skill) |
| `repo list\|add\|remove\|rules\|detect-rules\|map-anchors\|convention` | A multi-repo host's registry: its repos, their rules files and their commit conventions |
| `link <server>/projects/<project-id>` | Link a nested install's checkout to a hi2vi project, which then holds its workspace (cloud mode); the workspace key is pasted at a prompt |
| `unlink` / `unlink --from-disk` | Return a linked checkout to local mode, the files on disk the truth again |
| `sync` / `sync --keep local\|cloud <path>…` | In a linked checkout, pull and push the clean changes and list what differs; `--keep` resolves the named paths |
| `check` (`check --no-rebuild` in CI) | Rebuild the generated files, then check workspace integrity |

**The Claude Code adapter** is a folder of its own, `adapters/claude_code/`, run as `python3 adapters/claude_code/adapter.py <command>`:
`route` (the resolved route table and the agent files' sync state; `route <slice_id> [--retry]` one slice's dispatch lines; `--drafter`,
`--critic`, `--judge`, `--reader`, `--code`, `--explore` for the other agents), `sync-agents` (apply the `executors.toml` per-row
overrides to the six managed agent files), `meter [--phase P] [--slice S] [--json]` (the main thread beside every span, metered from
Claude Code's transcripts at list price, with each slice's verdict read from its `result.md`) and `compact-resume` (the SessionStart
hook that prints the resume card after a compaction). The engine never imports it.

Ids are minted by the engine, never picked: `phase new` and `defer-job` print the next number with a
two-character random tail (`P46-k2`, `D92-x4`), so ids stay easy to say and two branches minting at once
do not clash. Anywhere an id is typed, the number alone works (`46`, `P46`, `p46`) while only one phase
carries it; if two branches each made a P46, the engine lists both and you type the tail (`46-k2`).
Ids from older workspaces keep working unrenamed, with their brief forms: `12` or `P12`, `7kq2` or `P-7kq2`.

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
| `pr` | Write and check a phase's draft PR bodies, and close the phase by one ordered checklist (`reference/close.md`): open the drafts when the review passes and read their CI (on a gated phase you read them on GitHub, then `accept`), re-read only what changed, Ready and the landing, a worktree's integration, then clean up what the phase started and its merged branches |
| `read-code` | Blind-read a product change made outside a phase before it is pushed: dispatch the `code-reader` on the range the skill's step 1 resolves, or a named one, and report its findings |
| `parallel-phase` | Run a phase in its own branch + worktree when you ask for one: start it, add a repo, see every stream; it integrates back by the `pr` skill's close checklist |
| `defer-job` | Park work as a deferred job, outside active selection |
| `deferred` | Rebuild and show the deferred-jobs dashboard |
| `promote-deferred` | Promote a deferred job into an active phase or slice |
| `agenda` | Show the agenda, or run one agenda command (`/agenda add …`, `/agenda solve A7`) |
| `archive-phase` | Archive review-passed phases (normally batched via `phase archive --all`) |
| `rotate-backlog` | Sync the open PRs, then archive every done phase that owes nothing and report the rest; it creates and runs no phase |
| `executor-route` | Show the adapter's route table and its meter, or one slice's dispatch decision (`/executor-route 46.S2`) |
| `commit` | Group pending changes into focused conventional commits |
| `retrofit` | Non-destructively adopt this workspace into an existing repo |
| `update-workspace` | Update an adopted workspace's machinery to the latest upstream, preserving your work |

> **Knowledge (`/knowledge:explain`).** Explaining a topic, a change or a phase into your knowledge
> base is done by the **knowledge plugin** from the [knowledge repo](https://github.com/leetusik/knowledge),
> not by this workspace. The plugin owns the skill, the CLI and the document API, so they stay in step.
> Install it once:
>
>     /plugin marketplace add leetusik/knowledge
>     /plugin install knowledge@knowledge
>
> then run `/knowledge:setup` once (connect to the hosted KB, or scaffold your own) and use
> `/knowledge:explain <topic>`. Every explain is its own **explain phase**, one per publishable unit: a
> standalone document by default, a book or one chapter of a book only when you ask. After one
> confirmation the phase is created **and** run in its own worktree under `.claude/worktrees/`, and
> merges back by itself: one writer reads this repository's code and the records of the phases that
> built the subject, a critic on a second model checks the draft against them, and it is published
> private. It does no research of its own and covers only this repository's code; a subject no phase
> recorded is offered a research phase first. A book still stops for its outline sign-off and its
> acceptance gate. Plugin version 0.10.0 or later is required; the writer runs on your session's
> permissions (the plugin's README, *Explain: permissions*). To update: `/plugin marketplace update knowledge`,
> then update `knowledge@knowledge` from the `/plugin` panel's Installed tab (or, from a shell,
> `claude plugin update knowledge@knowledge`). The review never writes an explainer; it only reports
> `explain: not written — run /knowledge:explain P<N> for a document, or ask it for a book`.

The orchestrator delegates the heavy lifting to a **`slice-executor`** subagent, on a row
picked by each slice's risk. The mid row is the default (since v46):
implementation, `fix`, `docs` and `qa` slices rated `risk: low`, real code writing and multi-file
changes included. The high row takes decomposition, `research`, the phase review (which it
runs in a fresh context that never edits source, validating the phase, running its walkthrough
and — only on a pass — updating the two gate sections the phase made untrue; a `changes_requested`
or `blocked` verdict stops there and hands the findings back), a
slice rated `risk: high` for a named trigger (open design, a core invariant, an unlocated root
cause, a wide blast radius), and every second attempt after mid. Risk is two values, `low` and `high`, defaulting to `high` — only an exact `low` routes down, so an
unset or unrecognized value always lands on the high row, and the decomposition rates every
slice explicitly. When an executor on the mid row needs a design decision the plan did not make, hits a
trigger its rating missed, or fails the same validation twice, it returns an `escalate` verdict; the
orchestrator folds the findings into the plan and re-dispatches on the high row (once per
slice), and a review finding against mid-row work gets a `high` fix slice — so most slices run on
the mid row's lower effort while the high row takes what is genuinely hard or has already failed once. Model and effort come from one **route table** the Claude Code adapter owns, resolved per slice at dispatch time:
`high` (opus @ high — review, decomposition, the mockup span, any risk but `low`, every second
attempt), `research` (opus @ high), `mid` (opus @ medium — implementation, fix, docs and qa rated `low`) and
`explore` (haiku @ xhigh, the read-only `Explore` lookup agent; no slice runs on haiku since v83). Three rows serve design, never a slice: `design` (fable @ high, `design-drafter`), `critic` (opus @ high, `design-critic`) and `judge` (opus @ high, alias only, the same critic file in judge mode); the critic and the judge may share the drafter's model. Two more serve no slice: `reader` (opus @ high, `pr-reader`) reads a draft PR only when you ask, or for a team repo with PR rules, and `code` (opus @ high, `code-reader`, the adapter's `route --code`) reads a code change blind, dispatched by the review's own executor and by `/read-code`. The repo-root
`executors.toml` overrides rows one by one (`[claude.<row>]`, seed-once — updates never overwrite it),
applied to the agent files with `python3 adapters/claude_code/adapter.py sync-agents`; the presets are gone, and a
leftover `mode = "…"` line is refused with the migration step. `python3 adapters/claude_code/adapter.py
route <slice_id>` prints the decision the orchestrator dispatches from (kind first, then
risk, then attempt; `/executor-route` shows the table), and its `meter` reads each slice's verdict from
its `result.md` and meters what the main thread and each span actually processed
from Claude Code's transcripts, so the table is tuned from this workspace's own runs; executors may hand bulky read-only lookups to `Explore` but never their `result.md`,
`phase.md`, code, validation or verdict. Workflow skills are
**explicit-invocation only** — agents don't fire them on their own. They are the **operator's
interface**: you invoke the slash command; the agent does everything it implies.

### Read order

When an agent picks up work, it reads just in time, in this order — and no further by default:

1. `works/state.json` and `next` — the pointer
2. The **active** phase folder (`intent.md` and the bounded `phase.md`) and **active** slice folder
   only
3. Only the `docs/current/` **sections** the work touches — never the whole doc set
   up front

Archived phases are history; they're not read by default.

### Durable docs: written by the slice that changes them

The docs hold only what the code cannot say. A slice whose change makes one of them untrue updates
it itself: `docs/current/*.md` are plain files it edits in place. An older install's `docs/index.json`
and `docs/versions/` stay on disk, unread. Doc consolidation — the `## Doc impact` notes and the docs
phase that paid them — is retired.

### Phase worktrees (on request)

A phase runs **on the checkout you are already in** — `main`, normally. There is no flag to pass
and nothing to set up. When you want two phases moving at once, **you ask**, and that phase moves
into its own git worktree. (This works on an at-root install and on a nested one; the nested
install is described in its own paragraph below.) Asking looks like either of these:

- the word **`worktree`** alongside the command — `/do-whole-phase worktree`, `/do-next-slice
  worktree` — or the same thing in your own words ("in a worktree", "in parallel", "on its own
  branch");
- **`python3 scripts/workflow.py worktree start <P>`** run by your own hand, after which execution
  enters the stamped worktree without asking again.

Either way the agent cuts `phase/P<N>-<slug>` and a worktree at `.claude/worktrees/P<N>-<slug>`,
then enters it **in the same session** and drives the phase there. `main` keeps working whatever it
was working, each checkout sees only its own stream, and the phase is the unit of worktree parallelism
(inside one phase, only slices the decomposition declared independent run together, in that phase's own
checkout). The agent never starts a worktree on its own
initiative: when another phase is already in flight, `next` *suggests* one for the phase queued
behind it, and acting on that suggestion is your call.

**A dirty `main` does not block it.** The stamp commit carries exactly the phase folder plus the
regenerated `works/` files; whatever else is dirty or staged stays behind on `main`, uncommitted,
and the worktree starts from that commit. `.claude/worktrees/` is written to the repo's
`.git/info/exclude`, never to `.gitignore`, so `main` never shows the nested worktree as untracked.
What still refuses: a phase that is not `planned` or is already stamped, a merge or rebase in
progress, a taken branch or path.

**Staying on `main` takes nothing** — it is the default. `phase new --on-main`, which pinned a phase
back when v42 made the worktree the default, is a no-op kept only so older habits still run; it writes
nothing. `worktree status` shows every
stream's state from any checkout. `works/backlog.md`'s `## Streams` table lists the default stream and
every in-flight worktree phase, read live from its branch (with the host branch in a nested install).

**In a nested install**, `worktree start <P> --host-branch <name> [--host-base <ref>]` cuts a pair: a
host worktree under `.claude/worktrees/` on your host branch, with the `workflow/` worktree
(`phase/P<N>-<slug>`) inside it. The agent proposes the branch name from your team's custom, which you
record with `repo convention` (commits, branches and pull requests), and you confirm it. The base
defaults to the host's default branch (`--host-base` overrides it), and the agent runs `git fetch`
first when your custom says to branch from fresh main. The host side follows your custom (one PR per
ticket or per phase, or several phases folded onto one branch by rebase, with the checks re-run on the
combined commit); the engine never pushes or merges into the host's default branch, and the `pr` skill
opens the phase's draft PR when its review passes.
Teardown keeps your host branch (it deletes only an empty branch the engine created). A worktree
isolates files only: docker containers, ports, local databases and caches stay shared across streams,
so coordinate them yourself.

**On a multi-repo host** ([Several repos under one host](#several-repos-under-one-host)) the pair
becomes a **set**: the same two worktrees plus one per repo the phase changes, at
`<host worktree>/<repo>/`. `worktree start <P> --host-branch <name> --repo <name>=<branch>`
(repeatable, with `--repo-base <name>=<ref>` to stack a repo's branch on another) cuts them, and
`worktree add-repo <P> --repo <name>=<branch>`, run inside the set, adds one mid-phase. Each repo's
branch name follows that repo's custom and you confirm it. `worktree teardown` removes the repo
worktrees first, then the nested one, then the host's, and it refuses any git worktree in the host
worktree that it did not stamp, even with `--discard-ignored`: remove it by hand after integrating
its branch, or adopt it with `worktree add-repo ... --adopt`. The workspace never fetches, pushes
or merges into any repo's default branch; each repo's draft PR opens when the review passes.

**Integrating back.** Once the branch review passes, the agent runs the integration itself, by
`close <P>` (the `pr` skill's close checklist): `worktree gate <P>` advises on the quiet point (the
branch's phase done + `main` between phases), then it exits the worktree and, on `main`, makes a **local merge**, runs
`worktree merge-finish` (regenerates the shared dashboards), writes the gate sections the branch
review recorded in its `result.md`, and runs `worktree teardown <P>`. **Every phase opens a draft PR
when its review passes**, and your `accept` closes it (Ready, then a solo repo's merge by its landing custom; a team repo's merge is the team's) — merging it on GitHub
is the remote variant. CI (`.github/workflows/workspace-ci.yml`) runs `check --no-rebuild` on each pull
request and each push to the default branch. A closed gate stops the sequence with a report instead of merging. Before the phase finishes, the close
also stops what the phase started (its servers, its containers with their volumes) and deletes its
merged head branches, local and remote.

See the [`parallel-phase`](payload/claude/skills/parallel-phase/SKILL.md) skill (`/parallel-phase`) for the
eight worktree rules and the full lifecycle, and `python3 scripts/workflow.py --help` for the command reference.
(v42 made the worktree the default for every phase; v43 put it back on request, because one phase at
a time is the normal shape of this workspace and a branch per phase made every ordinary run pay for
parallelism it never used. The mechanism itself is unchanged.)

## Project structure

```
.
├── CLAUDE.md                      # the contract on one screen (~4 KB)
├── bootstrap_agentic_workspace.sh # the scaffolding script (self-contained)
├── scripts/
│   └── workflow.py, wf_*.py       # the engine that drives all state
├── adapters/
│   └── claude_code/adapter.py     # the Claude Code adapter: routes, sync-agents, the meter, the resume hook
├── executors.toml                 # your per-row route overrides (seed-once)
├── docs/
│   └── current/                   # the durable docs, plain files edited in place
├── works/
│   ├── state.json                 # current / next pointer (canonical)
│   ├── backlog.md / deferred.md / agenda.md   # generated dashboards (lean: IDs & pointers only)
│   ├── phases/
│   │   ├── active/<P>/            # phase.json, phase.md (bounded notebook), slices/<id>/
│   │   └── archived/             # finished phases
│   ├── deferred/                  # one folder per parked job
│   └── agenda/                    # one folder per agenda item
├── .claude/
│   ├── skills/                    # 18 Agent Skills (/slash commands)
│   ├── agents/                    # slice-executor + design-drafter + design-critic + pr-reader + code-reader + Explore (models from executors.toml)
│   └── settings.json              # pre-approves workflow.py and the adapter; denies force-push & rm -rf
└── .github/
    └── workflows/
        └── workspace-ci.yml       # CI: check --no-rebuild on push/PR (remote variant)
```

## ⭐ How I work with coding agents

I don't hand an agent a vague task and hope. The whole reason this workspace exists is to force a
few habits that make agents reliable on long, real work — not just impressive in a demo. These are
the ones I lean on; the skills carry them, and the rule table in the [contract in `CLAUDE.md`](payload/contract.md) names what enforces each rule.

1. **Decompose before you build.** The first move on any phase is a decomposition slice, not code.
   I make the agent break the work into small, ordered slices and write the plan down — planning is
   its own step with its own artifact. A task you can't slice is a task you don't understand yet.

2. **Give agents durable, shared memory.** Conversations compact and agents forget, so I never keep
   important context only in the chat. Every phase has a notebook (`phase.md`) that each slice reads
   on the way in and rewrites — under a size budget — on the way out, so it stays the *state* of the
   phase rather than its log; the log is each slice's own `result.md`, and what the code cannot
   say lands in versioned docs, written by the slice that changed it. The next slice — or the next *session* —
   starts from what the last one learned.

3. **Make every slice prove itself.** A slice writes its `plan.md` before it touches anything and a
   `result.md` when it's done, and the phase doesn't close until a fresh-context review checks it
   against the objective. "It runs" isn't the bar; "it was reviewed and matches what we set out to
   do" is.

4. **Write down what the code cannot say.** The durable docs hold only that, and the slice whose
   change makes one untrue edits it in the same commit — so git keeps the history of *what we
   decided and why*, next to the change that decided it.

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

This repo is developed with its own workflow, so contributing means *using* it, through your
agent. The maintainer's workspace is a private multi-repo host in the folder above the
clone, so a clone has none: install your own private one at the clone root with the default (nested) install,
`sh bootstrap_agentic_workspace.sh`. Then drive it as described below, with
`python3 workflow/scripts/workflow.py …`. You edit `payload/` and `installer/` (never the
installed copies; see the root [`CLAUDE.md`](CLAUDE.md)).

1. Open a phase: ask your agent — *"make a phase for \<your change\>"*. It runs
   `python3 workflow/scripts/workflow.py phase new …`, which seeds only `DECOMP` + `REVIEW`, and
   stops there.
2. Execute it: type `/do-next-slice` or `/do-whole-phase`, or let any agent run the `workflow.py`
   commands directly. The `DECOMP` slice breaks the phase into slices.
3. Review it: the phase closes only on a passing review — the agent records it with
   `python3 workflow/scripts/workflow.py review 46 --verdict …`; you read the result and approve.
   On a phase that changes what you can see, the review stops one step earlier: it ends with the
   phase `pending` and a concrete walkthrough, and the pass is recorded only after you have walked
   the running product yourself and cleared the gate (`gate 46 clear --words "…"`).
4. Accept it: your `accept` closes the phase — its draft PR goes Ready (and merges in a solo repo),
   and what the phase started is stopped and its merged branches deleted.

A few house rules:

- **Commits** follow `type(scope): summary` — imperative mood, no trailing period (types: `feat`,
  `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`). Commit per completed
  slice; branch off `main` first. Host commits carry no phase or slice IDs (those live in
  your private workspace's own repo).
- **Rebuild the artifact whenever you touch machinery.** `bootstrap_agentic_workspace.sh` is a
  build product: the shipped sources live under `payload/` (`payload/scripts/*.py`, `payload/adapters/**`,
  `payload/claude/**`, the contract [`payload/contract.md`](payload/contract.md),
  `payload/works/templates/**`, …). After editing `payload/**` or `installer/**`, run
  `python3 installer/build.py` and commit the rebuilt artifact in the same commit
  (`python3 installer/build.py --check` must pass; register the tracked hook once with
  `git config core.hooksPath .githooks`). The maintainer's own workspace is a private multi-repo
  host one folder above the repo, and its installed copies live there, so a clone has none; in
  your own install the `.claude/skills`, `.claude/agents` and `workflow/` are installed copies
  too: never edit them; see the root [`CLAUDE.md`](CLAUDE.md) for the dev loop.
- **Docs are plain files.** A slice whose change makes `docs/current/*.md` untrue edits it in place; an
  older install's `docs/versions/` stay unread.

The contract in [`CLAUDE.md`](payload/contract.md) (installed as `CLAUDE.md`) is the source of truth; this README only points at it.

## License

Licensed under the [Apache License 2.0](LICENSE).
