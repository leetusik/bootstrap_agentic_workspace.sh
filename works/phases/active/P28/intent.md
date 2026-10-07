# Intent — P28

- Captured at: 2026-10-07T11:23:01+09:00
- Origin: operator

## Original Input (verbatim)

> I recently onboarded a new company. and here is my thoughts:
> --
> 1. onboarding on co-working workspace and adapting all of my workflow could be too much for teams. 
> 2. so I'm thinking, make a branch just for me, and add all of workflow related stuff in one folder /workflow at root. leave a single note on root claude md.
> --
> what do you think? and tell me your thoughts. and I'm thikning not to gitignore the workflow folder
>
> I dont have access to the repo but let's say they have .claude/ and claude.md in that case, it's hard to add my custom agents or skills to the repo? or maybe no problem?. and for now, I prefer it's strictly mine. what would the workflow after adopting this? from start to PR
>
> no new version of this workflow needed? if needed, do it now.

## Confirmed Intent (refined + clarified)

A **nested personal install mode**: one engineer runs this workspace privately inside a host
(company) repo they don't own. The team sees **no footprint**: no branch, no tracked file and no
diff in any PR.

- **Layout.** The engine and all workflow state (`scripts/workflow.py`, `works/`, `docs/`, the
  templates, the contract) live in a **nested git repo at `/workflow`**, versioned there and
  hidden from the host by **`.git/info/exclude`** (never the host's `.gitignore`).
- **Claude Code wiring.** Skills and executors go into the host's existing (tracked) `.claude/`
  as **untracked** files listed in `.git/info/exclude`. Personal permissions and hooks go in
  **`.claude/settings.local.json`**, never the host's `settings.json`. The contract pointer is a
  root **`CLAUDE.local.md`** (verify Claude Code loads it, e.g. via `/memory`; fall back to a
  repo-scoped note in `~/.claude/CLAUDE.md` if it doesn't). The host's `CLAUDE.md` is never edited.
- **Name clashes.** At install, check the host's `.claude/skills/` and `.claude/agents/`. A
  clashing name is installed with a prefix (e.g. `wf-create-phase`) and reported; every other
  name stays the same.
- **Nothing team-visible.** No CI workflow, no `.gitattributes` merge, no host `docs/`, no
  `core.hooksPath` change, nothing in any tracked file. After install, `git status` in the host
  repo is clean.
- **Two commits per slice.** Product code goes to the host repo on the operator's ticket branch,
  in the **host's commit convention**. `works/` state goes to the `/workflow` repo in this
  workspace's convention.
- **Host commit convention.** Asked once at install: infer it from the host's `git log` and
  `CONTRIBUTING`, confirm it with the operator, and record it in `/workflow`, including whether
  Claude `Co-Authored-By` trailers are allowed in the host repo.
- **Review boundary.** `phase-scope` records the **host repo's** base commit at phase creation
  and reads the product diff from the host repo, not from the nested repo that holds `works/`.
- **Parallel worktrees** (`parallel-start` and the rest) are **disabled** in nested mode, with a
  clear refusal.
- **Paths.** The contract and the skills reach the engine and state through the `/workflow`
  prefix in nested mode; the normal at-root install is unchanged.
- **Updates.** `--update` works on a nested install with the same zero-footprint guarantees.
- **Target per-ticket flow:** branch the host's way off `origin/main` → `/create-phase` →
  `/do-whole-phase` → `/review-phase` → push and open a PR that carries no workflow traces.

## Clarifications Resolved

- Q: How should name clashes with the host's own skills and agents be handled? — A: Detect at
  install. Prefix only the clashing names, and report them.
- Q: How should the agent learn the host repo's commit convention? — A: Ask once at install.
  Infer it from git log and CONTRIBUTING, confirm it with the operator, and record it in
  `/workflow`, including whether co-author trailers are allowed.
- Q: The operator has no access to the company repo yet. What does the acceptance walkthrough run
  against? — A: **Wait for the real repo.** The acceptance gate stays open (phase `pending`)
  until the operator has tried the flow in the real company repo. A throwaway fake host repo may
  still be used for the slices' own verification, but it does not clear the gate.
- Q: Strictly private, or should teammates ever see the workflow state? — A: Strictly the
  operator's own.
- Q: Create only, or run it too? — A: Create, then run `/do-whole-phase`.

## Notes

- Today's retrofit (`--into-existing`) must not be reused as-is for this: it merges into
  `.claude/settings.json` (`installer/main.py` ~197), writes `.github/workflows/workspace-ci.yml`
  (~138), merges `.gitattributes` (~139) and writes `docs/`.
- `ROOT = Path(__file__).resolve().parents[1]` (`scripts/workflow.py:16`) already resolves to
  `/workflow` when the engine sits at `/workflow/scripts/`. The host repo root is a second root
  the engine has to learn.
- If anything ever leaves the machine, the nested repo's remote should be inside the company's
  organization, never a personal account: phase and slice files describe the company's code.
