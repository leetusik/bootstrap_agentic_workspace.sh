# Intent — P29

- Captured at: 2026-10-07T15:04:33+09:00
- Origin: operator

## Original Input (verbatim)

> I want it to be default behaviour of this workflow.sh. and if htat's the case, /update-workspace would be changed to right? go a head.

(Context: "it" is the v49 nested personal install, `--nested`, which the operator had just had explained as "repo in the repo".)

## Confirmed Intent (refined + clarified)

Make the nested personal install the installer's **default layout everywhere**:

- `sh bootstrap_agentic_workspace.sh <existing git repo>` installs nested with no flag.
- A fresh/empty directory is `git init`ed as the host and gets the nested `workflow/` install inside it — the operator's own new projects get the two-repo shape too.
- The at-root layout is reached only explicitly: `--at-root` for a fresh dir; `--into-existing` stays the committed, team-visible retrofit and implies at-root.
- `--nested` stays accepted as a harmless no-op so old commands and docs keep working.
- `--update` auto-detects the installed layout from its marker (`workflow/.agentic-nested.json` → nested; otherwise at-root) and refreshes in that layout; `--nested` is no longer needed on update. `/update-workspace` drops its separate nested branch and just runs `--update`.
- Existing at-root installs (this upstream repo, arb_upbit_1, any other) keep updating at-root — **no migration**.
- This upstream repo stays at-root; `installer/build.py` is unchanged in role.
- Ships as **v50**: CHANGELOG entry with migration notes, README.md + README.en.md, `docs/retrofit-guide.md`, skills that reference the install modes, and the rebuilt `bootstrap_agentic_workspace.sh` (`build.py --check` passes).

Accepted consequences (told to the operator, confirmed with "ok"): new personal projects are private by default (skills/agents untracked in host `.claude/`, phase history in `workflow/`); parallel worktrees (`parallel-*`) are off on nested installs, so they are off by default unless `--at-root` was used.

## Clarifications Resolved

- Q: Where should nested become the default — existing repos only, or everywhere including new projects? — A: Everywhere, new projects too.
- Q: How should /update-workspace change? — A: Auto-detect layout from the install's marker; existing at-root installs keep updating at-root, no migration.
- Q: Process? — A: Create P29 and run it (`/do-whole-phase`, auto).
- Q: Explicit flag name for the at-root layout — `--at-root` (with `--into-existing` implying it)? — A: ok.

## Notes

- The smoke suite (`retrofit_smoke.sh`) must be run alone in its own foreground Bash call.
- Real code change in `installer/main.py` plus the shipped embedded artifact: risk rating is DECOMP's call.
