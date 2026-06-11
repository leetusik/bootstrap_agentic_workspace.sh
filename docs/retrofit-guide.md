# Retrofit Guide — Adopting the Agentic Workspace into an Existing Project

This guide walks you through adding the agentic workspace to a repository that
**already has code, a README, `scripts/`, `docs/`, or git history** — not just a
fresh, empty directory.

The plain bootstrap (`bootstrap_agentic_workspace.sh <dir>`) intentionally
refuses to touch a non-empty repo or overwrite existing files. Retrofit is the
**safe, non-destructive** path for an existing repo: it only ever *adds* the
workspace's own files, *skips* anything you already have, and *additively merges*
a small, well-known set (your existing `CLAUDE.md` and `.claude/settings.json`)
without deleting or rewriting your content.

> **One-line promise:** retrofit never clobbers a file you already have. If it
> cannot add the workspace without overwriting something load-bearing, it stops
> **before writing anything** and tells you why.

---

## When to use this

| Situation | Use |
|---|---|
| Brand-new / empty directory | the plain bootstrap (see the README Quickstart) |
| A repo that already has code/docs/history, **no** workspace yet | **this guide** (`--into-existing` or the `/retrofit` skill) |
| A repo that already has the workspace | nothing — retrofit is a no-op; just use `/do-next-slice` etc. |

## Prerequisites

- `python3 >= 3.8` and a POSIX shell (same as the plain bootstrap).
- A git repository with a **clean working tree** is strongly recommended, so the
  retrofit's additions show up as a reviewable diff. The installer itself runs
  **no git commands** and never touches your history — you stay in control of
  what gets committed.
- A checkout of `bootstrap_agentic_workspace.sh` (the installer script), or the
  one-liner `curl` from the README.

---

## The recommended path

### Option A — the `/retrofit` skill (agent-driven)

From inside your existing repo, in Claude Code or Codex:

```
/retrofit            # Claude Code
$retrofit            # Codex
```

The skill runs a preflight (confirms you're in a git repo, warns on a dirty
tree, and confirms the repo doesn't already have a workspace), **reads your
project** (README, package manifest, primary language, latest commit) to
synthesize a first-phase name and objective that reflect *your* code, runs the
installer in retrofit mode with those values, reconciles the contract files, runs
`validate`, and reports what it added, skipped, and merged. It is
explicit-invocation only — it never fires on its own.

### Option B — the installer directly

This is the command the `/retrofit` skill wraps — normally **your agent runs
it** (Option A). Paste it yourself only if you are working without an agent:

```sh
# from the root of your existing repo
sh /path/to/bootstrap_agentic_workspace.sh . --into-existing \
  --name "My Existing Project" \
  --summary "What this project is, in one sentence." \
  --phase-name "Adopt workspace + capture current state" \
  --phase-objective "Install the workspace and decompose the first real change to <project>, building on the code that already exists."
```

`--into-existing` switches the installer from "refuse if non-empty / overwrite
everything" to the non-destructive policy below. The `--phase-name` /
`--phase-objective` flags seed your first phase **P1** from your project's
current state instead of from a generic placeholder (see *Seeding the first
phase*).

---

## What retrofit adds, and how collisions are handled

The workspace's own surface is: the routing contract (`CLAUDE.md` / `AGENTS.md`),
the engine (`scripts/workflow.py`), the skills (`.claude/skills/`,
`.agents/skills/`, `.codex/`), the versioned docs (`docs/`), and the state
machine (`works/`). Retrofit classifies **every** path it would write into one of
four tiers:

### Tier 1 — Skip if you already have it (keep yours)

Pure content files are written only if absent; if present, **yours is kept
untouched**. This covers the skills, the `phase-reviewer` subagent,
`.codex/config.toml`, the `works/templates/*`, and `docs/README.md`.

### Tier 2 — Whole subsystem, only if entirely absent

The **docs/ doc-versioning system** and the **works/ state machine** are
installed as a unit, and **only if you don't already have them**:

- If you already have `docs/index.json`, retrofit does **not** install its doc
  system into your `docs/` (no `index.json` overwrite, no scattering of
  `v0001_bootstrap.md` files). Your `docs/` is left exactly as-is. Adopt the
  versioning later by hand (see *Adopting docs versioning into an existing
  `docs/`*).
- If you already have a `works/` workspace (`works/state.json` present), retrofit
  stops — there's nothing to merge between two state machines.
- A `docs/` or `scripts/` directory that exists but doesn't contain the
  workspace's files is fine: directories are shared; only the specific managed
  files matter.

### Tier 3 — Additive, idempotent merge

Two files commonly pre-exist and are *additively* merged — your content is
preserved; only the workspace's entries are added, and re-running changes
nothing:

- **`.claude/settings.json`** — the workspace's permission entries
  (`Bash(python3 scripts/workflow.py:*)`, `Read`, `Edit`, …) are **unioned** into
  your existing `permissions.allow` / `permissions.deny`. All your other keys are
  preserved. (`.claude/settings.local.json` is never touched.) Without this, every
  workflow command would prompt for permission.
- **`CLAUDE.md` / `AGENTS.md`** — your file is kept, and a short, clearly
  delimited workspace section is appended between markers:

  ```
  <!-- BEGIN agentic-workspace -->
  > This repo uses the agentic workspace. The full operating contract is in
  > CLAUDE.workspace.md; the engine is scripts/workflow.py.
  <!-- END agentic-workspace -->
  ```

  The full contract is written alongside as **`CLAUDE.workspace.md`** /
  **`AGENTS.workspace.md`** (sidecars, not merged into your file) so you can
  reconcile the two routing contracts deliberately. Re-running replaces just the
  marked block — it never duplicates.

### Tier 4 — Stop, don't clobber

If your repo already has a **`scripts/workflow.py`**, retrofit **aborts before
writing anything**. The entire runtime shells out to `scripts/workflow.py`, so a
foreign file there would silently break `rebuild`, `validate`, and every skill.
Relocate or rename your file, or adopt the workspace manually, then re-run.

Because classification happens in a **first pass with no writes**, a Tier-4
collision means a clean abort — never a half-installed repo.

At the end, retrofit prints a **summary** of what it created, skipped, merged,
and which subsystems it installed vs. left alone.

---

## Seeding the first phase from your project's current state

A fresh bootstrap seeds a generic placeholder phase ("Bootstrap Intake"). For an
existing project, you want P1 to reflect what's already there. Pass real values:

- `--phase-name` — e.g. *"Adopt workspace + capture current architecture"*.
- `--phase-objective` — describe the existing code and the first real change you
  intend, so the `P1.DECOMP` slice has real context to decompose.

The `/retrofit` skill does this for you by reading your README, package manifest,
language, and latest commit. Either way, P1 still starts as `DECOMP` + `REVIEW`
only (the contract is unchanged) — "seeded from state" means *better starting
text*, not a different structure. Your first real work gets decomposed by
`P1.DECOMP`, exactly as on a fresh install.

---

## After retrofit — finishing the adoption

If you adopted via the `/retrofit` skill, the agent has already reconciled the
contract, checked `.gitignore`, validated, and reported — your job is to review
the diff and say "commit". If the installer was run bare, ask your agent to
finish these steps (or do them by hand):

1. **Review the diff** *(operator)*. `git status` should show only **added**
   files (plus the additive merge into `.claude/settings.json`, where your
   custom entries survive and only workspace entries were added). Nothing you
   had is deleted or rewritten.
2. **Reconcile the contract** *(agent — you decide the calls)*. If you had a
   `CLAUDE.md`, have the agent read `CLAUDE.workspace.md` and fold what you want
   into your own contract (or keep the sidecar + marker pointer). Conflicts
   between your conventions and the workspace's (e.g. branching/commit rules)
   are yours to resolve deliberately — your project's rules win where they
   disagree.
3. **Ignore Python bytecode** *(agent)*. Running `workflow.py` creates
   `scripts/__pycache__/`; the agent adds it to your `.gitignore`:

   ```
   __pycache__/
   *.pyc
   ```

   (Retrofit never edits your `.gitignore` for you.)
4. **Verify** *(agent — see below)*.
5. **Commit the adoption** *(agent, on your say-so)* — e.g.
   `chore: adopt agentic workspace`. The installer never commits, and the agent
   won't either until you've reviewed the diff.

## Verifying the adoption

The agent runs (the `/retrofit` skill already did):

```sh
python3 scripts/workflow.py validate   # -> "Workflow validation passed."
python3 scripts/workflow.py next       # -> current_phase=P1, current_slice=P1.DECOMP
```

Then confirm `works/state.json` exists and `works/phases/active/P1/phase.json`
carries the name/objective you seeded (not the placeholder). From here you drive
with `/do-next-slice` (`$do-next-slice` in Codex) — or any agent can call
`python3 scripts/workflow.py` directly.

## Re-running is safe

Retrofit is idempotent. A second `--into-existing` run over an already-adopted
repo detects the existing workspace (`works/` is present), makes no changes, and
exits cleanly (exit 0) — a safe no-op. (To re-apply the workspace after deleting
parts of it, remove `works/` first.)

---

## Manual fallback (no flag)

This is the **no-agent escape hatch** — the one genuinely by-hand path. If you
can't or don't want to use `--into-existing` (or an agent), retrofit by hand
using a throwaway staging copy — the same idea the flag automates:

1. Bootstrap a fresh workspace into an **empty temp dir**:
   `sh bootstrap_agentic_workspace.sh /tmp/ws-stage --name "…" --phase-name "…" --phase-objective "…"`.
2. Copy the workspace files that you **don't already have** into your repo —
   never overwriting: `scripts/workflow.py`, `.claude/`, `.agents/`, `.codex/`,
   `docs/` (only if you have no `docs/index.json`), `works/`, and the contract as
   `CLAUDE.workspace.md` / `AGENTS.workspace.md`. A safe copy is
   `rsync -a --ignore-existing /tmp/ws-stage/ .` followed by a `git status`
   review.
3. Union the staged `.claude/settings.json` permissions into yours by hand.
4. From your repo, run `python3 scripts/workflow.py rebuild` then `validate`.
5. Delete the temp dir.

If your repo already has a `scripts/workflow.py`, do **not** overwrite it —
relocate yours first, as the flag would force you to.

## Adopting docs versioning into an existing `docs/`

If you already have a `docs/` and retrofit skipped its versioning system, you can
adopt it later: copy `scripts/workflow.py`'s expected layout
(`docs/index.json`, `docs/current/`, `docs/versions/`) from a staged fresh
workspace, or start fresh with `doc-new-version` once `docs/index.json` exists.
Keep your existing docs as plain files alongside, and only move content into the
versioned system when you want it to be durable, regenerated truth.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "target already has scripts/workflow.py" (abort) | Tier-4 collision | Rename/relocate your `workflow.py`, then re-run. |
| "this repo already contains an agentic workspace" | `works/state.json` present | Nothing to do — use the workspace directly. |
| docs system not installed | you already have `docs/index.json` | Intended (Tier 2). Adopt manually if you want it. |
| Every workflow command prompts for permission | `.claude/settings.json` merge skipped or your tool ignores it | Confirm the workspace permission entries are present in `.claude/settings.json`. |
| `git status` shows a modified file you had | should not happen for Tier 1/2/4 | The only intended modification is the additive `.claude/settings.json` merge and the marked `CLAUDE.md` section; report anything else as a bug. |
